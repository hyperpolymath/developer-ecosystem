module engine

import ..core
import ..processors

// ProcessingState represents the current state of the audio processor
pub enum ProcessingState {
	idle       // Not processing
	active     // Actively processing audio
	bypassed   // Bypass mode - no processing
	error      // Error state
}

// ProcessorConfig holds configuration for the audio processor
pub struct ProcessorConfig {
pub mut:
	sample_rate        u32
	buffer_size        u32
	channels           u8
	enable_normalizer  bool
	enable_compressor  bool
	enable_noise_redux bool
	enable_eq          bool
	enable_limiter     bool
}

// default_config returns a sensible default configuration
pub fn default_config() ProcessorConfig {
	return ProcessorConfig{
		sample_rate: 48000
		buffer_size: 512
		channels: 2
		enable_normalizer: true
		enable_compressor: true
		enable_noise_redux: true
		enable_eq: true
		enable_limiter: true
	}
}

// AudioProcessor is the main processing engine
pub struct AudioProcessor {
pub mut:
	state           ProcessingState
	bypass          bool
	config          ProcessorConfig

	// Processing modules
	normalizer      processors.Normalizer
	compressor      processors.Compressor
	noise_reducer   processors.NoiseReducer
	equalizer       processors.Equalizer
	limiter         processors.Limiter

	// Metering
	input_level_db  f32
	output_level_db f32
	gain_reduction  f32

	// Statistics
	frames_processed u64
	buffer_underruns u32
mut:
	sample_rate     u32
}

// new_audio_processor creates a new audio processor with given config
pub fn new_audio_processor(config ProcessorConfig) AudioProcessor {
	return AudioProcessor{
		state: .idle
		bypass: false
		config: config
		normalizer: processors.new_normalizer(.streaming, config.sample_rate)
		compressor: processors.new_compressor(.moderate, config.sample_rate)
		noise_reducer: processors.new_noise_reducer(.adaptive, config.sample_rate)
		equalizer: processors.new_equalizer(config.sample_rate)
		limiter: processors.new_limiter(-0.5, config.sample_rate)
		input_level_db: -120.0
		output_level_db: -120.0
		gain_reduction: 0.0
		frames_processed: 0
		buffer_underruns: 0
		sample_rate: config.sample_rate
	}
}

// process processes an audio buffer through the entire chain
pub fn (mut ap AudioProcessor) process(mut buffer core.AudioBuffer) {
	if ap.bypass || ap.state == .bypassed {
		return
	}

	ap.state = .active

	// Measure input level
	ap.input_level_db = core.linear_to_db(buffer.rms_level())

	// Processing chain:
	// 1. Noise reduction (clean up source)
	if ap.config.enable_noise_redux && ap.noise_reducer.enabled {
		ap.noise_reducer.process(mut buffer)
	}

	// 2. Normalization (achieve consistent loudness)
	if ap.config.enable_normalizer && ap.normalizer.enabled {
		ap.normalizer.process(mut buffer)
	}

	// 3. Compression (control dynamics)
	if ap.config.enable_compressor && ap.compressor.enabled {
		ap.compressor.process(mut buffer)
		ap.gain_reduction = ap.compressor.get_gain_reduction()
	}

	// 4. Equalization (shape frequency response)
	if ap.config.enable_eq && ap.equalizer.enabled {
		ap.equalizer.process(mut buffer)
	}

	// 5. Limiting (protect output)
	if ap.config.enable_limiter && ap.limiter.enabled {
		ap.limiter.process(mut buffer)
	}

	// Measure output level
	ap.output_level_db = core.linear_to_db(buffer.rms_level())

	// Update statistics
	ap.frames_processed += u64(buffer.frame_count)
}

// set_bypass enables or disables bypass mode
pub fn (mut ap AudioProcessor) set_bypass(bypass bool) {
	ap.bypass = bypass
	ap.state = if bypass { .bypassed } else { .active }
}

// toggle_bypass toggles bypass mode
pub fn (mut ap AudioProcessor) toggle_bypass() {
	ap.set_bypass(!ap.bypass)
}

// is_bypassed returns whether bypass is active
pub fn (ap &AudioProcessor) is_bypassed() bool {
	return ap.bypass
}

// set_normalizer_target sets the target loudness for normalization
pub fn (mut ap AudioProcessor) set_normalizer_target(lufs f32) {
	ap.normalizer.set_target_lufs(lufs)
}

// set_compression_mode sets the compression aggressiveness
pub fn (mut ap AudioProcessor) set_compression_mode(mode processors.CompressionMode) {
	ap.compressor = processors.new_compressor(mode, ap.sample_rate)
}

// set_noise_reduction_mode sets noise reduction aggressiveness
pub fn (mut ap AudioProcessor) set_noise_reduction_mode(mode processors.NoiseReductionMode) {
	ap.noise_reducer = processors.new_noise_reducer(mode, ap.sample_rate)
}

// set_eq_preset applies an equalizer preset
pub fn (mut ap AudioProcessor) set_eq_preset(preset processors.EQPreset) {
	ap.equalizer.apply_preset(preset)
}

// set_eq_band sets a specific EQ band gain
pub fn (mut ap AudioProcessor) set_eq_band(band int, gain_db f32) {
	ap.equalizer.set_band_gain(band, gain_db)
}

// enable_voice_enhancement enables voice clarity enhancement
pub fn (mut ap AudioProcessor) enable_voice_enhancement(enable bool) {
	ap.noise_reducer.voice_enhance = enable
}

// start_noise_learning starts learning the noise profile
pub fn (mut ap AudioProcessor) start_noise_learning() {
	ap.noise_reducer.start_learning()
}

// stop_noise_learning stops learning the noise profile
pub fn (mut ap AudioProcessor) stop_noise_learning() {
	ap.noise_reducer.stop_learning()
}

// get_levels returns current input/output levels in dB
pub fn (ap &AudioProcessor) get_levels() (f32, f32) {
	return ap.input_level_db, ap.output_level_db
}

// get_stats returns processing statistics
pub fn (ap &AudioProcessor) get_stats() (u64, u32) {
	return ap.frames_processed, ap.buffer_underruns
}

// reset resets all processor states
pub fn (mut ap AudioProcessor) reset() {
	ap.normalizer.reset()
	ap.compressor.reset()
	ap.noise_reducer.reset()
	ap.equalizer.reset()
	ap.limiter.reset()
	ap.frames_processed = 0
	ap.buffer_underruns = 0
	ap.input_level_db = -120.0
	ap.output_level_db = -120.0
}
