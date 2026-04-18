// SPDX-License-Identifier: AGPL-3.0-or-later
//! File Provider Item representation
//!
//! Maps to NSFileProviderItem in iOS.

use crate::domain::DomainIdentifier;
use crate::error::{IosError, IosResult};
use cfk_core::{Entry, EntryKind, VirtualPath};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Item identifier (opaque string)
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ItemIdentifier(pub String);

impl ItemIdentifier {
    /// Root container identifier
    pub fn root() -> Self {
        Self("root".to_string())
    }

    /// Working set identifier
    pub fn working_set() -> Self {
        Self(".workingset".to_string())
    }

    /// Trash identifier
    pub fn trash() -> Self {
        Self(".trash".to_string())
    }

    /// Create from domain and path
    pub fn from_path(domain: &DomainIdentifier, path: &VirtualPath) -> Self {
        Self(format!("{}:{}", domain.0, path))
    }

    /// Parse into domain and path
    pub fn parse(&self) -> Option<(DomainIdentifier, String)> {
        let parts: Vec<&str> = self.0.splitn(2, ':').collect();
        if parts.len() == 2 {
            Some((DomainIdentifier::new(parts[0]), parts[1].to_string()))
        } else {
            None
        }
    }

    /// Check if this is a special identifier
    pub fn is_special(&self) -> bool {
        self.0.starts_with('.')
    }

    /// Check if this is the root
    pub fn is_root(&self) -> bool {
        self.0 == "root"
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Item type flags
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemType {
    File = 0,
    Directory = 1,
    Symlink = 2,
    Package = 3,  // macOS/iOS package (folder displayed as file)
    Unknown = 255,
}

impl From<EntryKind> for ItemType {
    fn from(kind: EntryKind) -> Self {
        match kind {
            EntryKind::File => ItemType::File,
            EntryKind::Directory => ItemType::Directory,
            EntryKind::Symlink => ItemType::Symlink,
            EntryKind::Unknown => ItemType::Unknown,
        }
    }
}

/// Item capabilities (what operations are allowed)
#[derive(Debug, Clone, Copy)]
pub struct ItemCapabilities(pub u64);

impl ItemCapabilities {
    pub const READING: u64 = 1 << 0;
    pub const WRITING: u64 = 1 << 1;
    pub const REPARENTING: u64 = 1 << 2;   // Can be moved
    pub const RENAMING: u64 = 1 << 3;
    pub const TRASHING: u64 = 1 << 4;
    pub const DELETING: u64 = 1 << 5;
    pub const EVICTING: u64 = 1 << 6;      // Can be removed from local storage
    pub const ADDING_SUBITEM: u64 = 1 << 7;
    pub const CONTENT_ENUMERATION: u64 = 1 << 8;
    pub const PLAYING: u64 = 1 << 9;

    /// Default capabilities for a file
    pub fn file_default() -> Self {
        Self(
            Self::READING
                | Self::WRITING
                | Self::REPARENTING
                | Self::RENAMING
                | Self::TRASHING
                | Self::DELETING
                | Self::EVICTING,
        )
    }

    /// Default capabilities for a directory
    pub fn directory_default() -> Self {
        Self(
            Self::READING
                | Self::REPARENTING
                | Self::RENAMING
                | Self::TRASHING
                | Self::DELETING
                | Self::ADDING_SUBITEM
                | Self::CONTENT_ENUMERATION,
        )
    }

    /// Read-only capabilities
    pub fn read_only() -> Self {
        Self(Self::READING | Self::EVICTING | Self::CONTENT_ENUMERATION)
    }
}

/// File Provider Item
///
/// Represents a file or folder in the File Provider.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileProviderItem {
    /// Unique identifier
    pub identifier: ItemIdentifier,
    /// Parent identifier
    pub parent_identifier: ItemIdentifier,
    /// Filename (not full path)
    pub filename: String,
    /// Item type
    pub item_type: u32,
    /// File size (for files)
    pub size: Option<u64>,
    /// Creation date
    pub creation_date: Option<DateTime<Utc>>,
    /// Modification date
    pub content_modification_date: Option<DateTime<Utc>>,
    /// Content type (UTI)
    pub content_type: Option<String>,
    /// Capabilities
    pub capabilities: u64,
    /// Whether downloaded
    pub is_downloaded: bool,
    /// Whether downloading
    pub is_downloading: bool,
    /// Whether uploaded
    pub is_uploaded: bool,
    /// Whether uploading
    pub is_uploading: bool,
    /// Download progress (0.0 - 1.0)
    pub download_progress: f64,
    /// Upload progress (0.0 - 1.0)
    pub upload_progress: f64,
    /// Version identifier (for conflict resolution)
    pub version_identifier: Option<String>,
    /// Content checksum
    pub checksum: Option<String>,
    /// Favorite status
    pub is_favorite: bool,
    /// Tag data
    pub tag_data: Option<Vec<u8>>,
    /// Custom metadata
    #[serde(default)]
    pub user_info: HashMap<String, String>,
}

impl FileProviderItem {
    /// Create from cfk_core Entry
    pub fn from_entry(
        domain: &DomainIdentifier,
        entry: &Entry,
        parent: &ItemIdentifier,
    ) -> Self {
        let filename = entry
            .path
            .segments
            .last()
            .cloned()
            .unwrap_or_else(|| entry.path.backend.clone());

        let item_type: ItemType = entry.kind.into();
        let capabilities = match entry.kind {
            EntryKind::Directory => ItemCapabilities::directory_default(),
            _ => ItemCapabilities::file_default(),
        };

        let content_type = entry.metadata.mime_type.clone().or_else(|| {
            // Guess from filename
            if filename.ends_with(".txt") {
                Some("public.plain-text".to_string())
            } else if filename.ends_with(".pdf") {
                Some("com.adobe.pdf".to_string())
            } else if filename.ends_with(".jpg") || filename.ends_with(".jpeg") {
                Some("public.jpeg".to_string())
            } else if filename.ends_with(".png") {
                Some("public.png".to_string())
            } else {
                Some("public.data".to_string())
            }
        });

        Self {
            identifier: ItemIdentifier::from_path(domain, &entry.path),
            parent_identifier: parent.clone(),
            filename,
            item_type: item_type as u32,
            size: entry.metadata.size,
            creation_date: entry.metadata.created,
            content_modification_date: entry.metadata.modified,
            content_type,
            capabilities: capabilities.0,
            is_downloaded: false,
            is_downloading: false,
            is_uploaded: true,
            is_uploading: false,
            download_progress: 0.0,
            upload_progress: 1.0,
            version_identifier: entry.metadata.content_hash.clone(),
            checksum: entry.metadata.content_hash.clone(),
            is_favorite: false,
            tag_data: None,
            user_info: entry.metadata.custom.clone(),
        }
    }

    /// Create a root item
    pub fn root(domain: &DomainIdentifier, display_name: &str) -> Self {
        Self {
            identifier: ItemIdentifier::root(),
            parent_identifier: ItemIdentifier::root(),
            filename: display_name.to_string(),
            item_type: ItemType::Directory as u32,
            size: None,
            creation_date: None,
            content_modification_date: None,
            content_type: Some("public.folder".to_string()),
            capabilities: ItemCapabilities::directory_default().0,
            is_downloaded: true,
            is_downloading: false,
            is_uploaded: true,
            is_uploading: false,
            download_progress: 1.0,
            upload_progress: 1.0,
            version_identifier: None,
            checksum: None,
            is_favorite: false,
            tag_data: None,
            user_info: HashMap::new(),
        }
    }

    /// Check if this is a directory
    pub fn is_directory(&self) -> bool {
        self.item_type == ItemType::Directory as u32
    }

    /// Check if this is a file
    pub fn is_file(&self) -> bool {
        self.item_type == ItemType::File as u32
    }

    /// Set download state
    pub fn set_downloading(&mut self, progress: f64) {
        self.is_downloading = progress < 1.0;
        self.is_downloaded = progress >= 1.0;
        self.download_progress = progress;
    }

    /// Set upload state
    pub fn set_uploading(&mut self, progress: f64) {
        self.is_uploading = progress < 1.0;
        self.is_uploaded = progress >= 1.0;
        self.upload_progress = progress;
    }
}

/// Item version for conflict resolution
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ItemVersion {
    /// Content version (changes when file content changes)
    pub content_version: Vec<u8>,
    /// Metadata version (changes when metadata changes)
    pub metadata_version: Vec<u8>,
}

impl ItemVersion {
    pub fn new(content: impl AsRef<[u8]>, metadata: impl AsRef<[u8]>) -> Self {
        Self {
            content_version: content.as_ref().to_vec(),
            metadata_version: metadata.as_ref().to_vec(),
        }
    }

    pub fn from_checksum(checksum: &str) -> Self {
        Self {
            content_version: checksum.as_bytes().to_vec(),
            metadata_version: checksum.as_bytes().to_vec(),
        }
    }
}

/// Enumeration page for paginated listing
#[derive(Debug, Clone)]
pub struct EnumerationPage {
    pub items: Vec<FileProviderItem>,
    pub next_page_token: Option<String>,
    pub sync_anchor: Option<Vec<u8>>,
}

impl EnumerationPage {
    pub fn new(items: Vec<FileProviderItem>) -> Self {
        Self {
            items,
            next_page_token: None,
            sync_anchor: None,
        }
    }

    pub fn with_next_page(mut self, token: String) -> Self {
        self.next_page_token = Some(token);
        self
    }

    pub fn with_sync_anchor(mut self, anchor: Vec<u8>) -> Self {
        self.sync_anchor = Some(anchor);
        self
    }
}
