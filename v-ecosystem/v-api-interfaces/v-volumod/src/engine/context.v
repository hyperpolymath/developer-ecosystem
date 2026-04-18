module engine

import time
import ..processors

// TimeOfDay represents periods of the day for contextual adjustment
pub enum TimeOfDay {
	morning    // 6:00 - 12:00
	afternoon  // 12:00 - 18:00
	evening    // 18:00 - 22:00
	night      // 22:00 - 6:00
}

// DeviceType represents different audio output devices
pub enum DeviceType {
	speakers        // Built-in or external speakers
	headphones      // Wired or wireless headphones
	earbuds         // In-ear monitors
	bluetooth       // Bluetooth speakers/headphones
	hdmi            // HDMI audio output
	unknown
}

// DeviceProfile holds device-specific audio settings
pub struct DeviceProfile {
pub mut:
	name            string
	device_type     DeviceType
	eq_preset       processors.EQPreset
	max_volume_db   f32        // Volume limit for this device
	bass_boost      f32        // Device-specific bass adjustment
	treble_boost    f32        // Device-specific treble adjustment
	compensation    []f32      // Frequency response compensation
}

// TimeProfile holds time-of-day specific settings
pub struct TimeProfile {
pub mut:
	time_of_day     TimeOfDay
	max_volume_db   f32        // Volume limit for this time
	eq_preset       processors.EQPreset
	compression_mode processors.CompressionMode
}

// EnvironmentProfile holds environment-specific settings
pub struct EnvironmentProfile {
pub mut:
	name            string
	ambient_noise_db f32       // Expected ambient noise level
	noise_reduction  processors.NoiseReductionMode
	voice_enhance    bool
}

// ContextManager manages contextual audio adaptations
pub struct ContextManager {
pub mut:
	enabled              bool
	current_time         TimeOfDay
	current_device       DeviceProfile
	current_environment  EnvironmentProfile

	// Time-based profiles
	time_profiles        map[TimeOfDay]TimeProfile

	// Device profiles
	device_profiles      map[string]DeviceProfile

	// Environment profiles
	environment_profiles map[string]EnvironmentProfile

	// Auto-detection settings
	auto_detect_time     bool
	auto_detect_device   bool
	auto_detect_ambient  bool
mut:
	last_update          i64  // Unix timestamp of last context update
}

// new_context_manager creates a new context manager with defaults
pub fn new_context_manager() ContextManager {
	mut cm := ContextManager{
		enabled: true
		auto_detect_time: true
		auto_detect_device: true
		auto_detect_ambient: false
		last_update: 0
	}

	// Initialize default time profiles
	cm.time_profiles[.morning] = TimeProfile{
		time_of_day: .morning
		max_volume_db: 0.0
		eq_preset: .flat
		compression_mode: .gentle
	}
	cm.time_profiles[.afternoon] = TimeProfile{
		time_of_day: .afternoon
		max_volume_db: 0.0
		eq_preset: .flat
		compression_mode: .gentle
	}
	cm.time_profiles[.evening] = TimeProfile{
		time_of_day: .evening
		max_volume_db: -3.0
		eq_preset: .flat
		compression_mode: .moderate
	}
	cm.time_profiles[.night] = TimeProfile{
		time_of_day: .night
		max_volume_db: -6.0
		eq_preset: .night_mode
		compression_mode: .aggressive
	}

	// Initialize default device profiles
	cm.device_profiles['default_speakers'] = DeviceProfile{
		name: 'Default Speakers'
		device_type: .speakers
		eq_preset: .flat
		max_volume_db: 0.0
		bass_boost: 0.0
		treble_boost: 0.0
		compensation: []
	}
	cm.device_profiles['default_headphones'] = DeviceProfile{
		name: 'Default Headphones'
		device_type: .headphones
		eq_preset: .flat
		max_volume_db: -3.0  // Protect hearing
		bass_boost: 0.0
		treble_boost: 0.0
		compensation: []
	}

	// Initialize default environment profiles
	cm.environment_profiles['quiet'] = EnvironmentProfile{
		name: 'Quiet Environment'
		ambient_noise_db: -50.0
		noise_reduction: .light
		voice_enhance: false
	}
	cm.environment_profiles['normal'] = EnvironmentProfile{
		name: 'Normal Environment'
		ambient_noise_db: -40.0
		noise_reduction: .moderate
		voice_enhance: false
	}
	cm.environment_profiles['noisy'] = EnvironmentProfile{
		name: 'Noisy Environment'
		ambient_noise_db: -30.0
		noise_reduction: .aggressive
		voice_enhance: true
	}

	cm.current_device = cm.device_profiles['default_speakers']
	cm.current_environment = cm.environment_profiles['normal']

	return cm
}

// get_current_time_of_day determines the current time period
pub fn get_current_time_of_day() TimeOfDay {
	now := time.now()
	hour := now.hour

	if hour >= 6 && hour < 12 {
		return .morning
	} else if hour >= 12 && hour < 18 {
		return .afternoon
	} else if hour >= 18 && hour < 22 {
		return .evening
	} else {
		return .night
	}
}

// update updates the context based on current conditions
pub fn (mut cm ContextManager) update() {
	if !cm.enabled {
		return
	}

	// Update time-of-day context
	if cm.auto_detect_time {
		cm.current_time = get_current_time_of_day()
	}

	cm.last_update = time.now().unix()
}

// apply_to_processor applies current context settings to audio processor
pub fn (cm &ContextManager) apply_to_processor(mut processor AudioProcessor) {
	if !cm.enabled {
		return
	}

	// Apply time-based settings
	if time_profile := cm.time_profiles[cm.current_time] {
		processor.set_compression_mode(time_profile.compression_mode)
		if time_profile.eq_preset != .flat {
			processor.set_eq_preset(time_profile.eq_preset)
		}
	}

	// Apply device-specific settings
	if cm.current_device.eq_preset != .flat {
		processor.set_eq_preset(cm.current_device.eq_preset)
	}

	// Apply environment settings
	processor.set_noise_reduction_mode(cm.current_environment.noise_reduction)
	processor.enable_voice_enhancement(cm.current_environment.voice_enhance)
}

// set_device sets the current output device profile
pub fn (mut cm ContextManager) set_device(device_id string) {
	if profile := cm.device_profiles[device_id] {
		cm.current_device = profile
	}
}

// set_environment sets the current environment profile
pub fn (mut cm ContextManager) set_environment(env_id string) {
	if profile := cm.environment_profiles[env_id] {
		cm.current_environment = profile
	}
}

// add_device_profile adds a custom device profile
pub fn (mut cm ContextManager) add_device_profile(id string, profile DeviceProfile) {
	cm.device_profiles[id] = profile
}

// add_environment_profile adds a custom environment profile
pub fn (mut cm ContextManager) add_environment_profile(id string, profile EnvironmentProfile) {
	cm.environment_profiles[id] = profile
}

// get_time_profile returns the profile for a time period
pub fn (cm &ContextManager) get_time_profile(tod TimeOfDay) ?TimeProfile {
	return cm.time_profiles[tod]
}

// set_time_profile sets the profile for a time period
pub fn (mut cm ContextManager) set_time_profile(tod TimeOfDay, profile TimeProfile) {
	cm.time_profiles[tod] = profile
}

// get_current_settings returns a summary of current context settings
pub fn (cm &ContextManager) get_current_settings() string {
	time_str := match cm.current_time {
		.morning { 'Morning' }
		.afternoon { 'Afternoon' }
		.evening { 'Evening' }
		.night { 'Night' }
	}
	return 'Time: ${time_str}, Device: ${cm.current_device.name}, Environment: ${cm.current_environment.name}'
}
