// SPDX-License-Identifier: AGPL-3.0-or-later
//! FUSE virtual filesystem for Czech File Knife
//!
//! This module provides FUSE mounting capabilities to access
//! any CFK backend as a local filesystem.
//! Currently a stub - full implementation coming in a future release.

use cfk_core::{CfkError, CfkResult};
use std::path::PathBuf;
use thiserror::Error;

/// VFS errors
#[derive(Error, Debug)]
pub enum VfsError {
    #[error("Mount point does not exist: {0}")]
    MountPointNotFound(String),

    #[error("Mount point is not a directory: {0}")]
    MountPointNotDirectory(String),

    #[error("Already mounted at: {0}")]
    AlreadyMounted(String),

    #[error("Not mounted")]
    NotMounted,

    #[error("FUSE error: {0}")]
    Fuse(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// Mount options
#[derive(Debug, Clone, Default)]
pub struct MountOptions {
    /// Allow other users to access the mount
    pub allow_other: bool,
    /// Allow root to access the mount
    pub allow_root: bool,
    /// Read-only mount
    pub read_only: bool,
    /// Enable caching
    pub cache: bool,
    /// Cache timeout in seconds
    pub cache_timeout_secs: Option<u64>,
    /// Debug mode
    pub debug: bool,
}

/// VFS mount handle
pub struct VfsMount {
    mount_point: PathBuf,
    _options: MountOptions,
}

impl VfsMount {
    /// Mount a CFK backend at the given path
    ///
    /// # Arguments
    /// * `backend_id` - The backend to mount (e.g., "local", "dropbox")
    /// * `mount_point` - The local path to mount at
    /// * `options` - Mount options
    pub fn mount(
        _backend_id: &str,
        _mount_point: impl Into<PathBuf>,
        _options: MountOptions,
    ) -> CfkResult<Self> {
        Err(CfkError::Unsupported(
            "FUSE VFS mounting not yet implemented".into(),
        ))
    }

    /// Get the mount point path
    pub fn mount_point(&self) -> &PathBuf {
        &self.mount_point
    }

    /// Check if the mount is still active
    pub fn is_mounted(&self) -> bool {
        false
    }

    /// Unmount the filesystem
    pub fn unmount(self) -> CfkResult<()> {
        Err(CfkError::Unsupported(
            "FUSE VFS mounting not yet implemented".into(),
        ))
    }
}

impl Drop for VfsMount {
    fn drop(&mut self) {
        // Attempt to unmount on drop
        // In real implementation, this would call fuser::unmount
    }
}

/// List active mounts
pub fn list_mounts() -> Vec<VfsMount> {
    Vec::new()
}

/// Check if FUSE is available on this system
pub fn is_fuse_available() -> bool {
    #[cfg(target_os = "linux")]
    {
        std::path::Path::new("/dev/fuse").exists()
    }

    #[cfg(target_os = "macos")]
    {
        // Check for macFUSE
        std::path::Path::new("/Library/Filesystems/macfuse.fs").exists()
    }

    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_fuse_available() {
        // Just make sure it doesn't panic
        let _ = is_fuse_available();
    }

    #[test]
    fn test_mount_not_implemented() {
        let result = VfsMount::mount("local", "/tmp/test", MountOptions::default());
        assert!(result.is_err());
    }
}
