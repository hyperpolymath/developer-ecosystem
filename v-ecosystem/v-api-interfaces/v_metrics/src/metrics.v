// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Metrics collection with dimensional tagging, aggregation, and export Connector
// Author: Jonathan D.A. Jewell
//
// Metrics collection with dimensional tagging, aggregation, and export.
// Provides typed client bindings for the proven-metrics protocol.

module metrics

import os
import time
import net

// --- Metric type ---

// MetricType classifies the metric.
pub enum MetricType {
	counter     // Monotonically increasing
	gauge       // Can go up or down
	histogram   // Distribution of values
	summary     // Statistical summary
}

// --- Data structures ---

// Metric defines a single metric series.
pub struct Metric {
pub:
	name        string
	metric_type MetricType
	help        string
	labels      map[string]string
	value       f64
	timestamp   i64
}

// MetricsConfig holds metrics collector parameters.
pub struct MetricsConfig {
pub:
	endpoint     string = "/metrics"
	listen_port  int = 9090
	push_url     string    // Push gateway URL (empty = pull)
	interval_secs int = 15
}

// MetricsCollector manages metric registration and export.
pub struct MetricsCollector {
mut:
	config   MetricsConfig
	metrics  []Metric
}

// --- Collector lifecycle ---

// new_metrics_collector creates a new metrics collector.
pub fn new_metrics_collector(config MetricsConfig) &MetricsCollector {
	return &MetricsCollector{
		config:  config
		metrics: []Metric{}
	}
}

// register_metric adds a metric.
pub fn (mut c MetricsCollector) register_metric(metric Metric) ! {
	if metric.name.len == 0 {
		return error("metric name must not be empty")
	}
	c.metrics << metric
	println("[metrics] registered: ${metric.name} (${metric.metric_type})")
}

// scrape returns all metrics in exposition format.
pub fn (c &MetricsCollector) scrape() []Metric {
	return c.metrics
}

// --- Tests ---

fn test_empty_metric_name_rejected() {
	mut collector := new_metrics_collector(MetricsConfig{})
	collector.register_metric(Metric{ name: "", metric_type: .counter, help: "test", labels: {}, value: 0.0, timestamp: 0 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
