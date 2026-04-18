module processors

import ..core

// EQBand represents a single equalizer band
pub struct EQBand {
pub mut:
	frequency    f32              // Center frequency in Hz
	gain_db      f32              // Gain in dB (-24 to +24)
	q            f32              // Q factor (bandwidth)
	filter_type  core.FilterType  // Type of filter
mut:
	filter_l     core.BiquadFilter // Left channel filter
	filter_r     core.BiquadFilter // Right channel filter
}

// EQPreset defines preset equalizer configurations
pub enum EQPreset {
	flat           // No adjustment
	speech         // Optimized for voice clarity
	music          // Balanced for music listening
	bass_boost     // Enhanced low frequencies
	treble_boost   // Enhanced high frequencies
	loudness       // Psychoacoustic loudness curve
	hearing_aid    // Compensates for common hearing loss patterns
	night_mode     // Reduced bass for quiet listening
}

// Equalizer implements a multi-band graphic/parametric equalizer
pub struct Equalizer {
pub mut:
	enabled      bool
	bands        []EQBand
	output_gain  f32         // Master output gain in dB
mut:
	sample_rate  u32
}

// new_equalizer creates an equalizer with default 10-band configuration
pub fn new_equalizer(sample_rate u32) Equalizer {
	// Standard 10-band frequencies (ISO standard)
	frequencies := [f32(31.0), 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]

	mut bands := []EQBand{}
	for freq in frequencies {
		mut band := EQBand{
			frequency: freq
			gain_db: 0.0
			q: 1.414  // ~1 octave bandwidth
			filter_type: .peak
			filter_l: core.new_biquad_filter(.peak, freq, sample_rate, 1.414, 0.0)
			filter_r: core.new_biquad_filter(.peak, freq, sample_rate, 1.414, 0.0)
		}
		bands << band
	}

	return Equalizer{
		enabled: true
		bands: bands
		output_gain: 0.0
		sample_rate: sample_rate
	}
}

// apply_preset applies a predefined EQ curve
pub fn (mut eq Equalizer) apply_preset(preset EQPreset) {
	// Gain values for each of the 10 bands
	gains := match preset {
		.flat {
			[f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
		.speech {
			// Boost presence range, cut lows
			[f32(-6), -4, -2, 0, 2, 4, 4, 2, 0, -2]
		}
		.music {
			// Slight smile curve
			[f32(2), 1, 0, -1, 0, 0, 1, 2, 2, 1]
		}
		.bass_boost {
			[f32(6), 5, 3, 1, 0, 0, 0, 0, 0, 0]
		}
		.treble_boost {
			[f32(0), 0, 0, 0, 0, 1, 2, 4, 5, 6]
		}
		.loudness {
			// Fletcher-Munson inspired curve
			[f32(6), 4, 1, 0, -1, 0, 1, 3, 4, 3]
		}
		.hearing_aid {
			// Compensate for presbycusis (age-related hearing loss)
			[f32(0), 0, 0, 0, 1, 3, 5, 7, 9, 10]
		}
		.night_mode {
			// Reduce bass, slight presence boost
			[f32(-8), -6, -3, -1, 0, 2, 2, 1, 0, -1]
		}
	}

	for i, gain in gains {
		if i < eq.bands.len {
			eq.set_band_gain(i, gain)
		}
	}
}

// set_band_gain sets the gain for a specific band
pub fn (mut eq Equalizer) set_band_gain(band_index int, gain_db f32) {
	if band_index < 0 || band_index >= eq.bands.len {
		return
	}

	clamped_gain := core.clamp(gain_db, -24.0, 24.0)
	eq.bands[band_index].gain_db = clamped_gain

	// Rebuild filters with new gain
	freq := eq.bands[band_index].frequency
	q := eq.bands[band_index].q
	eq.bands[band_index].filter_l = core.new_biquad_filter(.peak, freq, eq.sample_rate, q, clamped_gain)
	eq.bands[band_index].filter_r = core.new_biquad_filter(.peak, freq, eq.sample_rate, q, clamped_gain)
}

// set_all_gains sets all band gains from an array
pub fn (mut eq Equalizer) set_all_gains(gains []f32) {
	for i, gain in gains {
		if i < eq.bands.len {
			eq.set_band_gain(i, gain)
		}
	}
}

// get_band_gains returns all band gains as an array
pub fn (eq &Equalizer) get_band_gains() []f32 {
	mut gains := []f32{len: eq.bands.len}
	for i, band in eq.bands {
		gains[i] = band.gain_db
	}
	return gains
}

// process applies equalization to an audio buffer
pub fn (mut eq Equalizer) process(mut buffer core.AudioBuffer) {
	if !eq.enabled || buffer.samples.len == 0 {
		return
	}

	// Skip processing if all bands are at 0 dB
	mut has_active_band := false
	for band in eq.bands {
		if band.gain_db != 0.0 {
			has_active_band = true
			break
		}
	}
	if !has_active_band && eq.output_gain == 0.0 {
		return
	}

	// Process each sample through all bands
	for i := 0; i < int(buffer.frame_count); i++ {
		// Left channel (or mono)
		mut left := buffer.get_sample(u32(i), 0)
		for j in 0 .. eq.bands.len {
			left = eq.bands[j].filter_l.process(left)
		}
		buffer.set_sample(u32(i), 0, left)

		// Right channel if stereo
		if buffer.channels > 1 {
			mut right := buffer.get_sample(u32(i), 1)
			for j in 0 .. eq.bands.len {
				right = eq.bands[j].filter_r.process(right)
			}
			buffer.set_sample(u32(i), 1, right)
		}
	}

	// Apply output gain
	if eq.output_gain != 0.0 {
		buffer.apply_gain(core.db_to_linear(eq.output_gain))
	}
}

// reset clears all filter states
pub fn (mut eq Equalizer) reset() {
	for mut band in eq.bands {
		band.filter_l.reset()
		band.filter_r.reset()
	}
}

// AdaptiveEqualizer extends Equalizer with automatic adjustment
pub struct AdaptiveEqualizer {
	Equalizer
pub mut:
	auto_adjust     bool        // Enable automatic adjustment
	target_curve    EQPreset    // Target frequency response
	adaptation_rate f32         // How quickly to adapt (0-1)
mut:
	band_history    [][]f32     // History of band energies for analysis
	history_index   int
}

// new_adaptive_equalizer creates an adaptive equalizer
pub fn new_adaptive_equalizer(sample_rate u32) AdaptiveEqualizer {
	mut aeq := AdaptiveEqualizer{
		Equalizer: new_equalizer(sample_rate)
		auto_adjust: false
		target_curve: .flat
		adaptation_rate: 0.01
		history_index: 0
	}

	// Initialize history buffers
	for _ in 0 .. aeq.bands.len {
		aeq.band_history << []f32{len: 10, init: 0.0}
	}

	return aeq
}

// analyze_and_adjust analyzes audio and adjusts EQ automatically
pub fn (mut aeq AdaptiveEqualizer) analyze_and_adjust(buffer &core.AudioBuffer) {
	if !aeq.auto_adjust || buffer.samples.len == 0 {
		return
	}

	// Simple band energy analysis
	// In a real implementation, this would use FFT for accurate measurement

	// Get target gains for the selected curve
	target_gains := match aeq.target_curve {
		.flat { [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0] }
		.speech { [f32(-6), -4, -2, 0, 2, 4, 4, 2, 0, -2] }
		.music { [f32(2), 1, 0, -1, 0, 0, 1, 2, 2, 1] }
		else { [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0] }
	}

	// Gradually move toward target
	for i in 0 .. aeq.bands.len {
		if i < target_gains.len {
			current := aeq.bands[i].gain_db
			target := target_gains[i]
			new_gain := current + aeq.adaptation_rate * (target - current)
			aeq.set_band_gain(i, new_gain)
		}
	}
}
