//! Syncthing storage backend
//!
//! Connects to Syncthing's REST API to expose synced folders.
//! Note: Syncthing folders are local, this backend provides folder discovery and sync status.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Syncthing connection configuration
#[derive(Debug, Clone)]
pub struct SyncthingConfig {
    pub api_url: String,
    pub api_key: String,
}

/// Syncthing folder information
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FolderConfig {
    pub id: String,
    pub label: String,
    pub path: String,
    #[serde(rename = "type")]
    pub folder_type: String,
    pub paused: bool,
}

/// Syncthing folder status
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FolderStatus {
    pub state: String,
    pub local_files: u64,
    pub local_bytes: u64,
    pub global_files: u64,
    pub global_bytes: u64,
    pub need_files: u64,
    pub need_bytes: u64,
}

/// Syncthing storage backend
pub struct SyncthingBackend {
    id: String,
    http: Client,
    config: Arc<RwLock<SyncthingConfig>>,
    capabilities: StorageCapabilities,
    /// Cache of folder configs
    folders: Arc<RwLock<HashMap<String, FolderConfig>>>,
}

impl SyncthingBackend {
    pub fn new(id: impl Into<String>, config: SyncthingConfig) -> Self {
        Self {
            id: id.into(),
            http: Client::new(),
            config: Arc::new(RwLock::new(config)),
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: true,
                list: true,
                search: false,
                versioning: true,
                sharing: false,
                streaming: true,
                resume: true,
                watch: true,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
            folders: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Make API GET request
    async fn api_get<T: for<'de> Deserialize<'de>>(&self, endpoint: &str) -> CfkResult<T> {
        let config = self.config.read().await;
        let url = format!("{}/rest/{}", config.api_url, endpoint);

        let response = self
            .http
            .get(&url)
            .header("X-API-Key", &config.api_key)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            return Err(CfkError::ProviderApi {
                provider: "syncthing".into(),
                message: response.text().await.unwrap_or_default(),
            });
        }

        response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))
    }

    /// Make API POST request
    async fn api_post<T: for<'de> Deserialize<'de>>(
        &self,
        endpoint: &str,
        body: impl Serialize,
    ) -> CfkResult<T> {
        let config = self.config.read().await;
        let url = format!("{}/rest/{}", config.api_url, endpoint);

        let response = self
            .http
            .post(&url)
            .header("X-API-Key", &config.api_key)
            .json(&body)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            return Err(CfkError::ProviderApi {
                provider: "syncthing".into(),
                message: response.text().await.unwrap_or_default(),
            });
        }

        response
            .json()
            .await
            .map_err(|e| CfkError::Serialization(e.to_string()))
    }

    /// Refresh folder list
    pub async fn refresh_folders(&self) -> CfkResult<()> {
        #[derive(Deserialize)]
        struct ConfigResponse {
            folders: Vec<FolderConfig>,
        }

        let config: ConfigResponse = self.api_get("config").await?;

        let mut folders = self.folders.write().await;
        folders.clear();
        for folder in config.folders {
            folders.insert(folder.id.clone(), folder);
        }

        Ok(())
    }

    /// Get folder status
    pub async fn get_folder_status(&self, folder_id: &str) -> CfkResult<FolderStatus> {
        self.api_get(&format!("db/status?folder={}", folder_id))
            .await
    }

    /// Trigger rescan of a folder
    pub async fn rescan_folder(&self, folder_id: &str) -> CfkResult<()> {
        let config = self.config.read().await;
        let url = format!(
            "{}/rest/db/scan?folder={}",
            config.api_url, folder_id
        );

        let response = self
            .http
            .post(&url)
            .header("X-API-Key", &config.api_key)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            return Err(CfkError::ProviderApi {
                provider: "syncthing".into(),
                message: response.text().await.unwrap_or_default(),
            });
        }

        Ok(())
    }

    /// Get local path for a virtual path
    fn get_local_path(&self, folder_id: &str, subpath: &str) -> CfkResult<PathBuf> {
        // This would need the folder cache to be populated
        // For now, return an error indicating the need for local backend
        Err(CfkError::Unsupported(format!(
            "Use LocalBackend for actual file operations on folder {} subpath {}",
            folder_id, subpath
        )))
    }

    /// Parse path into folder ID and subpath
    fn parse_path(&self, path: &VirtualPath) -> (Option<String>, String) {
        if path.segments.is_empty() {
            (None, String::new())
        } else {
            let folder_id = path.segments[0].clone();
            let subpath = if path.segments.len() > 1 {
                path.segments[1..].join("/")
            } else {
                String::new()
            };
            (Some(folder_id), subpath)
        }
    }
}

#[async_trait]
impl StorageBackend for SyncthingBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Syncthing"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        #[derive(Deserialize)]
        struct SystemStatus {
            #[serde(rename = "myID")]
            _my_id: String,
        }

        self.api_get::<SystemStatus>("system/status").await.is_ok()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() {
            // Root - return as directory
            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata: Metadata::default(),
            });
        }

        let folder_id = folder_id.unwrap();

        if subpath.is_empty() {
            // Folder root
            let status = self.get_folder_status(&folder_id).await?;

            let mut metadata = Metadata::default();
            metadata.size = Some(status.local_bytes);

            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata,
            });
        }

        // For subpaths, delegate to local backend
        Err(CfkError::Unsupported(
            "Use LocalBackend for file metadata in Syncthing folders".into(),
        ))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() {
            // List all synced folders
            self.refresh_folders().await?;

            let folders = self.folders.read().await;
            let entries: Vec<Entry> = folders
                .values()
                .map(|f| {
                    let mut metadata = Metadata::default();
                    // Use label as display name in custom metadata
                    metadata.custom
                        .insert("label".to_string(), f.label.clone());
                    metadata
                        .custom
                        .insert("type".to_string(), f.folder_type.clone());
                    metadata.custom.insert(
                        "paused".to_string(),
                        if f.paused { "true" } else { "false" }.to_string(),
                    );

                    Entry {
                        path: VirtualPath::new(&self.id, &f.id),
                        kind: EntryKind::Directory,
                        metadata,
                    }
                })
                .collect();

            return Ok(entries);
        }

        if !subpath.is_empty() {
            return Err(CfkError::Unsupported(
                "Use LocalBackend to list files in Syncthing folders".into(),
            ));
        }

        // For folder contents, we need to use the database browse API
        #[derive(Deserialize)]
        struct BrowseEntry {
            name: String,
            #[serde(rename = "type")]
            entry_type: String,
            size: Option<u64>,
            #[serde(rename = "modTime")]
            mod_time: Option<String>,
        }

        let folder_id = folder_id.unwrap();
        let entries: Vec<BrowseEntry> = self
            .api_get(&format!("db/browse?folder={}&levels=1", folder_id))
            .await?;

        let base_path = path.segments.join("/");

        Ok(entries
            .iter()
            .map(|e| {
                let path_str = if base_path.is_empty() {
                    e.name.clone()
                } else {
                    format!("{}/{}", base_path, e.name)
                };

                let kind = if e.entry_type == "d" {
                    EntryKind::Directory
                } else {
                    EntryKind::File
                };

                let mut metadata = Metadata::default();
                metadata.size = e.size;

                Entry {
                    path: VirtualPath::new(&self.id, &path_str),
                    kind,
                    metadata,
                }
            })
            .collect())
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() || subpath.is_empty() {
            return Err(CfkError::InvalidPath("Cannot read folder as file".into()));
        }

        // Syncthing doesn't provide file content via API
        // Files must be accessed through local filesystem
        Err(CfkError::Unsupported(
            "Use LocalBackend to read files in Syncthing folders".into(),
        ))
    }

    async fn write_file(&self, path: &VirtualPath, _data: Bytes) -> CfkResult<Entry> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() || subpath.is_empty() {
            return Err(CfkError::InvalidPath("Cannot write to folder".into()));
        }

        Err(CfkError::Unsupported(
            "Use LocalBackend to write files in Syncthing folders, then trigger rescan".into(),
        ))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() {
            return Err(CfkError::InvalidPath("Cannot delete root".into()));
        }

        if subpath.is_empty() {
            return Err(CfkError::Unsupported(
                "Cannot delete Syncthing folder via this API".into(),
            ));
        }

        Err(CfkError::Unsupported(
            "Use LocalBackend to delete files in Syncthing folders".into(),
        ))
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let (folder_id, subpath) = self.parse_path(path);

        if folder_id.is_none() {
            return Err(CfkError::Unsupported(
                "Create new Syncthing folder via Syncthing UI".into(),
            ));
        }

        if subpath.is_empty() {
            return Err(CfkError::AlreadyExists(path.to_string()));
        }

        Err(CfkError::Unsupported(
            "Use LocalBackend to create directories in Syncthing folders".into(),
        ))
    }

    async fn copy(&self, _from: &VirtualPath, _to: &VirtualPath) -> CfkResult<Entry> {
        Err(CfkError::Unsupported(
            "Use LocalBackend to copy files in Syncthing folders".into(),
        ))
    }

    async fn rename(&self, _from: &VirtualPath, _to: &VirtualPath) -> CfkResult<Entry> {
        Err(CfkError::Unsupported(
            "Use LocalBackend to rename files in Syncthing folders".into(),
        ))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // Sum up space from all folders
        self.refresh_folders().await?;

        let folders = self.folders.read().await;
        let mut total_bytes = 0u64;

        for folder in folders.values() {
            if let Ok(status) = self.get_folder_status(&folder.id).await {
                total_bytes += status.local_bytes;
            }
        }

        // Syncthing doesn't track quota, return local bytes as both
        Ok((total_bytes, total_bytes))
    }
}

/// Syncthing device information
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceConfig {
    pub device_id: String,
    pub name: String,
    pub addresses: Vec<String>,
    pub paused: bool,
}

/// Extension methods for Syncthing-specific operations
impl SyncthingBackend {
    /// List connected devices
    pub async fn list_devices(&self) -> CfkResult<Vec<DeviceConfig>> {
        #[derive(Deserialize)]
        struct ConfigResponse {
            devices: Vec<DeviceConfig>,
        }

        let config: ConfigResponse = self.api_get("config").await?;
        Ok(config.devices)
    }

    /// Get system connections
    pub async fn get_connections(&self) -> CfkResult<HashMap<String, ConnectionInfo>> {
        #[derive(Deserialize)]
        struct ConnectionsResponse {
            connections: HashMap<String, ConnectionInfo>,
        }

        let resp: ConnectionsResponse = self.api_get("system/connections").await?;
        Ok(resp.connections)
    }

    /// Pause syncing
    pub async fn pause(&self) -> CfkResult<()> {
        let config = self.config.read().await;
        let url = format!("{}/rest/system/pause", config.api_url);

        self.http
            .post(&url)
            .header("X-API-Key", &config.api_key)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        Ok(())
    }

    /// Resume syncing
    pub async fn resume(&self) -> CfkResult<()> {
        let config = self.config.read().await;
        let url = format!("{}/rest/system/resume", config.api_url);

        self.http
            .post(&url)
            .header("X-API-Key", &config.api_key)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        Ok(())
    }
}

/// Connection information
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionInfo {
    pub connected: bool,
    pub paused: bool,
    pub address: String,
    pub client_version: String,
    #[serde(rename = "type")]
    pub connection_type: String,
}
