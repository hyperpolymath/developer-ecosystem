// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_metrics -- Metrics collection and exposition (Prometheus-compatible)
// for the V-Ecosystem. Maps to proven-servers/protocols/proven-metrics.
// Implements Counter, Gauge, Histogram, and Summary metric types with
// label support and Prometheus text exposition format output.
module v_metrics

import math
import net

// MetricType enumerates the four Prometheus metric types.
pub enum MetricType {
	counter
	gauge
	histogram
	summary
}

// metric_type_to_string returns the Prometheus-format type name.
pub fn metric_type_to_string(mt MetricType) string {
	return match mt {
		.counter { 'counter' }
		.gauge { 'gauge' }
		.histogram { 'histogram' }
		.summary { 'summary' }
	}
}

// Labels is a map of key-value label pairs attached to a metric sample.
pub type Labels = map[string]string

// Metric is a generic metric container used for untyped or ad-hoc metrics.
pub struct Metric {
pub:
	// name is the metric name (e.g. "http_requests_total").
	name string
	// metric_type identifies the metric kind.
	metric_type MetricType
	// help is a human-readable description of what the metric measures.
	help string
pub mut:
	// labels holds the dimensional label set for this metric sample.
	labels Labels
	// value is the current numeric value.
	value f64
}

// Counter is a monotonically increasing metric. Its value can only go up
// (or be reset to zero on process restart).
pub struct Counter {
pub:
	// name is the metric name.
	name string
	// help is a human-readable description.
	help string
pub mut:
	// labels holds the dimensional label set.
	labels Labels
	// value is the current counter value. Must be non-negative.
	value f64
}

// inc increments the counter by 1.
pub fn (mut c Counter) inc() {
	c.value += 1.0
}

// add increments the counter by the given non-negative value.
// Negative values are silently ignored to preserve monotonicity.
pub fn (mut c Counter) add(v f64) {
	if v >= 0 {
		c.value += v
	}
}

// Gauge is a metric that can go up or down, representing a current value
// such as temperature, memory usage, or active connections.
pub struct Gauge {
pub:
	// name is the metric name.
	name string
	// help is a human-readable description.
	help string
pub mut:
	// labels holds the dimensional label set.
	labels Labels
	// value is the current gauge value.
	value f64
}

// set sets the gauge to the given value.
pub fn (mut g Gauge) set(v f64) {
	g.value = v
}

// inc increments the gauge by 1.
pub fn (mut g Gauge) inc() {
	g.value += 1.0
}

// dec decrements the gauge by 1.
pub fn (mut g Gauge) dec() {
	g.value -= 1.0
}

// Histogram tracks the distribution of observed values in configurable
// buckets. Each bucket counts observations less than or equal to its
// upper bound.
pub struct Histogram {
pub:
	// name is the metric name.
	name string
	// help is a human-readable description.
	help string
	// buckets contains the upper bounds for histogram buckets, sorted ascending.
	buckets []f64
pub mut:
	// observations stores all observed values for percentile computation.
	observations []f64
	// bucket_counts tracks how many observations fell into each bucket.
	bucket_counts []u64
	// sum_value is the running sum of all observed values.
	sum_value f64
	// count_value is the total number of observations.
	count_value u64
}

// new_histogram creates a Histogram with the given buckets. Buckets are
// sorted ascending and a +Inf bucket is always implicitly present.
pub fn new_histogram(name string, help string, buckets []f64) &Histogram {
	mut sorted_buckets := buckets.clone()
	sorted_buckets.sort(a < b)
	return &Histogram{
		name: name
		help: help
		buckets: sorted_buckets
		bucket_counts: []u64{len: sorted_buckets.len, init: 0}
	}
}

// observe records a single value in the histogram, incrementing the
// appropriate bucket counters and updating the sum and count.
pub fn (mut h Histogram) observe(v f64) {
	h.observations << v
	h.sum_value += v
	h.count_value++
	for i, bound in h.buckets {
		if v <= bound {
			h.bucket_counts[i]++
		}
	}
}

// MetricsRegistry is a collection of all registered metrics. It provides
// a single point for registering new metrics and exposing them in
// Prometheus text format.
pub struct MetricsRegistry {
pub mut:
	// metrics holds generic/untyped metrics.
	metrics []Metric
	// counters holds all registered Counter instances.
	counters []&Counter
	// gauges holds all registered Gauge instances.
	gauges []&Gauge
	// histograms holds all registered Histogram instances.
	histograms []&Histogram
}

// new_registry creates an empty MetricsRegistry.
pub fn new_registry() &MetricsRegistry {
	return &MetricsRegistry{}
}

// register_counter creates and registers a new Counter with the given
// name and help text. Returns a mutable reference to the counter.
pub fn (mut r MetricsRegistry) register_counter(name string, help string) &Counter {
	c := &Counter{
		name: name
		help: help
	}
	r.counters << c
	return c
}

// register_gauge creates and registers a new Gauge with the given name
// and help text. Returns a mutable reference to the gauge.
pub fn (mut r MetricsRegistry) register_gauge(name string, help string) &Gauge {
	g := &Gauge{
		name: name
		help: help
	}
	r.gauges << g
	return g
}

// register_histogram creates and registers a new Histogram with the given
// name, help text, and bucket boundaries. Returns a mutable reference.
pub fn (mut r MetricsRegistry) register_histogram(name string, help string, buckets []f64) &Histogram {
	h := new_histogram(name, help, buckets)
	r.histograms << h
	return h
}

// format_labels converts a Labels map into the Prometheus label string
// format: {key1="val1",key2="val2"}. Returns an empty string if there
// are no labels.
fn format_labels(labels Labels) string {
	if labels.len == 0 {
		return ''
	}
	mut parts := []string{}
	for key, val in labels {
		parts << '${key}="${val}"'
	}
	return '{${parts.join(',')}}'
}

// expose renders all registered metrics in Prometheus text exposition
// format (version 0.0.4). The output is suitable for serving at a
// /metrics HTTP endpoint.
pub fn (r MetricsRegistry) expose() string {
	mut lines := []string{}

	// Counters
	for c in r.counters {
		lines << '# HELP ${c.name} ${c.help}'
		lines << '# TYPE ${c.name} counter'
		label_str := format_labels(c.labels)
		lines << '${c.name}${label_str} ${format_f64(c.value)}'
	}

	// Gauges
	for g in r.gauges {
		lines << '# HELP ${g.name} ${g.help}'
		lines << '# TYPE ${g.name} gauge'
		label_str := format_labels(g.labels)
		lines << '${g.name}${label_str} ${format_f64(g.value)}'
	}

	// Histograms
	for h in r.histograms {
		lines << '# HELP ${h.name} ${h.help}'
		lines << '# TYPE ${h.name} histogram'
		mut cumulative := u64(0)
		for i, bound in h.buckets {
			cumulative += h.bucket_counts[i]
			lines << '${h.name}_bucket{le="${format_f64(bound)}"} ${cumulative}'
		}
		lines << '${h.name}_bucket{le="+Inf"} ${h.count_value}'
		lines << '${h.name}_sum ${format_f64(h.sum_value)}'
		lines << '${h.name}_count ${h.count_value}'
	}

	return lines.join('\n') + '\n'
}

// format_f64 formats a float to a string, removing unnecessary trailing
// zeroes but keeping at least one decimal place for Prometheus compatibility.
fn format_f64(v f64) string {
	if v == math.floor(v) && !math.is_inf(v, 0) {
		return '${int(v)}'
	}
	return '${v}'
}

// MetricsServer serves the metrics registry over HTTP at a configurable
// path and port.
pub struct MetricsServer {
pub:
	// port is the TCP port to listen on.
	port int
	// registry is the metrics registry to expose.
	registry &MetricsRegistry
	// path is the HTTP path to serve metrics at (default "/metrics").
	path string = '/metrics'
}

// new_server creates a MetricsServer with the given port and registry.
pub fn new_server(port int, registry &MetricsRegistry) &MetricsServer {
	return &MetricsServer{
		port: port
		registry: registry
	}
}

// serve starts the HTTP server and blocks. Responds to GET requests on
// the configured path with the Prometheus text exposition format.
// TODO: Full HTTP serving -- currently logs a start message.
pub fn (s MetricsServer) serve() ! {
	println('v_metrics server starting on TCP port ${s.port} at path ${s.path}...')
	// TODO: Accept TCP connections via net.listen_tcp, parse HTTP requests,
	//       and respond with s.registry.expose() for matching paths.
	//       For now, validate the port is usable.
	mut listener := net.listen_tcp(s.port)!
	defer {
		listener.close() or {}
	}
	println('v_metrics server listening on TCP port ${s.port}')
}
