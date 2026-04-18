//! Storage backend trait

use async_trait::async_trait;
use bytes::Bytes;
use std::pin::Pin;
use futures::Stream;

use crate::{
    entry::{DirectoryListing, Entry},
    error::CfkResult,
    operations::*,
    VirtualPath,
};

/// Byte stream type
pub type ByteStream = Pin<Box<dyn Stream<Item = CfkResult<Bytes>> + Send>>;

/// Storage backend capabilities
#[derive(Debug, Clone, Default)]
pub struct StorageCapabilities {
    pub read: bool,
    pub write: bool,
    pub delete: bool,
    pub rename: bool,
    pub copy: bool,
    pub list: bool,
    pub search: bool,
    pub versioning: bool,
    pub sharing: bool,
    pub offline: bool,
    pub streaming: bool,
    pub resumable_uploads: bool,
    pub content_hashing: bool,
}

impl StorageCapabilities {
    pub fn full() -> Self {
        Self {
            read: true, write: true, delete: true, rename: true,
            copy: true, list: true, search: true, versioning: true,
            sharing: true, offline: true, streaming: true,
            resumable_uploads: true, content_hashing: true,
        }
    }

    pub fn read_only() -> Self {
        Self { read: true, list: true, ..Default::default() }
    }

    pub fn local_filesystem() -> Self {
        Self {
            read: true, write: true, delete: true, rename: true,
            copy: true, list: true, search: true, offline: true,
            streaming: true, content_hashing: true,
            ..Default::default()
        }
    }
}

/// Space information
#[derive(Debug, Clone, Default)]
pub struct SpaceInfo {
    pub total: Option<u64>,
    pub used: Option<u64>,
    pub available: Option<u64>,
}

impl SpaceInfo {
    pub fn unknown() -> Self {
        Self::default()
    }
}

/// File version information
#[derive(Debug, Clone)]
pub struct FileVersion {
    pub id: String,
    pub modified: chrono::DateTime<chrono::Utc>,
    pub size: Option<u64>,
    pub author: Option<String>,
}

/// Search options
#[derive(Debug, Clone, Default)]
pub struct SearchOptions {
    pub query: String,
    pub path: Option<VirtualPath>,
    pub recursive: bool,
    pub limit: Option<usize>,
}

/// Storage backend trait
#[async_trait]
pub trait StorageBackend: Send + Sync {
    fn id(&self) -> &str;
    fn display_name(&self) -> &str;
    fn capabilities(&self) -> &StorageCapabilities;

    async fn is_available(&self) -> bool;
    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry>;
    async fn list_directory(&self, path: &VirtualPath, options: &ListOptions) -> CfkResult<DirectoryListing>;
    async fn read_file(&self, path: &VirtualPath, options: &ReadOptions) -> CfkResult<ByteStream>;
    async fn write_file(&self, path: &VirtualPath, data: Bytes, options: &WriteOptions) -> CfkResult<Entry>;
    async fn write_file_stream(&self, path: &VirtualPath, stream: ByteStream, size_hint: Option<u64>, options: &WriteOptions) -> CfkResult<Entry>;
    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry>;
    async fn delete(&self, path: &VirtualPath, options: &DeleteOptions) -> CfkResult<()>;
    async fn copy(&self, source: &VirtualPath, dest: &VirtualPath, options: &CopyOptions) -> CfkResult<Entry>;
    async fn rename(&self, source: &VirtualPath, dest: &VirtualPath, options: &MoveOptions) -> CfkResult<Entry>;
    async fn get_space_info(&self) -> CfkResult<SpaceInfo>;

    // Optional methods with defaults
    async fn search(&self, _options: &SearchOptions) -> CfkResult<Vec<Entry>> {
        Err(crate::CfkError::Unsupported("Search not supported".into()))
    }

    async fn get_versions(&self, _path: &VirtualPath) -> CfkResult<Vec<FileVersion>> {
        Err(crate::CfkError::Unsupported("Versioning not supported".into()))
    }

    async fn get_version(&self, _path: &VirtualPath, _version_id: &str) -> CfkResult<ByteStream> {
        Err(crate::CfkError::Unsupported("Versioning not supported".into()))
    }
}
