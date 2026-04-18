//! WebDAV storage backend
//!
//! HTTP-based distributed authoring and versioning protocol.
//! Compatible with NextCloud, ownCloud, SharePoint, Apache mod_dav, etc.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use chrono::{DateTime, Utc};
use reqwest::{header, Client, Method, StatusCode};
use serde::Deserialize;
use std::sync::Arc;
use tokio::sync::RwLock;

/// WebDAV authentication method
#[derive(Debug, Clone)]
pub enum WebDavAuth {
    /// No authentication
    None,
    /// Basic authentication
    Basic { username: String, password: String },
    /// Bearer token (OAuth)
    Bearer(String),
    /// Digest authentication (handled by reqwest)
    Digest { username: String, password: String },
}

/// WebDAV backend configuration
#[derive(Debug, Clone)]
pub struct WebDavConfig {
    /// Base URL (e.g., "https://cloud.example.com/remote.php/dav/files/username")
    pub base_url: String,
    /// Authentication method
    pub auth: WebDavAuth,
    /// Custom headers
    pub headers: Vec<(String, String)>,
}

/// WebDAV storage backend
pub struct WebDavBackend {
    id: String,
    config: Arc<RwLock<WebDavConfig>>,
    http: Client,
    capabilities: StorageCapabilities,
}

impl WebDavBackend {
    pub fn new(id: impl Into<String>, config: WebDavConfig) -> Self {
        Self {
            id: id.into(),
            config: Arc::new(RwLock::new(config)),
            http: Client::new(),
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: true,
                list: true,
                search: false,
                versioning: false, // Some servers support it
                sharing: false,
                streaming: true,
                resume: true,
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
        }
    }

    /// Build authenticated request
    async fn request(&self, method: Method, path: &str) -> reqwest::RequestBuilder {
        let config = self.config.read().await;
        let url = format!("{}/{}", config.base_url.trim_end_matches('/'), path.trim_start_matches('/'));

        let mut request = self.http.request(method, &url);

        match &config.auth {
            WebDavAuth::None => {}
            WebDavAuth::Basic { username, password } => {
                request = request.basic_auth(username, Some(password));
            }
            WebDavAuth::Bearer(token) => {
                request = request.bearer_auth(token);
            }
            WebDavAuth::Digest { username, password } => {
                // reqwest handles digest auth automatically
                request = request.basic_auth(username, Some(password));
            }
        }

        for (key, value) in &config.headers {
            request = request.header(key, value);
        }

        request
    }

    /// Convert VirtualPath to URL path
    fn to_url_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            String::new()
        } else {
            path.segments
                .iter()
                .map(|s| urlencoding::encode(s).to_string())
                .collect::<Vec<_>>()
                .join("/")
        }
    }

    /// PROPFIND request for listing/metadata
    async fn propfind(&self, path: &str, depth: &str) -> CfkResult<Vec<DavResponse>> {
        let body = r#"<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getlastmodified/>
    <d:creationdate/>
    <d:getetag/>
    <d:getcontenttype/>
  </d:prop>
</d:propfind>"#;

        let response = self
            .request(Method::from_bytes(b"PROPFIND").unwrap(), path)
            .await
            .header("Depth", depth)
            .header(header::CONTENT_TYPE, "application/xml")
            .body(body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != StatusCode::MULTI_STATUS {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let text = response
            .text()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        parse_multistatus(&text)
    }
}

/// DAV response from PROPFIND
#[derive(Debug, Clone, Default)]
struct DavResponse {
    href: String,
    is_collection: bool,
    content_length: Option<u64>,
    last_modified: Option<DateTime<Utc>>,
    creation_date: Option<DateTime<Utc>>,
    etag: Option<String>,
    content_type: Option<String>,
}

/// Parse WebDAV multistatus XML response
fn parse_multistatus(xml: &str) -> CfkResult<Vec<DavResponse>> {
    // Simple XML parsing without full XML crate
    let mut responses = Vec::new();
    let mut current: Option<DavResponse> = None;

    for line in xml.lines() {
        let line = line.trim();

        if line.contains("<d:response>") || line.contains("<D:response>") {
            current = Some(DavResponse::default());
        } else if line.contains("</d:response>") || line.contains("</D:response>") {
            if let Some(resp) = current.take() {
                responses.push(resp);
            }
        } else if let Some(ref mut resp) = current {
            // Parse href
            if let Some(href) = extract_tag_content(line, "href") {
                resp.href = urlencoding::decode(&href).unwrap_or(href.into()).to_string();
            }

            // Parse resourcetype
            if line.contains("<d:collection") || line.contains("<D:collection") {
                resp.is_collection = true;
            }

            // Parse content length
            if let Some(len) = extract_tag_content(line, "getcontentlength") {
                resp.content_length = len.parse().ok();
            }

            // Parse last modified
            if let Some(modified) = extract_tag_content(line, "getlastmodified") {
                resp.last_modified = parse_http_date(&modified);
            }

            // Parse creation date
            if let Some(created) = extract_tag_content(line, "creationdate") {
                resp.creation_date = DateTime::parse_from_rfc3339(&created)
                    .ok()
                    .map(|dt| dt.with_timezone(&Utc));
            }

            // Parse etag
            if let Some(etag) = extract_tag_content(line, "getetag") {
                resp.etag = Some(etag.trim_matches('"').to_string());
            }

            // Parse content type
            if let Some(ct) = extract_tag_content(line, "getcontenttype") {
                resp.content_type = Some(ct);
            }
        }
    }

    Ok(responses)
}

/// Extract content between XML tags
fn extract_tag_content(line: &str, tag: &str) -> Option<String> {
    let patterns = [
        format!("<d:{}>", tag),
        format!("<D:{}>", tag),
        format!("<{}:", tag),
    ];

    for pattern in &patterns {
        if let Some(start) = line.find(pattern) {
            let content_start = start + pattern.len();
            let end_patterns = [
                format!("</d:{}>", tag),
                format!("</D:{}>", tag),
                format!("</{}:", tag),
            ];

            for end_pattern in &end_patterns {
                if let Some(end) = line[content_start..].find(end_pattern) {
                    return Some(line[content_start..content_start + end].to_string());
                }
            }
        }
    }

    None
}

/// Parse HTTP date format
fn parse_http_date(s: &str) -> Option<DateTime<Utc>> {
    // Try RFC 2822 first (most common)
    if let Ok(dt) = DateTime::parse_from_rfc2822(s) {
        return Some(dt.with_timezone(&Utc));
    }

    // Try RFC 3339
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return Some(dt.with_timezone(&Utc));
    }

    // Try common HTTP date format
    let formats = [
        "%a, %d %b %Y %H:%M:%S GMT",
        "%A, %d-%b-%y %H:%M:%S GMT",
        "%a %b %e %H:%M:%S %Y",
    ];

    for fmt in &formats {
        if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(s, fmt) {
            return Some(DateTime::from_naive_utc_and_offset(dt, Utc));
        }
    }

    None
}

impl DavResponse {
    fn to_entry(&self, backend_id: &str, base_href: &str) -> Entry {
        // Extract relative path from href
        let relative_path = self
            .href
            .trim_start_matches(base_href)
            .trim_start_matches('/')
            .trim_end_matches('/');

        let kind = if self.is_collection {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = self.content_length;
        metadata.modified = self.last_modified;
        metadata.created = self.creation_date;
        metadata.checksum = self.etag.clone();
        metadata.mime_type = self.content_type.clone();

        Entry {
            path: VirtualPath::new(backend_id, relative_path),
            kind,
            metadata,
        }
    }
}

#[async_trait]
impl StorageBackend for WebDavBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "WebDAV"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.propfind("", "0").await.is_ok()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let url_path = self.to_url_path(path);
        let responses = self.propfind(&url_path, "0").await?;

        responses
            .first()
            .map(|r| r.to_entry(&self.id, ""))
            .ok_or_else(|| CfkError::NotFound(path.to_string()))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let url_path = self.to_url_path(path);
        let responses = self.propfind(&url_path, "1").await?;

        // First response is the directory itself, skip it
        Ok(responses
            .iter()
            .skip(1)
            .map(|r| r.to_entry(&self.id, ""))
            .collect())
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let url_path = self.to_url_path(path);

        let response = self
            .request(Method::GET, &url_path)
            .await
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            if status == StatusCode::NOT_FOUND {
                return Err(CfkError::NotFound(path.to_string()));
            }
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let url_path = self.to_url_path(path);

        let response = self
            .request(Method::PUT, &url_path)
            .await
            .header(header::CONTENT_TYPE, "application/octet-stream")
            .body(data.to_vec())
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(path).await
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let url_path = self.to_url_path(path);

        let response = self
            .request(Method::DELETE, &url_path)
            .await
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != StatusCode::NO_CONTENT {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let url_path = self.to_url_path(path);

        let response = self
            .request(Method::from_bytes(b"MKCOL").unwrap(), &url_path)
            .await
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != StatusCode::CREATED {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(path).await
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_url_path(from);
        let to_path = self.to_url_path(to);

        let config = self.config.read().await;
        let dest_url = format!(
            "{}/{}",
            config.base_url.trim_end_matches('/'),
            to_path.trim_start_matches('/')
        );

        let response = self
            .request(Method::from_bytes(b"COPY").unwrap(), &from_path)
            .await
            .header("Destination", &dest_url)
            .header("Overwrite", "T")
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success()
            && response.status() != StatusCode::CREATED
            && response.status() != StatusCode::NO_CONTENT
        {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(to).await
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_url_path(from);
        let to_path = self.to_url_path(to);

        let config = self.config.read().await;
        let dest_url = format!(
            "{}/{}",
            config.base_url.trim_end_matches('/'),
            to_path.trim_start_matches('/')
        );

        let response = self
            .request(Method::from_bytes(b"MOVE").unwrap(), &from_path)
            .await
            .header("Destination", &dest_url)
            .header("Overwrite", "T")
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success()
            && response.status() != StatusCode::CREATED
            && response.status() != StatusCode::NO_CONTENT
        {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "webdav".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        self.get_metadata(to).await
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // WebDAV quota requires RFC 4331 support
        let body = r#"<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:quota-available-bytes/>
    <d:quota-used-bytes/>
  </d:prop>
</d:propfind>"#;

        let response = self
            .request(Method::from_bytes(b"PROPFIND").unwrap(), "")
            .await
            .header("Depth", "0")
            .header(header::CONTENT_TYPE, "application/xml")
            .body(body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let text = response
            .text()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let available = extract_tag_content(&text, "quota-available-bytes")
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        let used = extract_tag_content(&text, "quota-used-bytes")
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        let total = available + used;
        Ok((available, total))
    }
}

/// NextCloud-specific extensions
impl WebDavBackend {
    /// Create a NextCloud backend with standard configuration
    pub fn nextcloud(
        id: impl Into<String>,
        server_url: &str,
        username: &str,
        password: &str,
    ) -> Self {
        let base_url = format!(
            "{}/remote.php/dav/files/{}",
            server_url.trim_end_matches('/'),
            username
        );

        Self::new(
            id,
            WebDavConfig {
                base_url,
                auth: WebDavAuth::Basic {
                    username: username.to_string(),
                    password: password.to_string(),
                },
                headers: vec![],
            },
        )
    }

    /// Create an ownCloud backend
    pub fn owncloud(
        id: impl Into<String>,
        server_url: &str,
        username: &str,
        password: &str,
    ) -> Self {
        let base_url = format!(
            "{}/remote.php/webdav",
            server_url.trim_end_matches('/')
        );

        Self::new(
            id,
            WebDavConfig {
                base_url,
                auth: WebDavAuth::Basic {
                    username: username.to_string(),
                    password: password.to_string(),
                },
                headers: vec![],
            },
        )
    }
}
