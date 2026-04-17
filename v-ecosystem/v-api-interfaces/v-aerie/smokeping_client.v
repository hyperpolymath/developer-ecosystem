// SPDX-License-Identifier: PMPL-1.0-or-later
//
// smokeping_client.v — HTTP Client for SmokePing Probe
//
// Queries the SmokePing backend at SMOKEPING_URL (default http://smokeping:80)
// to obtain latency, packet loss, and jitter metrics from SmokePing's RRD-based
// smoke chart data. Parses the response into SmokePingSample and SmokeChartPoint
// records matching the Idris2 ABI and protobuf definitions.
//
// SmokePing sends ICMP pings to configured targets and records median RTT,
// packet loss percentage, and standard deviation over time. The "smoke chart"
// visualises latency distribution — this client fetches the underlying data
// points that drive those charts.
//
// Phase 2 integration: complements LibreSpeed (throughput) and Hyperglass (BGP)
// with fine-grained latency/jitter monitoring per target.

module main

import net.http
import os
import time

// SmokePingSample represents a single measurement snapshot from SmokePing.
// Fields match src/abi/Types.idr and src/api/proto/aerie.proto SmokePingSample.
//
// A sample captures the result of one probe round: the median RTT across
// all pings in that round, the percentage of pings that were lost, the
// minimum and maximum RTTs, and the standard deviation (jitter indicator).
pub struct SmokePingSample {
pub:
	timestamp string // ISO 8601 timestamp of the measurement
	target    string // Target hostname or IP being probed
	median_ms f64    // Median round-trip time in milliseconds
	loss_pct  f64    // Packet loss percentage (0.0 - 100.0)
	min_ms    f64    // Minimum RTT in milliseconds
	max_ms    f64    // Maximum RTT in milliseconds
	stddev_ms f64    // Standard deviation of RTT (jitter proxy)
}

// SmokeChartPoint represents a single point in a SmokePing smoke chart
// time series. Contains only the two most important metrics (median RTT
// and loss percentage) for compact chart rendering.
//
// A smoke chart typically shows 24 hours of data at 5-minute resolution,
// yielding ~288 points per target.
pub struct SmokeChartPoint {
pub:
	timestamp string // ISO 8601 timestamp
	median_ms f64    // Median RTT in milliseconds
	loss_pct  f64    // Packet loss percentage (0.0 - 100.0)
}

// SmokePingPayload is the response wrapper for SmokePing queries.
// Contains both the current (most recent) sample and a time-series
// array of chart points for trend visualisation.
pub struct SmokePingPayload {
pub:
	target  string           // Target hostname or IP that was probed
	current SmokePingSample  // Most recent measurement snapshot
	chart   []SmokeChartPoint // Historical data points for charting
}

// get_smokeping_url returns the configured SmokePing endpoint.
// Reads from SMOKEPING_URL environment variable; defaults to the
// internal container network address http://smokeping:80 when unset.
fn get_smokeping_url() string {
	url := os.getenv('SMOKEPING_URL')
	if url.len > 0 {
		return url
	}
	return 'http://smokeping:80'
}

// get_smokeping_data queries SmokePing for latency/loss data for the
// specified target (hostname or IP address).
//
// Attempts to fetch smoke chart data from SmokePing's CGI endpoint
// using the "s" (summary) display mode. SmokePing's CGI returns
// HTML/RRD data — we parse what is available and fall back to
// synthetic samples with -1 values if the probe is unreachable.
//
// In production, SmokePing runs as a container in the aerie-net network
// and responds on its internal port 80 (mapped to host 8081).
//
// The CGI URL pattern is:
//   /smokeping/smokeping.cgi?target=<target>&displaymode=s
//
// where displaymode=s requests the summary/smoke chart view.
pub fn get_smokeping_data(target string) SmokePingPayload {
	base_url := get_smokeping_url()
	now := time.now().format_rfc3339()

	// SmokePing CGI endpoint for smoke chart data
	cgi_url := '${base_url}/smokeping/smokeping.cgi?target=${target}&displaymode=s'

	response := http.get(cgi_url) or {
		eprintln('smokeping: probe unreachable at ${base_url}: ${err}')
		return SmokePingPayload{
			target:  target
			current: SmokePingSample{
				timestamp: now
				target:    target
				median_ms: -1
				loss_pct:  -1
				min_ms:    -1
				max_ms:    -1
				stddev_ms: -1
			}
			chart: []
		}
	}

	if response.status_code != 200 {
		eprintln('smokeping: unexpected status ${response.status_code} for target ${target}')
		return SmokePingPayload{
			target:  target
			current: SmokePingSample{
				timestamp: now
				target:    target
				median_ms: -1
				loss_pct:  -1
				min_ms:    -1
				max_ms:    -1
				stddev_ms: -1
			}
			chart: []
		}
	}

	// Parse the SmokePing response body.
	// SmokePing CGI returns HTML with embedded RRD data. We attempt
	// to extract numerical values from the response. If parsing fails,
	// return a zero-value sample (probe reachable but data not parseable).
	chart_points := parse_smokeping_response(response.body, target)

	// Build the current sample from the most recent chart point,
	// or use zero values if no chart data was extracted.
	current := if chart_points.len > 0 {
		last := chart_points[chart_points.len - 1]
		SmokePingSample{
			timestamp: last.timestamp
			target:    target
			median_ms: last.median_ms
			loss_pct:  last.loss_pct
			min_ms:    last.median_ms // Approximation — CGI summary lacks min/max
			max_ms:    last.median_ms // Approximation — CGI summary lacks min/max
			stddev_ms: 0              // Not available from summary display mode
		}
	} else {
		SmokePingSample{
			timestamp: now
			target:    target
			median_ms: 0
			loss_pct:  0
			min_ms:    0
			max_ms:    0
			stddev_ms: 0
		}
	}

	return SmokePingPayload{
		target:  target
		current: current
		chart:   chart_points
	}
}

// parse_smokeping_response extracts SmokeChartPoint records from
// SmokePing's CGI HTML response body.
//
// SmokePing's CGI output contains RRD data embedded in the HTML.
// We look for lines containing numerical data in known formats:
//   - RRD XML export: <row><v>timestamp</v><v>value</v>...</row>
//   - JavaScript data arrays: data = [[timestamp, value, ...], ...]
//   - CSV-style output: timestamp,median,loss,...
//
// If none of these formats are detected, returns an empty array
// (the caller will use zero-value defaults).
fn parse_smokeping_response(body string, target string) []SmokeChartPoint {
	mut points := []SmokeChartPoint{}

	// Attempt to find RRD-style data lines in the response.
	// SmokePing embeds chart data in various formats depending on
	// the installation and version. We try multiple extraction strategies.

	lines := body.split('\n')
	for line in lines {
		trimmed := line.trim_space()

		// Strategy 1: Look for comma-separated numeric data lines
		// (some SmokePing installations output CSV-like data)
		if trimmed.len > 0 && trimmed[0] >= `0` && trimmed[0] <= `9` {
			fields := trimmed.split(',')
			if fields.len >= 3 {
				ts := fields[0].trim_space()
				median := fields[1].trim_space().f64()
				loss := fields[2].trim_space().f64()

				if median >= 0 {
					points << SmokeChartPoint{
						timestamp: ts
						median_ms: median
						loss_pct:  loss
					}
				}
			}
		}

		// Strategy 2: Look for RRD XML row elements
		// Format: <row><v>timestamp</v><v>median</v><v>loss</v></row>
		if trimmed.starts_with('<row>') && trimmed.contains('<v>') {
			values := extract_rrd_values(trimmed)
			if values.len >= 3 {
				points << SmokeChartPoint{
					timestamp: values[0]
					median_ms: values[1].f64()
					loss_pct:  values[2].f64()
				}
			}
		}
	}

	return points
}

// extract_rrd_values pulls <v>...</v> values from an RRD XML row element.
// Returns the inner text of each <v> tag as a string array.
fn extract_rrd_values(row string) []string {
	mut values := []string{}
	mut remaining := row

	for {
		start := remaining.index('<v>') or { break }
		end := remaining.index('</v>') or { break }
		if end > start + 3 {
			values << remaining[start + 3..end]
		}
		remaining = remaining[end + 4..]
	}

	return values
}

// smokeping_payload_to_json serialises a SmokePingPayload to JSON.
// Field names use camelCase to match the GraphQL schema convention
// (medianMs, lossPct, minMs, maxMs, stddevMs).
pub fn smokeping_payload_to_json(payload SmokePingPayload) string {
	// Serialise the current sample
	c := payload.current
	current_json := '{"timestamp":"${c.timestamp}","target":"${c.target}","medianMs":${c.median_ms},"lossPct":${c.loss_pct},"minMs":${c.min_ms},"maxMs":${c.max_ms},"stddevMs":${c.stddev_ms}}'

	// Serialise the chart points array
	mut chart_json := []string{}
	for pt in payload.chart {
		chart_json << '{"timestamp":"${pt.timestamp}","medianMs":${pt.median_ms},"lossPct":${pt.loss_pct}}'
	}

	return '{"target":"${payload.target}","current":${current_json},"chart":[${chart_json.join(",")}]}'
}
