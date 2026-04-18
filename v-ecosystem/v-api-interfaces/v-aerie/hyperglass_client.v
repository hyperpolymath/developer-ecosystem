// SPDX-License-Identifier: PMPL-1.0-or-later
//
// hyperglass_client.v — HTTP Client for Hyperglass Probe
//
// Queries the Hyperglass BGP looking glass at HYPERGLASS_URL
// (default http://hyperglass:8082) for route forensics data.
// Parses responses into RouteHop records matching the Idris2 ABI
// and protobuf definitions.
//
// Hyperglass provides BGP route path analysis, showing each hop
// in the network path with ASN ownership and round-trip latency.

module main

import net.http
import os
import x.json2

// RouteHop represents a single hop in a BGP route path.
// Fields match src/abi/Types.idr and src/api/proto/aerie.proto.
pub struct RouteHop {
pub:
	hop    int
	ip     string
	asn    string
	rtt_ms f64
}

// RouteForensicsPayload is the response wrapper for route forensics queries.
pub struct RouteForensicsPayload {
pub:
	target string
	path   []RouteHop
}

// get_hyperglass_url returns the configured Hyperglass endpoint.
fn get_hyperglass_url() string {
	url := os.getenv('HYPERGLASS_URL')
	if url.len > 0 {
		return url
	}
	return 'http://hyperglass:8082'
}

// get_route_forensics queries Hyperglass for BGP route information
// to the specified target (IP address or hostname).
//
// Attempts to call the Hyperglass API for a BGP route lookup.
// If the probe is unreachable, returns an empty path list with
// the target preserved (rather than failing the entire request).
//
// In production, Hyperglass runs as a container in the aerie-net
// network and exposes its API on internal port 80 (mapped to host 8082).
pub fn get_route_forensics(target string) RouteForensicsPayload {
	base_url := get_hyperglass_url()

	// Hyperglass API query endpoint
	response := http.fetch(http.FetchConfig{
		url:    '${base_url}/api/query/'
		method: .post
		header: http.new_header(key: .content_type, value: 'application/json')
		data:   '{"query_location":"","query_target":"${target}","query_type":"bgp_route"}'
	}) or {
		eprintln('hyperglass: probe unreachable at ${base_url}: ${err}')
		return RouteForensicsPayload{
			target: target
			path:   []
		}
	}

	if response.status_code != 200 {
		eprintln('hyperglass: unexpected status ${response.status_code} for target ${target}')
		return RouteForensicsPayload{
			target: target
			path:   []
		}
	}

	// Parse the Hyperglass response into RouteHop records
	parsed := json2.decode[json2.Any](response.body) or {
		eprintln('hyperglass: failed to parse response JSON')
		return RouteForensicsPayload{
			target: target
			path:   []
		}
	}

	// Extract route hops from the parsed JSON
	hops := parse_route_hops(parsed)

	return RouteForensicsPayload{
		target: target
		path:   hops
	}
}

// parse_route_hops extracts RouteHop records from a Hyperglass JSON response.
// The exact structure depends on the Hyperglass version and device type.
fn parse_route_hops(data json2.Any) []RouteHop {
	mut hops := []RouteHop{}

	// Hyperglass returns route data in various formats depending on
	// the router type. We attempt to extract hop-by-hop information.
	arr := data.as_array()
	for i, item in arr {
		obj := item.as_map()
		ip := if 'prefix' in obj {
			obj['prefix'] or { json2.Any('') }.str()
		} else if 'ip' in obj {
			obj['ip'] or { json2.Any('') }.str()
		} else {
			''
		}

		asn := if 'as_path' in obj {
			obj['as_path'] or { json2.Any('') }.str()
		} else if 'asn' in obj {
			obj['asn'] or { json2.Any('') }.str()
		} else {
			''
		}

		hops << RouteHop{
			hop:    i + 1
			ip:     ip
			asn:    asn
			rtt_ms: 0
		}
	}

	return hops
}

// route_forensics_to_json serialises a RouteForensicsPayload to JSON.
pub fn route_forensics_to_json(payload RouteForensicsPayload) string {
	mut hops_json := []string{}
	for h in payload.path {
		asn_field := if h.asn.len > 0 { '"${h.asn}"' } else { 'null' }
		rtt_field := if h.rtt_ms > 0 { '${h.rtt_ms}' } else { 'null' }
		hops_json << '{"hop":${h.hop},"ip":"${h.ip}","asn":${asn_field},"rttMs":${rtt_field}}'
	}
	return '{"target":"${payload.target}","path":[${hops_json.join(",")}]}'
}
