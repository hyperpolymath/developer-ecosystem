//! OneDrive storage backend
//!
//! Microsoft Graph API implementation for OneDrive Personal and Business.

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

const MS_AUTH_URL: &str = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize";
const MS_TOKEN_URL: &str = "https://login.microsoftonline.com/common/oauth2/v2.0/token";
const GRAPH_API_URL: &str = "https://graph.microsoft.com/v1.0";

/// Microsoft OAuth tokens
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OneDriveTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<DateTime<Utc>>,
}

/// OneDrive backend configuration
#[derive(Debug, Clone)]
pub struct OneDriveConfig {
    pub client_id: String,
    pub redirect_uri: String,
    /// Use OneDrive for Business (SharePoint) instead of personal
    pub business: bool,
}

/// OneDrive storage backend
pub struct OneDriveBackend {
    id: String,
    config: OneDriveConfig,
    tokens: Arc<RwLock<Option<OneDriveTokens>>>,
    http: Client,
    capabilities: StorageCapabilities,
}

impl OneDriveBackend {
    pub fn new(id: impl Into<String>, config: OneDriveConfig) -> Self {
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
                max_file_size: Some(250 * 1024 * 1024 * 1024), // 250GB
            },
        }
    }

    /// Start OAuth 2.0 + PKCE flow
    pub fn start_auth(&self) -> (String, PkceCodeVerifier) {
        let client = BasicClient::new(ClientId::new(self.config.client_id.clone()))
            .set_auth_uri(AuthUrl::new(MS_AUTH_URL.to_string()).unwrap())
            .set_token_uri(TokenUrl::new(MS_TOKEN_URL.to_string()).unwrap())
            .set_redirect_uri(RedirectUrl::new(self.config.redirect_uri.clone()).unwrap());

        let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();

        let (auth_url, _csrf_token) = client
            .authorize_url(CsrfToken::new_random)
            .add_scope(Scope::new("Files.ReadWrite.All".to_string()))
            .add_scope(Scope::new("offline_access".to_string()))
            .set_pkce_challenge(pkce_challenge)
            .url();

        (auth_url.to_string(), pkce_verifier)
    }

    /// Complete OAuth flow with authorization code
    pub async fn complete_auth(
        &self,
        code: &str,
        verifier: PkceCodeVerifier,
    ) -> CfkResult<OneDriveTokens> {
        let params = [
            ("code", code.to_string()),
            ("grant_type", "authorization_code".to_string()),
            ("client_id", self.config.client_id.clone()),
            ("redirect_uri", self.config.redirect_uri.clone()),
            ("code_verifier", verifier.secret().to_string()),
        ];

        let response = self
            .http
            .post(MS_TOKEN_URL)
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

        let tokens = OneDriveTokens {
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
    pub async fn set_tokens(&self, tokens: OneDriveTokens) {
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

    /// Build API path for OneDrive
    fn api_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            format!("{}/me/drive/root", GRAPH_API_URL)
        } else {
            let path_str = path.segments.join("/");
            format!("{}/me/drive/root:/{}", GRAPH_API_URL, path_str)
        }
    }

    /// Build children API path
    fn children_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            format!("{}/me/drive/root/children", GRAPH_API_URL)
        } else {
            let path_str = path.segments.join("/");
            format!("{}/me/drive/root:/{}:/children", GRAPH_API_URL, path_str)
        }
    }
}

/// OneDrive item metadata
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DriveItem {
    id: String,
    name: String,
    size: Option<u64>,
    created_date_time: Option<String>,
    last_modified_date_time: Option<String>,
    folder: Option<FolderFacet>,
    file: Option<FileFacet>,
    parent_reference: Option<ParentReference>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct FolderFacet {
    child_count: Option<u32>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct FileFacet {
    mime_type: Option<String>,
    hashes: Option<FileHashes>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct FileHashes {
    quick_xor_hash: Option<String>,
    sha1_hash: Option<String>,
    sha256_hash: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ParentReference {
    path: Option<String>,
}

impl DriveItem {
    fn to_entry(&self, backend_id: &str, base_path: &str) -> Entry {
        let path_str = if base_path.is_empty() {
            self.name.clone()
        } else {
            format!("{}/{}", base_path, self.name)
        };
        let virtual_path = VirtualPath::new(backend_id, &path_str);

        let kind = if self.folder.is_some() {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = self.size;

        if let Some(ref file) = self.file {
            metadata.mime_type = file.mime_type.clone();
            if let Some(ref hashes) = file.hashes {
                metadata.checksum = hashes
                    .sha256_hash
                    .clone()
                    .or_else(|| hashes.sha1_hash.clone());
            }
        }

        if let Some(ref modified) = self.last_modified_date_time {
            if let Ok(dt) = DateTime::parse_from_rfc3339(modified) {
                metadata.modified = Some(dt.with_timezone(&Utc));
            }
        }
        if let Some(ref created) = self.created_date_time {
            if let Ok(dt) = DateTime::parse_from_rfc3339(created) {
                metadata.created = Some(dt.with_timezone(&Utc));
            }
        }

        Entry {
            path: virtual_path,
            kind,
            metadata,
        }
    }
}

#[async_trait]
impl StorageBackend for OneDriveBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        if self.config.business {
            "OneDrive for Business"
        } else {
            "OneDrive"
        }
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.tokens.read().await.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let url = self.api_path(path);

        let response = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
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
                provider: "onedrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let item: DriveItem = response
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
        let url = self.children_path(path);

        let mut entries = Vec::new();
        let mut next_link: Option<String> = Some(url);

        while let Some(url) = next_link.take() {
            let response = self
                .http
                .get(&url)
                .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
                .send()
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            #[derive(Deserialize)]
            struct ItemList {
                value: Vec<DriveItem>,
                #[serde(rename = "@odata.nextLink")]
                next_link: Option<String>,
            }

            let list: ItemList = response
                .json()
                .await
                .map_err(|e| CfkError::Serialization(e.to_string()))?;

            let base_path = path.segments.join("/");

            for item in list.value {
                entries.push(item.to_entry(&self.id, &base_path));
            }

            next_link = list.next_link;
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let url = format!("{}:/content", self.api_path(path));

        let response = self
            .http
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "onedrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let url = format!("{}:/content", self.api_path(path));

        let response = self
            .http
            .put(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .header("Content-Type", "application/octet-stream")
            .body(data.to_vec())
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "onedrive".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let item: DriveItem = response
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

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let url = self.api_path(path);

        let response = self
            .http
            .delete(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() && response.status() != reqwest::StatusCode::NO_CONTENT {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "onedrive".into(),
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

        let name = path.segments.last().cloned().unwrap_or_default();
        let url = self.children_path(&parent_path);

        #[derive(Serialize)]
        struct CreateFolder {
            name: String,
            folder: serde_json::Value,
            #[serde(rename = "@microsoft.graph.conflictBehavior")]
            conflict_behavior: String,
        }

        let body = CreateFolder {
            name,
            folder: serde_json::json!({}),
            conflict_behavior: "fail".to_string(),
        };

        let response = self
            .http
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: DriveItem = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let base_path = parent_path.segments.join("/");
        Ok(item.to_entry(&self.id, &base_path))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_url = self.api_path(from);
        let to_parent = if to.segments.len() > 1 {
            VirtualPath::new(&self.id, &to.segments[..to.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };
        let to_name = to.segments.last().cloned().unwrap_or_default();

        // Get the parent folder's drive item id
        let parent_response = self
            .http
            .get(&self.api_path(&to_parent))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let parent_item: DriveItem = parent_response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        #[derive(Serialize)]
        #[serde(rename_all = "camelCase")]
        struct CopyRequest {
            parent_reference: ParentRef,
            name: String,
        }

        #[derive(Serialize)]
        struct ParentRef {
            id: String,
        }

        let body = CopyRequest {
            parent_reference: ParentRef { id: parent_item.id },
            name: to_name,
        };

        let _response = self
            .http
            .post(format!("{}:/copy", from_url))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        // Copy is async in OneDrive, return metadata of destination
        self.get_metadata(to).await
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let url = self.api_path(from);
        let to_name = to.segments.last().cloned().unwrap_or_default();

        #[derive(Serialize)]
        struct RenameRequest {
            name: String,
        }

        let body = RenameRequest { name: to_name };

        let response = self
            .http
            .patch(&url)
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let item: DriveItem = response
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
            .get(format!("{}/me/drive", GRAPH_API_URL))
            .header("Authorization", format!("Bearer {}", self.get_access_token().await?))
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        #[derive(Deserialize)]
        struct Drive {
            quota: Option<DriveQuota>,
        }

        #[derive(Deserialize)]
        struct DriveQuota {
            total: Option<u64>,
            used: Option<u64>,
            remaining: Option<u64>,
        }

        let drive: Drive = response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))?;

        let quota = drive.quota.unwrap_or(DriveQuota {
            total: None,
            used: None,
            remaining: None,
        });

        let total = quota.total.unwrap_or(0);
        let available = quota.remaining.unwrap_or(0);

        Ok((available, total))
    }
}
