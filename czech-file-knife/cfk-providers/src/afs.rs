//! Andrew File System (AFS) storage backend
//!
//! OpenAFS client implementation with Kerberos authentication.
//! Designed for academic and enterprise distributed file systems.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use std::path::{Path, PathBuf};
use std::process::Command;
use tokio::fs;

/// AFS backend configuration
#[derive(Debug, Clone)]
pub struct AfsConfig {
    /// AFS cell name (e.g., "athena.mit.edu")
    pub cell: String,
    /// Local AFS mount point (typically /afs)
    pub mount_point: PathBuf,
    /// Kerberos principal (optional, uses default if not set)
    pub principal: Option<String>,
    /// Keytab file path (optional, for service accounts)
    pub keytab: Option<PathBuf>,
}

impl Default for AfsConfig {
    fn default() -> Self {
        Self {
            cell: String::new(),
            mount_point: PathBuf::from("/afs"),
            principal: None,
            keytab: None,
        }
    }
}

/// AFS storage backend
pub struct AfsBackend {
    id: String,
    config: AfsConfig,
    capabilities: StorageCapabilities,
}

impl AfsBackend {
    pub fn new(id: impl Into<String>, config: AfsConfig) -> Self {
        Self {
            id: id.into(),
            config,
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: true,
                list: true,
                search: false,
                versioning: false,
                sharing: true, // ACLs
                streaming: true,
                resume: true,
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
        }
    }

    /// Authenticate with Kerberos and obtain AFS tokens
    pub fn authenticate(&self) -> CfkResult<()> {
        // Use kinit for Kerberos authentication
        if let Some(ref keytab) = self.config.keytab {
            let principal = self
                .config
                .principal
                .as_deref()
                .ok_or_else(|| CfkError::Auth("Principal required with keytab".into()))?;

            let status = Command::new("kinit")
                .args(["-k", "-t", keytab.to_str().unwrap(), principal])
                .status()
                .map_err(|e| CfkError::Auth(format!("kinit failed: {}", e)))?;

            if !status.success() {
                return Err(CfkError::Auth("kinit failed".into()));
            }
        } else if let Some(ref principal) = self.config.principal {
            // Interactive kinit
            let status = Command::new("kinit")
                .arg(principal)
                .status()
                .map_err(|e| CfkError::Auth(format!("kinit failed: {}", e)))?;

            if !status.success() {
                return Err(CfkError::Auth("kinit failed".into()));
            }
        }

        // Get AFS tokens using aklog
        let status = Command::new("aklog")
            .args(["-c", &self.config.cell])
            .status()
            .map_err(|e| CfkError::Auth(format!("aklog failed: {}", e)))?;

        if !status.success() {
            return Err(CfkError::Auth("aklog failed".into()));
        }

        Ok(())
    }

    /// Check if we have valid AFS tokens
    pub fn has_tokens(&self) -> bool {
        Command::new("tokens")
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    }

    /// Convert VirtualPath to local filesystem path
    fn to_local_path(&self, path: &VirtualPath) -> PathBuf {
        let mut local_path = self.config.mount_point.clone();
        local_path.push(&self.config.cell);
        for segment in &path.segments {
            local_path.push(segment);
        }
        local_path
    }

    /// Convert local path to VirtualPath
    fn to_virtual_path(&self, local_path: &Path) -> CfkResult<VirtualPath> {
        let cell_path = self.config.mount_point.join(&self.config.cell);
        let relative = local_path
            .strip_prefix(&cell_path)
            .map_err(|_| CfkError::InvalidPath("Path not in AFS cell".into()))?;

        let segments: Vec<String> = relative
            .components()
            .filter_map(|c| c.as_os_str().to_str().map(String::from))
            .collect();

        Ok(VirtualPath {
            backend_id: self.id.clone(),
            segments,
        })
    }

    /// Get AFS ACL for a directory
    pub fn get_acl(&self, path: &VirtualPath) -> CfkResult<AfsAcl> {
        let local_path = self.to_local_path(path);

        let output = Command::new("fs")
            .args(["listacl", local_path.to_str().unwrap()])
            .output()
            .map_err(|e| CfkError::Io(e.to_string()))?;

        if !output.status.success() {
            return Err(CfkError::ProviderApi {
                provider: "afs".into(),
                message: String::from_utf8_lossy(&output.stderr).to_string(),
            });
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        parse_acl(&stdout)
    }

    /// Set AFS ACL
    pub fn set_acl(&self, path: &VirtualPath, principal: &str, rights: &str) -> CfkResult<()> {
        let local_path = self.to_local_path(path);

        let status = Command::new("fs")
            .args([
                "setacl",
                local_path.to_str().unwrap(),
                principal,
                rights,
            ])
            .status()
            .map_err(|e| CfkError::Io(e.to_string()))?;

        if !status.success() {
            return Err(CfkError::ProviderApi {
                provider: "afs".into(),
                message: "Failed to set ACL".into(),
            });
        }

        Ok(())
    }

    /// Get quota information for a volume
    pub fn get_quota(&self, path: &VirtualPath) -> CfkResult<AfsQuota> {
        let local_path = self.to_local_path(path);

        let output = Command::new("fs")
            .args(["listquota", local_path.to_str().unwrap()])
            .output()
            .map_err(|e| CfkError::Io(e.to_string()))?;

        if !output.status.success() {
            return Err(CfkError::ProviderApi {
                provider: "afs".into(),
                message: String::from_utf8_lossy(&output.stderr).to_string(),
            });
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        parse_quota(&stdout)
    }
}

/// AFS Access Control List
#[derive(Debug, Clone, Default)]
pub struct AfsAcl {
    pub positive: Vec<AfsAclEntry>,
    pub negative: Vec<AfsAclEntry>,
}

/// AFS ACL entry
#[derive(Debug, Clone)]
pub struct AfsAclEntry {
    pub principal: String,
    pub rights: String,
}

/// AFS Quota information
#[derive(Debug, Clone, Default)]
pub struct AfsQuota {
    pub volume: String,
    pub quota_kb: u64,
    pub used_kb: u64,
    pub percent_used: f32,
}

/// Parse AFS ACL output
fn parse_acl(output: &str) -> CfkResult<AfsAcl> {
    let mut acl = AfsAcl::default();
    let mut in_positive = true;

    for line in output.lines() {
        let line = line.trim();
        if line.starts_with("Access list for") || line.is_empty() {
            continue;
        }
        if line.starts_with("Normal rights:") {
            in_positive = true;
            continue;
        }
        if line.starts_with("Negative rights:") {
            in_positive = false;
            continue;
        }

        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
            let entry = AfsAclEntry {
                principal: parts[0].to_string(),
                rights: parts[1].to_string(),
            };
            if in_positive {
                acl.positive.push(entry);
            } else {
                acl.negative.push(entry);
            }
        }
    }

    Ok(acl)
}

/// Parse AFS quota output
fn parse_quota(output: &str) -> CfkResult<AfsQuota> {
    let mut quota = AfsQuota::default();

    for line in output.lines().skip(1) {
        // Skip header
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 4 {
            quota.volume = parts[0].to_string();
            quota.quota_kb = parts[1].parse().unwrap_or(0);
            quota.used_kb = parts[2].parse().unwrap_or(0);
            quota.percent_used = parts[3]
                .trim_end_matches('%')
                .parse()
                .unwrap_or(0.0);
            break;
        }
    }

    Ok(quota)
}

#[async_trait]
impl StorageBackend for AfsBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "AFS"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        let cell_path = self.config.mount_point.join(&self.config.cell);
        cell_path.exists() && self.has_tokens()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let local_path = self.to_local_path(path);

        let metadata = fs::metadata(&local_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        let kind = if metadata.is_dir() {
            EntryKind::Directory
        } else if metadata.is_symlink() {
            EntryKind::Symlink
        } else {
            EntryKind::File
        };

        let mut meta = Metadata::default();
        meta.size = Some(metadata.len());

        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            meta.permissions = Some(metadata.mode());
            meta.uid = Some(metadata.uid());
            meta.gid = Some(metadata.gid());
        }

        if let Ok(modified) = metadata.modified() {
            meta.modified = Some(chrono::DateTime::from(modified));
        }
        if let Ok(created) = metadata.created() {
            meta.created = Some(chrono::DateTime::from(created));
        }

        Ok(Entry {
            path: path.clone(),
            kind,
            metadata: meta,
        })
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let local_path = self.to_local_path(path);

        let mut entries = Vec::new();
        let mut dir = fs::read_dir(&local_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        while let Some(entry) = dir
            .next_entry()
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?
        {
            let entry_path = entry.path();
            let virtual_path = self.to_virtual_path(&entry_path)?;

            let metadata = entry
                .metadata()
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;

            let kind = if metadata.is_dir() {
                EntryKind::Directory
            } else if metadata.is_symlink() {
                EntryKind::Symlink
            } else {
                EntryKind::File
            };

            let mut meta = Metadata::default();
            meta.size = Some(metadata.len());

            if let Ok(modified) = metadata.modified() {
                meta.modified = Some(chrono::DateTime::from(modified));
            }

            entries.push(Entry {
                path: virtual_path,
                kind,
                metadata: meta,
            });
        }

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let local_path = self.to_local_path(path);

        let data = fs::read(&local_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        Ok(Bytes::from(data))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        let local_path = self.to_local_path(path);

        // Ensure parent directory exists
        if let Some(parent) = local_path.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;
        }

        fs::write(&local_path, &data)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        self.get_metadata(path).await
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let local_path = self.to_local_path(path);

        let metadata = fs::metadata(&local_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        if metadata.is_dir() {
            fs::remove_dir_all(&local_path)
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;
        } else {
            fs::remove_file(&local_path)
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let local_path = self.to_local_path(path);

        fs::create_dir_all(&local_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        self.get_metadata(path).await
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_local_path(from);
        let to_path = self.to_local_path(to);

        // Ensure parent directory exists
        if let Some(parent) = to_path.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;
        }

        fs::copy(&from_path, &to_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        self.get_metadata(to).await
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let from_path = self.to_local_path(from);
        let to_path = self.to_local_path(to);

        // Ensure parent directory exists
        if let Some(parent) = to_path.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|e| CfkError::Io(e.to_string()))?;
        }

        fs::rename(&from_path, &to_path)
            .await
            .map_err(|e| CfkError::Io(e.to_string()))?;

        self.get_metadata(to).await
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        let root = VirtualPath::new(&self.id, "");
        let quota = self.get_quota(&root)?;

        let total = quota.quota_kb * 1024;
        let used = quota.used_kb * 1024;
        let available = total.saturating_sub(used);

        Ok((available, total))
    }
}

/// AFS rights constants
pub mod rights {
    /// Read files
    pub const READ: &str = "r";
    /// List directory
    pub const LIST: &str = "l";
    /// Insert (create) files
    pub const INSERT: &str = "i";
    /// Delete files
    pub const DELETE: &str = "d";
    /// Write/modify files
    pub const WRITE: &str = "w";
    /// Lock files
    pub const LOCK: &str = "k";
    /// Administer ACLs
    pub const ADMIN: &str = "a";

    /// All rights
    pub const ALL: &str = "rlidwka";
    /// Read-only
    pub const READ_ONLY: &str = "rl";
    /// Write (no admin)
    pub const WRITE_NO_ADMIN: &str = "rlidwk";
}
