module ui

// AccessibilityRole defines ARIA-like roles for UI elements
pub enum AccessibilityRole {
	button
	toggle
	slider
	menu
	menuitem
	status
	alert
	dialog
}

// AccessibilityState holds accessibility state information
pub struct AccessibilityState {
pub mut:
	role          AccessibilityRole
	label         string           // Human-readable label
	description   string           // Detailed description
	value         string           // Current value (for sliders, toggles)
	enabled       bool
	focused       bool
	expanded      bool             // For menus
	checked       bool             // For toggles
	live          string           // "polite", "assertive", or ""
}

// AccessibilityManager handles accessibility features
pub struct AccessibilityManager {
pub mut:
	screen_reader_enabled  bool
	high_contrast_mode     bool
	reduced_motion         bool
	keyboard_navigation    bool
	hearing_loop_enabled   bool
	text_scale             f32
mut:
	announcements          []string
	focus_order            []string
	current_focus          int
}

// new_accessibility_manager creates a new accessibility manager
pub fn new_accessibility_manager() AccessibilityManager {
	return AccessibilityManager{
		screen_reader_enabled: false
		high_contrast_mode: false
		reduced_motion: false
		keyboard_navigation: true
		hearing_loop_enabled: false
		text_scale: 1.0
		announcements: []
		focus_order: []
		current_focus: -1
	}
}

// announce queues an announcement for screen readers
pub fn (mut am AccessibilityManager) announce(message string, priority string) {
	if !am.screen_reader_enabled {
		return
	}

	// Priority: "polite" waits, "assertive" interrupts
	if priority == 'assertive' {
		// Insert at beginning for immediate announcement
		am.announcements.insert(0, message)
	} else {
		am.announcements << message
	}
}

// get_next_announcement gets and removes the next announcement
pub fn (mut am AccessibilityManager) get_next_announcement() ?string {
	if am.announcements.len == 0 {
		return none
	}
	announcement := am.announcements[0]
	am.announcements.delete(0)
	return announcement
}

// set_focus_order sets the keyboard navigation order
pub fn (mut am AccessibilityManager) set_focus_order(elements []string) {
	am.focus_order = elements
	if elements.len > 0 && am.current_focus < 0 {
		am.current_focus = 0
	}
}

// move_focus moves focus to next or previous element
pub fn (mut am AccessibilityManager) move_focus(forward bool) string {
	if am.focus_order.len == 0 {
		return ''
	}

	if forward {
		am.current_focus = (am.current_focus + 1) % am.focus_order.len
	} else {
		am.current_focus = (am.current_focus - 1 + am.focus_order.len) % am.focus_order.len
	}

	return am.focus_order[am.current_focus]
}

// get_current_focus returns the currently focused element
pub fn (am &AccessibilityManager) get_current_focus() string {
	if am.current_focus >= 0 && am.current_focus < am.focus_order.len {
		return am.focus_order[am.current_focus]
	}
	return ''
}

// build_bypass_button_state creates accessibility state for bypass button
pub fn build_bypass_button_state(is_bypassed bool) AccessibilityState {
	return AccessibilityState{
		role: .toggle
		label: 'Bypass audio processing'
		description: if is_bypassed {
			'Audio processing is currently bypassed. Click to enable processing.'
		} else {
			'Audio processing is active. Click to bypass processing.'
		}
		value: if is_bypassed { 'On' } else { 'Off' }
		enabled: true
		focused: false
		expanded: false
		checked: is_bypassed
		live: 'polite'
	}
}

// build_status_state creates accessibility state for status indicator
pub fn build_status_state(status string, input_db f32, output_db f32) AccessibilityState {
	return AccessibilityState{
		role: .status
		label: 'VoluMod Status'
		description: 'Current status: ${status}. Input level: ${input_db:.0f} dB. Output level: ${output_db:.0f} dB.'
		value: status
		enabled: true
		focused: false
		expanded: false
		checked: false
		live: 'polite'
	}
}

// build_preset_menu_state creates accessibility state for preset menu
pub fn build_preset_menu_state(current_preset string, is_expanded bool) AccessibilityState {
	return AccessibilityState{
		role: .menu
		label: 'Audio preset selection'
		description: 'Currently selected: ${current_preset}. Use arrow keys to navigate presets.'
		value: current_preset
		enabled: true
		focused: false
		expanded: is_expanded
		checked: false
		live: ''
	}
}

// format_level_for_speech formats audio level for screen reader
pub fn format_level_for_speech(db f32) string {
	if db < -60 {
		return 'silent'
	} else if db < -40 {
		return 'very quiet'
	} else if db < -20 {
		return 'quiet'
	} else if db < -10 {
		return 'moderate'
	} else if db < -3 {
		return 'loud'
	} else {
		return 'very loud'
	}
}

// HearingLoopOutput manages telecoil/hearing loop integration
pub struct HearingLoopOutput {
pub mut:
	enabled       bool
	frequency_hz  f32    // Typically 3100 Hz for T-coil
	modulation    f32    // Modulation depth
mut:
	phase         f32
}

// new_hearing_loop_output creates hearing loop output manager
pub fn new_hearing_loop_output() HearingLoopOutput {
	return HearingLoopOutput{
		enabled: false
		frequency_hz: 3100.0
		modulation: 0.85
		phase: 0.0
	}
}

// KeyboardShortcuts defines keyboard shortcuts for accessibility
pub struct KeyboardShortcuts {
pub:
	bypass           string  // Toggle bypass
	volume_up        string  // Increase volume
	volume_down      string  // Decrease volume
	preset_next      string  // Next preset
	preset_prev      string  // Previous preset
	noise_learn      string  // Start noise learning
	help             string  // Open help
}

// default_shortcuts returns default keyboard shortcuts
pub fn default_shortcuts() KeyboardShortcuts {
	return KeyboardShortcuts{
		bypass: 'Ctrl+Shift+B'
		volume_up: 'Ctrl+Shift+Up'
		volume_down: 'Ctrl+Shift+Down'
		preset_next: 'Ctrl+Shift+Right'
		preset_prev: 'Ctrl+Shift+Left'
		noise_learn: 'Ctrl+Shift+N'
		help: 'F1'
	}
}
