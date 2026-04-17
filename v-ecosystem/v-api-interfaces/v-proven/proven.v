// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Proven V Bindings - Thin FFI wrapper around libproven.
//
// All computation is performed in formally verified Idris 2 code via Zig FFI.
// This module contains ONLY data marshalling; NO reimplemented logic.

module proven

#flag -lproven
#flag -L../../ffi/zig/zig-out/lib
#flag -I../../bindings/c/include

#include "proven.h"

// ============================================================================
// C type declarations matching proven.h
// ============================================================================

struct C.ProvenIntResult {
	status int
	value  i64
}

struct C.ProvenBoolResult {
	status int
	value  bool
}

struct C.ProvenStringResult {
	status int
	value  &u8
	length usize
}

struct C.ProvenFloatResult {
	status int
	value  f64
}

struct C.ProvenUrlComponents {
	scheme     &u8
	scheme_len usize
	host       &u8
	host_len   usize
	port       u16
	has_port   bool
	path       &u8
	path_len   usize
	query      &u8
	query_len  usize
	fragment   &u8
	fragment_len usize
}

struct C.ProvenUrlResult {
	status     int
	components C.ProvenUrlComponents
}

struct C.ProvenIPv4Address {
	octets [4]u8
}

struct C.ProvenIPv4Result {
	status  int
	address C.ProvenIPv4Address
}

struct C.ProvenContentTypeResult {
	status         int
	media_type     &u8
	media_type_len usize
	subtype        &u8
	subtype_len    usize
	suffix         &u8
	suffix_len     usize
	category       int
	charset        int
	has_charset    bool
}

struct C.ProvenUUID {
	bytes [16]u8
}

struct C.ProvenUUIDResult {
	status int
	uuid   C.ProvenUUID
}

struct C.ProvenDateTime {
	year              int
	month             u8
	day               u8
	hour              u8
	minute            u8
	second            u8
	nanosecond        u32
	tz_offset_minutes i16
}

struct C.ProvenDateTimeResult {
	status   int
	datetime C.ProvenDateTime
}

struct C.ProvenPasswordResult {
	strength      int
	has_lowercase bool
	has_uppercase bool
	has_digit     bool
	has_special   bool
	length        usize
}

struct C.ProvenHexDecodeResult {
	status int
	data   &u8
	length usize
}

struct C.ProvenCurrencyResult {
	status         int
	amount_minor   i64
	currency_code  [3]u8
	decimal_places u8
}

struct C.ProvenPhoneResult {
	status          int
	country_code    u16
	national_number u64
	is_valid        bool
}

struct C.ProvenSemanticVersion {
	major          u32
	minor          u32
	patch          u32
	prerelease_len usize
	prerelease     &u8
}

struct C.ProvenVersionResult {
	status  int
	version C.ProvenSemanticVersion
}

struct C.ProvenGeoCoordinate {
	latitude  f64
	longitude f64
}

struct C.ProvenGeoResult {
	status     int
	coordinate C.ProvenGeoCoordinate
}

struct C.ProvenCookieAttributes {
	domain     &u8
	domain_len usize
	path       &u8
	path_len   usize
	max_age    i64
	secure     bool
	http_only  bool
	same_site  int
	partitioned bool
}

struct C.ProvenBoundedBuffer {
	data     &u8
	capacity usize
	length   usize
}

struct C.ProvenBufferResult {
	status int
	buffer &C.ProvenBoundedBuffer
}

struct C.ProvenRateLimiter {
	tokens      f64
	capacity    f64
	refill_rate f64
	last_refill i64
}

struct C.ProvenCircuitBreaker {
	state             int
	failure_count     u32
	failure_threshold u32
	success_count     u32
	success_threshold u32
	last_failure      i64
	timeout_ms        i64
}

struct C.ProvenMonotonicCounter {
	value     u64
	max_value u64
}

struct C.ProvenStateMachine {
	current_state u32
	state_count   u32
	transitions   &u8
}

struct C.ProvenTensor2D {
	data &f64
	rows usize
	cols usize
}

struct C.ProvenBoundedQueue {
	data     &i64
	capacity usize
	head     usize
	tail     usize
	count    usize
}

struct C.ProvenBloomFilter {
	bits       &u8
	bit_count  usize
	hash_count u32
}

struct C.ProvenRetryConfig {
	max_attempts   u32
	base_delay_ms  u64
	max_delay_ms   u64
	multiplier     f64
}

struct C.ProvenLRUEntry {
	key   u64
	value i64
	prev  usize
	next  usize
	valid bool
}

struct C.ProvenLRUCache {
	entries  &C.ProvenLRUEntry
	capacity usize
	head     usize
	tail     usize
	count    usize
}

struct C.ProvenGraph {
	edges      &u8
	node_count usize
}

struct C.ProvenImageReference {
	registry       &u8
	registry_len   usize
	repository     &u8
	repository_len usize
	tag            &u8
	tag_len        usize
	digest         &u8
	digest_len     usize
}

struct C.ProvenImageRefResult {
	status    int
	reference C.ProvenImageReference
}

struct C.ProvenDigest {
	algorithm int
	value     &u8
	value_len usize
}

struct C.ProvenDigestResult {
	status int
	digest C.ProvenDigest
}

struct C.ProvenAuthChallenge {
	scheme      &u8
	scheme_len  usize
	realm       &u8
	realm_len   usize
	service     &u8
	service_len usize
	scope       &u8
	scope_len   usize
}

struct C.ProvenAuthChallengeResult {
	status    int
	challenge C.ProvenAuthChallenge
}

struct C.ProvenRGBColor {
	r u8
	g u8
	b u8
}

struct C.ProvenHSLColor {
	h f64
	s f64
	l f64
}

struct C.ProvenColorResult {
	status int
	color  C.ProvenRGBColor
}

struct C.ProvenEvent {
	event_type   int
	data_ptr     &u8
	data_len     usize
	timestamp_us u64
	code         int
}

// ============================================================================
// Foreign function declarations - every exported symbol from libproven
// ============================================================================

// Memory management
fn C.proven_free_string(ptr &u8)

// Lifecycle
fn C.proven_init() int
fn C.proven_deinit()
fn C.proven_is_initialized() bool

// Version information
fn C.proven_ffi_abi_version() u32
fn C.proven_version_major() u32
fn C.proven_version_minor() u32
fn C.proven_version_patch() u32
fn C.proven_module_count() u32

// SafeMath
fn C.proven_math_div(numerator i64, denominator i64) C.ProvenIntResult
fn C.proven_math_mod(numerator i64, denominator i64) C.ProvenIntResult
fn C.proven_math_add_checked(a i64, b i64) C.ProvenIntResult
fn C.proven_math_sub_checked(a i64, b i64) C.ProvenIntResult
fn C.proven_math_mul_checked(a i64, b i64) C.ProvenIntResult
fn C.proven_math_abs_safe(n i64) C.ProvenIntResult
fn C.proven_math_clamp(lo i64, hi i64, value i64) i64
fn C.proven_math_pow_checked(base i64, exp u32) C.ProvenIntResult

// SafeString
fn C.proven_string_is_valid_utf8(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_string_escape_sql(ptr &u8, len usize) C.ProvenStringResult
fn C.proven_string_escape_html(ptr &u8, len usize) C.ProvenStringResult
fn C.proven_string_escape_js(ptr &u8, len usize) C.ProvenStringResult

// SafePath
fn C.proven_path_has_traversal(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_path_sanitize_filename(ptr &u8, len usize) C.ProvenStringResult

// SafeCrypto
fn C.proven_crypto_constant_time_eq(ptr1 &u8, len1 usize, ptr2 &u8, len2 usize) C.ProvenBoolResult
fn C.proven_crypto_random_bytes(ptr &u8, len usize) int

// SafeUrl
fn C.proven_url_parse(ptr &u8, len usize) C.ProvenUrlResult
fn C.proven_url_free(components &C.ProvenUrlComponents)

// SafeEmail
fn C.proven_email_is_valid(ptr &u8, len usize) C.ProvenBoolResult

// SafeNetwork
fn C.proven_network_parse_ipv4(ptr &u8, len usize) C.ProvenIPv4Result
fn C.proven_network_ipv4_is_private(addr C.ProvenIPv4Address) bool
fn C.proven_network_ipv4_is_loopback(addr C.ProvenIPv4Address) bool

// SafeHeader
fn C.proven_header_has_crlf(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_header_is_valid_name(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_header_is_dangerous(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_header_render(name_ptr &u8, name_len usize, value_ptr &u8, value_len usize) C.ProvenStringResult
fn C.proven_header_build_csp(directives_json &u8, json_len usize) C.ProvenStringResult
fn C.proven_header_build_hsts(max_age i64, include_subdomains bool, preload bool) C.ProvenStringResult

// SafeCookie
fn C.proven_cookie_has_injection(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_cookie_validate_name(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_cookie_validate_value(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_cookie_get_prefix(ptr &u8, len usize) C.ProvenIntResult
fn C.proven_cookie_build_set_cookie(name_ptr &u8, name_len usize, value_ptr &u8, value_len usize, attrs C.ProvenCookieAttributes) C.ProvenStringResult
fn C.proven_cookie_build_delete(name_ptr &u8, name_len usize) C.ProvenStringResult

// SafeContentType
fn C.proven_content_type_parse(ptr &u8, len usize) C.ProvenContentTypeResult
fn C.proven_content_type_free(result &C.ProvenContentTypeResult)
fn C.proven_content_type_can_sniff_dangerous(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_content_type_render(type_ptr &u8, type_len usize, subtype_ptr &u8, subtype_len usize, suffix_ptr &u8, suffix_len usize, charset int, has_charset bool) C.ProvenStringResult
fn C.proven_content_type_is_json(subtype_ptr &u8, subtype_len usize, suffix_ptr &u8, suffix_len usize) C.ProvenBoolResult
fn C.proven_content_type_is_xml(subtype_ptr &u8, subtype_len usize, suffix_ptr &u8, suffix_len usize) C.ProvenBoolResult

// SafeUUID
fn C.proven_uuid_v4() C.ProvenUUIDResult
fn C.proven_uuid_to_string(uuid C.ProvenUUID) C.ProvenStringResult
fn C.proven_uuid_parse(ptr &u8, len usize) C.ProvenUUIDResult
fn C.proven_uuid_is_nil(uuid C.ProvenUUID) bool
fn C.proven_uuid_version(uuid C.ProvenUUID) u8

// SafeJson
fn C.proven_json_is_valid(ptr &u8, len usize) C.ProvenBoolResult
fn C.proven_json_get_type(ptr &u8, len usize) int

// SafeDateTime
fn C.proven_datetime_parse(ptr &u8, len usize) C.ProvenDateTimeResult
fn C.proven_datetime_format_iso8601(dt C.ProvenDateTime) C.ProvenStringResult
fn C.proven_datetime_is_leap_year(year int) bool
fn C.proven_datetime_days_in_month(year int, month u8) u8

// SafeFloat
fn C.proven_float_div(a f64, b f64) C.ProvenFloatResult
fn C.proven_float_is_finite(x f64) bool
fn C.proven_float_is_nan(x f64) bool
fn C.proven_float_sqrt(x f64) C.ProvenFloatResult
fn C.proven_float_ln(x f64) C.ProvenFloatResult

// SafePassword
fn C.proven_password_validate(ptr &u8, len usize) C.ProvenPasswordResult
fn C.proven_password_is_common(ptr &u8, len usize) bool

// SafeHex
fn C.proven_hex_encode(ptr &u8, len usize, uppercase bool) C.ProvenStringResult
fn C.proven_hex_decode(ptr &u8, len usize) C.ProvenHexDecodeResult
fn C.proven_hex_free(result &C.ProvenHexDecodeResult)

// SafeCurrency
fn C.proven_currency_parse(ptr &u8, len usize) C.ProvenCurrencyResult
fn C.proven_currency_format(amount_minor i64, code &u8, decimal_places u8) C.ProvenStringResult

// SafePhone
fn C.proven_phone_parse(ptr &u8, len usize) C.ProvenPhoneResult
fn C.proven_phone_format_e164(country_code u16, national_number u64) C.ProvenStringResult

// SafeVersion
fn C.proven_version_parse(ptr &u8, len usize) C.ProvenVersionResult
fn C.proven_version_compare(a C.ProvenSemanticVersion, b C.ProvenSemanticVersion) int
fn C.proven_version_free(version &C.ProvenSemanticVersion)

// SafeGeo
fn C.proven_geo_validate(lat f64, lon f64) C.ProvenGeoResult
fn C.proven_geo_distance(a C.ProvenGeoCoordinate, b C.ProvenGeoCoordinate) C.ProvenFloatResult
fn C.proven_geo_in_bounds(coord C.ProvenGeoCoordinate, min_lat f64, max_lat f64, min_lon f64, max_lon f64) bool

// SafeChecksum
fn C.proven_checksum_crc32(ptr &u8, len usize) C.ProvenIntResult
fn C.proven_checksum_verify_crc32(ptr &u8, len usize, expected u32) C.ProvenBoolResult

// SafeProbability
fn C.proven_probability_create(value f64) f64
fn C.proven_probability_and(a f64, b f64) f64
fn C.proven_probability_or_exclusive(a f64, b f64) f64
fn C.proven_probability_not(p f64) f64

// SafeCalculator
fn C.proven_calculator_eval(ptr &u8, len usize) C.ProvenFloatResult

// SafeBuffer
fn C.proven_buffer_create(capacity usize) C.ProvenBufferResult
fn C.proven_buffer_append(buffer &C.ProvenBoundedBuffer, ptr &u8, len usize) int
fn C.proven_buffer_get(buffer &C.ProvenBoundedBuffer, out_ptr &&u8, out_len &usize) int
fn C.proven_buffer_free(buffer &C.ProvenBoundedBuffer)

// SafeRateLimiter
fn C.proven_rate_limiter_create(capacity f64, refill_rate f64) &C.ProvenRateLimiter
fn C.proven_rate_limiter_try_acquire(limiter &C.ProvenRateLimiter, tokens f64) bool
fn C.proven_rate_limiter_free(limiter &C.ProvenRateLimiter)

// SafeCircuitBreaker
fn C.proven_circuit_breaker_create(failure_threshold u32, success_threshold u32, timeout_ms i64) &C.ProvenCircuitBreaker
fn C.proven_circuit_breaker_allow(cb &C.ProvenCircuitBreaker) bool
fn C.proven_circuit_breaker_success(cb &C.ProvenCircuitBreaker)
fn C.proven_circuit_breaker_failure(cb &C.ProvenCircuitBreaker)
fn C.proven_circuit_breaker_state(cb &C.ProvenCircuitBreaker) int
fn C.proven_circuit_breaker_free(cb &C.ProvenCircuitBreaker)

// SafeRetry
fn C.proven_retry_delay(config C.ProvenRetryConfig, attempt u32) u64
fn C.proven_retry_should_retry(config C.ProvenRetryConfig, attempt u32) bool

// SafeMonotonic
fn C.proven_monotonic_create(initial u64, max_value u64) &C.ProvenMonotonicCounter
fn C.proven_monotonic_next(counter &C.ProvenMonotonicCounter) C.ProvenIntResult
fn C.proven_monotonic_free(counter &C.ProvenMonotonicCounter)

// SafeStateMachine
fn C.proven_state_machine_create(state_count u32, initial_state u32) &C.ProvenStateMachine
fn C.proven_state_machine_allow(sm &C.ProvenStateMachine, from u32, to u32) bool
fn C.proven_state_machine_transition(sm &C.ProvenStateMachine, to u32) bool
fn C.proven_state_machine_state(sm &C.ProvenStateMachine) u32
fn C.proven_state_machine_free(sm &C.ProvenStateMachine)

// SafeTensor
fn C.proven_tensor_create(rows usize, cols usize) &C.ProvenTensor2D
fn C.proven_tensor_set(tensor &C.ProvenTensor2D, row usize, col usize, value f64) int
fn C.proven_tensor_get(tensor &C.ProvenTensor2D, row usize, col usize) C.ProvenFloatResult
fn C.proven_tensor_matmul(a &C.ProvenTensor2D, b &C.ProvenTensor2D) &C.ProvenTensor2D
fn C.proven_tensor_free(tensor &C.ProvenTensor2D)

// SafeMl
fn C.proven_ml_softmax(input &f64, output &f64, len usize) int
fn C.proven_ml_sigmoid(x f64) f64
fn C.proven_ml_relu(x f64) f64
fn C.proven_ml_leaky_relu(x f64, alpha f64) f64
fn C.proven_ml_clamp(x f64, min_val f64, max_val f64) f64

// SafeLru
fn C.proven_lru_create(capacity usize) &C.ProvenLRUCache
fn C.proven_lru_get(cache &C.ProvenLRUCache, key u64) C.ProvenIntResult
fn C.proven_lru_put(cache &C.ProvenLRUCache, key u64, value i64) int
fn C.proven_lru_free(cache &C.ProvenLRUCache)

// SafeGraph
fn C.proven_graph_create(node_count usize) &C.ProvenGraph
fn C.proven_graph_add_edge(graph &C.ProvenGraph, from usize, to usize) int
fn C.proven_graph_has_edge(graph &C.ProvenGraph, from usize, to usize) bool
fn C.proven_graph_free(graph &C.ProvenGraph)

// SafeQueue
fn C.proven_queue_create(capacity usize) &C.ProvenBoundedQueue
fn C.proven_queue_push(queue &C.ProvenBoundedQueue, value i64) bool
fn C.proven_queue_pop(queue &C.ProvenBoundedQueue) C.ProvenIntResult
fn C.proven_queue_size(queue &C.ProvenBoundedQueue) usize
fn C.proven_queue_free(queue &C.ProvenBoundedQueue)

// SafeBloom
fn C.proven_bloom_create(expected_elements usize, false_positive_rate f64) &C.ProvenBloomFilter
fn C.proven_bloom_add(filter &C.ProvenBloomFilter, ptr &u8, len usize)
fn C.proven_bloom_contains(filter &C.ProvenBloomFilter, ptr &u8, len usize) bool
fn C.proven_bloom_free(filter &C.ProvenBloomFilter)

// SafeRegistry
fn C.proven_registry_parse(ptr &u8, len usize) C.ProvenImageRefResult
fn C.proven_registry_to_string(ref &C.ProvenImageReference) C.ProvenStringResult
fn C.proven_registry_has_registry(ref &C.ProvenImageReference) C.ProvenBoolResult

// SafeDigest
fn C.proven_digest_parse(ptr &u8, len usize) C.ProvenDigestResult
fn C.proven_digest_verify(expected &C.ProvenDigest, actual &C.ProvenDigest) C.ProvenBoolResult
fn C.proven_digest_to_string(digest &C.ProvenDigest) C.ProvenStringResult

// SafeHttp
fn C.proven_http_url_encode(ptr &u8, len usize) C.ProvenStringResult
fn C.proven_http_url_decode(ptr &u8, len usize) C.ProvenStringResult
fn C.proven_http_parse_www_authenticate(ptr &u8, len usize) C.ProvenAuthChallengeResult

// SafeColor
fn C.proven_color_parse_hex(ptr &u8, len usize) C.ProvenColorResult
fn C.proven_color_rgb_to_hsl(rgb C.ProvenRGBColor) C.ProvenHSLColor
fn C.proven_color_to_hex(rgb C.ProvenRGBColor) C.ProvenStringResult

// SafeAngle
fn C.proven_angle_deg_to_rad(degrees f64) f64
fn C.proven_angle_rad_to_deg(radians f64) f64
fn C.proven_angle_normalize_degrees(degrees f64) f64
fn C.proven_angle_normalize_radians(radians f64) f64

// SafeUnit
fn C.proven_unit_convert_length(value f64, from int, to int) C.ProvenFloatResult
fn C.proven_unit_convert_temp(value f64, from int, to int) C.ProvenFloatResult

// Callbacks
fn C.proven_callback_register(event_type int, callback fn (voidptr, &C.ProvenEvent) int, context voidptr) u32
fn C.proven_callback_unregister(handle u32) int
fn C.proven_callback_fire(event_type int, data_ptr &u8, data_len usize, code int) int
fn C.proven_callback_count(event_type int) u32
fn C.proven_callback_clear_all() u32

// ============================================================================
// Idiomatic V wrapper functions
// ============================================================================

// Helper: convert C string result to V string, freeing the C allocation.
fn string_from_proven(result C.ProvenStringResult) ?string {
	if result.status != 0 {
		return none
	}
	if result.value == unsafe { nil } {
		return none
	}
	v_str := unsafe { tos(result.value, int(result.length)) }.clone()
	C.proven_free_string(result.value)
	return v_str
}

// --- Lifecycle ---

// Initialize the Proven runtime. Must be called before any other function.
pub fn init() bool {
	return C.proven_init() == 0
}

// Cleanup the Proven runtime.
pub fn deinit() {
	C.proven_deinit()
}

// Check if the runtime is initialized.
pub fn is_initialized() bool {
	return C.proven_is_initialized()
}

// --- Version ---

// Get the FFI ABI version.
pub fn ffi_abi_version() u32 {
	return C.proven_ffi_abi_version()
}

// Get major version number.
pub fn version_major() u32 {
	return C.proven_version_major()
}

// Get minor version number.
pub fn version_minor() u32 {
	return C.proven_version_minor()
}

// Get patch version number.
pub fn version_patch() u32 {
	return C.proven_version_patch()
}

// Get total module count.
pub fn module_count() u32 {
	return C.proven_module_count()
}

// --- SafeMath ---

// Safe integer division. Returns none on division by zero or overflow.
pub fn safe_div(a i64, b i64) ?i64 {
	result := C.proven_math_div(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Safe modulo. Returns none on division by zero.
pub fn safe_mod(a i64, b i64) ?i64 {
	result := C.proven_math_mod(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Checked addition with overflow detection.
pub fn safe_add(a i64, b i64) ?i64 {
	result := C.proven_math_add_checked(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Checked subtraction with underflow detection.
pub fn safe_sub(a i64, b i64) ?i64 {
	result := C.proven_math_sub_checked(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Checked multiplication with overflow detection.
pub fn safe_mul(a i64, b i64) ?i64 {
	result := C.proven_math_mul_checked(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Safe absolute value. Returns none for min_i64.
pub fn safe_abs(n i64) ?i64 {
	result := C.proven_math_abs_safe(n)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Clamp value to [lo, hi] range.
pub fn clamp(lo i64, hi i64, value i64) i64 {
	return C.proven_math_clamp(lo, hi, value)
}

// Integer exponentiation with overflow checking.
pub fn safe_pow(base i64, exp u32) ?i64 {
	result := C.proven_math_pow_checked(base, exp)
	if result.status != 0 {
		return none
	}
	return result.value
}

// --- SafeString ---

// Check if bytes are valid UTF-8.
pub fn is_valid_utf8(data []u8) ?bool {
	result := C.proven_string_is_valid_utf8(data.data, usize(data.len))
	if result.status != 0 {
		return none
	}
	return result.value
}

// Escape string for SQL (single quotes).
pub fn escape_sql(input string) ?string {
	return string_from_proven(C.proven_string_escape_sql(input.str, usize(input.len)))
}

// Escape string for HTML (prevents XSS).
pub fn escape_html(input string) ?string {
	return string_from_proven(C.proven_string_escape_html(input.str, usize(input.len)))
}

// Escape string for JavaScript string literals.
pub fn escape_js(input string) ?string {
	return string_from_proven(C.proven_string_escape_js(input.str, usize(input.len)))
}

// --- SafePath ---

// Check if path contains directory traversal sequences.
pub fn has_traversal(path string) bool {
	result := C.proven_path_has_traversal(path.str, usize(path.len))
	if result.status != 0 {
		return false
	}
	return result.value
}

// Sanitize a filename by removing dangerous characters.
pub fn sanitize_filename(filename string) ?string {
	return string_from_proven(C.proven_path_sanitize_filename(filename.str, usize(filename.len)))
}

// --- SafeCrypto ---

// Constant-time byte comparison (timing-attack safe).
pub fn constant_time_eq(a []u8, b []u8) bool {
	result := C.proven_crypto_constant_time_eq(a.data, usize(a.len), b.data, usize(b.len))
	if result.status != 0 {
		return false
	}
	return result.value
}

// Constant-time string comparison (timing-attack safe).
pub fn constant_time_equals_string(a string, b string) bool {
	return constant_time_eq(a.bytes(), b.bytes())
}

// Fill buffer with cryptographically secure random bytes.
pub fn random_bytes(count int) ?[]u8 {
	mut buf := []u8{len: count}
	status := C.proven_crypto_random_bytes(buf.data, usize(count))
	if status != 0 {
		return none
	}
	return buf
}

// --- SafeUrl ---

// Parse a URL into components. Caller must call url_free on result.
pub fn url_parse(url string) C.ProvenUrlResult {
	return C.proven_url_parse(url.str, usize(url.len))
}

// Free URL components allocated by url_parse.
pub fn url_free(mut components C.ProvenUrlComponents) {
	C.proven_url_free(&components)
}

// --- SafeEmail ---

// Validate email address (RFC 5321 simplified).
pub fn is_valid_email(email string) bool {
	result := C.proven_email_is_valid(email.str, usize(email.len))
	if result.status != 0 {
		return false
	}
	return result.value
}

// --- SafeNetwork ---

// Parse IPv4 address string.
pub fn parse_ipv4(address string) ?C.ProvenIPv4Address {
	result := C.proven_network_parse_ipv4(address.str, usize(address.len))
	if result.status != 0 {
		return none
	}
	return result.address
}

// Check if IPv4 address is private (RFC 1918).
pub fn ipv4_is_private(addr C.ProvenIPv4Address) bool {
	return C.proven_network_ipv4_is_private(addr)
}

// Check if IPv4 address is loopback (127.0.0.0/8).
pub fn ipv4_is_loopback(addr C.ProvenIPv4Address) bool {
	return C.proven_network_ipv4_is_loopback(addr)
}

// --- SafeHeader ---

// Check for CRLF injection characters in header value.
pub fn header_has_crlf(value string) bool {
	result := C.proven_header_has_crlf(value.str, usize(value.len))
	return result.status == 0 && result.value
}

// Check if header name is a valid token per RFC 7230.
pub fn header_is_valid_name(name string) bool {
	result := C.proven_header_is_valid_name(name.str, usize(name.len))
	return result.status == 0 && result.value
}

// Check if header name is dangerous.
pub fn header_is_dangerous(name string) bool {
	result := C.proven_header_is_dangerous(name.str, usize(name.len))
	return result.status == 0 && result.value
}

// Create validated header string "Name: Value".
pub fn header_render(name string, value string) ?string {
	return string_from_proven(C.proven_header_render(name.str, usize(name.len), value.str, usize(value.len)))
}

// Build Content-Security-Policy header value from JSON directives.
pub fn header_build_csp(directives_json string) ?string {
	return string_from_proven(C.proven_header_build_csp(directives_json.str, usize(directives_json.len)))
}

// Build HSTS header value.
pub fn header_build_hsts(max_age i64, include_subdomains bool, preload bool) ?string {
	return string_from_proven(C.proven_header_build_hsts(max_age, include_subdomains, preload))
}

// --- SafeCookie ---

// Check for cookie injection characters.
pub fn cookie_has_injection(value string) bool {
	result := C.proven_cookie_has_injection(value.str, usize(value.len))
	return result.status == 0 && result.value
}

// Validate cookie name.
pub fn cookie_validate_name(name string) bool {
	result := C.proven_cookie_validate_name(name.str, usize(name.len))
	return result.status == 0 && result.value
}

// Validate cookie value.
pub fn cookie_validate_value(value string) bool {
	result := C.proven_cookie_validate_value(value.str, usize(value.len))
	return result.status == 0 && result.value
}

// Get cookie prefix type (0=none, 1=__Secure-, 2=__Host-).
pub fn cookie_get_prefix(name string) ?i64 {
	result := C.proven_cookie_get_prefix(name.str, usize(name.len))
	if result.status != 0 {
		return none
	}
	return result.value
}

// Build delete cookie header.
pub fn cookie_build_delete(name string) ?string {
	return string_from_proven(C.proven_cookie_build_delete(name.str, usize(name.len)))
}

// --- SafeContentType ---

// Parse Content-Type header. Caller must call content_type_free on result.
pub fn content_type_parse(content_type string) C.ProvenContentTypeResult {
	return C.proven_content_type_parse(content_type.str, usize(content_type.len))
}

// Free content type result.
pub fn content_type_free(mut result C.ProvenContentTypeResult) {
	C.proven_content_type_free(&result)
}

// Check if content type can be sniffed to something dangerous.
pub fn content_type_can_sniff_dangerous(content_type string) bool {
	result := C.proven_content_type_can_sniff_dangerous(content_type.str, usize(content_type.len))
	return result.status == 0 && result.value
}

// --- SafeUUID ---

// Generate a UUID v4 (random).
pub fn uuid_v4() ?C.ProvenUUID {
	result := C.proven_uuid_v4()
	if result.status != 0 {
		return none
	}
	return result.uuid
}

// Format UUID as canonical string.
pub fn uuid_to_string(uuid C.ProvenUUID) ?string {
	return string_from_proven(C.proven_uuid_to_string(uuid))
}

// Parse UUID from string.
pub fn uuid_parse(input string) ?C.ProvenUUID {
	result := C.proven_uuid_parse(input.str, usize(input.len))
	if result.status != 0 {
		return none
	}
	return result.uuid
}

// Check if UUID is nil (all zeros).
pub fn uuid_is_nil(uuid C.ProvenUUID) bool {
	return C.proven_uuid_is_nil(uuid)
}

// Get UUID version.
pub fn uuid_version(uuid C.ProvenUUID) u8 {
	return C.proven_uuid_version(uuid)
}

// --- SafeJson ---

// Check if string is valid JSON.
pub fn json_is_valid(input string) bool {
	result := C.proven_json_is_valid(input.str, usize(input.len))
	return result.status == 0 && result.value
}

// Get JSON value type at root level.
pub fn json_get_type(input string) int {
	return C.proven_json_get_type(input.str, usize(input.len))
}

// --- SafeDateTime ---

// Parse ISO 8601 date string.
pub fn datetime_parse(input string) ?C.ProvenDateTime {
	result := C.proven_datetime_parse(input.str, usize(input.len))
	if result.status != 0 {
		return none
	}
	return result.datetime
}

// Format DateTime as ISO 8601 string.
pub fn datetime_format_iso8601(dt C.ProvenDateTime) ?string {
	return string_from_proven(C.proven_datetime_format_iso8601(dt))
}

// Check if year is a leap year.
pub fn datetime_is_leap_year(year int) bool {
	return C.proven_datetime_is_leap_year(year)
}

// Get number of days in a month.
pub fn datetime_days_in_month(year int, month u8) u8 {
	return C.proven_datetime_days_in_month(year, month)
}

// --- SafeFloat ---

// Safe floating-point division.
pub fn float_div(a f64, b f64) ?f64 {
	result := C.proven_float_div(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Check if float is finite.
pub fn float_is_finite(x f64) bool {
	return C.proven_float_is_finite(x)
}

// Check if float is NaN.
pub fn float_is_nan(x f64) bool {
	return C.proven_float_is_nan(x)
}

// Safe square root.
pub fn float_sqrt(x f64) ?f64 {
	result := C.proven_float_sqrt(x)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Safe natural logarithm.
pub fn float_ln(x f64) ?f64 {
	result := C.proven_float_ln(x)
	if result.status != 0 {
		return none
	}
	return result.value
}

// --- SafePassword ---

// Validate password strength.
pub fn password_validate(password string) C.ProvenPasswordResult {
	return C.proven_password_validate(password.str, usize(password.len))
}

// Check if password is in common passwords list.
pub fn password_is_common(password string) bool {
	return C.proven_password_is_common(password.str, usize(password.len))
}

// --- SafeHex ---

// Encode bytes to hex string.
pub fn hex_encode(data []u8, uppercase bool) ?string {
	return string_from_proven(C.proven_hex_encode(data.data, usize(data.len), uppercase))
}

// Decode hex string to bytes.
pub fn hex_decode(input string) ?[]u8 {
	result := C.proven_hex_decode(input.str, usize(input.len))
	if result.status != 0 {
		return none
	}
	if result.data == unsafe { nil } {
		return none
	}
	decoded := unsafe { result.data.vbytes(int(result.length)) }.clone()
	mut r := result
	C.proven_hex_free(&r)
	return decoded
}

// --- SafeCurrency ---

// Parse currency amount.
pub fn currency_parse(input string) C.ProvenCurrencyResult {
	return C.proven_currency_parse(input.str, usize(input.len))
}

// Format currency amount.
pub fn currency_format(amount_minor i64, code [3]u8, decimal_places u8) ?string {
	return string_from_proven(C.proven_currency_format(amount_minor, &code[0], decimal_places))
}

// --- SafePhone ---

// Parse phone number to E.164 format.
pub fn phone_parse(input string) C.ProvenPhoneResult {
	return C.proven_phone_parse(input.str, usize(input.len))
}

// Format phone number as E.164 string.
pub fn phone_format_e164(country_code u16, national_number u64) ?string {
	return string_from_proven(C.proven_phone_format_e164(country_code, national_number))
}

// --- SafeVersion ---

// Parse semantic version string.
pub fn version_parse(input string) C.ProvenVersionResult {
	return C.proven_version_parse(input.str, usize(input.len))
}

// Compare two semantic versions.
pub fn version_compare(a C.ProvenSemanticVersion, b C.ProvenSemanticVersion) int {
	return C.proven_version_compare(a, b)
}

// Free version result resources.
pub fn version_free(mut version C.ProvenSemanticVersion) {
	C.proven_version_free(&version)
}

// --- SafeGeo ---

// Validate and normalize geographic coordinate.
pub fn geo_validate(lat f64, lon f64) ?C.ProvenGeoCoordinate {
	result := C.proven_geo_validate(lat, lon)
	if result.status != 0 {
		return none
	}
	return result.coordinate
}

// Calculate distance between two points (Haversine formula) in meters.
pub fn geo_distance(a C.ProvenGeoCoordinate, b C.ProvenGeoCoordinate) ?f64 {
	result := C.proven_geo_distance(a, b)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Check if coordinate is inside a bounding box.
pub fn geo_in_bounds(coord C.ProvenGeoCoordinate, min_lat f64, max_lat f64, min_lon f64, max_lon f64) bool {
	return C.proven_geo_in_bounds(coord, min_lat, max_lat, min_lon, max_lon)
}

// --- SafeChecksum ---

// Calculate CRC32 checksum.
pub fn checksum_crc32(data []u8) ?i64 {
	result := C.proven_checksum_crc32(data.data, usize(data.len))
	if result.status != 0 {
		return none
	}
	return result.value
}

// Verify CRC32 matches expected value.
pub fn checksum_verify_crc32(data []u8, expected u32) bool {
	result := C.proven_checksum_verify_crc32(data.data, usize(data.len), expected)
	return result.status == 0 && result.value
}

// --- SafeProbability ---

// Create probability value (clamped to [0, 1]).
pub fn probability_create(value f64) f64 {
	return C.proven_probability_create(value)
}

// Multiply probabilities (independent events).
pub fn probability_and(a f64, b f64) f64 {
	return C.proven_probability_and(a, b)
}

// Add probabilities (mutually exclusive events).
pub fn probability_or_exclusive(a f64, b f64) f64 {
	return C.proven_probability_or_exclusive(a, b)
}

// Complement probability.
pub fn probability_not(p f64) f64 {
	return C.proven_probability_not(p)
}

// --- SafeCalculator ---

// Evaluate an arithmetic expression safely.
pub fn calculator_eval(expr string) ?f64 {
	result := C.proven_calculator_eval(expr.str, usize(expr.len))
	if result.status != 0 {
		return none
	}
	return result.value
}

// --- SafeBuffer ---

// Create a bounded buffer.
pub fn buffer_create(capacity usize) ?&C.ProvenBoundedBuffer {
	result := C.proven_buffer_create(capacity)
	if result.status != 0 {
		return none
	}
	return result.buffer
}

// Append data to buffer with bounds checking.
pub fn buffer_append(buffer &C.ProvenBoundedBuffer, data []u8) bool {
	return C.proven_buffer_append(buffer, data.data, usize(data.len)) == 0
}

// Free buffer.
pub fn buffer_free(buffer &C.ProvenBoundedBuffer) {
	C.proven_buffer_free(buffer)
}

// --- SafeRateLimiter ---

// Create a rate limiter.
pub fn rate_limiter_create(capacity f64, refill_rate f64) ?&C.ProvenRateLimiter {
	ptr := C.proven_rate_limiter_create(capacity, refill_rate)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Try to acquire tokens from the rate limiter.
pub fn rate_limiter_try_acquire(limiter &C.ProvenRateLimiter, tokens f64) bool {
	return C.proven_rate_limiter_try_acquire(limiter, tokens)
}

// Free rate limiter.
pub fn rate_limiter_free(limiter &C.ProvenRateLimiter) {
	C.proven_rate_limiter_free(limiter)
}

// --- SafeCircuitBreaker ---

// Create a circuit breaker.
pub fn circuit_breaker_create(failure_threshold u32, success_threshold u32, timeout_ms i64) ?&C.ProvenCircuitBreaker {
	ptr := C.proven_circuit_breaker_create(failure_threshold, success_threshold, timeout_ms)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Check if a request should be allowed.
pub fn circuit_breaker_allow(cb &C.ProvenCircuitBreaker) bool {
	return C.proven_circuit_breaker_allow(cb)
}

// Record a successful operation.
pub fn circuit_breaker_success(cb &C.ProvenCircuitBreaker) {
	C.proven_circuit_breaker_success(cb)
}

// Record a failed operation.
pub fn circuit_breaker_failure(cb &C.ProvenCircuitBreaker) {
	C.proven_circuit_breaker_failure(cb)
}

// Get current circuit state.
pub fn circuit_breaker_state(cb &C.ProvenCircuitBreaker) int {
	return C.proven_circuit_breaker_state(cb)
}

// Free circuit breaker.
pub fn circuit_breaker_free(cb &C.ProvenCircuitBreaker) {
	C.proven_circuit_breaker_free(cb)
}

// --- SafeRetry ---

// Calculate delay for a given attempt.
pub fn retry_delay(config C.ProvenRetryConfig, attempt u32) u64 {
	return C.proven_retry_delay(config, attempt)
}

// Check if retry should be attempted.
pub fn retry_should_retry(config C.ProvenRetryConfig, attempt u32) bool {
	return C.proven_retry_should_retry(config, attempt)
}

// --- SafeMonotonic ---

// Create a monotonic counter.
pub fn monotonic_create(initial u64, max_value u64) ?&C.ProvenMonotonicCounter {
	ptr := C.proven_monotonic_create(initial, max_value)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Get next value and increment.
pub fn monotonic_next(counter &C.ProvenMonotonicCounter) ?i64 {
	result := C.proven_monotonic_next(counter)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Free monotonic counter.
pub fn monotonic_free(counter &C.ProvenMonotonicCounter) {
	C.proven_monotonic_free(counter)
}

// --- SafeStateMachine ---

// Create a state machine.
pub fn state_machine_create(state_count u32, initial_state u32) ?&C.ProvenStateMachine {
	ptr := C.proven_state_machine_create(state_count, initial_state)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Allow a state transition.
pub fn state_machine_allow(sm &C.ProvenStateMachine, from u32, to u32) bool {
	return C.proven_state_machine_allow(sm, from, to)
}

// Attempt to transition to a new state.
pub fn state_machine_transition(sm &C.ProvenStateMachine, to u32) bool {
	return C.proven_state_machine_transition(sm, to)
}

// Get current state index.
pub fn state_machine_state(sm &C.ProvenStateMachine) u32 {
	return C.proven_state_machine_state(sm)
}

// Free state machine.
pub fn state_machine_free(sm &C.ProvenStateMachine) {
	C.proven_state_machine_free(sm)
}

// --- SafeTensor ---

// Create a 2D tensor initialized to zero.
pub fn tensor_create(rows usize, cols usize) ?&C.ProvenTensor2D {
	ptr := C.proven_tensor_create(rows, cols)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Set tensor value at (row, col).
pub fn tensor_set(tensor &C.ProvenTensor2D, row usize, col usize, value f64) bool {
	return C.proven_tensor_set(tensor, row, col, value) == 0
}

// Get tensor value at (row, col).
pub fn tensor_get(tensor &C.ProvenTensor2D, row usize, col usize) ?f64 {
	result := C.proven_tensor_get(tensor, row, col)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Matrix multiplication.
pub fn tensor_matmul(a &C.ProvenTensor2D, b &C.ProvenTensor2D) ?&C.ProvenTensor2D {
	ptr := C.proven_tensor_matmul(a, b)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Free tensor.
pub fn tensor_free(tensor &C.ProvenTensor2D) {
	C.proven_tensor_free(tensor)
}

// --- SafeMl ---

// Sigmoid function.
pub fn ml_sigmoid(x f64) f64 {
	return C.proven_ml_sigmoid(x)
}

// ReLU function.
pub fn ml_relu(x f64) f64 {
	return C.proven_ml_relu(x)
}

// Leaky ReLU function.
pub fn ml_leaky_relu(x f64, alpha f64) f64 {
	return C.proven_ml_leaky_relu(x, alpha)
}

// Clamp value to [min_val, max_val].
pub fn ml_clamp(x f64, min_val f64, max_val f64) f64 {
	return C.proven_ml_clamp(x, min_val, max_val)
}

// --- SafeLru ---

// Create an LRU cache.
pub fn lru_create(capacity usize) ?&C.ProvenLRUCache {
	ptr := C.proven_lru_create(capacity)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Get value from LRU cache.
pub fn lru_get(cache &C.ProvenLRUCache, key u64) ?i64 {
	result := C.proven_lru_get(cache, key)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Put value in LRU cache.
pub fn lru_put(cache &C.ProvenLRUCache, key u64, value i64) bool {
	return C.proven_lru_put(cache, key, value) == 0
}

// Free LRU cache.
pub fn lru_free(cache &C.ProvenLRUCache) {
	C.proven_lru_free(cache)
}

// --- SafeGraph ---

// Create a directed graph.
pub fn graph_create(node_count usize) ?&C.ProvenGraph {
	ptr := C.proven_graph_create(node_count)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Add directed edge.
pub fn graph_add_edge(graph &C.ProvenGraph, from usize, to usize) bool {
	return C.proven_graph_add_edge(graph, from, to) == 0
}

// Check if directed edge exists.
pub fn graph_has_edge(graph &C.ProvenGraph, from usize, to usize) bool {
	return C.proven_graph_has_edge(graph, from, to)
}

// Free graph.
pub fn graph_free(graph &C.ProvenGraph) {
	C.proven_graph_free(graph)
}

// --- SafeQueue ---

// Create a bounded queue.
pub fn queue_create(capacity usize) ?&C.ProvenBoundedQueue {
	ptr := C.proven_queue_create(capacity)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Push value to queue.
pub fn queue_push(queue &C.ProvenBoundedQueue, value i64) bool {
	return C.proven_queue_push(queue, value)
}

// Pop value from queue.
pub fn queue_pop(queue &C.ProvenBoundedQueue) ?i64 {
	result := C.proven_queue_pop(queue)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Get queue element count.
pub fn queue_size(queue &C.ProvenBoundedQueue) usize {
	return C.proven_queue_size(queue)
}

// Free queue.
pub fn queue_free(queue &C.ProvenBoundedQueue) {
	C.proven_queue_free(queue)
}

// --- SafeBloom ---

// Create a Bloom filter.
pub fn bloom_create(expected_elements usize, false_positive_rate f64) ?&C.ProvenBloomFilter {
	ptr := C.proven_bloom_create(expected_elements, false_positive_rate)
	if ptr == unsafe { nil } {
		return none
	}
	return ptr
}

// Add element to Bloom filter.
pub fn bloom_add(filter &C.ProvenBloomFilter, data []u8) {
	C.proven_bloom_add(filter, data.data, usize(data.len))
}

// Check if element might be in filter.
pub fn bloom_contains(filter &C.ProvenBloomFilter, data []u8) bool {
	return C.proven_bloom_contains(filter, data.data, usize(data.len))
}

// Free Bloom filter.
pub fn bloom_free(filter &C.ProvenBloomFilter) {
	C.proven_bloom_free(filter)
}

// --- SafeColor ---

// Parse hex color string.
pub fn color_parse_hex(input string) ?C.ProvenRGBColor {
	result := C.proven_color_parse_hex(input.str, usize(input.len))
	if result.status != 0 {
		return none
	}
	return result.color
}

// Convert RGB to HSL.
pub fn color_rgb_to_hsl(rgb C.ProvenRGBColor) C.ProvenHSLColor {
	return C.proven_color_rgb_to_hsl(rgb)
}

// Format RGB as hex string.
pub fn color_to_hex(rgb C.ProvenRGBColor) ?string {
	return string_from_proven(C.proven_color_to_hex(rgb))
}

// --- SafeAngle ---

// Convert degrees to radians.
pub fn angle_deg_to_rad(degrees f64) f64 {
	return C.proven_angle_deg_to_rad(degrees)
}

// Convert radians to degrees.
pub fn angle_rad_to_deg(radians f64) f64 {
	return C.proven_angle_rad_to_deg(radians)
}

// Normalize angle to [0, 360) degrees.
pub fn angle_normalize_degrees(degrees f64) f64 {
	return C.proven_angle_normalize_degrees(degrees)
}

// Normalize angle to [0, 2*pi) radians.
pub fn angle_normalize_radians(radians f64) f64 {
	return C.proven_angle_normalize_radians(radians)
}

// --- SafeUnit ---

// Convert length between units.
pub fn unit_convert_length(value f64, from int, to int) ?f64 {
	result := C.proven_unit_convert_length(value, from, to)
	if result.status != 0 {
		return none
	}
	return result.value
}

// Convert temperature between units.
pub fn unit_convert_temp(value f64, from int, to int) ?f64 {
	result := C.proven_unit_convert_temp(value, from, to)
	if result.status != 0 {
		return none
	}
	return result.value
}

// --- SafeHttp ---

// URL-encode a string (RFC 3986).
pub fn http_url_encode(input string) ?string {
	return string_from_proven(C.proven_http_url_encode(input.str, usize(input.len)))
}

// URL-decode a percent-encoded string.
pub fn http_url_decode(input string) ?string {
	return string_from_proven(C.proven_http_url_decode(input.str, usize(input.len)))
}

// --- Callbacks ---

// Register a callback for a specific event type.
pub fn callback_register(event_type int, callback fn (voidptr, &C.ProvenEvent) int, context voidptr) u32 {
	return C.proven_callback_register(event_type, callback, context)
}

// Unregister a callback by handle.
pub fn callback_unregister(handle u32) bool {
	return C.proven_callback_unregister(handle) == 0
}

// Fire an event.
pub fn callback_fire(event_type int, data string, code int) int {
	return C.proven_callback_fire(event_type, data.str, usize(data.len), code)
}

// Query how many callbacks are registered for an event type.
pub fn callback_count(event_type int) u32 {
	return C.proven_callback_count(event_type)
}

// Unregister all callbacks.
pub fn callback_clear_all() u32 {
	return C.proven_callback_clear_all()
}
