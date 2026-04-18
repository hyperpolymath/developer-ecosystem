//! Google Drive storage backend
//!
//! Full implementation of Google Drive API v3 with OAuth 2.0 + PKCE authentication.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use chrono::{DateTime, Utc};
use oauth2::{
    basic::BasicClient, AuthUrl, ClientId, CsrfToken, PkceCodeChallenge, PkceCodeVerifier,
    RedirectUrl, Scope, TokenUrl,
};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

const GOOGLE_AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const DRIVE_API_URL: &str = "https://www.googleapis.com/drive/v3";
const DRIVE_UPLOAD_URL: &str = "https://www.googleapis.com/upload/drive/v3";

/// Google OAuth tokens
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoogleTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
}

/// Google Drive backend configuration
#[derive(Debug, Clone)]
pub struct GoogleDriveConfig {
    pub client_id: String,
    pub client_secret: Option<String>,
    pub redirect_uri: String,
}

/// Google Drive storage backend
pub struct GoogleDriveBackend {
    id: String,
    config: GoogleDriveConfig,
    tokens: Arc<RwLock<Option<GoogleTokens>>>,
    http: Client,
    capabilities: StorageCapabilities,
    /// Cache of file ID to path mapping
    path_cache: Arc<RwLock<HashMap<String, String>>>,
}

impl GoogleDriveBackend {
    pub fn new(id: impl Into<String>, config: GoogleDriveConfig) -> Self {
        Self {
            id: id.into(),
            config,
            tokens: Arc::new(RwLock::new(None)),
            http: Client::new(),
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: true,
                list: true,
                search: true,
                versioning: true,
                sharing: true,
                streaming: true,
                resume: true,
                watch: true,
                metadata: true,
                thumbnails: true,
                max_file_size: Some(5 * 1024 * 1024 * 1024 * 1024), // 5TB
            },
            path_cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Start OAuth 2.0 + PKCE flow
    pub fn start_auth(&self) -> (String, PkceCodeVerifier) {
        let client = BasicClient::new(ClientId::new(self.config.client_id.clone()))
            .set_auth_uri(AuthUrl::new(GOOGLE_AUTH_URL.to_string()).unwrap())
            .set_token_uri(TokenUrl::new(GOOGLE_TOKEN_URL.to_string()).unwrap())
            .set_redirect_uri(RedirectUrl::new(self.config.redirect_uri.clone()).unwrap());

        let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();

        let (auth_url, _csrf_token) = client
            .authorize_url(CsrfToken::new_random)
            .add_scope(Scope::new(
                "https://www.googleapis.com/auth/drive".to_string(),
            ))
            .add_scope(Scope::new(
                "https://www.googleapis.com/auth/drive.metadata.readonly".to_string(),
            ))
            .set_pkce_challenge(pkce_challenge)
            .add_extra_param("access_type", "offline")
            .add_extra_param("prompt", "consent")
            .url();

        (auth_url.to_string(), pkce_verifier)
    }

    /// Complete OAuth flow with authorization code
    pub async fn complete_auth(
        &self,
        code: &str,
        verifier: PkceCodeVerifier,
    ) -> CfkResult<GoogleTokens> {
        let mut params = vec![
            ("code", code.to_string()),
            ("grant_type", "authorization_code".to_string()),
            ("client_id", self.config.client_id.clone()),
            ("redirect_uri", self.config.redirect_uri.clone()),
            ("code_verifier", verifier.secret().to_string()),
        ];

        if let Some(ref secret) = self.config.client_secret {
            params.push(("client_secret", secret.clone()));
        }

        let response = self
            .http
            .post(GOOGLE_TOKEN_URL)
            .form(&params)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::Auth(format!("Token exchange failed: {}", error_text)));
        }

        #[derive(Deserialize)]
        struct TokenResponse {
            access_token: String,
            refresh_token: Option<String>,
            expires_in: Option<i64>,
        }

        let token_resp: TokenResponse = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let tokens = GoogleTokens {
            access_token: token_resp.access_token,
            refresh_token: token_resp.refresh_token,
            expires_at: token_resp
                .expires_in
                .map(|secs| Utc::now() + chrono::Duration::seconds(secs)),
        };

        *self.tokens.write().await = Some(tokens.clone());
        Ok(tokens)
    }

    /// Set tokens directly
    pub async fn set_tokens(&self, tokens: GoogleTokens) {
        *self.tokens.write().await = Some(tokens);
    }

    /// Get current access token
    async fn get_access_token(&self) -> CfkResult<String> {
        let tokens = self.tokens.read().await;
        tokens
            .as_ref()
            .map(|t| t.access_token.clone())
            .ok_or_else(|| CfkError::Auth("Not authenticated".into()))
    }

    /// Resolve path to file ID
    async fn resolve_file_id(&self, path: &VirtualPath) -> CfkResult<String> {
        if path.segments.is_empty() {
            return Ok("root".to_string());
        }

        // Check cache first
        let path_str = path.to_string();
        {
            let cache = self.path_cache.read().await;
            if let Some(id) = cache.get(&path_str) {
                return Ok(id.clone());
            }
        }

        // Resolve path segment by segment
        let mut current_id = "root".to_string();

        for segment in &path.segments {
            let query = format!(
                "'{}' in parents and name = '{}' and trashed = false",
                current_id, segment
            );

            let response = self
                .http
                .get(format!("{}/files", DRIVE_API_URL))
                .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
                .query(&[("q", &query), ("fields", &"files(id,name)".to_string())])
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            #[derive(Deserialize)]
            struct FileList {
                files: Vec<DriveFile>,
            }

            let list: FileList = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            current_id = list
                .files
                .first()
                .map(|f| f.id.clone())
                .ok_or_else(|| CfkError::NotFound(path.to_string()))?;
        }

        // Cache the result
        {
            let mut cache = self.path_cache.write().await;
            cache.insert(path_str, current_id.clone());
        }

        Ok(current_id)
    }

    /// Convert VirtualPath to parent folder ID and filename
    fn path_to_parent_and_name(&self, path: &VirtualPath) -> (String, String) {
        if path.segments.is_empty() {
            ("root".to_string(), String::new())
        } else if path.segments.len() == 1 {
            ("root".to_string(), path.segments[0].clone())
        } else {
            let parent_segments = &path.segments[..path.segments.len() - 1];
            let parent_path = parent_segments.join("/");
            let name = path.segments.last().unwrap().clone();
            (parent_path, name)
        }
    }
}

/// Google Drive file metadata
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DriveFile {
    id: String,
    name: String,
    mime_type: String,
    #[serde(default)]
    size: Option<String>,
    created_time: Option<String>,
    modified_time: Option<String>,
    #[serde(default)]
    parents: Vec<String>,
    #[serde(default)]
    trashed: bool,
    md5_checksum: Option<String>,
}

impl DriveFile {
    fn to_entry(&self, backend_id: &str, path: &str) -> Entry {
        let virtual_path = VirtualPath::new(backend_id, path);

        let kind = if self.mime_type == "application/vnd.google-apps.folder" {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = self.size.as_ref().and_then(|s| s.parse().ok());
        metadata.mime_type = Some(self.mime_type.clone());

        if let Some(ref modified) = self.modified_time {
            if let Ok(dt) = DateTime::parse_from_rfc3339(modified) {
                metadata.modified = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref created) = self.created_time {
            if let Ok(dt) = DateTime::parse_from_rfc3339(created) {
                metadata.created = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref checksum) = self.md5_checksum {
            metadata.checksum = Some(checksum.clone());
        }

        Entry {
            path: virtual_path,
            kind,
            metadata,
        }
    }
}

#[async_trait]
impl StorageBackend for GoogleDriveBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Google Drive"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.tokens.read().await.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let file_id = self.resolve_file_id(path).await?;

        let response = self
            .http
            .get(format!("{}/files/{}", DRIVE_API_URL, file_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .query(&[(
                "fields",
                "id,name,mimeType,size,createdTime,modifiedTime,parents,trashed,md5Checksum",
            )])
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            if status == reqwest::StatusCode::NOT_FOUND {
                return Err(CfkError::NotFound(path.to_string()));
            }
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "gdrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let file: DriveFile = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let path_str = path.segments.join("/");
        Ok(file.to_entry(&self.id, &path_str))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let folder_id = self.resolve_file_id(path).await?;

        let mut entries = Vec::new();
        let mut page_token: Option<String> = None;

        loop {
            let query = format!("'{}' in parents and trashed = false", folder_id);

            let mut request = self
                .http
                .get(format!("{}/files", DRIVE_API_URL))
                .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
                .query(&[
                    ("q", query.as_str()),
                    (
                        "fields",
                        "nextPageToken,files(id,name,mimeType,size,createdTime,modifiedTime,md5Checksum)",
                    ),
                    ("pageSize", "1000"),
                ]);

            if let Some(ref token) = page_token {
                request = request.query(&[("pageToken", token.as_str())]);
            }

            let response = request
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            #[derive(Deserialize)]
            #[serde(rename_all = "camelCase")]
            struct FileList {
                files: Vec<DriveFile>,
                next_page_token: Option<String>,
            }

            let list: FileList = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = if path.segments.is_empty() {
                String::new()
            } else {
                format!("{}/", path.segments.join("/"))
            };

            for file in list.files {
                let file_path = format!("{}{}", base_path, file.name);
                entries.push(file.to_entry(&self.id, &file_path));
            }

            page_token = list.next_page_token;
            if page_token.is_none() {
                break;
            }
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let file_id = self.resolve_file_id(path).await?;

        let response = self
            .http
            .get(format!("{}/files/{}?alt=media", DRIVE_API_URL, file_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "gdrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let token = self.get_access_token().await?;

        // Check if file exists
        let existing_id = self.resolve_file_id(path).await.ok();

        let (parent_path, name) = self.path_to_parent_and_name(path);
        let parent_id = if parent_path == "root" {
            "root".to_string()
        } else {
            let parent_virtual = VirtualPath::new(&self.id, &parent_path);
            self.resolve_file_id(&parent_virtual).await?
        };

        let file: DriveFile = if let Some(file_id) = existing_id {
            // Update existing file
            let response = self
                .http
                .patch(format!(
                    "{}/files/{}?uploadType=media",
                    DRIVE_UPLOAD_URL, file_id
                ))
                .header("Authorization", format!("Bearer {}", token))
                .header("Content-Type", "application/octet-stream")
                .body(data.to_vec())
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?
        } else {
            // Create new file
            #[derive(Serialize)]
            struct FileMetadata {
                name: String,
                parents: Vec<String>,
            }

            let metadata = FileMetadata {
                name: name.clone(),
                parents: vec![parent_id],
            };

            let metadata_json =
                serde_json::to_string(&metadata).map_err(|e| CfkError::Serialization(e.to_string()))?;

            // Use multipart upload
            let boundary = "cfk_boundary_12345";
            let body = format!(
                "--{}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n{}\r\n--{}\r\nContent-Type: application/octet-stream\r\n\r\n",
                boundary, metadata_json, boundary
            );

            let mut full_body = body.into_bytes();
            full_body.extend_from_slice(&data);
            full_body.extend_from_slice(format!("\r\n--{}--", boundary).as_bytes());

            let response = self
                .http
                .post(format!("{}?uploadType=multipart", DRIVE_UPLOAD_URL))
                .header("Authorization", format!("Bearer {}", token))
                .header(
                    "Content-Type",
                    format!("multipart/related; boundary={}", boundary),
                )
                .body(full_body)
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?
        };

        let path_str = path.segments.join("/");
        Ok(file.to_entry(&self.id, &path_str))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let file_id = self.resolve_file_id(path).await?;

        let response = self
            .http
            .delete(format!("{}/files/{}", DRIVE_API_URL, file_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != reqwest::StatusCode::NO_CONTENT {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "gdrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        // Invalidate cache
        {
            let mut cache = self.path_cache.write().await;
            cache.remove(&path.to_string());
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let token = self.get_access_token().await?;
        let (parent_path, name) = self.path_to_parent_and_name(path);

        let parent_id = if parent_path == "root" {
            "root".to_string()
        } else {
            let parent_virtual = VirtualPath::new(&self.id, &parent_path);
            self.resolve_file_id(&parent_virtual).await?
        };

        #[derive(Serialize)]
        #[serde(rename_all = "camelCase")]
        struct FolderMetadata {
            name: String,
            mime_type: String,
            parents: Vec<String>,
        }

        let metadata = FolderMetadata {
            name,
            mime_type: "application/vnd.google-apps.folder".to_string(),
            parents: vec![parent_id],
        };

        let response = self
            .http
            .post(format!("{}/files", DRIVE_API_URL))
            .header("Authorization", format!("Bearer {}", token))
            .json(&metadata)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let file: DriveFile = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let path_str = path.segments.join("/");
        Ok(file.to_entry(&self.id, &path_str))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let token = self.get_access_token().await?;
        let file_id = self.resolve_file_id(from).await?;

        let (parent_path, name) = self.path_to_parent_and_name(to);
        let parent_id = if parent_path == "root" {
            "root".to_string()
        } else {
            let parent_virtual = VirtualPath::new(&self.id, &parent_path);
            self.resolve_file_id(&parent_virtual).await?
        };

        #[derive(Serialize)]
        struct CopyMetadata {
            name: String,
            parents: Vec<String>,
        }

        let metadata = CopyMetadata {
            name,
            parents: vec![parent_id],
        };

        let response = self
            .http
            .post(format!("{}/files/{}/copy", DRIVE_API_URL, file_id))
            .header("Authorization", format!("Bearer {}", token))
            .json(&metadata)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let file: DriveFile = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let path_str = to.segments.join("/");
        Ok(file.to_entry(&self.id, &path_str))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let token = self.get_access_token().await?;
        let file_id = self.resolve_file_id(from).await?;

        let (parent_path, name) = self.path_to_parent_and_name(to);
        let parent_id = if parent_path == "root" {
            "root".to_string()
        } else {
            let parent_virtual = VirtualPath::new(&self.id, &parent_path);
            self.resolve_file_id(&parent_virtual).await?
        };

        #[derive(Serialize)]
        struct UpdateMetadata {
            name: String,
        }

        let metadata = UpdateMetadata { name };

        let response = self
            .http
            .patch(format!(
                "{}/files/{}?addParents={}&removeParents={}",
                DRIVE_API_URL, file_id, parent_id, "root"
            ))
            .header("Authorization", format!("Bearer {}", token))
            .json(&metadata)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let file: DriveFile = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        // Invalidate cache
        {
            let mut cache = self.path_cache.write().await;
            cache.remove(&from.to_string());
        }

        let path_str = to.segments.join("/");
        Ok(file.to_entry(&self.id, &path_str))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        let response = self
            .http
            .get(format!("{}/about", DRIVE_API_URL))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .query(&[("fields", "storageQuota")])
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct About {
            storage_quota: StorageQuota,
        }

        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct StorageQuota {
            limit: Option<String>,
            usage: Option<String>,
        }

        let about: About = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let total: u64 = about
            .storage_quota
            .limit
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        let used: u64 = about
            .storage_quota
            .usage
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        let available = total.saturating_sub(used);

        Ok((available, total))
    }
}
