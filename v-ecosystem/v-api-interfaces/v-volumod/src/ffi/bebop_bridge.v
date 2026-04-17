module ffi

import ..engine
import ..core

// BebopBridge provides FFI interface for cross-platform communication
pub struct BebopBridge {
mut:
	processor     &engine.AudioProcessor = unsafe { nil }
	context       &engine.ContextManager = unsafe { nil }
	last_meter    MeterData
}

// new_bebop_bridge creates a new Bebop FFI bridge
pub fn new_bebop_bridge(processor &engine.AudioProcessor, context &engine.ContextManager) BebopBridge {
	return BebopBridge{
		processor: processor
		context: context
		last_meter: MeterData{}
	}
}

// serialize_state serializes current processor state
pub fn (bb &BebopBridge) serialize_state() []u8 {
	if bb.processor == unsafe { nil } {
		return []
	}

	state := ProcessorState{
		is_active: bb.processor.state == .active
		is_bypassed: bb.processor.bypass
		input_level_db: bb.processor.input_level_db
		output_level_db: bb.processor.output_level_db
		gain_reduction: bb.processor.gain_reduction
		preset_name: 'Auto'
	}

	// Simple serialization (in real implementation, use Bebop)
	return serialize_processor_state(state)
}

// handle_command processes a command and returns response
pub fn (mut bb BebopBridge) handle_command(cmd_bytes []u8) []u8 {
	cmd := deserialize_command(cmd_bytes)

	mut response := Response{
		success: true
		error_message: ''
		state: ProcessorState{}
		data: []
	}

	if bb.processor == unsafe { nil } {
		response.success = false
		response.error_message = 'Processor not initialized'
		return serialize_response(response)
	}

	cmd_type := unsafe { CommandType(cmd.cmd_type) }

	match cmd_type {
		.set_bypass {
			bb.processor.set_bypass(cmd.param_int != 0)
		}
		.set_preset {
			// Map preset index to EQ preset
			// This is simplified - real implementation would have more presets
			bb.processor.set_eq_preset(.flat)
		}
		.set_normalizer_target {
			bb.processor.set_normalizer_target(cmd.param_float)
		}
		.set_compression_mode {
			mode := match cmd.param_int {
				0 { engine.processors.CompressionMode.gentle }
				1 { engine.processors.CompressionMode.moderate }
				2 { engine.processors.CompressionMode.aggressive }
				else { engine.processors.CompressionMode.limiting }
			}
			bb.processor.set_compression_mode(mode)
		}
		.set_noise_mode {
			mode := match cmd.param_int {
				0 { engine.processors.NoiseReductionMode.light }
				1 { engine.processors.NoiseReductionMode.moderate }
				2 { engine.processors.NoiseReductionMode.aggressive }
				else { engine.processors.NoiseReductionMode.adaptive }
			}
			bb.processor.set_noise_reduction_mode(mode)
		}
		.set_eq_band {
			// param_int = band index, param_float = gain
			bb.processor.set_eq_band(cmd.param_int, cmd.param_float)
		}
		.start_noise_learn {
			bb.processor.start_noise_learning()
		}
		.stop_noise_learn {
			bb.processor.stop_noise_learning()
		}
		.reset {
			bb.processor.reset()
		}
		.get_state {
			response.state = ProcessorState{
				is_active: bb.processor.state == .active
				is_bypassed: bb.processor.bypass
				input_level_db: bb.processor.input_level_db
				output_level_db: bb.processor.output_level_db
				gain_reduction: bb.processor.gain_reduction
				preset_name: 'Auto'
			}
		}
		.get_levels {
			input, output := bb.processor.get_levels()
			response.state.input_level_db = input
			response.state.output_level_db = output
		}
	}

	return serialize_response(response)
}

// process_audio processes audio data through the bridge
pub fn (mut bb BebopBridge) process_audio(audio_bytes []u8) []u8 {
	audio_data := deserialize_audio_data(audio_bytes)

	mut buffer := core.from_samples(
		audio_data.samples,
		audio_data.sample_rate,
		audio_data.channels
	)

	if bb.processor != unsafe { nil } {
		bb.processor.process(mut buffer)
	}

	// Update meter data
	bb.last_meter = MeterData{
		input_peak_db: bb.processor.input_level_db
		input_rms_db: bb.processor.input_level_db
		output_peak_db: bb.processor.output_level_db
		output_rms_db: bb.processor.output_level_db
		gain_reduction: bb.processor.gain_reduction
		timestamp_ms: audio_data.timestamp_ms
	}

	result := AudioData{
		samples: buffer.samples
		sample_rate: audio_data.sample_rate
		channels: audio_data.channels
		frame_count: audio_data.frame_count
		timestamp_ms: audio_data.timestamp_ms
	}

	return serialize_audio_data(result)
}

// get_meter_data returns current meter data
pub fn (bb &BebopBridge) get_meter_data() []u8 {
	return serialize_meter_data(bb.last_meter)
}

// Simple serialization helpers (placeholder - real implementation uses Bebop)

fn serialize_processor_state(state ProcessorState) []u8 {
	// Simplified binary serialization
	mut data := []u8{}
	data << u8(if state.is_active { 1 } else { 0 })
	data << u8(if state.is_bypassed { 1 } else { 0 })
	// Add float bytes...
	return data
}

fn deserialize_command(data []u8) Command {
	if data.len == 0 {
		return Command{}
	}
	return Command{
		cmd_type: data[0]
		param_int: 0
		param_float: 0.0
		param_string: ''
		param_bytes: []
	}
}

fn serialize_response(response Response) []u8 {
	mut data := []u8{}
	data << u8(if response.success { 1 } else { 0 })
	return data
}

fn deserialize_audio_data(data []u8) AudioData {
	// Simplified - real implementation would properly deserialize
	return AudioData{
		samples: []
		sample_rate: 48000
		channels: 2
		frame_count: 0
		timestamp_ms: 0
	}
}

fn serialize_audio_data(audio AudioData) []u8 {
	// Simplified serialization
	return []u8{}
}

fn serialize_meter_data(meter MeterData) []u8 {
	return []u8{}
}

// C FFI exports for external language bindings

// volumod_init initializes the audio processor
[export: 'volumod_init']
pub fn volumod_init(sample_rate u32, channels u8, buffer_size u32) voidptr {
	config := engine.ProcessorConfig{
		sample_rate: sample_rate
		buffer_size: buffer_size
		channels: channels
		enable_normalizer: true
		enable_compressor: true
		enable_noise_redux: true
		enable_eq: true
		enable_limiter: true
	}
	processor := engine.new_audio_processor(config)
	// In real implementation, allocate on heap and return pointer
	return unsafe { nil }
}

// volumod_process processes audio samples
[export: 'volumod_process']
pub fn volumod_process(handle voidptr, samples &f32, num_samples int) {
	// Process audio through the engine
}

// volumod_set_bypass sets bypass mode
[export: 'volumod_set_bypass']
pub fn volumod_set_bypass(handle voidptr, bypass bool) {
	// Set bypass mode
}

// volumod_destroy cleans up resources
[export: 'volumod_destroy']
pub fn volumod_destroy(handle voidptr) {
	// Free allocated resources
}
