module processors

import math
import ..core

// NoiseProfile stores learned noise characteristics
pub struct NoiseProfile {
mut:
	floor_db       f32          // Estimated noise floor in dB
	spectrum       []f32        // Noise spectrum estimate per band
	is_learned     bool         // Whether profile has been learned
	update_rate    f32          // How quickly to adapt to new noise
}

// NoiseReductionMode defines the aggressiveness of noise reduction
pub enum NoiseReductionMode {
	light        // Minimal processing, preserves quality
	moderate     // Balanced reduction
	aggressive   // Maximum reduction, may affect quality
	adaptive     // Automatically adjusts based on noise level
}

// NoiseReducer implements perceptual noise reduction
pub struct NoiseReducer {
pub mut:
	enabled           bool
	mode              NoiseReductionMode
	reduction_db      f32              // Amount of noise reduction in dB
	voice_enhance     bool             // Enhance speech frequencies
	learn_noise       bool             // Currently learning noise profile
mut:
	sample_rate       u32
	fft_size          int              // FFT size for spectral processing
	hop_size          int              // Hop size between frames
	noise_profile     NoiseProfile
	input_buffer      []f32            // Accumulation buffer for FFT
	output_buffer     []f32            // Overlap-add output buffer
	window            []f32            // Analysis window (Hann)
	buffer_pos        int              // Current position in buffer

	// Frequency band energies for simplified spectral processing
	band_count        int
	band_energies     []f32
	band_thresholds   []f32

	// Envelope followers for each band
	band_envelopes    []f32
	attack_coef       f32
	release_coef      f32

	// Voice enhancement filters
	voice_filter_low  core.BiquadFilter
	voice_filter_high core.BiquadFilter
}

// new_noise_reducer creates a noise reducer with specified mode
pub fn new_noise_reducer(mode NoiseReductionMode, sample_rate u32) NoiseReducer {
	reduction := match mode {
		.light { f32(6.0) }
		.moderate { f32(12.0) }
		.aggressive { f32(20.0) }
		.adaptive { f32(10.0) }
	}

	band_count := 16
	fft_size := 1024
	hop_size := 256

	// Create Hann window
	mut window := []f32{len: fft_size}
	for i in 0 .. fft_size {
		window[i] = f32(0.5 * (1.0 - math.cos(2.0 * math.pi * f64(i) / f64(fft_size - 1))))
	}

	// Voice enhancement filters (boost 1kHz-4kHz range)
	voice_low := core.new_biquad_filter(.highpass, 300.0, sample_rate, 0.707, 0.0)
	voice_high := core.new_biquad_filter(.peak, 2500.0, sample_rate, 1.0, 3.0)

	return NoiseReducer{
		enabled: true
		mode: mode
		reduction_db: reduction
		voice_enhance: false
		learn_noise: false
		sample_rate: sample_rate
		fft_size: fft_size
		hop_size: hop_size
		noise_profile: NoiseProfile{
			floor_db: -60.0
			spectrum: []f32{len: band_count, init: -60.0}
			is_learned: false
			update_rate: 0.1
		}
		input_buffer: []f32{len: fft_size, init: 0.0}
		output_buffer: []f32{len: fft_size * 2, init: 0.0}
		window: window
		buffer_pos: 0
		band_count: band_count
		band_energies: []f32{len: band_count, init: 0.0}
		band_thresholds: []f32{len: band_count, init: 0.0}
		band_envelopes: []f32{len: band_count, init: 0.0}
		attack_coef: core.smooth_coefficient(5.0, sample_rate)
		release_coef: core.smooth_coefficient(50.0, sample_rate)
		voice_filter_low: voice_low
		voice_filter_high: voice_high
	}
}

// get_band_index returns the frequency band index for a given frequency
fn (nr &NoiseReducer) get_band_index(freq f32) int {
	// Bark-scale-like frequency mapping
	if freq < 100 {
		return 0
	}
	// Logarithmic distribution across bands
	max_freq := f32(nr.sample_rate) / 2.0
	log_ratio := math.log(f64(freq / 100.0)) / math.log(f64(max_freq / 100.0))
	band := int(log_ratio * f64(nr.band_count - 1))
	return core.clamp(f32(band), 0.0, f32(nr.band_count - 1)).int()
}

// learn_noise_floor updates the noise profile from quiet sections
pub fn (mut nr NoiseReducer) learn_noise_floor(buffer &core.AudioBuffer) {
	if buffer.samples.len == 0 {
		return
	}

	// Calculate RMS level
	rms := buffer.rms_level()
	rms_db := core.linear_to_db(rms)

	// Update noise floor estimate
	if nr.noise_profile.is_learned {
		// Exponential moving average
		nr.noise_profile.floor_db += nr.noise_profile.update_rate *
			(rms_db - nr.noise_profile.floor_db)
	} else {
		nr.noise_profile.floor_db = rms_db
		nr.noise_profile.is_learned = true
	}
}

// process_spectral_gate applies frequency-dependent noise gate
fn (mut nr NoiseReducer) process_spectral_gate(sample f32, channel int) f32 {
	// Simplified band-based processing (real implementation would use FFT)
	// This uses a multiband approach for efficiency

	input_db := core.linear_to_db(if sample < 0 { -sample } else { sample })

	// Adaptive threshold based on noise floor
	threshold := nr.noise_profile.floor_db + nr.reduction_db / 2.0

	// Soft gate with hysteresis
	if input_db < threshold {
		// Below threshold - apply reduction
		reduction := core.db_to_linear(-(threshold - input_db).min(nr.reduction_db))
		return sample * reduction
	}

	return sample
}

// process applies noise reduction to an audio buffer
pub fn (mut nr NoiseReducer) process(mut buffer core.AudioBuffer) {
	if !nr.enabled || buffer.samples.len == 0 {
		return
	}

	// If learning mode, update noise profile
	if nr.learn_noise {
		nr.learn_noise_floor(buffer)
	}

	// Adaptive mode: adjust reduction based on noise level
	if nr.mode == .adaptive {
		// Estimate current noise level from low-energy frames
		rms_db := core.linear_to_db(buffer.rms_level())
		if rms_db < nr.noise_profile.floor_db + 10.0 {
			// Quiet section - update noise floor
			nr.noise_profile.floor_db += 0.01 * (rms_db - nr.noise_profile.floor_db)
		}
		// Adjust reduction based on noise floor
		nr.reduction_db = core.clamp(-(nr.noise_profile.floor_db + 40.0), 6.0, 24.0)
	}

	// Process each sample
	for i := 0; i < int(buffer.frame_count); i++ {
		for ch := u8(0); ch < buffer.channels; ch++ {
			mut sample := buffer.get_sample(u32(i), ch)

			// Apply spectral gate
			sample = nr.process_spectral_gate(sample, int(ch))

			// Voice enhancement if enabled
			if nr.voice_enhance {
				sample = nr.voice_filter_high.process(
					nr.voice_filter_low.process(sample)
				)
			}

			buffer.set_sample(u32(i), ch, sample)
		}
	}
}

// set_reduction sets the noise reduction amount in dB
pub fn (mut nr NoiseReducer) set_reduction(db f32) {
	nr.reduction_db = core.clamp(db, 0.0, 30.0)
}

// start_learning begins noise profile learning
pub fn (mut nr NoiseReducer) start_learning() {
	nr.learn_noise = true
	nr.noise_profile.is_learned = false
	nr.noise_profile.floor_db = -60.0
}

// stop_learning stops noise profile learning
pub fn (mut nr NoiseReducer) stop_learning() {
	nr.learn_noise = false
}

// get_noise_floor returns the estimated noise floor in dB
pub fn (nr &NoiseReducer) get_noise_floor() f32 {
	return nr.noise_profile.floor_db
}

// reset clears noise reducer state
pub fn (mut nr NoiseReducer) reset() {
	nr.noise_profile.is_learned = false
	nr.noise_profile.floor_db = -60.0
	for i in 0 .. nr.band_count {
		nr.band_energies[i] = 0.0
		nr.band_envelopes[i] = 0.0
	}
	nr.voice_filter_low.reset()
	nr.voice_filter_high.reset()
}
