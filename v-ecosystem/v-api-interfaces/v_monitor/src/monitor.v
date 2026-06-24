// SPDX-License-Identifier: MPL-2.0
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

// --- Metric type ---

// MetricType classifies the kind of metric being recorded.
pub enum MetricType {
	counter    // Monotonically increasing value (e.g. request count)
	gauge      // Instantaneous value that can go up or down (e.g. temperature)
	histogram  // Distribution of observed values (e.g. latency buckets)
	summary    // Calculated quantiles over a sliding window
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

// MetricSample stores a single recorded metric observation.
pub struct MetricSample {
pub:
	name      string
	value     f64
	labels    map[string]string
	metric_type MetricType
	recorded_at i64
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
	metrics    []MetricSample
}

// --- Manager lifecycle ---

// new_monitor_manager creates a new monitor manager.
pub fn new_monitor_manager(config MonitorConfig) &MonitorManager {
	return &MonitorManager{
		config:   config
		checks:   []MonitorCheck{}
		policies: []EscalationPolicy{}
		metrics:  []MetricSample{}
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

// record stores a metric sample with associated labels.
pub fn (mut m MonitorManager) record(name string, value f64, labels map[string]string) ! {
	if name.len == 0 {
		return error("metric name must not be empty")
	}
	m.metrics << MetricSample{
		name:        name
		value:       value
		labels:      labels
		metric_type: .gauge
		recorded_at: time.now().unix()
	}
}

// get returns the most recently recorded value for a named metric.
pub fn (m &MonitorManager) get(name string) !f64 {
	if name.len == 0 {
		return error("metric name must not be empty")
	}
	// Search in reverse order to find the most recent sample.
	for i := m.metrics.len - 1; i >= 0; i-- {
		if m.metrics[i].name == name {
			return m.metrics[i].value
		}
	}
	return error("metric '${name}' not found")
}

// list returns the names of all distinct metrics that have been recorded.
pub fn (m &MonitorManager) list() ![]string {
	mut seen := map[string]bool{}
	mut names := []string{}
	for sample in m.metrics {
		if sample.name !in seen {
			seen[sample.name] = true
			names << sample.name
		}
	}
	return names
}

// --- Prometheus export ---

// export_prometheus renders all recorded metrics in Prometheus text exposition format.
// Each metric is emitted as: metric_name{label="val",...} value timestamp
pub fn (m &MonitorManager) export_prometheus() string {
	mut lines := []string{}
	for sample in m.metrics {
		mut label_str := ""
		if sample.labels.len > 0 {
			mut lparts := []string{}
			for k, v in sample.labels {
				lparts << '${k}="${v}"'
			}
			label_str = '{' + lparts.join(',') + '}'
		}
		lines << '${sample.name}${label_str} ${sample.value} ${sample.recorded_at}'
	}
	return lines.join('\n')
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

fn test_record_and_get_roundtrip() {
	mut mgr := new_monitor_manager(MonitorConfig{})
	mgr.record("cpu_usage", 42.5, map[string]string{}) or { panic(err) }
	val := mgr.get("cpu_usage") or { panic(err) }
	assert val == 42.5
}

fn test_get_unknown_metric_rejected() {
	mgr := new_monitor_manager(MonitorConfig{})
	mgr.get("nonexistent") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}

fn test_export_prometheus_format() {
	mut mgr := new_monitor_manager(MonitorConfig{})
	labels := {"host": "server1"}
	mgr.record("http_requests_total", 1234.0, labels) or { panic(err) }
	output := mgr.export_prometheus()
	assert output.contains("http_requests_total")
	assert output.contains('host="server1"')
	assert output.contains("1234")
}

fn test_list_deduplicated() {
	mut mgr := new_monitor_manager(MonitorConfig{})
	mgr.record("mem_bytes", 1024.0, map[string]string{}) or { panic(err) }
	mgr.record("mem_bytes", 2048.0, map[string]string{}) or { panic(err) }
	mgr.record("cpu_pct", 0.5, map[string]string{}) or { panic(err) }
	names := mgr.list() or { panic(err) }
	assert names.len == 2
}
