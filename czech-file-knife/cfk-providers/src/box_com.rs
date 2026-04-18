//! Box.com storage backend
//!
//! Box API implementation with OAuth 2.0 authentication.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use chrono::{DateTime, Utc};
use oauth2::{
    basic::BasicClient, AuthUrl, ClientId, ClientSecret, CsrfToken, PkceCodeChallenge,
    PkceCodeVerifier, RedirectUrl, Scope, TokenUrl,
};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

const BOX_AUTH_URL: &str = "https://account.box.com/api/oauth2/authorize";
const BOX_TOKEN_URL: &str = "https://api.box.com/oauth2/token";
const BOX_API_URL: &str = "https://api.box.com/2.0";
const BOX_UPLOAD_URL: &str = "https://upload.box.com/api/2.0";

/// Box OAuth tokens
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BoxTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
}

/// Box backend configuration
#[derive(Debug, Clone)]
pub struct BoxConfig {
    pub client_id: String,
    pub client_secret: String,
    pub redirect_uri: String,
}

/// Box storage backend
pub struct BoxBackend {
    id: String,
    config: BoxConfig,
    tokens: Arc<RwLock<Option<BoxTokens>>>,
    http: Client,
    capabilities: StorageCapabilities,
    /// Cache of path to folder ID
    folder_cache: Arc<RwLock<HashMap<String, String>>>,
}

impl BoxBackend {
    pub fn new(id: impl Into<String>, config: BoxConfig) -> Self {
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
                max_file_size: Some(150 * 1024 * 1024 * 1024), // 150GB for enterprise
            },
            folder_cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Start OAuth 2.0 flow
    pub fn start_auth(&self) -> (String, PkceCodeVerifier) {
        let client = BasicClient::new(ClientId::new(self.config.client_id.clone()))
            .set_client_secret(ClientSecret::new(self.config.client_secret.clone()))
            .set_auth_uri(AuthUrl::new(BOX_AUTH_URL.to_string()).unwrap())
            .set_token_uri(TokenUrl::new(BOX_TOKEN_URL.to_string()).unwrap())
            .set_redirect_uri(RedirectUrl::new(self.config.redirect_uri.clone()).unwrap());

        let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();

        let (auth_url, _csrf_token) = client
            .authorize_url(CsrfToken::new_random)
            .add_scope(Scope::new("root_readwrite".to_string()))
            .set_pkce_challenge(pkce_challenge)
            .url();

        (auth_url.to_string(), pkce_verifier)
    }

    /// Complete OAuth flow
    pub async fn complete_auth(
        &self,
        code: &str,
        _verifier: PkceCodeVerifier,
    ) -> CfkResult<BoxTokens> {
        let params = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("client_id", &self.config.client_id),
            ("client_secret", &self.config.client_secret),
        ];

        let response = self
            .http
            .post(BOX_TOKEN_URL)
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

        let tokens = BoxTokens {
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
    pub async fn set_tokens(&self, tokens: BoxTokens) {
        *self.tokens.write().await = Some(tokens);
    }

    /// Get access token
    async fn get_access_token(&self) -> CfkResult<String> {
        let tokens = self.tokens.read().await;
        tokens
            .as_ref()
            .map(|t| t.access_token.clone())
            .ok_or_else(|| CfkError::Auth("Not authenticated".into()))
    }

    /// Resolve path to folder ID
    async fn resolve_folder_id(&self, path: &VirtualPath) -> CfkResult<String> {
        if path.segments.is_empty() {
            return Ok("0".to_string()); // Root folder
        }

        let path_str = path.to_string();
        {
            let cache = self.folder_cache.read().await;
            if let Some(id) = cache.get(&path_str) {
                return Ok(id.clone());
            }
        }

        // Navigate path
        let mut current_id = "0".to_string();

        for segment in &path.segments {
            let response = self
                .http
                .get(format!("{}/folders/{}/items", BOX_API_URL, current_id))
                .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
                .query(&[("fields", "id,name,type")])
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            #[derive(Deserialize)]
            struct ItemList {
                entries: Vec<BoxItem>,
            }

            let list: ItemList = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            current_id = list
                .entries
                .iter()
                .find(|e| e.name == *segment)
                .map(|e| e.id.clone())
                .ok_or_else(|| CfkError::NotFound(path.to_string()))?;
        }

        // Cache
        {
            let mut cache = self.folder_cache.write().await;
            cache.insert(path_str, current_id.clone());
        }

        Ok(current_id)
    }
}

/// Box item metadata
#[derive(Debug, Clone, Deserialize)]
struct BoxItem {
    id: String,
    #[serde(rename = "type")]
    item_type: String,
    name: String,
    size: Option<u64>,
    created_at: Option<String>,
    modified_at: Option<String>,
    sha1: Option<String>,
}

impl BoxItem {
    fn to_entry(&self, backend_id: &str, base_path: &str) -> Entry {
        let path_str = if base_path.is_empty() {
            self.name.clone()
        } else {
            format!("{}/{}", base_path, self.name)
        };
        let virtual_path = VirtualPath::new(backend_id, &path_str);

        let kind = if self.item_type == "folder" {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = self.size;

        if let Some(ref modified) = self.modified_at {
            if let Ok(dt) = DateTime::parse_from_rfc3339(modified) {
                metadata.modified = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref created) = self.created_at {
            if let Ok(dt) = DateTime::parse_from_rfc3339(created) {
                metadata.created = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref sha1) = self.sha1 {
            metadata.checksum = Some(sha1.clone());
        }

        Entry {
            path: virtual_path,
            kind,
            metadata,
        }
    }
}

#[async_trait]
impl StorageBackend for BoxBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Box"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.tokens.read().await.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let item_id = self.resolve_folder_id(path).await?;

        // Try as folder first
        let response = self
            .http
            .get(format!("{}/folders/{}", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if response.status().is_success() {
            let item: BoxItem = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = if path.segments.len() > 1 {
                path.segments[..path.segments.len() - 1].join("/")
            } else {
                String::new()
            };

            return Ok(item.to_entry(&self.id, &base_path));
        }

        // Try as file
        let response = self
            .http
            .get(format!("{}/files/{}", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: BoxItem = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let base_path = if path.segments.len() > 1 {
            path.segments[..path.segments.len() - 1].join("/")
        } else {
            String::new()
        };

        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let folder_id = self.resolve_folder_id(path).await?;

        let mut entries = Vec::new();
        let mut offset = 0;
        let limit = 1000;

        loop {
            let response = self
                .http
                .get(format!("{}/folders/{}/items", BOX_API_URL, folder_id))
                .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
                .query(&[
                    ("fields", "id,type,name,size,created_at,modified_at,sha1"),
                    ("limit", &limit.to_string()),
                    ("offset", &offset.to_string()),
                ])
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            #[derive(Deserialize)]
            struct ItemList {
                entries: Vec<BoxItem>,
                total_count: u64,
            }

            let list: ItemList = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = path.segments.join("/");

            for item in &list.entries {
                entries.push(item.to_entry(&self.id, &base_path));
            }

            offset += list.entries.len();
            if offset as u64 >= list.total_count {
                break;
            }
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let file_id = self.resolve_folder_id(path).await?;

        let response = self
            .http
            .get(format!("{}/files/{}/content", BOX_API_URL, file_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "box".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let parent_path = if path.segments.len() > 1 {
            VirtualPath::new(&self.id, &path.segments[..path.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };

        let parent_id = self.resolve_folder_id(&parent_path).await?;
        let name = path.segments.last().cloned().unwrap_or_default();

        // Use multipart upload
        let boundary = "cfk_box_boundary";

        #[derive(Serialize)]
        struct FileAttributes {
            name: String,
            parent: Parent,
        }

        #[derive(Serialize)]
        struct Parent {
            id: String,
        }

        let attributes = FileAttributes {
            name: name.clone(),
            parent: Parent { id: parent_id },
        };

        let attributes_json =
            serde_json::to_string(&attributes).map_err(|e| CfkError::Serialization(e.to_string()))?;

        let body = format!(
            "--{}\r\nContent-Disposition: form-data; name=\"attributes\"\r\n\r\n{}\r\n--{}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{}\"\r\nContent-Type: application/octet-stream\r\n\r\n",
            boundary, attributes_json, boundary, name
        );

        let mut full_body = body.into_bytes();
        full_body.extend_from_slice(&data);
        full_body.extend_from_slice(format!("\r\n--{}--", boundary).as_bytes());

        let response = self
            .http
            .post(format!("{}/files/content", BOX_UPLOAD_URL))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .header(
                "Content-Type",
                format!("multipart/form-data; boundary={}", boundary),
            )
            .body(full_body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        #[derive(Deserialize)]
        struct UploadResponse {
            entries: Vec<BoxItem>,
        }

        let upload_resp: UploadResponse = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let item = upload_resp
            .entries
            .first()
            .ok_or_else(|| CfkError::ProviderApi {
                provider: "box".into(),
                message: "No file returned".into(),
            })?;

        let base_path = parent_path.segments.join("/");
        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let item_id = self.resolve_folder_id(path).await?;

        // Try as file first
        let response = self
            .http
            .delete(format!("{}/files/{}", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if response.status().is_success() || response.status() == reqwest::StatusCode::NO_CONTENT {
            return Ok(());
        }

        // Try as folder
        let response = self
            .http
            .delete(format!("{}/folders/{}?recursive=true", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != reqwest::StatusCode::NO_CONTENT {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "box".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let parent_path = if path.segments.len() > 1 {
            VirtualPath::new(&self.id, &path.segments[..path.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };

        let parent_id = self.resolve_folder_id(&parent_path).await?;
        let name = path.segments.last().cloned().unwrap_or_default();

        #[derive(Serialize)]
        struct CreateFolder {
            name: String,
            parent: Parent,
        }

        #[derive(Serialize)]
        struct Parent {
            id: String,
        }

        let body = CreateFolder {
            name,
            parent: Parent { id: parent_id },
        };

        let response = self
            .http
            .post(format!("{}/folders", BOX_API_URL))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: BoxItem = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let base_path = parent_path.segments.join("/");
        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let item_id = self.resolve_folder_id(from).await?;
        let parent_path = if to.segments.len() > 1 {
            VirtualPath::new(&self.id, &to.segments[..to.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };
        let parent_id = self.resolve_folder_id(&parent_path).await?;
        let name = to.segments.last().cloned().unwrap_or_default();

        #[derive(Serialize)]
        struct CopyRequest {
            parent: Parent,
            name: String,
        }

        #[derive(Serialize)]
        struct Parent {
            id: String,
        }

        let body = CopyRequest {
            parent: Parent { id: parent_id },
            name,
        };

        // Try as file
        let response = self
            .http
            .post(format!("{}/files/{}/copy", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if response.status().is_success() {
            let item: BoxItem = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = parent_path.segments.join("/");
            return Ok(item.to_entry(&self.id, &base_path));
        }

        // Try as folder
        let response = self
            .http
            .post(format!("{}/folders/{}/copy", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: BoxItem = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let base_path = parent_path.segments.join("/");
        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let item_id = self.resolve_folder_id(from).await?;
        let name = to.segments.last().cloned().unwrap_or_default();

        #[derive(Serialize)]
        struct RenameRequest {
            name: String,
        }

        let body = RenameRequest { name };

        // Try as file
        let response = self
            .http
            .put(format!("{}/files/{}", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if response.status().is_success() {
            let item: BoxItem = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = if to.segments.len() > 1 {
                to.segments[..to.segments.len() - 1].join("/")
            } else {
                String::new()
            };
            return Ok(item.to_entry(&self.id, &base_path));
        }

        // Try as folder
        let response = self
            .http
            .put(format!("{}/folders/{}", BOX_API_URL, item_id))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: BoxItem = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let base_path = if to.segments.len() > 1 {
            to.segments[..to.segments.len() - 1].join("/")
        } else {
            String::new()
        };
        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        let response = self
            .http
            .get(format!("{}/users/me", BOX_API_URL))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .query(&[("fields", "space_amount,space_used")])
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        #[derive(Deserialize)]
        struct User {
            space_amount: Option<u64>,
            space_used: Option<u64>,
        }

        let user: User = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let total = user.space_amount.unwrap_or(0);
        let used = user.space_used.unwrap_or(0);
        let available = total.saturating_sub(used);

        Ok((available, total))
    }
}
