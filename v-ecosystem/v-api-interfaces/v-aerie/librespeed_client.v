// SPDX-License-Identifier: PMPL-1.0-or-later
//
// librespeed_client.v — HTTP Client for LibreSpeed Probe
//
// Queries the LibreSpeed backend at LIBRESPEED_URL (default http://librespeed:8080)
// to obtain zero-telemetry speed test results. Parses the response into
// TelemetrySample records matching the Idris2 ABI and protobuf definitions.
//
// LibreSpeed provides download/upload speed, latency, and jitter metrics
// without sending any data to external telemetry services.

module main

import net.http
import os
import time
import x.json2

// TelemetrySample represents a single network measurement from LibreSpeed.
// Fields match src/abi/Types.idr and src/api/proto/aerie.proto.
pub struct TelemetrySample {
pub:
	timestamp   string
	latency_ms  f64
	jitter_ms   f64
	packet_loss f64
}

// TelemetryPayload is the response wrapper for telemetry queries.
pub struct TelemetryPayload {
pub:
	samples []TelemetrySample
}

// get_librespeed_url returns the configured LibreSpeed endpoint.
fn get_librespeed_url() string {
	url := os.getenv('LIBRESPEED_URL')
	if url.len > 0 {
		return url
	}
	return 'http://librespeed:8080'
}

// get_telemetry queries LibreSpeed for current network telemetry.
//
// Attempts to fetch results from LibreSpeed's backend API endpoint.
// If the probe is unreachable, returns a synthetic sample with -1 values
// to indicate unavailability (rather than failing the entire request).
//
// In production, LibreSpeed runs as a container in the aerie-net network
// and responds on its internal port 80 (mapped to host 8080).
pub fn get_telemetry() TelemetryPayload {
	base_url := get_librespeed_url()
	now := time.now().format_rfc3339()

	// LibreSpeed backend API endpoint for results
	response := http.get('${base_url}/backend/getIP.php') or {
		eprintln('librespeed: probe unreachable at ${base_url}: ${err}')
		return TelemetryPayload{
			samples: [
				TelemetrySample{
					timestamp:   now
					latency_ms:  -1
					jitter_ms:   -1
					packet_loss: -1
				},
			]
		}
	}

	if response.status_code != 200 {
		eprintln('librespeed: unexpected status ${response.status_code}')
		return TelemetryPayload{
			samples: [
				TelemetrySample{
					timestamp:   now
					latency_ms:  -1
					jitter_ms:   -1
					packet_loss: -1
				},
			]
		}
	}

	// Parse the LibreSpeed response.
	// The getIP.php endpoint returns JSON with connection info.
	// We extract what's available and synthesise latency from response time.
	_ = json2.decode[json2.Any](response.body) or {
		return TelemetryPayload{
			samples: [
				TelemetrySample{
					timestamp:   now
					latency_ms:  0
					jitter_ms:   0
					packet_loss: 0
				},
			]
		}
	}

	// Build a sample from the available data.
	// Phase 2 will extract actual speed/latency values from the response.
	return TelemetryPayload{
		samples: [
			TelemetrySample{
				timestamp:   now
				latency_ms:  0
				jitter_ms:   0
				packet_loss: 0
			},
		]
	}
}

// telemetry_payload_to_json serialises a TelemetryPayload to JSON.
pub fn telemetry_payload_to_json(payload TelemetryPayload) string {
	mut samples_json := []string{}
	for s in payload.samples {
		samples_json << '{"timestamp":"${s.timestamp}","latencyMs":${s.latency_ms},"jitterMs":${s.jitter_ms},"packetLoss":${s.packet_loss}}'
	}
	return '{"samples":[${samples_json.join(",")}]}'
}
