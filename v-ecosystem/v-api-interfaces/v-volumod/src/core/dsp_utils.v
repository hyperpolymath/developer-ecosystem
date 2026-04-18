module core

import math

// db_to_linear converts decibels to linear amplitude
pub fn db_to_linear(db f32) f32 {
	return f32(math.pow(10.0, f64(db) / 20.0))
}

// linear_to_db converts linear amplitude to decibels
pub fn linear_to_db(linear f32) f32 {
	if linear <= 0.0 {
		return -120.0 // Effectively silence
	}
	return f32(20.0 * math.log10(f64(linear)))
}

// clamp restricts a value to a range
pub fn clamp(value f32, min_val f32, max_val f32) f32 {
	if value < min_val {
		return min_val
	}
	if value > max_val {
		return max_val
	}
	return value
}

// lerp performs linear interpolation between two values
pub fn lerp(a f32, b f32, t f32) f32 {
	return a + (b - a) * t
}

// smooth_coefficient calculates a smoothing coefficient for exponential smoothing
// time_constant_ms: time for signal to reach ~63% of target
// sample_rate: audio sample rate
pub fn smooth_coefficient(time_constant_ms f32, sample_rate u32) f32 {
	if time_constant_ms <= 0.0 {
		return 1.0
	}
	samples := time_constant_ms * f32(sample_rate) / 1000.0
	return f32(1.0 - math.exp(-1.0 / f64(samples)))
}

// EnvelopeFollower tracks the amplitude envelope of a signal
pub struct EnvelopeFollower {
mut:
	envelope     f32
	attack_coef  f32
	release_coef f32
}

// new_envelope_follower creates an envelope follower with attack/release times in ms
pub fn new_envelope_follower(attack_ms f32, release_ms f32, sample_rate u32) EnvelopeFollower {
	return EnvelopeFollower{
		envelope: 0.0
		attack_coef: smooth_coefficient(attack_ms, sample_rate)
		release_coef: smooth_coefficient(release_ms, sample_rate)
	}
}

// process updates the envelope with a new sample and returns current envelope
pub fn (mut ef EnvelopeFollower) process(input f32) f32 {
	abs_input := if input < 0 { -input } else { input }
	if abs_input > ef.envelope {
		ef.envelope += ef.attack_coef * (abs_input - ef.envelope)
	} else {
		ef.envelope += ef.release_coef * (abs_input - ef.envelope)
	}
	return ef.envelope
}

// reset clears the envelope state
pub fn (mut ef EnvelopeFollower) reset() {
	ef.envelope = 0.0
}

// BiquadFilter implements a second-order IIR filter
pub struct BiquadFilter {
mut:
	b0 f32
	b1 f32
	b2 f32
	a1 f32
	a2 f32
	x1 f32
	x2 f32
	y1 f32
	y2 f32
}

// FilterType defines the type of biquad filter
pub enum FilterType {
	lowpass
	highpass
	bandpass
	notch
	peak
	lowshelf
	highshelf
}

// new_biquad_filter creates a biquad filter with specified parameters
pub fn new_biquad_filter(filter_type FilterType, frequency f32, sample_rate u32, q f32, gain_db f32) BiquadFilter {
	w0 := 2.0 * math.pi * f64(frequency) / f64(sample_rate)
	cos_w0 := f32(math.cos(w0))
	sin_w0 := f32(math.sin(w0))
	alpha := sin_w0 / (2.0 * q)
	a := db_to_linear(gain_db / 2.0)

	mut b0, mut b1, mut b2, mut a0, mut a1, mut a2 := f32(0), f32(0), f32(0), f32(0), f32(0), f32(0)

	match filter_type {
		.lowpass {
			b0 = (1.0 - cos_w0) / 2.0
			b1 = 1.0 - cos_w0
			b2 = (1.0 - cos_w0) / 2.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		}
		.highpass {
			b0 = (1.0 + cos_w0) / 2.0
			b1 = -(1.0 + cos_w0)
			b2 = (1.0 + cos_w0) / 2.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		}
		.bandpass {
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		}
		.notch {
			b0 = 1.0
			b1 = -2.0 * cos_w0
			b2 = 1.0
			a0 = 1.0 + alpha
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha
		}
		.peak {
			b0 = 1.0 + alpha * a
			b1 = -2.0 * cos_w0
			b2 = 1.0 - alpha * a
			a0 = 1.0 + alpha / a
			a1 = -2.0 * cos_w0
			a2 = 1.0 - alpha / a
		}
		.lowshelf {
			sqrt_a := f32(math.sqrt(f64(a)))
			b0 = a * ((a + 1.0) - (a - 1.0) * cos_w0 + 2.0 * sqrt_a * alpha)
			b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cos_w0)
			b2 = a * ((a + 1.0) - (a - 1.0) * cos_w0 - 2.0 * sqrt_a * alpha)
			a0 = (a + 1.0) + (a - 1.0) * cos_w0 + 2.0 * sqrt_a * alpha
			a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cos_w0)
			a2 = (a + 1.0) + (a - 1.0) * cos_w0 - 2.0 * sqrt_a * alpha
		}
		.highshelf {
			sqrt_a := f32(math.sqrt(f64(a)))
			b0 = a * ((a + 1.0) + (a - 1.0) * cos_w0 + 2.0 * sqrt_a * alpha)
			b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cos_w0)
			b2 = a * ((a + 1.0) + (a - 1.0) * cos_w0 - 2.0 * sqrt_a * alpha)
			a0 = (a + 1.0) - (a - 1.0) * cos_w0 + 2.0 * sqrt_a * alpha
			a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cos_w0)
			a2 = (a + 1.0) - (a - 1.0) * cos_w0 - 2.0 * sqrt_a * alpha
		}
	}

	// Normalize coefficients
	return BiquadFilter{
		b0: b0 / a0
		b1: b1 / a0
		b2: b2 / a0
		a1: a1 / a0
		a2: a2 / a0
		x1: 0.0
		x2: 0.0
		y1: 0.0
		y2: 0.0
	}
}

// process filters a single sample
pub fn (mut f BiquadFilter) process(input f32) f32 {
	output := f.b0 * input + f.b1 * f.x1 + f.b2 * f.x2 - f.a1 * f.y1 - f.a2 * f.y2
	f.x2 = f.x1
	f.x1 = input
	f.y2 = f.y1
	f.y1 = output
	return output
}

// reset clears filter state
pub fn (mut f BiquadFilter) reset() {
	f.x1 = 0.0
	f.x2 = 0.0
	f.y1 = 0.0
	f.y2 = 0.0
}
