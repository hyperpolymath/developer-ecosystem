//! SFTP storage backend
//!
//! SSH File Transfer Protocol implementation.
//! Supports password, key-based, and agent authentication.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use std::path::PathBuf;

/// SFTP authentication method
#[derive(Debug, Clone)]
pub enum SftpAuth {
    /// Password authentication
    Password { username: String, password: String },
    /// Private key authentication
    PrivateKey {
        username: String,
        private_key_path: PathBuf,
        passphrase: Option<String>,
    },
    /// SSH agent authentication
    Agent { username: String },
}

/// SFTP backend configuration
#[derive(Debug, Clone)]
pub struct SftpConfig {
    /// Host address
    pub host: String,
    /// Port (default: 22)
    pub port: u16,
    /// Authentication method
    pub auth: SftpAuth,
    /// Known hosts file path
    pub known_hosts: Option<PathBuf>,
    /// Skip host key verification (insecure!)
    pub skip_host_key_check: bool,
    /// Remote base path
    pub base_path: String,
}

impl Default for SftpConfig {
    fn default() -> Self {
        Self {
            host: "localhost".to_string(),
            port: 22,
            auth: SftpAuth::Agent {
                username: whoami::username(),
            },
            known_hosts: None,
            skip_host_key_check: false,
            base_path: "/".to_string(),
        }
    }
}

/// SFTP storage backend
///
/// Note: This is a stub implementation. Full implementation would use
/// the `ssh2` or `russh` crate for SSH/SFTP protocol support.
pub struct SftpBackend {
    id: String,
    config: SftpConfig,
    capabilities: StorageCapabilities,
    // In a full implementation:
    // session: Option<ssh2::Session>,
    // sftp: Option<ssh2::Sftp>,
}

impl SftpBackend {
    pub fn new(id: impl Into<String>, config: SftpConfig) -> Self {
        Self {
            id: id.into(),
            config,
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: false, // SFTP doesn't have native copy
                list: true,
                search: false,
                versioning: false,
                sharing: false,
                streaming: true,
                resume: true, // With SEEK
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
        }
    }

    /// Create from SSH URL: sftp://user@host:port/path
    pub fn from_url(id: impl Into<String>, url: &str) -> CfkResult<Self> {
        let parsed = url::Url::parse(url)
            .map_err(|e| CfkError::InvalidPath(format!("Invalid URL: {}", e)))?;

        if parsed.scheme() != "sftp" {
            return Err(CfkError::InvalidPath("URL scheme must be sftp".into()));
        }

        let host = parsed
            .host_str()
            .ok_or_else(|| CfkError::InvalidPath("Missing host".into()))?
            .to_string();

        let port = parsed.port().unwrap_or(22);
        let username = if parsed.username().is_empty() {
            whoami::username()
        } else {
            parsed.username().to_string()
        };

        let base_path = if parsed.path().is_empty() {
            "/".to_string()
        } else {
            parsed.path().to_string()
        };

        let auth = if let Some(password) = parsed.password() {
            SftpAuth::Password {
                username,
                password: password.to_string(),
            }
        } else {
            SftpAuth::Agent { username }
        };

        Ok(Self::new(
            id,
            SftpConfig {
                host,
                port,
                auth,
                base_path,
                ..Default::default()
            },
        ))
    }

    /// Convert VirtualPath to remote path
    fn to_remote_path(&self, path: &VirtualPath) -> String {
        let base = self.config.base_path.trim_end_matches('/');
        if path.segments.is_empty() {
            base.to_string()
        } else {
            format!("{}/{}", base, path.segments.join("/"))
        }
    }

    /// Connect to SFTP server
    pub async fn connect(&self) -> CfkResult<()> {
        // In a full implementation, this would:
        // 1. Create TCP connection
        // 2. Perform SSH handshake
        // 3. Authenticate
        // 4. Initialize SFTP subsystem

        Err(CfkError::Unsupported(
            "SFTP backend requires ssh2 or russh crate. Stub implementation.".into(),
        ))
    }
}

#[async_trait]
impl StorageBackend for SftpBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "SFTP"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        // Would check SSH connection
        false
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let _remote_path = self.to_remote_path(path);

        // Would use SFTP stat() call
        // let attrs = sftp.stat(&remote_path)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let _remote_path = self.to_remote_path(path);

        // Would use SFTP readdir() call
        // let entries = sftp.readdir(&remote_path)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let _remote_path = self.to_remote_path(path);

        // Would open file and read:
        // let mut file = sftp.open(&remote_path)?;
        // let mut data = Vec::new();
        // file.read_to_end(&mut data)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn write_file(&self, path: &VirtualPath, _data: Bytes) -> CfkResult<Entry> {
        let _remote_path = self.to_remote_path(path);

        // Would create/open file and write:
        // let mut file = sftp.create(&remote_path)?;
        // file.write_all(&data)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let _remote_path = self.to_remote_path(path);

        // Would use SFTP unlink() or rmdir():
        // sftp.unlink(&remote_path)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let _remote_path = self.to_remote_path(path);

        // Would use SFTP mkdir():
        // sftp.mkdir(&remote_path, 0o755)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn copy(&self, _from: &VirtualPath, _to: &VirtualPath) -> CfkResult<Entry> {
        // SFTP doesn't support server-side copy
        // Would need to read + write
        Err(CfkError::Unsupported(
            "SFTP doesn't support native copy".into(),
        ))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let _from_path = self.to_remote_path(from);
        let _to_path = self.to_remote_path(to);

        // Would use SFTP rename():
        // sftp.rename(&from_path, &to_path, None)?;

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // SFTP has statvfs extension (OpenSSH)
        // Would use sftp.statvfs()

        Err(CfkError::Unsupported("SFTP stub - use ssh2 crate".into()))
    }
}

/// Helper to get username
mod whoami {
    pub fn username() -> String {
        std::env::var("USER")
            .or_else(|_| std::env::var("USERNAME"))
            .unwrap_or_else(|_| "nobody".to_string())
    }
}

/// SFTP file attributes (mirrors ssh2::FileStat)
#[derive(Debug, Clone, Default)]
pub struct FileAttributes {
    pub size: Option<u64>,
    pub uid: Option<u32>,
    pub gid: Option<u32>,
    pub permissions: Option<u32>,
    pub atime: Option<u64>,
    pub mtime: Option<u64>,
}

impl FileAttributes {
    pub fn is_dir(&self) -> bool {
        self.permissions
            .map(|p| (p & 0o40000) != 0)
            .unwrap_or(false)
    }

    pub fn is_symlink(&self) -> bool {
        self.permissions
            .map(|p| (p & 0o120000) == 0o120000)
            .unwrap_or(false)
    }

    pub fn is_file(&self) -> bool {
        self.permissions
            .map(|p| (p & 0o100000) != 0)
            .unwrap_or(false)
    }

    pub fn to_metadata(&self) -> Metadata {
        let mut meta = Metadata::default();
        meta.size = self.size;
        meta.permissions = self.permissions;
        meta.uid = self.uid;
        meta.gid = self.gid;

        if let Some(mtime) = self.mtime {
            meta.modified = chrono::DateTime::from_timestamp(mtime as i64, 0);
        }

        meta
    }
}
