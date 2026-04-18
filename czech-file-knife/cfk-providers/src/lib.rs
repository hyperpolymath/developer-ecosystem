//! Storage providers for Czech File Knife
//!
//! Supports 15+ backends: local, cloud, distributed, and exotic filesystems.
//! Plus exotic protocols: Gopher, Gemini, NNTP, RTSP, BitTorrent, etc.
//! Transport layers: TCP, QUIC, UDP, Unix sockets.

mod local;
pub mod protocols;
pub mod transport;

#[cfg(feature = "dropbox")]
pub mod dropbox;

#[cfg(feature = "gdrive")]
pub mod gdrive;

#[cfg(feature = "onedrive")]
pub mod onedrive;

#[cfg(feature = "box")]
pub mod box_com;

#[cfg(feature = "s3")]
pub mod s3;

#[cfg(feature = "ipfs")]
pub mod ipfs;

#[cfg(feature = "webdav")]
pub mod webdav;

#[cfg(feature = "afs")]
pub mod afs;

#[cfg(feature = "ninep")]
pub mod ninep;

#[cfg(feature = "sftp")]
pub mod sftp;

#[cfg(feature = "nfs")]
pub mod nfs;

#[cfg(feature = "smb")]
pub mod smb;

#[cfg(feature = "syncthing")]
pub mod syncthing;

#[cfg(feature = "ceph")]
pub mod ceph;

pub use local::LocalBackend;

// Re-export provider types when features are enabled
#[cfg(feature = "dropbox")]
pub use dropbox::{DropboxBackend, DropboxConfig, DropboxTokens};

#[cfg(feature = "gdrive")]
pub use gdrive::{GoogleDriveBackend, GoogleDriveConfig, GoogleTokens};

#[cfg(feature = "onedrive")]
pub use onedrive::{OneDriveBackend, OneDriveConfig, OneDriveTokens};

#[cfg(feature = "box")]
pub use box_com::{BoxBackend, BoxConfig, BoxTokens};

#[cfg(feature = "s3")]
pub use s3::{S3Backend, S3Config};

#[cfg(feature = "ipfs")]
pub use ipfs::{IpfsBackend, IpfsConfig};

#[cfg(feature = "webdav")]
pub use webdav::{WebDavBackend, WebDavConfig, WebDavAuth};

#[cfg(feature = "afs")]
pub use afs::{AfsBackend, AfsConfig};

#[cfg(feature = "ninep")]
pub use ninep::{NinePBackend, NinePConfig};

#[cfg(feature = "sftp")]
pub use sftp::{SftpBackend, SftpConfig, SftpAuth};

#[cfg(feature = "nfs")]
pub use nfs::{NfsBackend, NfsConfig, NfsVersion};

#[cfg(feature = "smb")]
pub use smb::{SmbBackend, SmbConfig, SmbVersion, SmbAuth};

#[cfg(feature = "syncthing")]
pub use syncthing::{SyncthingBackend, SyncthingConfig};

#[cfg(feature = "ceph")]
pub use ceph::{CephBackend, CephConfig, CephMode};

use cfk_core::{StorageBackend, CfkResult, CfkError};
use std::collections::HashMap;
use std::sync::Arc;

/// Registry of storage backends
pub struct BackendRegistry {
    backends: HashMap<String, Arc<dyn StorageBackend>>,
}

impl BackendRegistry {
    pub fn new() -> Self {
        Self { backends: HashMap::new() }
    }

    pub fn register(&mut self, backend: Arc<dyn StorageBackend>) {
        self.backends.insert(backend.id().to_string(), backend);
    }

    pub fn get(&self, id: &str) -> Option<Arc<dyn StorageBackend>> {
        self.backends.get(id).cloned()
    }

    pub fn get_or_err(&self, id: &str) -> CfkResult<Arc<dyn StorageBackend>> {
        self.get(id).ok_or_else(|| CfkError::BackendNotFound(id.to_string()))
    }

    pub fn list(&self) -> Vec<&str> {
        self.backends.keys().map(|s| s.as_str()).collect()
    }

    pub fn remove(&mut self, id: &str) -> Option<Arc<dyn StorageBackend>> {
        self.backends.remove(id)
    }
}

impl Default for BackendRegistry {
    fn default() -> Self {
        Self::new()
    }
}
