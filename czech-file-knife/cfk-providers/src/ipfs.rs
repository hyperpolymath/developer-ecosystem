//! IPFS storage backend
//!
//! Content-addressed distributed file system.
//! Supports local IPFS daemon, pinning services, and MFS (Mutable File System).

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use reqwest::{multipart, Client};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

const DEFAULT_API_URL: &str = "http://127.0.0.1:5001/api/v0";
const DEFAULT_GATEWAY_URL: &str = "http://127.0.0.1:8080";

/// IPFS backend configuration
#[derive(Debug, Clone)]
pub struct IpfsConfig {
    /// IPFS API URL (default: http://127.0.0.1:5001/api/v0)
    pub api_url: String,
    /// IPFS Gateway URL (default: http://127.0.0.1:8080)
    pub gateway_url: String,
    /// Use MFS (Mutable File System) for path-based operations
    pub use_mfs: bool,
    /// Pin files after adding
    pub auto_pin: bool,
}

impl Default for IpfsConfig {
    fn default() -> Self {
        Self {
            api_url: DEFAULT_API_URL.to_string(),
            gateway_url: DEFAULT_GATEWAY_URL.to_string(),
            use_mfs: true,
            auto_pin: true,
        }
    }
}

/// IPFS storage backend
pub struct IpfsBackend {
    id: String,
    config: Arc<RwLock<IpfsConfig>>,
    http: Client,
    capabilities: StorageCapabilities,
}

impl IpfsBackend {
    pub fn new(id: impl Into<String>, config: IpfsConfig) -> Self {
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
                versioning: true, // Content-addressed = immutable versions
                sharing: true,
                streaming: true,
                resume: false,
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
        }
    }

    /// Make API POST request
    async fn api_post(&self, endpoint: &str, params: &[(&str, &str)]) -> CfkResult<String> {
        let config = self.config.read().await;
        let url = format!("{}/{}", config.api_url, endpoint);

        let mut request = self.http.post(&url);

        for (key, value) in params {
            request = request.query(&[(key, value)]);
        }

        let response = request
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "ipfs".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .text()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    /// Make API POST request with JSON response
    async fn api_post_json<T: for<'de> Deserialize<'de>>(
        &self,
        endpoint: &str,
        params: &[(&str, &str)],
    ) -> CfkResult<T> {
        let text = self.api_post(endpoint, params).await?;
        serde_json::from_str(&text).map_err(|e| CfkError::Serialization(e.to_string()))
    }

    /// Add content to IPFS
    pub async fn add(&self, data: Bytes, name: Option<&str>) -> CfkResult<AddResponse> {
        let config = self.config.read().await;
        let url = format!("{}/add", config.api_url);

        let mut params = vec![("pin", if config.auto_pin { "true" } else { "false" })];
        if let Some(n) = name {
            params.push(("path", n));
        }

        let part = multipart::Part::bytes(data.to_vec())
            .file_name(name.unwrap_or("file").to_string());
        let form = multipart::Form::new().part("file", part);

        let mut request = self.http.post(&url);
        for (key, value) in &params {
            request = request.query(&[(key, value)]);
        }

        let response = request
            .multipart(form)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "ipfs".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        let text = response
            .text()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        // IPFS returns newline-delimited JSON for directories
        let last_line = text.lines().last().unwrap_or(&text);
        serde_json::from_str(last_line).map_err(|e| CfkError::Serialization(e.to_string()))
    }

    /// Get content by CID
    pub async fn cat(&self, cid: &str) -> CfkResult<Bytes> {
        let config = self.config.read().await;
        let url = format!("{}/cat", config.api_url);

        let response = self
            .http
            .post(&url)
            .query(&[("arg", cid)])
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "ipfs".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    /// Pin a CID
    pub async fn pin(&self, cid: &str) -> CfkResult<()> {
        self.api_post("pin/add", &[("arg", cid)]).await?;
        Ok(())
    }

    /// Unpin a CID
    pub async fn unpin(&self, cid: &str) -> CfkResult<()> {
        self.api_post("pin/rm", &[("arg", cid)]).await?;
        Ok(())
    }

    /// List pinned CIDs
    pub async fn list_pins(&self) -> CfkResult<Vec<PinInfo>> {
        #[derive(Deserialize)]
        struct PinLsResponse {
            #[serde(rename = "Keys")]
            keys: std::collections::HashMap<String, PinType>,
        }

        #[derive(Deserialize)]
        struct PinType {
            #[serde(rename = "Type")]
            pin_type: String,
        }

        let resp: PinLsResponse = self.api_post_json("pin/ls", &[("type", "all")]).await?;

        Ok(resp
            .keys
            .into_iter()
            .map(|(cid, pt)| PinInfo {
                cid,
                pin_type: pt.pin_type,
            })
            .collect())
    }

    /// MFS: Write file to path
    async fn mfs_write(&self, path: &str, data: Bytes) -> CfkResult<()> {
        let config = self.config.read().await;
        let url = format!("{}/files/write", config.api_url);

        let part = multipart::Part::bytes(data.to_vec()).file_name("file");
        let form = multipart::Form::new().part("file", part);

        let response = self
            .http
            .post(&url)
            .query(&[
                ("arg", path),
                ("create", "true"),
                ("parents", "true"),
                ("truncate", "true"),
            ])
            .multipart(form)
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "ipfs".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        Ok(())
    }

    /// MFS: Read file from path
    async fn mfs_read(&self, path: &str) -> CfkResult<Bytes> {
        let config = self.config.read().await;
        let url = format!("{}/files/read", config.api_url);

        let response = self
            .http
            .post(&url)
            .query(&[("arg", path)])
            .send()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            return Err(CfkError::ProviderApi {
                provider: "ipfs".into(),
                message: format!("{}: {}", status, error_text),
            });
        }

        response
            .bytes()
            .await
            .map_err(|e| CfkError::Network(e.to_string()))
    }

    /// MFS: List directory
    async fn mfs_ls(&self, path: &str) -> CfkResult<Vec<MfsEntry>> {
        #[derive(Deserialize)]
        struct LsResponse {
            #[serde(rename = "Entries")]
            entries: Option<Vec<MfsEntry>>,
        }

        let resp: LsResponse = self
            .api_post_json("files/ls", &[("arg", path), ("long", "true")])
            .await?;

        Ok(resp.entries.unwrap_or_default())
    }

    /// MFS: Get file/directory stat
    async fn mfs_stat(&self, path: &str) -> CfkResult<MfsStat> {
        self.api_post_json("files/stat", &[("arg", path)]).await
    }

    /// MFS: Create directory
    async fn mfs_mkdir(&self, path: &str) -> CfkResult<()> {
        self.api_post("files/mkdir", &[("arg", path), ("parents", "true")])
            .await?;
        Ok(())
    }

    /// MFS: Remove file/directory
    async fn mfs_rm(&self, path: &str, recursive: bool) -> CfkResult<()> {
        self.api_post(
            "files/rm",
            &[("arg", path), ("recursive", if recursive { "true" } else { "false" })],
        )
        .await?;
        Ok(())
    }

    /// MFS: Copy
    async fn mfs_cp(&self, from: &str, to: &str) -> CfkResult<()> {
        self.api_post("files/cp", &[("arg", from), ("arg", to)])
            .await?;
        Ok(())
    }

    /// MFS: Move
    async fn mfs_mv(&self, from: &str, to: &str) -> CfkResult<()> {
        self.api_post("files/mv", &[("arg", from), ("arg", to)])
            .await?;
        Ok(())
    }

    /// Convert VirtualPath to MFS path
    fn to_mfs_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            "/".to_string()
        } else {
            format!("/{}", path.segments.join("/"))
        }
    }
}

/// IPFS add response
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct AddResponse {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Hash")]
    pub hash: String,
    #[serde(rename = "Size")]
    pub size: String,
}

/// Pin information
#[derive(Debug, Clone)]
pub struct PinInfo {
    pub cid: String,
    pub pin_type: String,
}

/// MFS directory entry
#[derive(Debug, Clone, Deserialize)]
pub struct MfsEntry {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Type")]
    pub entry_type: u8,
    #[serde(rename = "Size")]
    pub size: u64,
    #[serde(rename = "Hash")]
    pub hash: String,
}

/// MFS stat response
#[derive(Debug, Clone, Deserialize)]
pub struct MfsStat {
    #[serde(rename = "Hash")]
    pub hash: String,
    #[serde(rename = "Size")]
    pub size: u64,
    #[serde(rename = "CumulativeSize")]
    pub cumulative_size: u64,
    #[serde(rename = "Type")]
    pub entry_type: String,
}

#[async_trait]
impl StorageBackend for IpfsBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "IPFS"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        #[derive(Deserialize)]
        struct IdResponse {
            #[serde(rename = "ID")]
            _id: String,
        }

        self.api_post_json::<IdResponse>("id", &[]).await.is_ok()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            let stat = self.mfs_stat(&mfs_path).await?;

            let kind = if stat.entry_type == "directory" {
                EntryKind::Directory
            } else {
                EntryKind::File
            };

            let mut metadata = Metadata::default();
            metadata.size = Some(stat.size);
            metadata.checksum = Some(stat.hash);

            return Ok(Entry {
                path: path.clone(),
                kind,
                metadata,
            });
        }

        // For CID-based paths
        if path.segments.is_empty() {
            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata: Metadata::default(),
            });
        }

        // Assume first segment is CID
        let cid = &path.segments[0];

        #[derive(Deserialize)]
        struct ObjectStat {
            #[serde(rename = "Hash")]
            hash: String,
            #[serde(rename = "NumLinks")]
            num_links: u64,
            #[serde(rename = "DataSize")]
            data_size: u64,
            #[serde(rename = "CumulativeSize")]
            cumulative_size: u64,
        }

        let stat: ObjectStat = self.api_post_json("object/stat", &[("arg", cid)]).await?;

        let kind = if stat.num_links > 0 {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = Some(stat.cumulative_size);
        metadata.checksum = Some(stat.hash);

        Ok(Entry {
            path: path.clone(),
            kind,
            metadata,
        })
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            let entries = self.mfs_ls(&mfs_path).await?;

            let base_path = if path.segments.is_empty() {
                String::new()
            } else {
                format!("{}/", path.segments.join("/"))
            };

            return Ok(entries
                .iter()
                .map(|e| {
                    let kind = if e.entry_type == 1 {
                        EntryKind::Directory
                    } else {
                        EntryKind::File
                    };

                    let mut metadata = Metadata::default();
                    metadata.size = Some(e.size);
                    metadata.checksum = Some(e.hash.clone());

                    Entry {
                        path: VirtualPath::new(&self.id, &format!("{}{}", base_path, e.name)),
                        kind,
                        metadata,
                    }
                })
                .collect());
        }

        // For non-MFS, list pins at root
        if path.segments.is_empty() {
            let pins = self.list_pins().await?;

            return Ok(pins
                .iter()
                .map(|p| {
                    let mut metadata = Metadata::default();
                    metadata.custom.insert("pin_type".to_string(), p.pin_type.clone());

                    Entry {
                        path: VirtualPath::new(&self.id, &p.cid),
                        kind: EntryKind::File, // Assume file, could be directory
                        metadata,
                    }
                })
                .collect());
        }

        // List IPFS directory by CID
        let cid = &path.segments[0];

        #[derive(Deserialize)]
        struct LsResponse {
            #[serde(rename = "Objects")]
            objects: Vec<LsObject>,
        }

        #[derive(Deserialize)]
        struct LsObject {
            #[serde(rename = "Links")]
            links: Vec<LsLink>,
        }

        #[derive(Deserialize)]
        struct LsLink {
            #[serde(rename = "Name")]
            name: String,
            #[serde(rename = "Hash")]
            hash: String,
            #[serde(rename = "Size")]
            size: u64,
            #[serde(rename = "Type")]
            link_type: u64,
        }

        let resp: LsResponse = self.api_post_json("ls", &[("arg", cid)]).await?;

        let links = resp
            .objects
            .first()
            .map(|o| &o.links)
            .cloned()
            .unwrap_or_default();

        let base_path = path.segments.join("/");

        Ok(links
            .iter()
            .map(|l| {
                let kind = if l.link_type == 1 {
                    EntryKind::Directory
                } else {
                    EntryKind::File
                };

                let mut metadata = Metadata::default();
                metadata.size = Some(l.size);
                metadata.checksum = Some(l.hash.clone());

                Entry {
                    path: VirtualPath::new(&self.id, &format!("{}/{}", base_path, l.name)),
                    kind,
                    metadata,
                }
            })
            .collect())
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            return self.mfs_read(&mfs_path).await;
        }

        // Read by CID
        if path.segments.is_empty() {
            return Err(CfkError::InvalidPath("No CID specified".into()));
        }

        let cid = path.segments.join("/");
        self.cat(&cid).await
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            self.mfs_write(&mfs_path, data).await?;

            // Get updated metadata
            let stat = self.mfs_stat(&mfs_path).await?;

            let mut metadata = Metadata::default();
            metadata.size = Some(stat.size);
            metadata.checksum = Some(stat.hash);

            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::File,
                metadata,
            });
        }

        // Add to IPFS and return the CID path
        let name = path.segments.last().map(String::as_str);
        let add_resp = self.add(data, name).await?;

        let mut metadata = Metadata::default();
        metadata.size = Some(add_resp.size.parse().unwrap_or(0));
        metadata.checksum = Some(add_resp.hash.clone());

        Ok(Entry {
            path: VirtualPath::new(&self.id, &add_resp.hash),
            kind: EntryKind::File,
            metadata,
        })
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            return self.mfs_rm(&mfs_path, true).await;
        }

        // For CID paths, unpin
        if !path.segments.is_empty() {
            let cid = &path.segments[0];
            return self.unpin(cid).await;
        }

        Err(CfkError::InvalidPath("Cannot delete root".into()))
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let config = self.config.read().await;

        if config.use_mfs {
            let mfs_path = self.to_mfs_path(path);
            self.mfs_mkdir(&mfs_path).await?;

            let stat = self.mfs_stat(&mfs_path).await?;

            let mut metadata = Metadata::default();
            metadata.checksum = Some(stat.hash);

            return Ok(Entry {
                path: path.clone(),
                kind: EntryKind::Directory,
                metadata,
            });
        }

        Err(CfkError::Unsupported(
            "Cannot create directory without MFS enabled".into(),
        ))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let config = self.config.read().await;

        if config.use_mfs {
            let from_path = self.to_mfs_path(from);
            let to_path = self.to_mfs_path(to);
            self.mfs_cp(&from_path, &to_path).await?;

            return self.get_metadata(to).await;
        }

        Err(CfkError::Unsupported("Copy requires MFS enabled".into()))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let config = self.config.read().await;

        if config.use_mfs {
            let from_path = self.to_mfs_path(from);
            let to_path = self.to_mfs_path(to);
            self.mfs_mv(&from_path, &to_path).await?;

            return self.get_metadata(to).await;
        }

        Err(CfkError::Unsupported("Rename requires MFS enabled".into()))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        #[derive(Deserialize)]
        struct RepoStat {
            #[serde(rename = "RepoSize")]
            repo_size: u64,
            #[serde(rename = "StorageMax")]
            storage_max: u64,
        }

        let stat: RepoStat = self.api_post_json("repo/stat", &[]).await?;

        let available = stat.storage_max.saturating_sub(stat.repo_size);
        Ok((available, stat.storage_max))
    }
}

/// Additional IPFS-specific operations
impl IpfsBackend {
    /// Resolve IPNS name to CID
    pub async fn resolve_ipns(&self, name: &str) -> CfkResult<String> {
        #[derive(Deserialize)]
        struct ResolveResponse {
            #[serde(rename = "Path")]
            path: String,
        }

        let resp: ResolveResponse = self
            .api_post_json("name/resolve", &[("arg", name)])
            .await?;

        Ok(resp.path)
    }

    /// Publish to IPNS
    pub async fn publish_ipns(&self, cid: &str) -> CfkResult<String> {
        #[derive(Deserialize)]
        struct PublishResponse {
            #[serde(rename = "Name")]
            name: String,
            #[serde(rename = "Value")]
            value: String,
        }

        let resp: PublishResponse = self
            .api_post_json("name/publish", &[("arg", cid)])
            .await?;

        Ok(resp.name)
    }

    /// Get peer information
    pub async fn swarm_peers(&self) -> CfkResult<Vec<String>> {
        #[derive(Deserialize)]
        struct SwarmPeersResponse {
            #[serde(rename = "Peers")]
            peers: Option<Vec<PeerInfo>>,
        }

        #[derive(Deserialize)]
        struct PeerInfo {
            #[serde(rename = "Peer")]
            peer: String,
        }

        let resp: SwarmPeersResponse = self.api_post_json("swarm/peers", &[]).await?;

        Ok(resp
            .peers
            .unwrap_or_default()
            .into_iter()
            .map(|p| p.peer)
            .collect())
    }

    /// Garbage collect unpinned blocks
    pub async fn repo_gc(&self) -> CfkResult<()> {
        self.api_post("repo/gc", &[]).await?;
        Ok(())
    }
}
