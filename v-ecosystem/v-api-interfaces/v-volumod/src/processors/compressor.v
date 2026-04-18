module processors

import math
import ..core

// CompressionMode defines the compression behavior
pub enum CompressionMode {
	gentle      // Light compression for general listening
	moderate    // Balanced compression for mixed content
	aggressive  // Heavy compression for loud environments
	limiting    // Brick-wall limiting for protection
}

// Compressor implements dynamic range compression with adaptive behavior
pub struct Compressor {
pub mut:
	enabled        bool
	threshold_db   f32    // Level above which compression begins
	ratio          f32    // Compression ratio (e.g., 4:1)
	attack_ms      f32    // Attack time in milliseconds
	release_ms     f32    // Release time in milliseconds
	knee_db        f32    // Soft knee width in dB
	makeup_gain_db f32    // Output gain compensation
	auto_makeup    bool   // Automatically calculate makeup gain
mut:
	sample_rate     u32
	envelope        f32
	attack_coef     f32
	release_coef    f32
	gain_reduction  f32   // Current gain reduction in dB (for metering)
}

// new_compressor creates a compressor with default settings
pub fn new_compressor(mode CompressionMode, sample_rate u32) Compressor {
	mut c := Compressor{
		enabled: true
		sample_rate: sample_rate
		envelope: 0.0
		gain_reduction: 0.0
	}

	match mode {
		.gentle {
			c.threshold_db = -20.0
			c.ratio = 2.0
			c.attack_ms = 20.0
			c.release_ms = 200.0
			c.knee_db = 6.0
			c.makeup_gain_db = 2.0
			c.auto_makeup = true
		}
		.moderate {
			c.threshold_db = -18.0
			c.ratio = 4.0
			c.attack_ms = 10.0
			c.release_ms = 150.0
			c.knee_db = 4.0
			c.makeup_gain_db = 4.0
			c.auto_makeup = true
		}
		.aggressive {
			c.threshold_db = -15.0
			c.ratio = 8.0
			c.attack_ms = 5.0
			c.release_ms = 100.0
			c.knee_db = 2.0
			c.makeup_gain_db = 6.0
			c.auto_makeup = true
		}
		.limiting {
			c.threshold_db = -1.0
			c.ratio = 20.0
			c.attack_ms = 0.5
			c.release_ms = 50.0
			c.knee_db = 0.0
			c.makeup_gain_db = 0.0
			c.auto_makeup = false
		}
	}

	c.attack_coef = core.smooth_coefficient(c.attack_ms, sample_rate)
	c.release_coef = core.smooth_coefficient(c.release_ms, sample_rate)

	return c
}

// set_attack sets attack time and recalculates coefficient
pub fn (mut c Compressor) set_attack(attack_ms f32) {
	c.attack_ms = core.clamp(attack_ms, 0.1, 500.0)
	c.attack_coef = core.smooth_coefficient(c.attack_ms, c.sample_rate)
}

// set_release sets release time and recalculates coefficient
pub fn (mut c Compressor) set_release(release_ms f32) {
	c.release_ms = core.clamp(release_ms, 10.0, 2000.0)
	c.release_coef = core.smooth_coefficient(c.release_ms, c.sample_rate)
}

// compute_gain calculates the gain reduction for a given input level
fn (c &Compressor) compute_gain(input_db f32) f32 {
	// Below threshold - no compression
	if input_db < c.threshold_db - c.knee_db / 2.0 {
		return 0.0
	}

	// Above threshold + knee - full compression
	if input_db > c.threshold_db + c.knee_db / 2.0 {
		return (c.threshold_db + (input_db - c.threshold_db) / c.ratio) - input_db
	}

	// Within knee - soft compression
	knee_start := c.threshold_db - c.knee_db / 2.0
	x := input_db - knee_start
	return (1.0 / c.ratio - 1.0) * x * x / (2.0 * c.knee_db)
}

// process applies compression to an audio buffer
pub fn (mut c Compressor) process(mut buffer core.AudioBuffer) {
	if !c.enabled || buffer.samples.len == 0 {
		return
	}

	// Calculate makeup gain
	makeup_linear := core.db_to_linear(c.makeup_gain_db)

	for i := 0; i < int(buffer.frame_count); i++ {
		// Find peak across all channels for this frame
		mut peak := f32(0.0)
		for ch := u8(0); ch < buffer.channels; ch++ {
			sample := buffer.get_sample(u32(i), ch)
			abs_sample := if sample < 0 { -sample } else { sample }
			if abs_sample > peak {
				peak = abs_sample
			}
		}

		// Convert to dB
		input_db := core.linear_to_db(peak)

		// Envelope follower with attack/release
		if input_db > c.envelope {
			c.envelope += c.attack_coef * (input_db - c.envelope)
		} else {
			c.envelope += c.release_coef * (input_db - c.envelope)
		}

		// Calculate gain reduction
		gr_db := c.compute_gain(c.envelope)
		c.gain_reduction = -gr_db // Store for metering (positive value)

		// Apply gain reduction and makeup
		gain := core.db_to_linear(gr_db) * makeup_linear

		// Apply to all channels
		for ch := u8(0); ch < buffer.channels; ch++ {
			sample := buffer.get_sample(u32(i), ch)
			buffer.set_sample(u32(i), ch, sample * gain)
		}
	}
}

// get_gain_reduction returns current gain reduction in dB (positive value)
pub fn (c &Compressor) get_gain_reduction() f32 {
	return c.gain_reduction
}

// reset clears compressor state
pub fn (mut c Compressor) reset() {
	c.envelope = 0.0
	c.gain_reduction = 0.0
}

// Limiter is a specialized compressor for peak limiting
pub struct Limiter {
pub mut:
	enabled      bool
	ceiling_db   f32   // Maximum output level
	release_ms   f32   // Release time
mut:
	sample_rate  u32
	envelope     f32
	release_coef f32
}

// new_limiter creates a brick-wall limiter
pub fn new_limiter(ceiling_db f32, sample_rate u32) Limiter {
	return Limiter{
		enabled: true
		ceiling_db: ceiling_db
		release_ms: 50.0
		sample_rate: sample_rate
		envelope: 0.0
		release_coef: core.smooth_coefficient(50.0, sample_rate)
	}
}

// process applies limiting to an audio buffer
pub fn (mut l Limiter) process(mut buffer core.AudioBuffer) {
	if !l.enabled || buffer.samples.len == 0 {
		return
	}

	ceiling_linear := core.db_to_linear(l.ceiling_db)

	for i := 0; i < int(buffer.frame_count); i++ {
		// Find peak
		mut peak := f32(0.0)
		for ch := u8(0); ch < buffer.channels; ch++ {
			sample := buffer.get_sample(u32(i), ch)
			abs_sample := if sample < 0 { -sample } else { sample }
			if abs_sample > peak {
				peak = abs_sample
			}
		}

		// Calculate required attenuation
		if peak > ceiling_linear {
			target_atten := ceiling_linear / peak
			// Instant attack for limiting
			if target_atten < l.envelope || l.envelope == 0.0 {
				l.envelope = target_atten
			} else {
				l.envelope += l.release_coef * (1.0 - l.envelope)
			}
		} else {
			l.envelope += l.release_coef * (1.0 - l.envelope)
		}

		// Apply attenuation
		if l.envelope < 1.0 {
			for ch := u8(0); ch < buffer.channels; ch++ {
				sample := buffer.get_sample(u32(i), ch)
				buffer.set_sample(u32(i), ch, sample * l.envelope)
			}
		}
	}
}

// reset clears limiter state
pub fn (mut l Limiter) reset() {
	l.envelope = 1.0
}
