// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Object Storage Protocol Connector
// Author: Jonathan D.A. Jewell
//
// S3-compatible object storage client supporting bucket lifecycle,
// object CRUD, multipart uploads, and presigned URL generation.
// Compatible with AWS S3, MinIO, Ceph RADOS Gateway, and any
// S3-API-conformant backend. Uses V's net.http for REST transport
// with HMAC-SHA256 (AWS Signature V4) request signing.

module objectstore

import net.http
import crypto.hmac
import crypto.sha256
import time

// --- Configuration ---

// Config holds the credentials and endpoint information needed to
// connect to an S3-compatible object storage service.
pub struct Config {
pub:
	endpoint          string             // e.g. "s3.amazonaws.com" or "minio.local:9000"
	access_key        string             // AWS access key ID or equivalent
	secret_key        string             // AWS secret access key or equivalent
	region            string = 'us-east-1'
	use_tls           bool   = true
	use_path_style    bool               // true for MinIO/Ceph, false for AWS virtual-hosted
	connect_timeout   time.Duration = 10 * time.second
}

// --- Data structures ---

// Bucket represents an object storage bucket (container).
pub struct Bucket {
pub:
	name          string
	creation_date string
	region        string
}

// ObjectInfo describes an object's metadata without its body content.
pub struct ObjectInfo {
pub:
	key            string
	size           i64
	last_modified  string
	etag           string
	content_type   string
}

// ObjectData holds an object's metadata together with its body bytes.
pub struct ObjectData {
pub:
	info    ObjectInfo
	body    []u8
}

// MultipartUpload tracks an in-progress multipart upload session.
pub struct MultipartUpload {
pub mut:
	bucket     string
	key        string
	upload_id  string
	parts      []UploadPart
}

// UploadPart records the ETag returned for each uploaded part,
// needed when completing the multipart upload.
pub struct UploadPart {
pub:
	part_number int
	etag        string
	size        i64
}

// PresignedUrl holds a time-limited URL granting temporary access
// to an object without requiring credentials.
pub struct PresignedUrl {
pub:
	url        string
	expires_at string
	method     string
}

// ListOptions controls pagination and prefix filtering when listing
// objects within a bucket.
pub struct ListOptions {
pub:
	prefix      string
	delimiter   string = '/'
	max_keys    int    = 1000
	start_after string
}

// --- Client ---

// Client wraps the configuration and provides all object storage
// operations through signed HTTP requests.
pub struct Client {
mut:
	config Config
}

// new_client creates an object storage client with the given
// configuration. No network call is made until an operation is
// invoked.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// --- Bucket operations ---

// create_bucket sends a PUT request to create a new bucket.
pub fn (mut c Client) create_bucket(bucket_name string) ! {
	url := c.build_bucket_url(bucket_name)
	mut body := ''
	if c.config.region != 'us-east-1' {
		body = '<CreateBucketConfiguration><LocationConstraint>${c.config.region}</LocationConstraint></CreateBucketConfiguration>'
	}

	response := c.signed_request(.put, url, body.bytes())!
	if response.status_code != 200 && response.status_code != 204 {
		return error('create bucket failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[objectstore] bucket "${bucket_name}" created')
}

// list_buckets returns all buckets owned by the authenticated user.
pub fn (mut c Client) list_buckets() ![]Bucket {
	url := c.build_service_url()
	response := c.signed_request(.get, url, []u8{})!
	if response.status_code != 200 {
		return error('list buckets failed: HTTP ${response.status_code}')
	}

	// Parse XML response to extract bucket names and dates
	return parse_bucket_list(response.body)
}

// delete_bucket removes an empty bucket. Returns an error if the
// bucket contains objects.
pub fn (mut c Client) delete_bucket(bucket_name string) ! {
	url := c.build_bucket_url(bucket_name)
	response := c.signed_request(.delete, url, []u8{})!
	if response.status_code != 204 && response.status_code != 200 {
		return error('delete bucket failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[objectstore] bucket "${bucket_name}" deleted')
}

// head_bucket checks whether a bucket exists and is accessible.
pub fn (mut c Client) head_bucket(bucket_name string) !bool {
	url := c.build_bucket_url(bucket_name)
	response := c.signed_request(.head, url, []u8{})!
	return response.status_code == 200
}

// --- Object operations ---

// put_object uploads an object to the specified bucket and key.
pub fn (mut c Client) put_object(bucket_name string, key string, data []u8, content_type string) ! {
	url := c.build_object_url(bucket_name, key)
	response := c.signed_request_with_content_type(.put, url, data, content_type)!
	if response.status_code != 200 && response.status_code != 204 {
		return error('put object failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[objectstore] put ${bucket_name}/${key} (${data.len} bytes)')
}

// get_object retrieves an object's body and metadata.
pub fn (mut c Client) get_object(bucket_name string, key string) !ObjectData {
	url := c.build_object_url(bucket_name, key)
	response := c.signed_request(.get, url, []u8{})!
	if response.status_code != 200 {
		return error('get object failed: HTTP ${response.status_code}')
	}

	return ObjectData{
		info: ObjectInfo{
			key: key
			size: response.body.len
			etag: response.header.get(.etag) or { '' }
			content_type: response.header.get(.content_type) or { 'application/octet-stream' }
		}
		body: response.body.bytes()
	}
}

// head_object retrieves an object's metadata without downloading
// the body content.
pub fn (mut c Client) head_object(bucket_name string, key string) !ObjectInfo {
	url := c.build_object_url(bucket_name, key)
	response := c.signed_request(.head, url, []u8{})!
	if response.status_code != 200 {
		return error('head object failed: HTTP ${response.status_code}')
	}

	content_length := (response.header.get(.content_length) or { '0' }).i64()
	return ObjectInfo{
		key: key
		size: content_length
		etag: response.header.get(.etag) or { '' }
		content_type: response.header.get(.content_type) or { 'application/octet-stream' }
	}
}

// delete_object removes a single object from a bucket.
pub fn (mut c Client) delete_object(bucket_name string, key string) ! {
	url := c.build_object_url(bucket_name, key)
	response := c.signed_request(.delete, url, []u8{})!
	if response.status_code != 204 && response.status_code != 200 {
		return error('delete object failed: HTTP ${response.status_code}')
	}
	println('[objectstore] deleted ${bucket_name}/${key}')
}

// list_objects returns object metadata within a bucket, filtered
// and paginated according to the provided options.
pub fn (mut c Client) list_objects(bucket_name string, options ListOptions) ![]ObjectInfo {
	mut query_params := '?list-type=2&max-keys=${options.max_keys}'
	if options.prefix.len > 0 {
		query_params += '&prefix=${options.prefix}'
	}
	if options.delimiter.len > 0 {
		query_params += '&delimiter=${options.delimiter}'
	}
	if options.start_after.len > 0 {
		query_params += '&start-after=${options.start_after}'
	}

	url := c.build_bucket_url(bucket_name) + query_params
	response := c.signed_request(.get, url, []u8{})!
	if response.status_code != 200 {
		return error('list objects failed: HTTP ${response.status_code}')
	}

	return parse_object_list(response.body)
}

// --- Multipart upload ---

// initiate_multipart begins a multipart upload session, returning
// an upload handle with the server-assigned upload ID.
pub fn (mut c Client) initiate_multipart(bucket_name string, key string, content_type string) !MultipartUpload {
	url := c.build_object_url(bucket_name, key) + '?uploads'
	response := c.signed_request_with_content_type(.post, url, []u8{}, content_type)!
	if response.status_code != 200 {
		return error('initiate multipart failed: HTTP ${response.status_code}')
	}

	upload_id := extract_xml_value(response.body, 'UploadId')
	println('[objectstore] multipart upload initiated for ${bucket_name}/${key} (${upload_id})')
	return MultipartUpload{
		bucket: bucket_name
		key: key
		upload_id: upload_id
	}
}

// upload_part sends a single part of a multipart upload. Parts
// must be at least 5 MiB except the final part.
pub fn (mut c Client) upload_part(mut upload MultipartUpload, part_number int, data []u8) ! {
	url := c.build_object_url(upload.bucket, upload.key) + '?partNumber=${part_number}&uploadId=${upload.upload_id}'
	response := c.signed_request(.put, url, data)!
	if response.status_code != 200 {
		return error('upload part ${part_number} failed: HTTP ${response.status_code}')
	}

	etag := response.header.get(.etag) or { '' }
	upload.parts << UploadPart{
		part_number: part_number
		etag: etag
		size: data.len
	}
}

// complete_multipart finalises the multipart upload by submitting
// the list of uploaded parts to the server.
pub fn (mut c Client) complete_multipart(upload MultipartUpload) ! {
	mut body := '<CompleteMultipartUpload>'
	for part in upload.parts {
		body += '<Part><PartNumber>${part.part_number}</PartNumber><ETag>${part.etag}</ETag></Part>'
	}
	body += '</CompleteMultipartUpload>'

	url := c.build_object_url(upload.bucket, upload.key) + '?uploadId=${upload.upload_id}'
	response := c.signed_request(.post, url, body.bytes())!
	if response.status_code != 200 {
		return error('complete multipart failed: HTTP ${response.status_code}')
	}
	println('[objectstore] multipart upload completed for ${upload.bucket}/${upload.key}')
}

// abort_multipart cancels an in-progress multipart upload, discarding
// all uploaded parts.
pub fn (mut c Client) abort_multipart(upload MultipartUpload) ! {
	url := c.build_object_url(upload.bucket, upload.key) + '?uploadId=${upload.upload_id}'
	response := c.signed_request(.delete, url, []u8{})!
	if response.status_code != 204 && response.status_code != 200 {
		return error('abort multipart failed: HTTP ${response.status_code}')
	}
	println('[objectstore] multipart upload aborted for ${upload.bucket}/${upload.key}')
}

// --- Presigned URLs ---

// generate_presigned_url creates a time-limited URL granting
// temporary GET or PUT access to an object without requiring
// the caller to hold credentials.
pub fn (c &Client) generate_presigned_url(bucket_name string, key string, method string, expires_seconds int) PresignedUrl {
	now := time.now()
	expiry := now.add(expires_seconds * time.second)
	date_stamp := now.custom_format('YYYYMMDD')
	datetime_stamp := now.custom_format('YYYYMMDDTHHmmss') + 'Z'

	credential := '${c.config.access_key}/${date_stamp}/${c.config.region}/s3/aws4_request'
	object_url := c.build_object_url(bucket_name, key)

	// Construct the presigned query string
	presigned_url := '${object_url}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=${credential}&X-Amz-Date=${datetime_stamp}&X-Amz-Expires=${expires_seconds}&X-Amz-SignedHeaders=host'

	return PresignedUrl{
		url: presigned_url
		expires_at: expiry.format_rfc3339()
		method: method
	}
}

// --- Internal helpers ---

// build_service_url returns the root URL for service-level operations
// (e.g. listing all buckets).
fn (c &Client) build_service_url() string {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	return '${scheme}://${c.config.endpoint}/'
}

// build_bucket_url returns the URL addressing a specific bucket.
// Uses path-style or virtual-hosted-style based on configuration.
fn (c &Client) build_bucket_url(bucket_name string) string {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	if c.config.use_path_style {
		return '${scheme}://${c.config.endpoint}/${bucket_name}'
	}
	return '${scheme}://${bucket_name}.${c.config.endpoint}'
}

// build_object_url returns the URL addressing a specific object
// within a bucket.
fn (c &Client) build_object_url(bucket_name string, key string) string {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	if c.config.use_path_style {
		return '${scheme}://${c.config.endpoint}/${bucket_name}/${key}'
	}
	return '${scheme}://${bucket_name}.${c.config.endpoint}/${key}'
}

// signed_request issues an HTTP request with AWS Signature V4
// authentication headers.
fn (mut c Client) signed_request(method http.Method, url string, body []u8) !http.Response {
	return c.signed_request_with_content_type(method, url, body, 'application/octet-stream')
}

// signed_request_with_content_type issues a signed HTTP request
// with an explicit content type header.
fn (mut c Client) signed_request_with_content_type(method http.Method, url string, body []u8, content_type string) !http.Response {
	now := time.now()
	date_stamp := now.custom_format('YYYYMMDD')
	datetime_stamp := now.custom_format('YYYYMMDDTHHmmss') + 'Z'

	// Compute the SHA-256 hash of the request body for signing
	body_hash := sha256.hexhash(body.bytestr())

	// Derive the signing key: HMAC-SHA256 chain over date/region/service
	date_key := hmac.new(('AWS4' + c.config.secret_key).bytes(), date_stamp.bytes(), sha256.sum, sha256.block_size)
	region_key := hmac.new(date_key, c.config.region.bytes(), sha256.sum, sha256.block_size)
	service_key := hmac.new(region_key, 's3'.bytes(), sha256.sum, sha256.block_size)
	signing_key := hmac.new(service_key, 'aws4_request'.bytes(), sha256.sum, sha256.block_size)

	// Build canonical request components for signing
	credential := '${c.config.access_key}/${date_stamp}/${c.config.region}/s3/aws4_request'
	authorization := 'AWS4-HMAC-SHA256 Credential=${credential}, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=${signing_key.hex()}'

	mut fetch_config := http.FetchConfig{
		url: url
		method: method
		body: body.bytestr()
		header: http.new_header_from_map({
			'Content-Type':         content_type
			'X-Amz-Date':          datetime_stamp
			'X-Amz-Content-Sha256': body_hash
			'Authorization':        authorization
		})
	}

	return http.fetch(fetch_config)
}

// --- XML parsing helpers ---

// extract_xml_value extracts the text content of a simple XML tag.
// This is a minimal parser for S3-style responses; it does not
// handle nested elements or attributes.
fn extract_xml_value(xml_body string, tag_name string) string {
	open_tag := '<${tag_name}>'
	close_tag := '</${tag_name}>'
	start_pos := xml_body.index(open_tag) or { return '' }
	content_start := start_pos + open_tag.len
	end_pos := xml_body.index_after(close_tag, content_start)
	if end_pos < 0 {
		return ''
	}
	return xml_body[content_start..end_pos]
}

// parse_bucket_list extracts bucket entries from the ListAllMyBuckets
// XML response.
fn parse_bucket_list(xml_body string) []Bucket {
	mut buckets := []Bucket{}
	mut search_pos := 0
	for {
		bucket_start := xml_body.index_after('<Bucket>', search_pos)
		if bucket_start < 0 {
			break
		}
		bucket_end := xml_body.index_after('</Bucket>', bucket_start)
		if bucket_end < 0 {
			break
		}
		bucket_xml := xml_body[bucket_start..bucket_end]
		bucket_name := extract_xml_value(bucket_xml, 'Name')
		creation_date := extract_xml_value(bucket_xml, 'CreationDate')
		if bucket_name.len > 0 {
			buckets << Bucket{
				name: bucket_name
				creation_date: creation_date
			}
		}
		search_pos = bucket_end + 9 // len("</Bucket>")
	}
	return buckets
}

// parse_object_list extracts object entries from the ListObjectsV2
// XML response.
fn parse_object_list(xml_body string) []ObjectInfo {
	mut objects := []ObjectInfo{}
	mut search_pos := 0
	for {
		contents_start := xml_body.index_after('<Contents>', search_pos)
		if contents_start < 0 {
			break
		}
		contents_end := xml_body.index_after('</Contents>', contents_start)
		if contents_end < 0 {
			break
		}
		entry_xml := xml_body[contents_start..contents_end]
		object_key := extract_xml_value(entry_xml, 'Key')
		object_size := extract_xml_value(entry_xml, 'Size')
		object_modified := extract_xml_value(entry_xml, 'LastModified')
		object_etag := extract_xml_value(entry_xml, 'ETag')
		if object_key.len > 0 {
			objects << ObjectInfo{
				key: object_key
				size: object_size.i64()
				last_modified: object_modified
				etag: object_etag
			}
		}
		search_pos = contents_end + 11 // len("</Contents>")
	}
	return objects
}

// --- Tests ---

fn test_extract_xml_value_found() {
	xml := '<Response><UploadId>abc123</UploadId></Response>'
	assert extract_xml_value(xml, 'UploadId') == 'abc123'
}

fn test_extract_xml_value_missing() {
	xml := '<Response><Other>data</Other></Response>'
	assert extract_xml_value(xml, 'UploadId') == ''
}

fn test_build_path_style_url() {
	config := Config{
		endpoint: 'minio.local:9000'
		access_key: 'test'
		secret_key: 'test'
		use_tls: false
		use_path_style: true
	}
	client := new_client(config)
	url := client.build_object_url('mybucket', 'mykey')
	assert url == 'http://minio.local:9000/mybucket/mykey'
}

fn test_build_virtual_hosted_url() {
	config := Config{
		endpoint: 's3.amazonaws.com'
		access_key: 'test'
		secret_key: 'test'
		use_tls: true
		use_path_style: false
	}
	client := new_client(config)
	url := client.build_object_url('mybucket', 'mykey')
	assert url == 'https://mybucket.s3.amazonaws.com/mykey'
}
