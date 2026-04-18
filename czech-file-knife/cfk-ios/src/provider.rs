// SPDX-License-Identifier: AGPL-3.0-or-later
//! File Provider Manager
//!
//! Coordinates between iOS File Provider and CFK backends.

use crate::domain::{DomainIdentifier, DomainManager, FileDomain};
use crate::error::{IosError, IosResult};
use crate::item::{EnumerationPage, FileProviderItem, ItemIdentifier};
use bytes::Bytes;
use cfk_core::backend::{ByteStream, SpaceInfo};
use cfk_core::entry::DirectoryListing;
use cfk_core::operations::{
    CopyOptions, DeleteOptions, ListOptions, MoveOptions, ReadOptions, WriteOptions,
};
use cfk_core::{Entry, StorageBackend, StorageCapabilities, VirtualPath};
use futures::StreamExt;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Placeholder backend for when real backends aren't available
struct PlaceholderBackend {
    id: String,
}

#[async_trait::async_trait]
impl StorageBackend for PlaceholderBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "Placeholder"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        static CAPS: StorageCapabilities = StorageCapabilities {
            read: false,
            write: false,
            delete: false,
            rename: false,
            copy: false,
            list: false,
            search: false,
            versioning: false,
            sharing: false,
            offline: false,
            streaming: false,
            resumable_uploads: false,
            content_hashing: false,
        };
        &CAPS
    }

    async fn is_available(&self) -> bool {
        false
    }

    async fn get_metadata(&self, _path: &VirtualPath) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn list_directory(
        &self,
        _path: &VirtualPath,
        _options: &ListOptions,
    ) -> cfk_core::CfkResult<DirectoryListing> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn read_file(
        &self,
        _path: &VirtualPath,
        _options: &ReadOptions,
    ) -> cfk_core::CfkResult<ByteStream> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn write_file(
        &self,
        _path: &VirtualPath,
        _data: Bytes,
        _options: &WriteOptions,
    ) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn write_file_stream(
        &self,
        _path: &VirtualPath,
        _stream: ByteStream,
        _size_hint: Option<u64>,
        _options: &WriteOptions,
    ) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn delete(
        &self,
        _path: &VirtualPath,
        _options: &DeleteOptions,
    ) -> cfk_core::CfkResult<()> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn create_directory(&self, _path: &VirtualPath) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn copy(
        &self,
        _from: &VirtualPath,
        _to: &VirtualPath,
        _options: &CopyOptions,
    ) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn rename(
        &self,
        _from: &VirtualPath,
        _to: &VirtualPath,
        _options: &MoveOptions,
    ) -> cfk_core::CfkResult<Entry> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }

    async fn get_space_info(&self) -> cfk_core::CfkResult<SpaceInfo> {
        Err(cfk_core::CfkError::Unsupported("Placeholder backend".into()))
    }
}

/// File Provider Manager
///
/// Main entry point for iOS File Provider operations.
pub struct FileProviderManager {
    /// Domain manager
    domains: Arc<DomainManager>,
    /// Active backends
    backends: Arc<RwLock<HashMap<DomainIdentifier, Arc<dyn StorageBackend>>>>,
    /// Local cache directory
    cache_dir: PathBuf,
    /// Temporary file directory
    temp_dir: PathBuf,
}

impl FileProviderManager {
    /// Create a new manager
    pub fn new(
        storage_path: impl Into<PathBuf>,
        cache_dir: impl Into<PathBuf>,
        temp_dir: impl Into<PathBuf>,
    ) -> Self {
        Self {
            domains: Arc::new(DomainManager::new(storage_path)),
            backends: Arc::new(RwLock::new(HashMap::new())),
            cache_dir: cache_dir.into(),
            temp_dir: temp_dir.into(),
        }
    }

    /// Initialize the manager
    pub async fn initialize(&self) -> IosResult<()> {
        // Load saved domains
        self.domains.load().await?;

        // Create cache/temp directories
        tokio::fs::create_dir_all(&self.cache_dir)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

        tokio::fs::create_dir_all(&self.temp_dir)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

        // Initialize backends for enabled domains
        for domain in self.domains.list_enabled().await {
            if let Err(e) = self.init_backend(&domain).await {
                tracing::warn!("Failed to init backend for {}: {}", domain.identifier.0, e);
            }
        }

        Ok(())
    }

    /// Initialize a backend for a domain
    async fn init_backend(&self, domain: &FileDomain) -> IosResult<()> {
        // In a full implementation, this would create the appropriate backend
        // based on domain.backend_type and domain.config_json
        let backend: Arc<dyn StorageBackend> = Arc::new(PlaceholderBackend {
            id: domain.identifier.0.clone(),
        });

        self.backends
            .write()
            .await
            .insert(domain.identifier.clone(), backend);

        Ok(())
    }

    /// Get backend for a domain
    async fn get_backend(
        &self,
        domain_id: &DomainIdentifier,
    ) -> IosResult<Arc<dyn StorageBackend>> {
        self.backends
            .read()
            .await
            .get(domain_id)
            .cloned()
            .ok_or_else(|| IosError::NotFound(format!("Backend not found: {}", domain_id.0)))
    }

    // --- Domain Management ---

    /// Add a new domain
    pub async fn add_domain(&self, domain: FileDomain) -> IosResult<()> {
        self.domains.add(domain.clone()).await?;
        if domain.enabled {
            self.init_backend(&domain).await?;
        }
        Ok(())
    }

    /// Remove a domain
    pub async fn remove_domain(&self, id: &DomainIdentifier) -> IosResult<()> {
        self.domains.remove(id).await?;
        self.backends.write().await.remove(id);
        Ok(())
    }

    /// List all domains
    pub async fn list_domains(&self) -> Vec<FileDomain> {
        self.domains.list().await
    }

    // --- Item Operations ---

    /// Get item for identifier
    pub async fn item(&self, identifier: &ItemIdentifier) -> IosResult<FileProviderItem> {
        if identifier.is_root() {
            // Return root item
            return Ok(FileProviderItem::root(
                &DomainIdentifier::new("default"),
                "Root",
            ));
        }

        let (domain_id, path_str) = identifier
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(identifier.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        let entry = backend
            .get_metadata(&path)
            .await
            .map_err(IosError::Core)?;

        // Determine parent
        let parent = if path.segments.is_empty() {
            ItemIdentifier::root()
        } else {
            let mut parent_path = path.clone();
            parent_path.segments.pop();
            ItemIdentifier::from_path(&domain_id, &parent_path)
        };

        Ok(FileProviderItem::from_entry(&domain_id, &entry, &parent))
    }

    /// Enumerate items in a container
    pub async fn enumerate_items(
        &self,
        container: &ItemIdentifier,
        _page_token: Option<&str>,
    ) -> IosResult<EnumerationPage> {
        if container.is_root() {
            // List domains as root items
            let domains = self.domains.list_enabled().await;
            let items: Vec<FileProviderItem> = domains
                .iter()
                .map(|d| {
                    let mut item = FileProviderItem::root(&d.identifier, &d.display_name);
                    item.identifier = ItemIdentifier(d.identifier.0.clone() + ":/");
                    item.parent_identifier = ItemIdentifier::root();
                    item
                })
                .collect();

            return Ok(EnumerationPage::new(items));
        }

        let (domain_id, path_str) = container
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(container.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        let listing = backend
            .list_directory(&path, &ListOptions::default())
            .await
            .map_err(IosError::Core)?;

        let items: Vec<FileProviderItem> = listing
            .entries
            .iter()
            .map(|e| FileProviderItem::from_entry(&domain_id, e, container))
            .collect();

        Ok(EnumerationPage::new(items))
    }

    /// Fetch contents of a file
    pub async fn fetch_contents(&self, identifier: &ItemIdentifier) -> IosResult<PathBuf> {
        let (domain_id, path_str) = identifier
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(identifier.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        let mut stream = backend
            .read_file(&path, &ReadOptions::default())
            .await
            .map_err(IosError::Core)?;

        // Collect stream into bytes
        let mut data = Vec::new();
        while let Some(chunk_result) = stream.next().await {
            let chunk = chunk_result.map_err(IosError::Core)?;
            data.extend_from_slice(&chunk);
        }

        // Write to cache
        let cache_path = self.cache_dir.join(&identifier.0.replace([':', '/'], "_"));
        tokio::fs::write(&cache_path, &data)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

        Ok(cache_path)
    }

    /// Create a new item
    pub async fn create_item(
        &self,
        parent: &ItemIdentifier,
        filename: &str,
        item_type: u32,
        contents: Option<&[u8]>,
    ) -> IosResult<FileProviderItem> {
        let (domain_id, parent_path_str) = parent
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(parent.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let parent_path =
            VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, parent_path_str))
                .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &parent_path_str));

        let item_path = parent_path.join(filename);

        let entry = if item_type == 1 {
            // Directory
            backend
                .create_directory(&item_path)
                .await
                .map_err(IosError::Core)?
        } else {
            // File
            let data = contents.map(Bytes::copy_from_slice).unwrap_or_default();
            backend
                .write_file(&item_path, data, &WriteOptions::default())
                .await
                .map_err(IosError::Core)?
        };

        Ok(FileProviderItem::from_entry(&domain_id, &entry, parent))
    }

    /// Modify item contents
    pub async fn modify_item(
        &self,
        identifier: &ItemIdentifier,
        contents: &[u8],
    ) -> IosResult<FileProviderItem> {
        let (domain_id, path_str) = identifier
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(identifier.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        let entry = backend
            .write_file(&path, Bytes::copy_from_slice(contents), &WriteOptions::default())
            .await
            .map_err(IosError::Core)?;

        // Determine parent
        let parent = if path.segments.len() <= 1 {
            ItemIdentifier::root()
        } else {
            let mut parent_path = path.clone();
            parent_path.segments.pop();
            ItemIdentifier::from_path(&domain_id, &parent_path)
        };

        Ok(FileProviderItem::from_entry(&domain_id, &entry, &parent))
    }

    /// Delete an item
    pub async fn delete_item(&self, identifier: &ItemIdentifier) -> IosResult<()> {
        let (domain_id, path_str) = identifier
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(identifier.0.clone()))?;

        let backend = self.get_backend(&domain_id).await?;
        let path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        backend
            .delete(&path, &DeleteOptions::default())
            .await
            .map_err(IosError::Core)?;

        // Remove from cache
        let cache_path = self.cache_dir.join(&identifier.0.replace([':', '/'], "_"));
        let _ = tokio::fs::remove_file(&cache_path).await;

        Ok(())
    }

    /// Rename/move an item
    pub async fn reparent_item(
        &self,
        identifier: &ItemIdentifier,
        new_parent: &ItemIdentifier,
        new_name: Option<&str>,
    ) -> IosResult<FileProviderItem> {
        let (domain_id, path_str) = identifier
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(identifier.0.clone()))?;

        let (new_domain_id, new_parent_path_str) = new_parent
            .parse()
            .ok_or_else(|| IosError::InvalidIdentifier(new_parent.0.clone()))?;

        if domain_id != new_domain_id {
            return Err(IosError::NotSupported(
                "Cross-domain move not supported".into(),
            ));
        }

        let backend = self.get_backend(&domain_id).await?;
        let from_path = VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, path_str))
            .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &path_str));

        let new_parent_path =
            VirtualPath::parse_uri(&format!("cfk://{}/{}", domain_id.0, new_parent_path_str))
                .unwrap_or_else(|| VirtualPath::new(&domain_id.0, &new_parent_path_str));

        let new_name = new_name.unwrap_or_else(|| {
            from_path.segments.last().map(|s| s.as_str()).unwrap_or("")
        });

        let to_path = new_parent_path.join(new_name);

        let entry = backend
            .rename(&from_path, &to_path, &MoveOptions::default())
            .await
            .map_err(IosError::Core)?;

        Ok(FileProviderItem::from_entry(&domain_id, &entry, new_parent))
    }

    /// Get storage space info for a domain
    pub async fn space_info(&self, domain_id: &DomainIdentifier) -> IosResult<(u64, u64)> {
        let backend = self.get_backend(domain_id).await?;
        let info = backend.get_space_info().await.map_err(IosError::Core)?;
        Ok((info.total.unwrap_or(0), info.used.unwrap_or(0)))
    }

    /// Evict item from local cache
    pub async fn evict_item(&self, identifier: &ItemIdentifier) -> IosResult<()> {
        let cache_path = self.cache_dir.join(&identifier.0.replace([':', '/'], "_"));
        tokio::fs::remove_file(&cache_path)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;
        Ok(())
    }
}
