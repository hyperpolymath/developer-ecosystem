module processors

import math
import ..core

// LoudnessStandard defines the target loudness standard
pub enum LoudnessStandard {
	ebu_r128      // -23 LUFS (broadcast)
	atsc_a85      // -24 LKFS (US broadcast)
	streaming     // -14 LUFS (Spotify, YouTube)
	custom
}

// Normalizer implements real-time loudness normalization
pub struct Normalizer {
pub mut:
	enabled        bool
	target_lufs    f32           // Target loudness in LUFS
	max_gain_db    f32           // Maximum gain boost allowed
	min_gain_db    f32           // Maximum attenuation allowed
	gate_threshold f32           // Noise gate threshold in dB
mut:
	sample_rate    u32
	integrated_sum f64           // Running sum for integrated loudness
	sample_count   u64           // Total samples processed
	momentary_buf  []f32         // 400ms momentary loudness buffer
	shortterm_buf  []f32         // 3s short-term loudness buffer
	current_gain   f32           // Current applied gain
	gain_smooth    f32           // Smoothing coefficient
	k_filter_l     core.BiquadFilter // K-weighting filter stage 1 (left)
	k_filter_l2    core.BiquadFilter // K-weighting filter stage 2 (left)
	k_filter_r     core.BiquadFilter // K-weighting filter stage 1 (right)
	k_filter_r2    core.BiquadFilter // K-weighting filter stage 2 (right)
}

// new_normalizer creates a normalizer with specified target loudness
pub fn new_normalizer(standard LoudnessStandard, sample_rate u32) Normalizer {
	target := match standard {
		.ebu_r128 { f32(-23.0) }
		.atsc_a85 { f32(-24.0) }
		.streaming { f32(-14.0) }
		.custom { f32(-16.0) }
	}

	// K-weighting pre-filter (high shelf at 1500Hz, +4dB)
	k_pre_l := core.new_biquad_filter(.highshelf, 1500.0, sample_rate, 0.707, 4.0)
	k_pre_l2 := core.new_biquad_filter(.highpass, 38.0, sample_rate, 0.5, 0.0)
	k_pre_r := core.new_biquad_filter(.highshelf, 1500.0, sample_rate, 0.707, 4.0)
	k_pre_r2 := core.new_biquad_filter(.highpass, 38.0, sample_rate, 0.5, 0.0)

	// Buffer sizes for momentary (400ms) and short-term (3s) loudness
	momentary_size := int(f32(sample_rate) * 0.4)
	shortterm_size := int(f32(sample_rate) * 3.0)

	return Normalizer{
		enabled: true
		target_lufs: target
		max_gain_db: 12.0
		min_gain_db: -24.0
		gate_threshold: -70.0
		sample_rate: sample_rate
		integrated_sum: 0.0
		sample_count: 0
		momentary_buf: []f32{len: momentary_size, init: 0.0}
		shortterm_buf: []f32{len: shortterm_size, init: 0.0}
		current_gain: 1.0
		gain_smooth: core.smooth_coefficient(100.0, sample_rate)
		k_filter_l: k_pre_l
		k_filter_l2: k_pre_l2
		k_filter_r: k_pre_r
		k_filter_r2: k_pre_r2
	}
}

// set_target_lufs sets a custom target loudness
pub fn (mut n Normalizer) set_target_lufs(lufs f32) {
	n.target_lufs = core.clamp(lufs, -60.0, 0.0)
}

// process normalizes an audio buffer in-place
pub fn (mut n Normalizer) process(mut buffer core.AudioBuffer) {
	if !n.enabled || buffer.samples.len == 0 {
		return
	}

	// Calculate current loudness using K-weighting
	mut sum_squares := f64(0.0)

	for i := 0; i < int(buffer.frame_count); i++ {
		// Get samples (mono or stereo)
		left := buffer.get_sample(u32(i), 0)
		right := if buffer.channels > 1 { buffer.get_sample(u32(i), 1) } else { left }

		// Apply K-weighting filters
		k_left := n.k_filter_l2.process(n.k_filter_l.process(left))
		k_right := n.k_filter_r2.process(n.k_filter_r.process(right))

		// Sum of squares for RMS-like measurement
		sum_squares += f64(k_left * k_left + k_right * k_right)
	}

	// Calculate block loudness in LUFS
	mean_squares := sum_squares / f64(buffer.frame_count * 2)
	block_lufs := if mean_squares > 0 {
		f32(-0.691 + 10.0 * math.log10(mean_squares))
	} else {
		f32(-120.0)
	}

	// Apply gate - only process if above threshold
	if block_lufs < n.gate_threshold {
		return
	}

	// Update integrated loudness
	n.integrated_sum += sum_squares * f64(buffer.frame_count)
	n.sample_count += u64(buffer.frame_count)

	// Calculate integrated loudness
	integrated_lufs := if n.sample_count > 0 {
		mean := n.integrated_sum / f64(n.sample_count * 2)
		if mean > 0 {
			f32(-0.691 + 10.0 * math.log10(mean))
		} else {
			f32(-120.0)
		}
	} else {
		f32(-120.0)
	}

	// Calculate required gain adjustment
	gain_db := n.target_lufs - integrated_lufs
	gain_db_clamped := core.clamp(gain_db, n.min_gain_db, n.max_gain_db)
	target_gain := core.db_to_linear(gain_db_clamped)

	// Smooth gain changes to avoid artifacts
	n.current_gain += n.gain_smooth * (target_gain - n.current_gain)

	// Apply gain to buffer
	buffer.apply_gain(n.current_gain)
}

// get_current_loudness returns the current integrated loudness in LUFS
pub fn (n &Normalizer) get_current_loudness() f32 {
	if n.sample_count == 0 {
		return -120.0
	}
	mean := n.integrated_sum / f64(n.sample_count * 2)
	if mean <= 0 {
		return -120.0
	}
	return f32(-0.691 + 10.0 * math.log10(mean))
}

// get_current_gain returns the current gain being applied in dB
pub fn (n &Normalizer) get_current_gain_db() f32 {
	return core.linear_to_db(n.current_gain)
}

// reset clears the loudness history
pub fn (mut n Normalizer) reset() {
	n.integrated_sum = 0.0
	n.sample_count = 0
	n.current_gain = 1.0
	n.k_filter_l.reset()
	n.k_filter_l2.reset()
	n.k_filter_r.reset()
	n.k_filter_r2.reset()
}
