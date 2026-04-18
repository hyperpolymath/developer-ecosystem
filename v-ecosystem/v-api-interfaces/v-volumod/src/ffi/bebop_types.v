module ffi

// Bebop-compatible type definitions for cross-platform interoperability
// These types can be serialized/deserialized via Bebop for IPC

// AudioConfig represents audio configuration for FFI
[serializable]
pub struct AudioConfig {
pub mut:
	sample_rate     u32
	channels        u8
	buffer_size     u32
	bit_depth       u8
}

// ProcessorState represents the current processor state for FFI
[serializable]
pub struct ProcessorState {
pub mut:
	is_active       bool
	is_bypassed     bool
	input_level_db  f32
	output_level_db f32
	gain_reduction  f32
	preset_name     string
}

// NormalizerSettings represents normalizer configuration
[serializable]
pub struct NormalizerSettings {
pub mut:
	enabled         bool
	target_lufs     f32
	max_gain_db     f32
	min_gain_db     f32
}

// CompressorSettings represents compressor configuration
[serializable]
pub struct CompressorSettings {
pub mut:
	enabled         bool
	threshold_db    f32
	ratio           f32
	attack_ms       f32
	release_ms      f32
	knee_db         f32
	makeup_gain_db  f32
}

// NoiseReducerSettings represents noise reducer configuration
[serializable]
pub struct NoiseReducerSettings {
pub mut:
	enabled         bool
	mode            u8     // 0=light, 1=moderate, 2=aggressive, 3=adaptive
	reduction_db    f32
	voice_enhance   bool
	noise_floor_db  f32
}

// EqualizerSettings represents equalizer configuration
[serializable]
pub struct EqualizerSettings {
pub mut:
	enabled         bool
	preset          u8     // Preset index
	band_gains      []f32  // Gains for each band
	output_gain_db  f32
}

// ContextSettings represents context manager configuration
[serializable]
pub struct ContextSettings {
pub mut:
	enabled           bool
	auto_time         bool
	auto_device       bool
	auto_ambient      bool
	current_time      u8    // 0=morning, 1=afternoon, 2=evening, 3=night
	current_device    string
	current_env       string
}

// Command represents a command from UI to audio engine
[serializable]
pub struct Command {
pub mut:
	cmd_type        u8     // Command type enum
	param_int       i32
	param_float     f32
	param_string    string
	param_bytes     []u8
}

// CommandType defines available commands
pub enum CommandType as u8 {
	set_bypass = 0
	set_preset = 1
	set_normalizer_target = 2
	set_compression_mode = 3
	set_noise_mode = 4
	set_eq_band = 5
	start_noise_learn = 6
	stop_noise_learn = 7
	reset = 8
	get_state = 9
	get_levels = 10
}

// Response represents a response from audio engine to UI
[serializable]
pub struct Response {
pub mut:
	success         bool
	error_message   string
	state           ProcessorState
	data            []u8
}

// AudioData represents a block of audio samples for FFI
[serializable]
pub struct AudioData {
pub mut:
	samples         []f32
	sample_rate     u32
	channels        u8
	frame_count     u32
	timestamp_ms    u64
}

// Meter data for UI visualization
[serializable]
pub struct MeterData {
pub mut:
	input_peak_db   f32
	input_rms_db    f32
	output_peak_db  f32
	output_rms_db   f32
	gain_reduction  f32
	timestamp_ms    u64
}

// DeviceInfo represents an audio device
[serializable]
pub struct DeviceInfo {
pub mut:
	id              string
	name            string
	device_type     u8    // 0=output, 1=input
	is_default      bool
	sample_rates    []u32
	channels        u8
}

// DeviceList represents available audio devices
[serializable]
pub struct DeviceList {
pub mut:
	output_devices  []DeviceInfo
	input_devices   []DeviceInfo
}
