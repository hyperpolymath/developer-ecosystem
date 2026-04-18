//! Dropbox storage backend
//!
//! Full implementation of Dropbox API v2 with OAuth 2.0 + PKCE authentication.

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
use std::sync::Arc;
use tokio::sync::RwLock;

const DROPBOX_AUTH_URL: &str = "https://www.dropbox.com/oauth2/authorize";
const DROPBOX_TOKEN_URL: &str = "https://api.dropboxapi.com/oauth2/token";
const DROPBOX_API_URL: &str = "https://api.dropboxapi.com/2";
const DROPBOX_CONTENT_URL: &str = "https://content.dropboxapi.com/2";

/// Dropbox OAuth tokens
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DropboxTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
}

/// Dropbox backend configuration
#[derive(Debug, Clone)]
pub struct DropboxConfig {
    pub client_id: String,
    pub redirect_uri: String,
}

/// Dropbox storage backend
pub struct DropboxBackend {
    id: String,
    config: DropboxConfig,
    tokens: Arc<RwLock<Option<DropboxTokens>>>,
    http: Client,
    capabilities: StorageCapabilities,
}

impl DropboxBackend {
    pub fn new(id: impl Into<String>, config: DropboxConfig) -> Self {
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
                watch: false,
                metadata: true,
                thumbnails: true,
                max_file_size: Some(350 * 1024 * 1024 * 1024), // 350GB
            },
        }
    }

    /// Start OAuth 2.0 + PKCE flow
    pub fn start_auth(&self) -> (String, PkceCodeVerifier) {
        let client = BasicClient::new(ClientId::new(self.config.client_id.clone()))
            .set_auth_uri(AuthUrl::new(DROPBOX_AUTH_URL.to_string()).unwrap())
            .set_token_uri(TokenUrl::new(DROPBOX_TOKEN_URL.to_string()).unwrap())
            .set_redirect_uri(RedirectUrl::new(self.config.redirect_uri.clone()).unwrap());

        let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();

        let (auth_url, _csrf_token) = client
            .authorize_url(CsrfToken::new_random)
            .add_scope(Scope::new("files.metadata.read".to_string()))
            .add_scope(Scope::new("files.metadata.write".to_string()))
            .add_scope(Scope::new("files.content.read".to_string()))
            .add_scope(Scope::new("files.content.write".to_string()))
            .set_pkce_challenge(pkce_challenge)
            .url();

        (auth_url.to_string(), pkce_verifier)
    }

    /// Complete OAuth flow with authorization code
    pub async fn complete_auth(
        &self,
        code: &str,
        verifier: PkceCodeVerifier,
    ) -> CfkResult<DropboxTokens> {
        let params = [
            ("code", code),
            ("grant_type", "authorization_code"),
            ("client_id", &self.config.client_id),
            ("redirect_uri", &self.config.redirect_uri),
            ("code_verifier", verifier.secret()),
        ];

        let response = self
            .http
            .post(DROPBOX_TOKEN_URL)
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

        let tokens = DropboxTokens {
            access_token: token_resp.access_token,
            refresh_token: token_resp.refresh_token,
            expires_at: token_resp
                .expires_in
                .map(|secs| Utc::now() + chrono::Duration::seconds(secs)),
        };

        *self.tokens.write().await = Some(tokens.clone());
        Ok(tokens)
    }

    /// Set tokens directly (for restoring from storage)
    pub async fn set_tokens(&self, tokens: DropboxTokens) {
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

    /// Make authenticated API request
    async fn api_request<T: for<'de> Deserialize<'de>>(
        &self,
        endpoint: &str,
        body: impl Serialize,
    ) -> CfkResult<T> {
        let token = self.get_access_token().await?;
        let url = format!("{}/{}", DROPBOX_API_URL, endpoint);

        let response = self
            .http
            .post(&url)
            .header("Authorization", format!("Bearer {}", token))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "dropbox".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))
    }

    /// Convert Dropbox path to VirtualPath
    fn to_virtual_path(&self, dropbox_path: &str) -> VirtualPath {
        let path = dropbox_path.trim_start_matches('/');
        VirtualPath::new(&self.id, path)
    }

    /// Convert VirtualPath to Dropbox path
    fn to_dropbox_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            String::new()
        } else {
            format!("/{}", path.segments.join("/"))
        }
    }
}

/// Dropbox file metadata response
#[derive(Debug, Deserialize)]
struct DropboxMetadata {
    #[serde(rename = ".tag")]
    tag: String,
    name: String,
    path_display: Option<String>,
    id: Option<String>,
    size: Option<u64>,
    client_modified: Option<String>,
    server_modified: Option<String>,
    rev: Option<String>,
    content_hash: Option<String>,
}

impl DropboxMetadata {
    fn to_entry(&self, backend_id: &str) -> Entry {
        let path = self
            .path_display
            .as_deref()
            .unwrap_or(&self.name)
            .trim_start_matches('/');
        let virtual_path = VirtualPath::new(backend_id, path);

        let kind = if self.tag == "folder" {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = self.size;
        if let Some(ref modified) = self.server_modified {
            if let Ok(dt) = DateTime::parse_from_rfc3339(modified) {
                metadata.modified = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref hash) = self.content_hash {
            metadata.checksum = Some(hash.clone());
        }

        Entry {
            path: virtual_path,
            kind,
            metadata,
        }
    }
}

/// List folder response
#[derive(Debug, Deserialize)]
struct ListFolderResponse {
    entries: Vec<DropboxMetadata>,
    cursor: String,
    has_more: bool,
}

#[async_trait]
impl StorageBackend for DropboxBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Dropbox"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.tokens.read().await.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let dropbox_path = self.to_dropbox_path(path);

        if dropbox_path.is_empty() {
            // Root folder
            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata: Metadata::default(),
            });
        }

        #[derive(Serialize)]
        struct GetMetadataArg {
            path: String,
        }

        let result: DropboxMetadata = self
            .api_request("files/get_metadata", GetMetadataArg { path: dropbox_path })
            .await?;

        Ok(result.to_entry(&self.id))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let dropbox_path = self.to_dropbox_path(path);

        #[derive(Serialize)]
        struct ListFolderArg {
            path: String,
            recursive: bool,
            include_deleted: bool,
            limit: u32,
        }

        let result: ListFolderResponse = self
            .api_request(
                "files/list_folder",
                ListFolderArg {
                    path: if dropbox_path.is_empty() {
                        String::new()
                    } else {
                        dropbox_path
                    },
                    recursive: false,
                    include_deleted: false,
                    limit: 2000,
                },
            )
            .await?;

        let mut entries: Vec<Entry> = result
            .entries
            .iter()
            .map(|m| m.to_entry(&self.id))
            .collect();

        // Handle pagination
        let mut cursor = result.cursor;
        let mut has_more = result.has_more;

        while has_more {
            #[derive(Serialize)]
            struct ListFolderContinueArg {
                cursor: String,
            }

            let continue_result: ListFolderResponse = self
                .api_request(
                    "files/list_folder/continue",
                    ListFolderContinueArg {
                        cursor: cursor.clone(),
                    },
                )
                .await?;

            entries.extend(continue_result.entries.iter().map(|m| m.to_entry(&self.id)));
            cursor = continue_result.cursor;
            has_more = continue_result.has_more;
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let token = self.get_access_token().await?;
        let dropbox_path = self.to_dropbox_path(path);

        #[derive(Serialize)]
        struct DownloadArg {
            path: String,
        }

        let arg = serde_json::to_string(&DownloadArg { path: dropbox_path })
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let response = self
            .http
            .post(format!("{}/files/download", DROPBOX_CONTENT_URL))
            .header("Authorization", format!("Bearer {}", token))
            .header("Dropbox-API-Arg", arg)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "dropbox".into(),
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
        let dropbox_path = self.to_dropbox_path(path);

        #[derive(Serialize)]
        struct UploadArg {
            path: String,
            mode: String,
            autorename: bool,
            mute: bool,
        }

        let arg = serde_json::to_string(&UploadArg {
            path: dropbox_path,
            mode: "overwrite".to_string(),
            autorename: false,
            mute: false,
        })
        .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let response = self
            .http
            .post(format!("{}/files/upload", DROPBOX_CONTENT_URL))
            .header("Authorization", format!("Bearer {}", token))
            .header("Dropbox-API-Arg", arg)
            .header("Content-Type", "application/octet-stream")
            .body(data.to_vec())
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "dropbox".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let metadata: DropboxMetadata = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        Ok(metadata.to_entry(&self.id))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let dropbox_path = self.to_dropbox_path(path);

        #[derive(Serialize)]
        struct DeleteArg {
            path: String,
        }

        let _: serde_json::Value = self
            .api_request("files/delete_v2", DeleteArg { path: dropbox_path })
            .await?;

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let dropbox_path = self.to_dropbox_path(path);

        #[derive(Serialize)]
        struct CreateFolderArg {
            path: String,
            autorename: bool,
        }

        #[derive(Deserialize)]
        struct CreateFolderResult {
            metadata: DropboxMetadata,
        }

        let result: CreateFolderResult = self
            .api_request(
                "files/create_folder_v2",
                CreateFolderArg {
                    path: dropbox_path,
                    autorename: false,
                },
            )
            .await?;

        Ok(result.metadata.to_entry(&self.id))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_dropbox_path(from);
        let to_path = self.to_dropbox_path(to);

        #[derive(Serialize)]
        struct CopyArg {
            from_path: String,
            to_path: String,
            autorename: bool,
        }

        #[derive(Deserialize)]
        struct CopyResult {
            metadata: DropboxMetadata,
        }

        let result: CopyResult = self
            .api_request(
                "files/copy_v2",
                CopyArg {
                    from_path,
                    to_path,
                    autorename: false,
                },
            )
            .await?;

        Ok(result.metadata.to_entry(&self.id))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_dropbox_path(from);
        let to_path = self.to_dropbox_path(to);

        #[derive(Serialize)]
        struct MoveArg {
            from_path: String,
            to_path: String,
            autorename: bool,
        }

        #[derive(Deserialize)]
        struct MoveResult {
            metadata: DropboxMetadata,
        }

        let result: MoveResult = self
            .api_request(
                "files/move_v2",
                MoveArg {
                    from_path,
                    to_path,
                    autorename: false,
                },
            )
            .await?;

        Ok(result.metadata.to_entry(&self.id))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        #[derive(Deserialize)]
        struct SpaceUsage {
            used: u64,
            allocation: SpaceAllocation,
        }

        #[derive(Deserialize)]
        struct SpaceAllocation {
            #[serde(rename = ".tag")]
            tag: String,
            allocated: Option<u64>,
        }

        let result: SpaceUsage = self
            .api_request("users/get_space_usage", serde_json::json!(null))
            .await?;

        let total = result.allocation.allocated.unwrap_or(0);
        let used = result.used;
        let available = total.saturating_sub(used);

        Ok((available, total))
    }
}
