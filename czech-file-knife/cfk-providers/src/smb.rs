//! SMB/CIFS storage backend
//!
//! Server Message Block / Common Internet File System protocol.
//! Compatible with Windows shares, Samba, and macOS file sharing.

use async_trait::async_trait;
use bytes::Bytes;
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use std::path::PathBuf;

/// SMB protocol version
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SmbVersion {
    /// SMB 1.0 (legacy, insecure)
    Smb1,
    /// SMB 2.0
    Smb2,
    /// SMB 2.1
    Smb21,
    /// SMB 3.0
    Smb3,
    /// SMB 3.0.2
    Smb302,
    /// SMB 3.1.1
    Smb311,
}

impl Default for SmbVersion {
    fn default() -> Self {
        Self::Smb3 // Secure default
    }
}

/// SMB authentication
#[derive(Debug, Clone)]
pub enum SmbAuth {
    /// Anonymous/Guest access
    Anonymous,
    /// NTLM authentication
    Ntlm { username: String, password: String, domain: Option<String> },
    /// Kerberos authentication
    Kerberos { principal: String },
}

impl Default for SmbAuth {
    fn default() -> Self {
        Self::Anonymous
    }
}

/// SMB backend configuration
#[derive(Debug, Clone)]
pub struct SmbConfig {
    /// Server hostname or IP
    pub server: String,
    /// Share name
    pub share: String,
    /// SMB protocol version
    pub version: SmbVersion,
    /// Authentication
    pub auth: SmbAuth,
    /// Port (default: 445, legacy: 139)
    pub port: u16,
    /// Encrypt traffic (SMB 3.0+)
    pub encryption: bool,
    /// Sign messages
    pub signing: bool,
}

impl Default for SmbConfig {
    fn default() -> Self {
        Self {
            server: "localhost".to_string(),
            share: "share".to_string(),
            version: SmbVersion::default(),
            auth: SmbAuth::default(),
            port: 445,
            encryption: true,
            signing: true,
        }
    }
}

/// SMB tree connection ID
#[derive(Debug, Clone, Copy, Default)]
struct TreeId(u32);

/// SMB session ID
#[derive(Debug, Clone, Copy, Default)]
struct SessionId(u64);

/// SMB file ID
#[derive(Debug, Clone, Copy, Default)]
struct FileId {
    persistent: u64,
    volatile: u64,
}

/// SMB storage backend
///
/// Note: This is a stub implementation. Full implementation would require
/// the SMB protocol which is complex. Consider using `pavao` or `smb` crate,
/// or system mount.
pub struct SmbBackend {
    id: String,
    config: SmbConfig,
    capabilities: StorageCapabilities,
    session: Option<SessionId>,
    tree_id: Option<TreeId>,
}

impl SmbBackend {
    pub fn new(id: impl Into<String>, config: SmbConfig) -> Self {
        let mut caps = StorageCapabilities {
            read: true,
            write: true,
            delete: true,
            rename: true,
            copy: true, // SMB2+ has server-side copy
            list: true,
            search: true, // SMB has FIND
            versioning: false,
            sharing: true, // Windows ACLs
            streaming: true,
            resume: true,
            watch: true, // Change notifications
            metadata: true,
            thumbnails: false,
            max_file_size: None,
        };

        // Adjust capabilities based on version
        if config.version == SmbVersion::Smb1 {
            caps.copy = false; // SMB1 doesn't have server-side copy
            caps.watch = false;
        }

        Self {
            id: id.into(),
            config,
            capabilities: caps,
            session: None,
            tree_id: None,
        }
    }

    /// Create from SMB URL: smb://user:pass@server/share
    pub fn from_url(id: impl Into<String>, url: &str) -> CfkResult<Self> {
        let parsed = url::Url::parse(url)
            .map_err(|e| CfkError::InvalidPath(format!("Invalid URL: {}", e)))?;

        if parsed.scheme() != "smb" {
            return Err(CfkError::InvalidPath("URL scheme must be smb".into()));
        }

        let server = parsed
            .host_str()
            .ok_or_else(|| CfkError::InvalidPath("Missing server".into()))?
            .to_string();

        let share = parsed
            .path()
            .trim_start_matches('/')
            .split('/')
            .next()
            .unwrap_or("share")
            .to_string();

        let port = parsed.port().unwrap_or(445);

        let auth = if !parsed.username().is_empty() {
            SmbAuth::Ntlm {
                username: parsed.username().to_string(),
                password: parsed.password().unwrap_or("").to_string(),
                domain: None,
            }
        } else {
            SmbAuth::Anonymous
        };

        Ok(Self::new(
            id,
            SmbConfig {
                server,
                share,
                port,
                auth,
                ..Default::default()
            },
        ))
    }

    /// Connect to SMB server
    pub async fn connect(&mut self) -> CfkResult<()> {
        // SMB2/3 connection sequence:
        // 1. TCP connect to port 445
        // 2. NEGOTIATE (select protocol version)
        // 3. SESSION_SETUP (authenticate)
        // 4. TREE_CONNECT (connect to share)

        Err(CfkError::Unsupported(
            "SMB backend is a stub. Use system mount, pavao, or smb crate.".into(),
        ))
    }

    /// Disconnect from SMB server
    pub async fn disconnect(&mut self) -> CfkResult<()> {
        // 1. TREE_DISCONNECT
        // 2. LOGOFF
        // 3. Close TCP connection

        self.tree_id = None;
        self.session = None;
        Ok(())
    }

    /// Convert VirtualPath to SMB path (backslashes)
    fn to_smb_path(&self, path: &VirtualPath) -> String {
        if path.segments.is_empty() {
            "\\".to_string()
        } else {
            format!("\\{}", path.segments.join("\\"))
        }
    }
}

#[async_trait]
impl StorageBackend for SmbBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        match self.config.version {
            SmbVersion::Smb1 => "SMB1/CIFS",
            SmbVersion::Smb2 => "SMB2",
            SmbVersion::Smb21 => "SMB2.1",
            SmbVersion::Smb3 => "SMB3",
            SmbVersion::Smb302 => "SMB3.0.2",
            SmbVersion::Smb311 => "SMB3.1.1",
        }
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        self.session.is_some() && self.tree_id.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let _smb_path = self.to_smb_path(path);
        // Would use QUERY_INFO with FileAllInformation class

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let _smb_path = self.to_smb_path(path);
        // Would use QUERY_DIRECTORY (SMB2) or FIND_FIRST2/FIND_NEXT2 (SMB1)

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let _smb_path = self.to_smb_path(path);
        // Would use CREATE (open) + READ + CLOSE

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn write_file(&self, path: &VirtualPath, _data: Bytes) -> CfkResult<Entry> {
        let _smb_path = self.to_smb_path(path);
        // Would use CREATE + WRITE + CLOSE

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let _smb_path = self.to_smb_path(path);
        // Would use CREATE with DELETE_ON_CLOSE or SET_INFO with FileDispositionInfo

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let _smb_path = self.to_smb_path(path);
        // Would use CREATE with FILE_DIRECTORY_FILE

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn copy(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        if self.config.version == SmbVersion::Smb1 {
            return Err(CfkError::Unsupported("SMB1 doesn't support server-side copy".into()));
        }

        let _from_path = self.to_smb_path(from);
        let _to_path = self.to_smb_path(to);
        // Would use IOCTL with FSCTL_SRV_COPYCHUNK

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        let _from_path = self.to_smb_path(from);
        let _to_path = self.to_smb_path(to);
        // Would use SET_INFO with FileRenameInformation

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // Would use QUERY_INFO with FileFsFullSizeInformation

        Err(CfkError::Unsupported("SMB stub - use system mount".into()))
    }
}

/// SMB file attributes
#[derive(Debug, Clone, Copy, Default)]
pub struct SmbFileAttributes(u32);

impl SmbFileAttributes {
    pub const READONLY: u32 = 0x0001;
    pub const HIDDEN: u32 = 0x0002;
    pub const SYSTEM: u32 = 0x0004;
    pub const DIRECTORY: u32 = 0x0010;
    pub const ARCHIVE: u32 = 0x0020;
    pub const NORMAL: u32 = 0x0080;
    pub const TEMPORARY: u32 = 0x0100;
    pub const SPARSE: u32 = 0x0200;
    pub const REPARSE_POINT: u32 = 0x0400;
    pub const COMPRESSED: u32 = 0x0800;
    pub const ENCRYPTED: u32 = 0x4000;

    pub fn is_directory(&self) -> bool {
        self.0 & Self::DIRECTORY != 0
    }

    pub fn is_hidden(&self) -> bool {
        self.0 & Self::HIDDEN != 0
    }

    pub fn is_readonly(&self) -> bool {
        self.0 & Self::READONLY != 0
    }

    pub fn is_symlink(&self) -> bool {
        self.0 & Self::REPARSE_POINT != 0
    }
}

/// SMB file information
#[derive(Debug, Clone, Default)]
pub struct SmbFileInfo {
    pub creation_time: u64,
    pub last_access_time: u64,
    pub last_write_time: u64,
    pub change_time: u64,
    pub attributes: SmbFileAttributes,
    pub allocation_size: u64,
    pub end_of_file: u64,
    pub file_id: u64,
}

impl SmbFileInfo {
    /// Convert Windows FILETIME to Unix timestamp
    fn filetime_to_unix(ft: u64) -> Option<i64> {
        // FILETIME is 100-nanosecond intervals since Jan 1, 1601
        // Unix epoch is Jan 1, 1970
        const FILETIME_UNIX_DIFF: u64 = 116444736000000000;
        if ft > FILETIME_UNIX_DIFF {
            Some(((ft - FILETIME_UNIX_DIFF) / 10000000) as i64)
        } else {
            None
        }
    }

    pub fn to_entry(&self, backend_id: &str, path: &str) -> Entry {
        let kind = if self.attributes.is_directory() {
            EntryKind::Directory
        } else if self.attributes.is_symlink() {
            EntryKind::Symlink
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = Some(self.end_of_file);

        if let Some(ts) = Self::filetime_to_unix(self.last_write_time) {
            metadata.modified = chrono::DateTime::from_timestamp(ts, 0);
        }
        if let Some(ts) = Self::filetime_to_unix(self.creation_time) {
            metadata.created = chrono::DateTime::from_timestamp(ts, 0);
        }

        metadata.custom.insert(
            "readonly".to_string(),
            self.attributes.is_readonly().to_string(),
        );
        metadata.custom.insert(
            "hidden".to_string(),
            self.attributes.is_hidden().to_string(),
        );

        Entry {
            path: VirtualPath::new(backend_id, path),
            kind,
            metadata,
        }
    }
}

/// Helper to use system mount
impl SmbBackend {
    /// Mount using system mount.cifs (Linux) or mount_smbfs (macOS)
    pub fn mount_system(&self, mount_point: &PathBuf) -> CfkResult<()> {
        use std::process::Command;

        let source = format!("//{}/{}", self.config.server, self.config.share);

        #[cfg(target_os = "linux")]
        {
            let (username, password) = match &self.config.auth {
                SmbAuth::Anonymous => ("guest".to_string(), String::new()),
                SmbAuth::Ntlm { username, password, .. } => (username.clone(), password.clone()),
                SmbAuth::Kerberos { .. } => {
                    return Err(CfkError::Unsupported(
                        "Kerberos mount requires system configuration".into(),
                    ))
                }
            };

            let options = format!(
                "username={},password={},vers={}",
                username,
                password,
                match self.config.version {
                    SmbVersion::Smb1 => "1.0",
                    SmbVersion::Smb2 => "2.0",
                    SmbVersion::Smb21 => "2.1",
                    SmbVersion::Smb3 | SmbVersion::Smb302 | SmbVersion::Smb311 => "3.0",
                }
            );

            let status = Command::new("mount")
                .args([
                    "-t", "cifs",
                    "-o", &options,
                    &source,
                    mount_point.to_str().unwrap_or("/mnt"),
                ])
                .status()
                .map_err(|e| CfkError::Io(e.to_string()))?;

            if !status.success() {
                return Err(CfkError::ProviderApi {
                    provider: "smb".into(),
                    message: "mount.cifs failed".into(),
                });
            }
        }

        #[cfg(target_os = "macos")]
        {
            let status = Command::new("mount_smbfs")
                .args([&source, mount_point.to_str().unwrap_or("/mnt")])
                .status()
                .map_err(|e| CfkError::Io(e.to_string()))?;

            if !status.success() {
                return Err(CfkError::ProviderApi {
                    provider: "smb".into(),
                    message: "mount_smbfs failed".into(),
                });
            }
        }

        #[cfg(not(any(target_os = "linux", target_os = "macos")))]
        {
            return Err(CfkError::Unsupported(
                "System SMB mount not supported on this platform".into(),
            ));
        }

        Ok(())
    }
}
