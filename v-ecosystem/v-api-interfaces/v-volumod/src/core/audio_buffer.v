module core

// AudioBuffer represents a block of audio samples for processing
pub struct AudioBuffer {
pub mut:
	samples      []f32  // Interleaved audio samples
	sample_rate  u32    // Sample rate in Hz (e.g., 44100, 48000)
	channels     u8     // Number of channels (1=mono, 2=stereo)
	frame_count  u32    // Number of frames (samples per channel)
}

// new_audio_buffer creates a new audio buffer with specified parameters
pub fn new_audio_buffer(sample_rate u32, channels u8, frame_count u32) AudioBuffer {
	total_samples := int(frame_count * u32(channels))
	return AudioBuffer{
		samples: []f32{len: total_samples, init: 0.0}
		sample_rate: sample_rate
		channels: channels
		frame_count: frame_count
	}
}

// from_samples creates an audio buffer from existing sample data
pub fn from_samples(samples []f32, sample_rate u32, channels u8) AudioBuffer {
	frame_count := u32(samples.len) / u32(channels)
	return AudioBuffer{
		samples: samples.clone()
		sample_rate: sample_rate
		channels: channels
		frame_count: frame_count
	}
}

// get_sample retrieves a sample at the given frame and channel
pub fn (b &AudioBuffer) get_sample(frame u32, channel u8) f32 {
	if frame >= b.frame_count || channel >= b.channels {
		return 0.0
	}
	idx := int(frame * u32(b.channels) + u32(channel))
	return b.samples[idx]
}

// set_sample sets a sample at the given frame and channel
pub fn (mut b AudioBuffer) set_sample(frame u32, channel u8, value f32) {
	if frame >= b.frame_count || channel >= b.channels {
		return
	}
	idx := int(frame * u32(b.channels) + u32(channel))
	b.samples[idx] = value
}

// peak_level calculates the peak amplitude across all samples
pub fn (b &AudioBuffer) peak_level() f32 {
	mut peak := f32(0.0)
	for sample in b.samples {
		abs_sample := if sample < 0 { -sample } else { sample }
		if abs_sample > peak {
			peak = abs_sample
		}
	}
	return peak
}

// rms_level calculates the RMS (root mean square) level
pub fn (b &AudioBuffer) rms_level() f32 {
	if b.samples.len == 0 {
		return 0.0
	}
	mut sum_squares := f64(0.0)
	for sample in b.samples {
		sum_squares += f64(sample) * f64(sample)
	}
	import math
	return f32(math.sqrt(sum_squares / f64(b.samples.len)))
}

// apply_gain multiplies all samples by a gain factor
pub fn (mut b AudioBuffer) apply_gain(gain f32) {
	for i in 0 .. b.samples.len {
		b.samples[i] *= gain
	}
}

// mix combines another buffer into this one with optional gain
pub fn (mut b AudioBuffer) mix(other &AudioBuffer, gain f32) {
	if b.samples.len != other.samples.len {
		return
	}
	for i in 0 .. b.samples.len {
		b.samples[i] += other.samples[i] * gain
	}
}

// clear zeros out all samples
pub fn (mut b AudioBuffer) clear() {
	for i in 0 .. b.samples.len {
		b.samples[i] = 0.0
	}
}

// clone creates a deep copy of the buffer
pub fn (b &AudioBuffer) clone() AudioBuffer {
	return AudioBuffer{
		samples: b.samples.clone()
		sample_rate: b.sample_rate
		channels: b.channels
		frame_count: b.frame_count
	}
}

// duration_ms returns the buffer duration in milliseconds
pub fn (b &AudioBuffer) duration_ms() f64 {
	return f64(b.frame_count) / f64(b.sample_rate) * 1000.0
}
