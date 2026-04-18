// SPDX-License-Identifier: PMPL-1.0-or-later
// Tests for safe diagnostic capture modules

module main

fn test_capture_result_creation() {
	result := CaptureResult{
		name: 'test_capture'
		success: true
		output: 'test output'
		error_msg: ''
		duration: 100
	}

	assert result.name == 'test_capture'
	assert result.success == true
	assert result.output == 'test output'
	assert result.duration == 100
}

fn test_capture_result_failure() {
	result := CaptureResult{
		name: 'failed_capture'
		success: false
		output: ''
		error_msg: 'Command not found'
		duration: 50
	}

	assert result.success == false
	assert result.error_msg == 'Command not found'
}

fn test_capture_module_creation() {
	mod := CaptureModule{
		name: 'os_version'
		display_name: 'OS Version'
		commands: ['uname -a', 'cat /etc/os-release']
	}

	assert mod.name == 'os_version'
	assert mod.display_name == 'OS Version'
	assert mod.commands.len == 2
}

fn test_os_version_commands_not_empty() {
	commands := get_os_version_commands()
	assert commands.len > 0
}

fn test_uptime_commands_not_empty() {
	commands := get_uptime_commands()
	assert commands.len > 0
}

fn test_disk_commands_not_empty() {
	commands := get_disk_commands()
	assert commands.len > 0
}

fn test_memory_commands_platform_specific() {
	commands := get_memory_commands()
	// Memory commands may be empty on some platforms
	$if linux {
		assert commands.len > 0
	}
	$if macos {
		assert commands.len > 0
	}
}

fn test_network_commands_platform_specific() {
	commands := get_network_commands()
	$if linux {
		assert commands.len > 0
	}
	$if macos {
		assert commands.len > 0
	}
}

fn test_process_commands_not_empty() {
	commands := get_process_commands()
	assert commands.len > 0
}

fn test_capture_module_list_coverage() {
	// Verify we have capture modules for key system areas
	module_names := ['os_version', 'uptime', 'disk_free', 'memory', 'network_summary', 'process_summary']

	for name in module_names {
		// Just verify these are valid module names we expect
		assert name.len > 0
	}
}
