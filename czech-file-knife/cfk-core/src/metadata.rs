//! File and directory metadata

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// File/directory metadata
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Metadata {
    pub size: Option<u64>,
    pub created: Option<DateTime<Utc>>,
    pub modified: Option<DateTime<Utc>>,
    pub accessed: Option<DateTime<Utc>>,
    pub permissions: Option<Permissions>,
    pub content_hash: Option<String>,
    pub mime_type: Option<String>,
    pub provider_id: Option<String>,
    pub revision: Option<String>,
    pub custom: HashMap<String, String>,
}

/// Unix-style permissions
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Permissions {
    pub mode: u32,
}

impl Permissions {
    pub fn new(mode: u32) -> Self {
        Self { mode }
    }

    pub fn is_readable(&self) -> bool {
        self.mode & 0o444 != 0
    }

    pub fn is_writable(&self) -> bool {
        self.mode & 0o222 != 0
    }

    pub fn is_executable(&self) -> bool {
        self.mode & 0o111 != 0
    }
}

impl Metadata {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_size(mut self, size: u64) -> Self {
        self.size = Some(size);
        self
    }

    pub fn with_modified(mut self, modified: DateTime<Utc>) -> Self {
        self.modified = Some(modified);
        self
    }
}
