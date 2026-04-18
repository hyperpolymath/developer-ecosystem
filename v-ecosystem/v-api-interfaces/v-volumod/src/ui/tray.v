module ui

import ..engine
import ..processors

// TrayState represents the visual state of the tray icon
pub enum TrayState {
	active       // Processing audio (green/blue indicator)
	bypassed     // Bypass mode (gray indicator)
	learning     // Learning noise profile (orange indicator)
	error        // Error state (red indicator)
	idle         // Not processing (dim indicator)
}

// TrayIcon manages the system tray interface
pub struct TrayIcon {
pub mut:
	state          TrayState
	tooltip        string
	visible        bool

	// Quick access settings
	bypass_enabled bool
	current_preset string
mut:
	processor      &engine.AudioProcessor = unsafe { nil }
	context        &engine.ContextManager = unsafe { nil }
}

// MenuItem represents a menu item in the tray context menu
pub struct MenuItem {
pub:
	id          string
	label       string
	enabled     bool
	checked     bool
	submenu     []MenuItem
}

// new_tray_icon creates a new tray icon interface
pub fn new_tray_icon(processor &engine.AudioProcessor, context &engine.ContextManager) TrayIcon {
	return TrayIcon{
		state: .idle
		tooltip: 'VoluMod - Audio Optimizer'
		visible: true
		bypass_enabled: false
		current_preset: 'Auto'
		processor: processor
		context: context
	}
}

// update_state updates the tray icon state based on processor state
pub fn (mut ti TrayIcon) update_state() {
	if ti.processor == unsafe { nil } {
		ti.state = .error
		return
	}

	if ti.processor.is_bypassed() {
		ti.state = .bypassed
		ti.tooltip = 'VoluMod - Bypassed'
	} else if ti.processor.noise_reducer.learn_noise {
		ti.state = .learning
		ti.tooltip = 'VoluMod - Learning noise profile...'
	} else if ti.processor.state == .active {
		ti.state = .active
		input, output := ti.processor.get_levels()
		ti.tooltip = 'VoluMod - Active\nInput: ${input:.1f} dB | Output: ${output:.1f} dB'
	} else {
		ti.state = .idle
		ti.tooltip = 'VoluMod - Idle'
	}
}

// build_context_menu builds the context menu items
pub fn (ti &TrayIcon) build_context_menu() []MenuItem {
	mut items := []MenuItem{}

	// Bypass toggle (most prominent)
	items << MenuItem{
		id: 'bypass'
		label: if ti.bypass_enabled { '✓ Bypass Active' } else { 'Enable Bypass' }
		enabled: true
		checked: ti.bypass_enabled
		submenu: []
	}

	items << MenuItem{
		id: 'separator1'
		label: '---'
		enabled: false
		checked: false
		submenu: []
	}

	// Quick presets submenu
	items << MenuItem{
		id: 'presets'
		label: 'Presets'
		enabled: true
		checked: false
		submenu: [
			MenuItem{
				id: 'preset_auto'
				label: 'Auto (Recommended)'
				enabled: true
				checked: ti.current_preset == 'Auto'
				submenu: []
			},
			MenuItem{
				id: 'preset_speech'
				label: 'Speech/Podcasts'
				enabled: true
				checked: ti.current_preset == 'Speech'
				submenu: []
			},
			MenuItem{
				id: 'preset_music'
				label: 'Music'
				enabled: true
				checked: ti.current_preset == 'Music'
				submenu: []
			},
			MenuItem{
				id: 'preset_night'
				label: 'Night Mode'
				enabled: true
				checked: ti.current_preset == 'Night'
				submenu: []
			},
			MenuItem{
				id: 'preset_hearing'
				label: 'Hearing Assistance'
				enabled: true
				checked: ti.current_preset == 'Hearing'
				submenu: []
			},
		]
	}

	// Noise reduction
	items << MenuItem{
		id: 'noise'
		label: 'Noise Reduction'
		enabled: true
		checked: false
		submenu: [
			MenuItem{
				id: 'noise_learn'
				label: 'Learn Noise Profile...'
				enabled: true
				checked: false
				submenu: []
			},
			MenuItem{
				id: 'noise_light'
				label: 'Light'
				enabled: true
				checked: false
				submenu: []
			},
			MenuItem{
				id: 'noise_moderate'
				label: 'Moderate'
				enabled: true
				checked: false
				submenu: []
			},
			MenuItem{
				id: 'noise_aggressive'
				label: 'Aggressive'
				enabled: true
				checked: false
				submenu: []
			},
		]
	}

	items << MenuItem{
		id: 'separator2'
		label: '---'
		enabled: false
		checked: false
		submenu: []
	}

	// Settings and quit
	items << MenuItem{
		id: 'settings'
		label: 'Settings...'
		enabled: true
		checked: false
		submenu: []
	}

	items << MenuItem{
		id: 'about'
		label: 'About VoluMod'
		enabled: true
		checked: false
		submenu: []
	}

	items << MenuItem{
		id: 'separator3'
		label: '---'
		enabled: false
		checked: false
		submenu: []
	}

	items << MenuItem{
		id: 'quit'
		label: 'Quit'
		enabled: true
		checked: false
		submenu: []
	}

	return items
}

// handle_menu_action handles a menu item click
pub fn (mut ti TrayIcon) handle_menu_action(action_id string) {
	if ti.processor == unsafe { nil } {
		return
	}

	match action_id {
		'bypass' {
			ti.processor.toggle_bypass()
			ti.bypass_enabled = ti.processor.is_bypassed()
		}
		'preset_auto' {
			ti.current_preset = 'Auto'
			ti.processor.set_eq_preset(.flat)
			ti.processor.set_compression_mode(.moderate)
		}
		'preset_speech' {
			ti.current_preset = 'Speech'
			ti.processor.set_eq_preset(.speech)
			ti.processor.enable_voice_enhancement(true)
		}
		'preset_music' {
			ti.current_preset = 'Music'
			ti.processor.set_eq_preset(.music)
			ti.processor.enable_voice_enhancement(false)
		}
		'preset_night' {
			ti.current_preset = 'Night'
			ti.processor.set_eq_preset(.night_mode)
			ti.processor.set_compression_mode(.aggressive)
		}
		'preset_hearing' {
			ti.current_preset = 'Hearing'
			ti.processor.set_eq_preset(.hearing_aid)
		}
		'noise_learn' {
			ti.processor.start_noise_learning()
		}
		'noise_light' {
			ti.processor.set_noise_reduction_mode(.light)
		}
		'noise_moderate' {
			ti.processor.set_noise_reduction_mode(.moderate)
		}
		'noise_aggressive' {
			ti.processor.set_noise_reduction_mode(.aggressive)
		}
		else {}
	}

	ti.update_state()
}

// get_icon_data returns icon data based on current state
pub fn (ti &TrayIcon) get_icon_data() []u8 {
	// Returns appropriate icon data based on state
	// In a real implementation, this would return actual icon bytes
	return match ti.state {
		.active { [u8(0x01)] }     // Active icon
		.bypassed { [u8(0x02)] }   // Bypassed icon
		.learning { [u8(0x03)] }   // Learning icon
		.error { [u8(0x04)] }      // Error icon
		.idle { [u8(0x05)] }       // Idle icon
	}
}

// show shows the tray icon
pub fn (mut ti TrayIcon) show() {
	ti.visible = true
}

// hide hides the tray icon
pub fn (mut ti TrayIcon) hide() {
	ti.visible = false
}
