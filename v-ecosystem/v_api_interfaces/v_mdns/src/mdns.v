// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mdns -- Multicast DNS (mDNS) service discovery, registration, browsing,
// and name resolution for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-mdns.
// Implements zero-configuration networking service advertisement and query
// per RFC 6762 and DNS-SD per RFC 6763.
module v_mdns

import time

// mdns_multicast_addr is the standard mDNS multicast address (IPv4).
const mdns_multicast_addr = '224.0.0.251'

// mdns_port is the standard mDNS port number.
const mdns_port = 5353

// RecordType enumerates DNS record types used in mDNS queries and responses.
pub enum RecordType as u16 {
	a     = 1
	aaaa  = 28
	ptr   = 12
	srv   = 33
	txt   = 16
}

// record_type_to_string returns the human-readable label for a RecordType.
pub fn record_type_to_string(rt RecordType) string {
	return match rt {
		.a { 'A' }
		.aaaa { 'AAAA' }
		.ptr { 'PTR' }
		.srv { 'SRV' }
		.txt { 'TXT' }
	}
}

// ServiceInfo holds the details of a registered or discovered mDNS service
// including its name, type, port, host, and TXT key-value records.
pub struct ServiceInfo {
pub:
	// name is the human-readable service instance name (e.g. "My Printer").
	name string
	// service_type is the DNS-SD service type (e.g. "_http._tcp.local.").
	service_type string
	// port is the port number the service listens on.
	port int
	// host is the hostname of the machine providing the service.
	host string
	// txt_records holds key-value pairs from the TXT record.
	txt_records map[string]string
	// ttl is the record time-to-live in seconds (default 120).
	ttl u32 = 120
pub mut:
	// last_seen records when this service was last seen/refreshed.
	last_seen ?time.Time
}

// full_name returns the fully-qualified DNS-SD instance name
// (e.g. "My Printer._http._tcp.local.").
pub fn (s ServiceInfo) full_name() string {
	return '${s.name}.${s.service_type}'
}

// is_expired checks whether the service record has exceeded its TTL
// since it was last seen.
pub fn (s ServiceInfo) is_expired() bool {
	seen := s.last_seen or { return true }
	elapsed := time.since(seen).seconds()
	return elapsed > i64(s.ttl)
}

// encode_txt_records serialises the TXT record key-value pairs into
// the DNS TXT record wire format (length-prefixed strings).
pub fn (s ServiceInfo) encode_txt_records() []u8 {
	mut result := []u8{}
	for key, value in s.txt_records {
		entry := '${key}=${value}'
		if entry.len <= 255 {
			result << u8(entry.len)
			result << entry.bytes()
		}
	}
	if result.len == 0 {
		// Empty TXT record must have a single zero-length string
		result << u8(0)
	}
	return result
}

// MdnsQuery represents a query to be sent via mDNS multicast.
pub struct MdnsQuery {
pub:
	// name is the domain name being queried.
	name string
	// record_type is the DNS record type to query for.
	record_type RecordType
	// unicast_response requests a unicast response (QU bit).
	unicast_response bool
}

// MdnsRecord holds a single DNS resource record from an mDNS response.
pub struct MdnsRecord {
pub:
	// name is the record name.
	name string
	// record_type is the DNS record type.
	record_type RecordType
	// ttl is the time-to-live in seconds.
	ttl u32
	// data is the record data as a string.
	data string
}

// MdnsResponse holds a complete mDNS response with answer records.
pub struct MdnsResponse {
pub:
	// records contains the answer resource records.
	records []MdnsRecord
	// additional contains additional resource records.
	additional []MdnsRecord
}

// MdnsServer manages service registration, discovery, and query handling
// for mDNS/DNS-SD on the local network.
pub struct MdnsServer {
pub:
	// hostname is the local machine's hostname.
	hostname string
	// domain is the mDNS domain (default ".local.").
	domain string = '.local.'
pub mut:
	// services contains the locally registered services.
	services []ServiceInfo
	// cache holds discovered remote services.
	cache []ServiceInfo
}

// new_server creates a new MdnsServer with the given hostname.
pub fn new_server(hostname string) &MdnsServer {
	return &MdnsServer{
		hostname: hostname
	}
}

// register_service advertises a new service on the local network.
// The service is added to the local registry and its TTL timer starts.
// TODO: Network I/O -- send mDNS announcement packets via multicast.
pub fn (mut s MdnsServer) register_service(service ServiceInfo) {
	mut svc := service
	svc.last_seen = time.now()
	// Replace existing service with same name and type
	for i, existing in s.services {
		if existing.name == service.name && existing.service_type == service.service_type {
			s.services[i] = svc
			return
		}
	}
	s.services << svc
}

// unregister_service removes a service from advertisement. Sends a
// goodbye packet (TTL=0) per RFC 6762 section 10.1.
// TODO: Network I/O -- send goodbye announcement via multicast.
pub fn (mut s MdnsServer) unregister_service(name string, service_type string) bool {
	original_len := s.services.len
	s.services = s.services.filter(!(it.name == name && it.service_type == service_type))
	return s.services.len < original_len
}

// browse_services returns all known services (local and cached) matching
// the given service type.
pub fn (s MdnsServer) browse_services(service_type string) []ServiceInfo {
	mut results := []ServiceInfo{}
	// Include local services
	for svc in s.services {
		if svc.service_type == service_type {
			results << svc
		}
	}
	// Include cached (discovered) services
	for svc in s.cache {
		if svc.service_type == service_type && !svc.is_expired() {
			results << svc
		}
	}
	return results
}

// resolve_service looks up a specific service by instance name and type.
// Checks local services first, then the discovery cache.
// TODO: Network I/O -- send unicast query if not in cache.
pub fn (s MdnsServer) resolve_service(name string, service_type string) !ServiceInfo {
	// Check local services
	for svc in s.services {
		if svc.name == name && svc.service_type == service_type {
			return svc
		}
	}
	// Check cache
	for svc in s.cache {
		if svc.name == name && svc.service_type == service_type && !svc.is_expired() {
			return svc
		}
	}
	return error('service not found: ${name}.${service_type}')
}

// query constructs an mDNS query for the given name and record type.
// Returns the query structure (network sending is deferred).
// TODO: Network I/O -- send query via multicast to 224.0.0.251:5353.
pub fn (s MdnsServer) query(name string, record_type RecordType) MdnsQuery {
	return MdnsQuery{
		name: name
		record_type: record_type
		unicast_response: false
	}
}

// process_response handles an incoming mDNS response by updating the
// service discovery cache. New services are added; existing ones are
// refreshed or removed (if TTL=0 / goodbye).
pub fn (mut s MdnsServer) process_response(resp MdnsResponse) {
	for record in resp.records {
		// Handle PTR records (service browsing)
		if record.record_type == .ptr {
			s.update_cache_from_ptr(record, resp)
		}
		// Handle goodbye (TTL=0)
		if record.ttl == 0 {
			s.cache = s.cache.filter(!(it.full_name() == record.name))
		}
	}
}

// update_cache_from_ptr extracts service info from PTR + SRV + TXT records.
fn (mut s MdnsServer) update_cache_from_ptr(ptr_record MdnsRecord, resp MdnsResponse) {
	instance_name := ptr_record.data
	service_type := ptr_record.name

	// Look for matching SRV and TXT in additional records
	mut port := 0
	mut host := ''
	mut txt := map[string]string{}

	for add in resp.additional {
		if add.name == instance_name {
			match add.record_type {
				.srv {
					// SRV data format: "priority weight port host"
					parts := add.data.split(' ')
					if parts.len >= 4 {
						port = parts[2].int()
						host = parts[3]
					}
				}
				.txt {
					// Parse TXT key=value pairs
					for entry in add.data.split(';') {
						kv := entry.split_nth('=', 2)
						if kv.len == 2 {
							txt[kv[0]] = kv[1]
						}
					}
				}
				else {}
			}
		}
	}

	// Determine display name from instance_name
	name := if instance_name.contains('.') {
		instance_name.all_before('.')
	} else {
		instance_name
	}

	svc := ServiceInfo{
		name: name
		service_type: service_type
		port: port
		host: host
		txt_records: txt
		ttl: ptr_record.ttl
		last_seen: time.now()
	}

	// Update or insert into cache
	for i, existing in s.cache {
		if existing.name == name && existing.service_type == service_type {
			s.cache[i] = svc
			return
		}
	}
	s.cache << svc
}

// service_count returns the number of locally registered services.
pub fn (s MdnsServer) service_count() int {
	return s.services.len
}

// cache_size returns the number of discovered services in the cache.
pub fn (s MdnsServer) cache_size() int {
	return s.cache.len
}

// prune_expired removes expired entries from the discovery cache.
pub fn (mut s MdnsServer) prune_expired() int {
	original := s.cache.len
	s.cache = s.cache.filter(!it.is_expired())
	return original - s.cache.len
}

// decode_txt_records parses DNS TXT record wire-format bytes into
// key-value pairs.
pub fn decode_txt_records(data []u8) map[string]string {
	mut result := map[string]string{}
	mut pos := 0
	for pos < data.len {
		length := int(data[pos])
		pos++
		if length == 0 || pos + length > data.len {
			break
		}
		entry := data[pos..pos + length].bytestr()
		kv := entry.split_nth('=', 2)
		if kv.len == 2 {
			result[kv[0]] = kv[1]
		}
		pos += length
	}
	return result
}
