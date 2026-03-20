// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// metrics_test -- Protocol conformance tests for v_metrics.
// Covers counter increment, gauge set, histogram bucket distribution,
// registry management, and Prometheus exposition format output.
module v_metrics

// test_metric_type_to_string verifies string labels for all metric types.
fn test_metric_type_to_string() {
	assert metric_type_to_string(.counter) == 'counter'
	assert metric_type_to_string(.gauge) == 'gauge'
	assert metric_type_to_string(.histogram) == 'histogram'
	assert metric_type_to_string(.summary) == 'summary'
}

// test_counter_inc verifies that incrementing a counter increases its
// value by 1 each time.
fn test_counter_inc() {
	mut c := Counter{
		name: 'test_counter'
		help: 'A test counter'
	}
	assert c.value == 0.0
	c.inc()
	assert c.value == 1.0
	c.inc()
	c.inc()
	assert c.value == 3.0
}

// test_counter_add verifies that adding a positive value increases the
// counter and that negative values are silently ignored.
fn test_counter_add() {
	mut c := Counter{
		name: 'test_counter'
		help: 'A test counter'
	}
	c.add(5.5)
	assert c.value == 5.5
	c.add(2.5)
	assert c.value == 8.0
	// Negative values should be ignored (counters are monotonic)
	c.add(-1.0)
	assert c.value == 8.0
}

// test_counter_add_zero verifies that adding zero is accepted (it is
// non-negative).
fn test_counter_add_zero() {
	mut c := Counter{
		name: 'test_counter'
		help: 'A test counter'
	}
	c.add(0.0)
	assert c.value == 0.0
}

// test_gauge_set verifies that setting a gauge replaces its value.
fn test_gauge_set() {
	mut g := Gauge{
		name: 'test_gauge'
		help: 'A test gauge'
	}
	g.set(42.0)
	assert g.value == 42.0
	g.set(-10.0)
	assert g.value == -10.0
}

// test_gauge_inc_dec verifies that increment and decrement modify the
// gauge value by 1.
fn test_gauge_inc_dec() {
	mut g := Gauge{
		name: 'test_gauge'
		help: 'A test gauge'
	}
	g.set(10.0)
	g.inc()
	assert g.value == 11.0
	g.dec()
	g.dec()
	assert g.value == 9.0
}

// test_histogram_observe verifies that observations are recorded into
// the correct buckets and that sum/count are updated.
fn test_histogram_observe() {
	mut h := new_histogram('request_duration', 'Request duration in seconds', [
		0.005,
		0.01,
		0.025,
		0.05,
		0.1,
		0.25,
		0.5,
		1.0,
	])

	h.observe(0.003) // fits in 0.005 bucket
	h.observe(0.008) // fits in 0.01 bucket
	h.observe(0.042) // fits in 0.05 bucket
	h.observe(0.15) // fits in 0.25 bucket
	h.observe(0.75) // fits in 1.0 bucket

	assert h.count_value == 5
	// Sum should be approximately 0.003 + 0.008 + 0.042 + 0.15 + 0.75 = 0.953
	assert h.sum_value > 0.95 && h.sum_value < 0.96

	// Bucket 0.005 should have 1 observation (0.003)
	assert h.bucket_counts[0] == 1
	// Bucket 0.01 should have 1 observation (0.008)
	assert h.bucket_counts[1] == 1
	// Bucket 0.025 should have 0
	assert h.bucket_counts[2] == 0
	// Bucket 0.05 should have 1 (0.042)
	assert h.bucket_counts[3] == 1
	// Bucket 0.1 should have 0
	assert h.bucket_counts[4] == 0
	// Bucket 0.25 should have 1 (0.15)
	assert h.bucket_counts[5] == 1
	// Bucket 0.5 should have 0
	assert h.bucket_counts[6] == 0
	// Bucket 1.0 should have 1 (0.75)
	assert h.bucket_counts[7] == 1
}

// test_histogram_bucket_sorting verifies that buckets are automatically
// sorted regardless of input order.
fn test_histogram_bucket_sorting() {
	h := new_histogram('test', 'test', [1.0, 0.1, 0.5, 0.01])
	assert h.buckets == [0.01, 0.1, 0.5, 1.0]
}

// test_registry_register_counter verifies that counters can be registered
// and used through the registry.
fn test_registry_register_counter() {
	mut r := new_registry()
	mut c := r.register_counter('http_requests_total', 'Total HTTP requests')
	c.inc()
	c.inc()
	assert c.value == 2.0
	assert r.counters.len == 1
}

// test_registry_register_gauge verifies that gauges can be registered
// and used through the registry.
fn test_registry_register_gauge() {
	mut r := new_registry()
	mut g := r.register_gauge('goroutines', 'Number of goroutines')
	g.set(150.0)
	assert g.value == 150.0
	assert r.gauges.len == 1
}

// test_registry_register_histogram verifies that histograms can be
// registered and used through the registry.
fn test_registry_register_histogram() {
	mut r := new_registry()
	mut h := r.register_histogram('request_size', 'Request size in bytes', [
		100.0,
		500.0,
		1000.0,
	])
	h.observe(250.0)
	h.observe(750.0)
	assert h.count_value == 2
	assert r.histograms.len == 1
}

// test_expose_counter verifies that the exposition format for a counter
// includes HELP, TYPE, and the metric value.
fn test_expose_counter() {
	mut r := new_registry()
	mut c := r.register_counter('test_total', 'A test counter')
	c.inc()
	c.inc()
	c.inc()
	output := r.expose()
	assert output.contains('# HELP test_total A test counter')
	assert output.contains('# TYPE test_total counter')
	assert output.contains('test_total 3')
}

// test_expose_gauge verifies that the exposition format for a gauge
// includes the correct type and value.
fn test_expose_gauge() {
	mut r := new_registry()
	mut g := r.register_gauge('temperature', 'Current temperature')
	g.set(23.5)
	output := r.expose()
	assert output.contains('# TYPE temperature gauge')
	assert output.contains('temperature 23.5')
}

// test_expose_histogram verifies that the exposition format for a
// histogram includes bucket lines, sum, and count.
fn test_expose_histogram() {
	mut r := new_registry()
	mut h := r.register_histogram('latency', 'Latency in ms', [10.0, 50.0, 100.0])
	h.observe(5.0)
	h.observe(25.0)
	h.observe(75.0)
	output := r.expose()
	assert output.contains('# TYPE latency histogram')
	assert output.contains('latency_bucket{le="10"} 1')
	assert output.contains('latency_bucket{le="50"} 2')
	assert output.contains('latency_bucket{le="100"} 3')
	assert output.contains('latency_bucket{le="+Inf"} 3')
	assert output.contains('latency_sum 105')
	assert output.contains('latency_count 3')
}

// test_expose_empty_registry verifies that an empty registry produces
// minimal output.
fn test_expose_empty_registry() {
	r := new_registry()
	output := r.expose()
	assert output == '\n'
}

// test_format_labels verifies label formatting for Prometheus output.
fn test_format_labels() {
	assert format_labels({}) == ''
	labels := {
		'method': 'GET'
		'status': '200'
	}
	result := format_labels(labels)
	assert result.contains('method="GET"')
	assert result.contains('status="200"')
	assert result.starts_with('{')
	assert result.ends_with('}')
}

// test_multiple_metrics verifies that a registry with multiple metric
// types produces correctly-formatted output for all of them.
fn test_multiple_metrics() {
	mut r := new_registry()
	mut c := r.register_counter('requests', 'Total requests')
	mut g := r.register_gauge('connections', 'Active connections')
	mut h := r.register_histogram('duration', 'Duration', [0.1, 0.5, 1.0])

	c.add(100.0)
	g.set(42.0)
	h.observe(0.3)

	output := r.expose()
	// All three metric types should be present
	assert output.contains('# TYPE requests counter')
	assert output.contains('# TYPE connections gauge')
	assert output.contains('# TYPE duration histogram')
}
