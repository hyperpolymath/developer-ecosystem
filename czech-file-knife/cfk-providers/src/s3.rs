//! S3-compatible storage backend
//!
//! Works with AWS S3, MinIO, Wasabi, DigitalOcean Spaces, Backblaze B2,
//! Cloudflare R2, and any S3-compatible object storage.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use chrono::{DateTime, Utc};
use reqwest::{header, Client, Method, StatusCode};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// S3 backend configuration
#[derive(Debug, Clone)]
pub struct S3Config {
    /// S3 endpoint URL (e.g., "https://s3.amazonaws.com" or "https://minio.example.com")
    pub endpoint: String,
    /// Bucket name
    pub bucket: String,
    /// AWS region
    pub region: String,
    /// Access key ID
    pub access_key_id: String,
    /// Secret access key
    pub secret_access_key: String,
    /// Use path-style URLs (required for MinIO and some providers)
    pub path_style: bool,
}

impl S3Config {
    /// Create AWS S3 configuration
    pub fn aws(bucket: &str, region: &str, access_key: &str, secret_key: &str) -> Self {
        Self {
            endpoint: format!("https://s3.{}.amazonaws.com", region),
            bucket: bucket.to_string(),
            region: region.to_string(),
            access_key_id: access_key.to_string(),
            secret_access_key: secret_key.to_string(),
            path_style: false,
        }
    }

    /// Create MinIO configuration
    pub fn minio(endpoint: &str, bucket: &str, access_key: &str, secret_key: &str) -> Self {
        Self {
            endpoint: endpoint.to_string(),
            bucket: bucket.to_string(),
            region: "us-east-1".to_string(),
            access_key_id: access_key.to_string(),
            secret_access_key: secret_key.to_string(),
            path_style: true,
        }
    }

    /// Create Cloudflare R2 configuration
    pub fn r2(account_id: &str, bucket: &str, access_key: &str, secret_key: &str) -> Self {
        Self {
            endpoint: format!("https://{}.r2.cloudflarestorage.com", account_id),
            bucket: bucket.to_string(),
            region: "auto".to_string(),
            access_key_id: access_key.to_string(),
            secret_access_key: secret_key.to_string(),
            path_style: true,
        }
    }

    /// Create Backblaze B2 configuration
    pub fn b2(bucket: &str, region: &str, key_id: &str, app_key: &str) -> Self {
        Self {
            endpoint: format!("https://s3.{}.backblazeb2.com", region),
            bucket: bucket.to_string(),
            region: region.to_string(),
            access_key_id: key_id.to_string(),
            secret_access_key: app_key.to_string(),
            path_style: false,
        }
    }

    /// Create DigitalOcean Spaces configuration
    pub fn digitalocean(region: &str, space: &str, key: &str, secret: &str) -> Self {
        Self {
            endpoint: format!("https://{}.digitaloceanspaces.com", region),
            bucket: space.to_string(),
            region: region.to_string(),
            access_key_id: key.to_string(),
            secret_access_key: secret.to_string(),
            path_style: false,
        }
    }

    /// Create Wasabi configuration
    pub fn wasabi(bucket: &str, region: &str, access_key: &str, secret_key: &str) -> Self {
        Self {
            endpoint: format!("https://s3.{}.wasabisys.com", region),
            bucket: bucket.to_string(),
            region: region.to_string(),
            access_key_id: access_key.to_string(),
            secret_access_key: secret_key.to_string(),
            path_style: false,
        }
    }
}

/// S3 storage backend
pub struct S3Backend {
    id: String,
    config: Arc<RwLock<S3Config>>,
    http: Client,
    capabilities: StorageCapabilities,
}

impl S3Backend {
    pub fn new(id: impl Into<String>, config: S3Config) -> Self {
        Self {
            id: id.into(),
            config: Arc::new(RwLock::new(config)),
            http: Client::new(),
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: false, // S3 doesn't support rename, need copy+delete
                copy: true,
                list: true,
                search: false,
                versioning: true,
                sharing: true, // Presigned URLs
                streaming: true,
                resume: true, // Multipart upload
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: Some(5 * 1024 * 1024 * 1024 * 1024), // 5TB
            },
        }
    }

    /// Build URL for an object
    async fn object_url(&self, key: &str) -> String {
        let config = self.config.read().await;

        if config.path_style {
            format!(
                "{}/{}/{}",
                config.endpoint.trim_end_matches('/'),
                config.bucket,
                key.trim_start_matches('/')
            )
        } else {
            // Virtual-hosted style
            let endpoint = config.endpoint.replace("://", &format!("://{}.bucket.", config.bucket));
            format!("{}/{}", endpoint.trim_end_matches('/'), key.trim_start_matches('/'))
        }
    }

    /// Build URL for bucket operations
    async fn bucket_url(&self) -> String {
        let config = self.config.read().await;

        if config.path_style {
            format!(
                "{}/{}",
                config.endpoint.trim_end_matches('/'),
                config.bucket
            )
        } else {
            config.endpoint.replace("://", &format!("://{}.bucket.", config.bucket))
        }
    }

    /// Sign request with AWS Signature Version 4
    async fn sign_request(
        &self,
        method: &Method,
        url: &str,
        headers: &mut BTreeMap<String, String>,
        payload_hash: &str,
    ) -> CfkResult<String> {
        let config = self.config.read().await;
        let now = Utc::now();
        let date_stamp = now.format("%Y%m%d").to_string();
        let amz_date = now.format("%Y%m%dT%H%M%SZ").to_string();

        headers.insert("x-amz-date".to_string(), amz_date.clone());
        headers.insert("x-amz-content-sha256".to_string(), payload_hash.to_string());

        // Parse URL
        let parsed = url::Url::parse(url).map_err(|e| CfkError::InvalidPath(e.to_string()))?;
        let host = parsed.host_str().unwrap_or("");
        let path = parsed.path();
        let query = parsed.query().unwrap_or("");

        headers.insert("host".to_string(), host.to_string());

        // Create canonical request
        let signed_headers: Vec<&str> = headers.keys().map(|s| s.as_str()).collect();
        let signed_headers_str = signed_headers.join(";");

        let canonical_headers: String = headers
            .iter()
            .map(|(k, v)| format!("{}:{}\n", k.to_lowercase(), v.trim()))
            .collect();

        let canonical_request = format!(
            "{}\n{}\n{}\n{}\n{}\n{}",
            method.as_str(),
            path,
            query,
            canonical_headers,
            signed_headers_str,
            payload_hash
        );

        let canonical_request_hash = sha256_hex(canonical_request.as_bytes());

        // Create string to sign
        let credential_scope = format!("{}/{}/s3/aws4_request", date_stamp, config.region);
        let string_to_sign = format!(
            "AWS4-HMAC-SHA256\n{}\n{}\n{}",
            amz_date, credential_scope, canonical_request_hash
        );

        // Calculate signature
        let k_date = hmac_sha256(
            format!("AWS4{}", config.secret_access_key).as_bytes(),
            date_stamp.as_bytes(),
        );
        let k_region = hmac_sha256(&k_date, config.region.as_bytes());
        let k_service = hmac_sha256(&k_region, b"s3");
        let k_signing = hmac_sha256(&k_service, b"aws4_request");
        let signature = hex::encode(hmac_sha256(&k_signing, string_to_sign.as_bytes()));

        // Build authorization header
        let authorization = format!(
            "AWS4-HMAC-SHA256 Credential={}/{}, SignedHeaders={}, Signature={}",
            config.access_key_id, credential_scope, signed_headers_str, signature
        );

        Ok(authorization)
    }

    /// Make signed request
    async fn request(
        &self,
        method: Method,
        key: &str,
        body: Option<Bytes>,
    ) -> CfkResult<reqwest::Response> {
        let url = if key.is_empty() {
            self.bucket_url().await
        } else {
            self.object_url(key).await
        };

        let payload_hash = if let Some(ref data) = body {
            sha256_hex(data)
        } else {
            sha256_hex(b"")
        };

        let mut headers = BTreeMap::new();
        let auth = self.sign_request(&method, &url, &mut headers, &payload_hash).await?;

        let mut request = self.http.request(method, &url);

        for (k, v) in &headers {
            request = request.header(k, v);
        }
        request = request.header(header::AUTHORIZATION, auth);

        if let Some(data) = body {
            request = request.body(data.to_vec());
        }

        request
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    /// List objects with prefix
    async fn list_objects(
        &self,
        prefix: &str,
        delimiter: Option<&str>,
    ) -> CfkResult<ListObjectsResult> {
        let config = self.config.read().await;
        let mut url = format!(
            "{}/{}?list-type=2",
            config.endpoint.trim_end_matches('/'),
            config.bucket
        );

        if !prefix.is_empty() {
            url.push_str(&format!("&prefix={}", urlencoding::encode(prefix)));
        }
        if let Some(d) = delimiter {
            url.push_str(&format!("&delimiter={}", urlencoding::encode(d)));
        }

        drop(config);

        let payload_hash = sha256_hex(b"");
        let mut headers = BTreeMap::new();
        let auth = self.sign_request(&Method::GET, &url, &mut headers, &payload_hash).await?;

        let mut request = self.http.get(&url);
        for (k, v) in &headers {
            request = request.header(k, v);
        }
        request = request.header(header::AUTHORIZATION, auth);

        let response = request
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let text = response.text().await.map_err(|e| CfkError::Network(e.to_string()))?;
        parse_list_objects_v2(&text)
    }

    /// Convert VirtualPath to S3 key
    fn to_key(&self, path: &VirtualPath) -> String {
        path.segments.join("/")
    }
}

/// S3 object metadata
#[derive(Debug, Clone, Default)]
struct S3Object {
    key: String,
    size: u64,
    last_modified: Option<DateTime<Utc>>,
    etag: Option<String>,
    storage_class: Option<String>,
}

/// Common prefix (directory) in listing
#[derive(Debug, Clone)]
struct CommonPrefix {
    prefix: String,
}

/// List objects result
#[derive(Debug, Clone, Default)]
struct ListObjectsResult {
    objects: Vec<S3Object>,
    common_prefixes: Vec<CommonPrefix>,
    is_truncated: bool,
    continuation_token: Option<String>,
}

/// Parse ListObjectsV2 XML response
fn parse_list_objects_v2(xml: &str) -> CfkResult<ListObjectsResult> {
    let mut result = ListObjectsResult::default();
    let mut in_contents = false;
    let mut current_object = S3Object::default();

    for line in xml.lines() {
        let line = line.trim();

        if line.contains("<Contents>") {
            in_contents = true;
            current_object = S3Object::default();
        } else if line.contains("</Contents>") {
            in_contents = false;
            result.objects.push(current_object.clone());
        } else if in_contents {
            if let Some(key) = extract_xml_value(line, "Key") {
                current_object.key = key;
            }
            if let Some(size) = extract_xml_value(line, "Size") {
                current_object.size = size.parse().unwrap_or(0);
            }
            if let Some(modified) = extract_xml_value(line, "LastModified") {
                current_object.last_modified = DateTime::parse_from_rfc3339(&modified)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc));
            }
            if let Some(etag) = extract_xml_value(line, "ETag") {
                current_object.etag = Some(etag.trim_matches('"').to_string());
            }
            if let Some(class) = extract_xml_value(line, "StorageClass") {
                current_object.storage_class = Some(class);
            }
        }

        if let Some(prefix) = extract_xml_value(line, "Prefix") {
            if line.contains("<CommonPrefixes>") || xml.contains("<CommonPrefixes>") {
                result.common_prefixes.push(CommonPrefix { prefix });
            }
        }

        if let Some(truncated) = extract_xml_value(line, "IsTruncated") {
            result.is_truncated = truncated == "true";
        }

        if let Some(token) = extract_xml_value(line, "NextContinuationToken") {
            result.continuation_token = Some(token);
        }
    }

    Ok(result)
}

/// Extract value from XML element
fn extract_xml_value(line: &str, tag: &str) -> Option<String> {
    let start_tag = format!("<{}>", tag);
    let end_tag = format!("</{}>", tag);

    if let Some(start) = line.find(&start_tag) {
        let content_start = start + start_tag.len();
        if let Some(end) = line[content_start..].find(&end_tag) {
            return Some(line[content_start..content_start + end].to_string());
        }
    }
    None
}

/// SHA-256 hash as hex string
fn sha256_hex(data: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex::encode(hasher.finalize())
}

/// HMAC-SHA256
fn hmac_sha256(key: &[u8], data: &[u8]) -> Vec<u8> {
    use hmac::{Hmac, Mac};
    use sha2::Sha256;

    type HmacSha256 = Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(key).expect("HMAC can take key of any size");
    mac.update(data);
    mac.finalize().into_bytes().to_vec()
}

#[async_trait]
impl StorageBackend for S3Backend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "S3"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.list_objects("", Some("/")).await.is_ok()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let key = self.to_key(path);

        if key.is_empty() {
            // Root
            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata: Metadata::default(),
            });
        }

        // HEAD request
        let response = self.request(Method::HEAD, &key, None).await?;

        if response.status() == StatusCode::NOT_FOUND {
            // Check if it's a directory (prefix)
            let prefix = format!("{}/", key);
            let list = self.list_objects(&prefix, Some("/")).await?;
            if !list.objects.is_empty() || !list.common_prefixes.is_empty() {
                return Ok(Entry {
                    path: path.clone(),
                    kind: EntryKind::Directory,
                    metadata: Metadata::default(),
                });
            }
            return Err(CfkError::NotFound(path.to_string()));
        }

        if !response.status().is_success() {
            let status = response.status();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}", status),
            });
        }

        let headers = response.headers();
        let mut metadata = Metadata::default();

        if let Some(len) = headers.get(header::CONTENT_LENGTH) {
            metadata.size = len.to_str().ok().and_then(|s| s.parse().ok());
        }

        if let Some(modified) = headers.get(header::LAST_MODIFIED) {
            if let Ok(s) = modified.to_str() {
                metadata.modified = DateTime::parse_from_rfc2822(s)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc));
            }
        }

        if let Some(etag) = headers.get(header::ETAG) {
            metadata.checksum = etag.to_str().ok().map(|s| s.trim_matches('"').to_string());
        }

        if let Some(ct) = headers.get(header::CONTENT_TYPE) {
            metadata.mime_type = ct.to_str().ok().map(String::from);
        }

        Ok(Entry {
            path: path.clone(),
            kind: EntryKind::File,
            metadata,
        })
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let mut prefix = self.to_key(path);
        if !prefix.is_empty() && !prefix.ends_with('/') {
            prefix.push('/');
        }

        let result = self.list_objects(&prefix, Some("/")).await?;

        let mut entries = Vec::new();

        // Add objects
        for obj in result.objects {
            let key = obj.key.trim_start_matches(&prefix);
            if key.is_empty() || key == "/" {
                continue;
            }

            let mut metadata = Metadata::default();
            metadata.size = Some(obj.size);
            metadata.modified = obj.last_modified;
            metadata.checksum = obj.etag;

            entries.push(Entry {
                path: VirtualPath::new(&self.id, &obj.key),
                kind: EntryKind::File,
                metadata,
            });
        }

        // Add directories (common prefixes)
        for cp in result.common_prefixes {
            let dir_name = cp.prefix.trim_end_matches('/');
            entries.push(Entry {
                path: VirtualPath::new(&self.id, dir_name),
                kind: EntryKind::Directory,
                metadata: Metadata::default(),
            });
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let key = self.to_key(path);
        let response = self.request(Method::GET, &key, None).await?;

        if !response.status().is_success() {
            let status = response.status();
            if status == StatusCode::NOT_FOUND {
                return Err(CfkError::NotFound(path.to_string()));
            }
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let key = self.to_key(path);
        let response = self.request(Method::PUT, &key, Some(data)).await?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(path).await
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let key = self.to_key(path);
        let response = self.request(Method::DELETE, &key, None).await?;

        if !response.status().is_success() && response.status() != StatusCode::NO_CONTENT {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        // S3 doesn't have real directories, create a zero-byte object with trailing slash
        let mut key = self.to_key(path);
        if !key.ends_with('/') {
            key.push('/');
        }

        let response = self.request(Method::PUT, &key, Some(Bytes::new())).await?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        Ok(Entry {
            path: path.clone(),
            kind: EntryKind::Directory,
            metadata: Metadata::default(),
        })
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_key = self.to_key(from);
        let to_key = self.to_key(to);
        let config = self.config.read().await;

        let copy_source = format!("{}/{}", config.bucket, from_key);
        drop(config);

        // Build copy request with x-amz-copy-source header
        let url = self.object_url(&to_key).await;
        let payload_hash = sha256_hex(b"");

        let mut headers = BTreeMap::new();
        headers.insert("x-amz-copy-source".to_string(), copy_source);

        let auth = self.sign_request(&Method::PUT, &url, &mut headers, &payload_hash).await?;

        let mut request = self.http.put(&url);
        for (k, v) in &headers {
            request = request.header(k, v);
        }
        request = request.header(header::AUTHORIZATION, auth);

        let response = request
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "s3".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(to).await
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        // S3 doesn't support rename, use copy + delete
        let entry = self.copy(from, to).await?;
        self.delete(from).await?;
        Ok(entry)
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // S3 doesn't have quota concept, return 0
        Ok((0, 0))
    }
}
