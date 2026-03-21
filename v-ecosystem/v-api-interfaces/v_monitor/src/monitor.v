// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem System monitoring with health checks, alerting, and escalation policies Connector
// Author: Jonathan D.A. Jewell
//
// System monitoring with health checks, alerting, and escalation policies.
// Provides typed client bindings for the proven-monitor protocol.

module monitor

import os
import time
import net

// --- Check type ---

// CheckType classifies the monitoring check.
pub enum CheckType {
	http         // HTTP endpoint check
	tcp          // TCP port check
	icmp         // Ping check
	dns          // DNS resolution check
	script       // Custom script
}

// --- Alert state ---

// AlertState tracks the alerting state machine.
pub enum AlertState {
	ok
	warning
	critical
	unknown
	acknowledged
}

// --- Data structures ---

// MonitorCheck defines a health check.
pub struct MonitorCheck {
pub:
	name         string
	check_type   CheckType
	target       string      // URL, host:port, or script path
	interval_secs int = 60
	timeout_secs int = 10
	state        AlertState = .unknown
}

// EscalationPolicy defines alert escalation.
pub struct EscalationPolicy {
pub:
	name         string
	channels     []string   // "email", "slack", "pagerduty"
	delay_secs   int = 300  // Delay before escalation
}

// MonitorConfig holds monitoring parameters.
pub struct MonitorConfig {
pub:
	dashboard_port int = 3000
	retention_days int = 30
}

// MonitorManager manages checks and escalation.
pub struct MonitorManager {
mut:
	config     MonitorConfig
	checks     []MonitorCheck
	policies   []EscalationPolicy
}

// --- Manager lifecycle ---

// new_monitor_manager creates a new monitor manager.
pub fn new_monitor_manager(config MonitorConfig) &MonitorManager {
	return &MonitorManager{
		config:   config
		checks:   []MonitorCheck{}
		policies: []EscalationPolicy{}
	}
}

// add_check registers a monitoring check.
pub fn (mut m MonitorManager) add_check(check MonitorCheck) ! {
	if check.name.len == 0 {
		return error("check name must not be empty")
	}
	m.checks << check
	println("[monitor] added check: ${check.name} (${check.check_type})")
}

// add_policy registers an escalation policy.
pub fn (mut m MonitorManager) add_policy(policy EscalationPolicy) ! {
	if policy.name.len == 0 {
		return error("policy name must not be empty")
	}
	m.policies << policy
	println("[monitor] added escalation policy: ${policy.name}")
}

// --- Tests ---

fn test_empty_check_name_rejected() {
	mut mgr := new_monitor_manager(MonitorConfig{})
	mgr.add_check(MonitorCheck{ name: "", check_type: .http, target: "http://localhost" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
