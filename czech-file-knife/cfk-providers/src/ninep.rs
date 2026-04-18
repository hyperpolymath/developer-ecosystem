//! 9P/Plan 9 filesystem protocol backend
//!
//! Used in WSL2 (drvfs), QEMU/KVM (virtio-9p), and Plan 9/Inferno systems.
//! Implements 9P2000.L (Linux extensions) protocol.

use async_trait::async_trait;
use bytes::{Buf, BufMut, Bytes, BytesMut};
use cfk_core::{
    CfkError, CfkResult, Entry, EntryKind, Metadata, StorageBackend, StorageCapabilities,
    VirtualPath,
};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::RwLock;

/// 9P message types
mod msg {
    pub const TVERSION: u8 = 100;
    pub const RVERSION: u8 = 101;
    pub const TAUTH: u8 = 102;
    pub const RAUTH: u8 = 103;
    pub const TATTACH: u8 = 104;
    pub const RATTACH: u8 = 105;
    pub const RERROR: u8 = 107;
    pub const TFLUSH: u8 = 108;
    pub const RFLUSH: u8 = 109;
    pub const TWALK: u8 = 110;
    pub const RWALK: u8 = 111;
    pub const TOPEN: u8 = 112;
    pub const ROPEN: u8 = 113;
    pub const TCREATE: u8 = 114;
    pub const RCREATE: u8 = 115;
    pub const TREAD: u8 = 116;
    pub const RREAD: u8 = 117;
    pub const TWRITE: u8 = 118;
    pub const RWRITE: u8 = 119;
    pub const TCLUNK: u8 = 120;
    pub const RCLUNK: u8 = 121;
    pub const TREMOVE: u8 = 122;
    pub const RREMOVE: u8 = 123;
    pub const TSTAT: u8 = 124;
    pub const RSTAT: u8 = 125;
    pub const TWSTAT: u8 = 126;
    pub const RWSTAT: u8 = 127;

    // 9P2000.L extensions
    pub const TLOPEN: u8 = 12;
    pub const RLOPEN: u8 = 13;
    pub const TLCREATE: u8 = 14;
    pub const RLCREATE: u8 = 15;
    pub const TREADDIR: u8 = 40;
    pub const RREADDIR: u8 = 41;
    pub const TGETATTR: u8 = 24;
    pub const RGETATTR: u8 = 25;
}

/// Open modes
mod omode {
    pub const READ: u8 = 0;
    pub const WRITE: u8 = 1;
    pub const RDWR: u8 = 2;
    pub const TRUNC: u16 = 0x10;
}

/// 9P QID type
#[derive(Debug, Clone, Default)]
struct Qid {
    qid_type: u8,
    version: u32,
    path: u64,
}

impl Qid {
    fn is_dir(&self) -> bool {
        self.qid_type & 0x80 != 0
    }
}

/// 9P backend configuration
#[derive(Debug, Clone)]
pub struct NinePConfig {
    /// Server address (host:port)
    pub address: String,
    /// Attach name (usually empty or a mount tag)
    pub aname: String,
    /// Username for authentication
    pub uname: String,
    /// Maximum message size
    pub msize: u32,
}

impl Default for NinePConfig {
    fn default() -> Self {
        Self {
            address: "127.0.0.1:564".to_string(),
            aname: String::new(),
            uname: "nobody".to_string(),
            msize: 8192,
        }
    }
}

/// 9P connection state
struct Connection {
    stream: TcpStream,
    msize: u32,
    root_fid: u32,
}

/// 9P storage backend
pub struct NinePBackend {
    id: String,
    config: NinePConfig,
    connection: Arc<RwLock<Option<Connection>>>,
    fid_counter: AtomicU32,
    capabilities: StorageCapabilities,
    /// Cache of path to fid mapping
    fid_cache: Arc<RwLock<HashMap<String, u32>>>,
}

impl NinePBackend {
    pub fn new(id: impl Into<String>, config: NinePConfig) -> Self {
        Self {
            id: id.into(),
            config,
            connection: Arc::new(RwLock::new(None)),
            fid_counter: AtomicU32::new(1),
            capabilities: StorageCapabilities {
                read: true,
                write: true,
                delete: true,
                rename: true,
                copy: false, // 9P doesn't have native copy
                list: true,
                search: false,
                versioning: false,
                sharing: false,
                streaming: true,
                resume: false,
                watch: false,
                metadata: true,
                thumbnails: false,
                max_file_size: None,
            },
            fid_cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Connect to 9P server
    pub async fn connect(&self) -> CfkResult<()> {
        let stream = TcpStream::connect(&self.config.address)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let mut conn = Connection {
            stream,
            msize: self.config.msize,
            root_fid: 0,
        };

        // Send Tversion
        let tag = 0xFFFF; // NOTAG for version
        let mut buf = BytesMut::new();
        buf.put_u32_le(0); // size placeholder
        buf.put_u8(msg::TVERSION);
        buf.put_u16_le(tag);
        buf.put_u32_le(self.config.msize);
        put_string(&mut buf, "9P2000.L");

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        // Read Rversion
        let reply = read_message(&mut conn.stream).await?;
        if reply[4] != msg::RVERSION {
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: "Version negotiation failed".into(),
            });
        }

        let mut cursor = &reply[7..];
        conn.msize = cursor.get_u32_le();

        // Send Tattach
        let root_fid = self.alloc_fid();
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TATTACH);
        buf.put_u16_le(1); // tag
        buf.put_u32_le(root_fid);
        buf.put_u32_le(0xFFFFFFFF); // afid (no auth)
        put_string(&mut buf, &self.config.uname);
        put_string(&mut buf, &self.config.aname);
        buf.put_u32_le(0); // n_uname (9P2000.L)

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        conn.root_fid = root_fid;
        *self.connection.write().await = Some(conn);

        Ok(())
    }

    /// Allocate a new fid
    fn alloc_fid(&self) -> u32 {
        self.fid_counter.fetch_add(1, Ordering::SeqCst)
    }

    /// Walk to a path and return the fid
    async fn walk(&self, path: &VirtualPath) -> CfkResult<u32> {
        let path_str = path.to_string();

        // Check cache
        {
            let cache = self.fid_cache.read().await;
            if let Some(&fid) = cache.get(&path_str) {
                return Ok(fid);
            }
        }

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        let new_fid = self.alloc_fid();

        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TWALK);
        buf.put_u16_le(2); // tag
        buf.put_u32_le(conn.root_fid);
        buf.put_u32_le(new_fid);

        // Path segments
        let segments = &path.segments;
        buf.put_u16_le(segments.len() as u16);
        for seg in segments {
            put_string(&mut buf, seg);
        }

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::NotFound(format!("{}: {}", path, error)));
        }

        // Cache the fid
        {
            let mut cache = self.fid_cache.write().await;
            cache.insert(path_str, new_fid);
        }

        Ok(new_fid)
    }

    /// Clunk (release) a fid
    async fn clunk(&self, fid: u32) -> CfkResult<()> {
        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TCLUNK);
        buf.put_u16_le(3);
        buf.put_u32_le(fid);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let _reply = read_message(&mut conn.stream).await?;
        Ok(())
    }

    /// Get file attributes (9P2000.L Tgetattr)
    async fn getattr(&self, fid: u32) -> CfkResult<FileAttr> {
        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TGETATTR);
        buf.put_u16_le(4);
        buf.put_u32_le(fid);
        buf.put_u64_le(0x7FF); // request_mask: all basic attrs

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        parse_getattr(&reply)
    }
}

/// File attributes
#[derive(Debug, Clone, Default)]
struct FileAttr {
    mode: u32,
    uid: u32,
    gid: u32,
    nlink: u64,
    size: u64,
    atime_sec: u64,
    mtime_sec: u64,
    ctime_sec: u64,
}

/// Parse Rgetattr response
fn parse_getattr(data: &[u8]) -> CfkResult<FileAttr> {
    if data.len() < 100 {
        return Err(CfkError::Serialization("Rgetattr too short".into()));
    }

    let mut cursor = &data[7..]; // Skip size, type, tag
    let _valid = cursor.get_u64_le();
    let _qid_type = cursor.get_u8();
    let _qid_version = cursor.get_u32_le();
    let _qid_path = cursor.get_u64_le();

    Ok(FileAttr {
        mode: cursor.get_u32_le(),
        uid: cursor.get_u32_le(),
        gid: cursor.get_u32_le(),
        nlink: cursor.get_u64_le(),
        _rdev: cursor.get_u64_le(),
        size: cursor.get_u64_le(),
        _blksize: cursor.get_u64_le(),
        _blocks: cursor.get_u64_le(),
        atime_sec: cursor.get_u64_le(),
        _atime_nsec: cursor.get_u64_le(),
        mtime_sec: cursor.get_u64_le(),
        _mtime_nsec: cursor.get_u64_le(),
        ctime_sec: cursor.get_u64_le(),
        ..Default::default()
    })
}

/// Parse error from Rerror message
fn parse_error(data: &[u8]) -> CfkResult<String> {
    if data.len() < 9 {
        return Ok("Unknown error".into());
    }

    let mut cursor = &data[7..];
    let len = cursor.get_u16_le() as usize;
    if cursor.len() >= len {
        Ok(String::from_utf8_lossy(&cursor[..len]).to_string())
    } else {
        Ok("Unknown error".into())
    }
}

/// Read a 9P message
async fn read_message(stream: &mut TcpStream) -> CfkResult<Vec<u8>> {
    let mut size_buf = [0u8; 4];
    stream
        .read_exact(&mut size_buf)
        .await
        .map_err(|e| CfkError::Network(e.to_string()))?;

    let size = u32::from_le_bytes(size_buf) as usize;
    if size < 4 || size > 1024 * 1024 {
        return Err(CfkError::Serialization("Invalid message size".into()));
    }

    let mut buf = vec![0u8; size];
    buf[0..4].copy_from_slice(&size_buf);

    stream
        .read_exact(&mut buf[4..])
        .await
        .map_err(|e| CfkError::Network(e.to_string()))?;

    Ok(buf)
}

/// Write string in 9P format (2-byte length prefix)
fn put_string(buf: &mut BytesMut, s: &str) {
    let bytes = s.as_bytes();
    buf.put_u16_le(bytes.len() as u16);
    buf.put_slice(bytes);
}

#[async_trait]
impl StorageBackend for NinePBackend {
    fn id(&self) -> &str {
        &self.id
    }

    fn display_name(&self) -> &str {
        "9P"
    }

    fn capabilities(&self) -> &StorageCapabilities {
        &self.capabilities
    }

    async fn is_available(&self) -> bool {
        let conn = self.connection.read().await;
        conn.is_some()
    }

    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let fid = self.walk(path).await?;
        let attr = self.getattr(fid).await?;

        let kind = if (attr.mode & 0o40000) != 0 {
            EntryKind::Directory
        } else if (attr.mode & 0o120000) == 0o120000 {
            EntryKind::Symlink
        } else {
            EntryKind::File
        };

        let mut metadata = Metadata::default();
        metadata.size = Some(attr.size);
        metadata.permissions = Some(attr.mode);
        metadata.uid = Some(attr.uid);
        metadata.gid = Some(attr.gid);

        if attr.mtime_sec > 0 {
            metadata.modified = chrono::DateTime::from_timestamp(attr.mtime_sec as i64, 0);
        }

        Ok(Entry {
            path: path.clone(),
            kind,
            metadata,
        })
    }

    async fn list_directory(&self, path: &VirtualPath) -> CfkResult<Vec<Entry>> {
        let fid = self.walk(path).await?;

        // Open directory for reading
        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        // Tlopen
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TLOPEN);
        buf.put_u16_le(5);
        buf.put_u32_le(fid);
        buf.put_u32_le(omode::READ as u32);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        // Treaddir
        let mut entries = Vec::new();
        let mut offset = 0u64;

        loop {
            let mut buf = BytesMut::new();
            buf.put_u32_le(0);
            buf.put_u8(msg::TREADDIR);
            buf.put_u16_le(6);
            buf.put_u32_le(fid);
            buf.put_u64_le(offset);
            buf.put_u32_le(conn.msize - 24);

            let size = buf.len() as u32;
            buf[0..4].copy_from_slice(&size.to_le_bytes());

            conn.stream
                .write_all(&buf)
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            let reply = read_message(&mut conn.stream).await?;
            if reply[4] == msg::RERROR {
                break;
            }

            let mut cursor = &reply[7..];
            let count = cursor.get_u32_le() as usize;
            if count == 0 {
                break;
            }

            // Parse directory entries
            let data = &cursor[..count];
            let mut pos = 0;

            while pos < data.len() {
                if pos + 24 > data.len() {
                    break;
                }

                let mut entry_cursor = &data[pos..];
                let qid_type = entry_cursor.get_u8();
                let _qid_version = entry_cursor.get_u32_le();
                let _qid_path = entry_cursor.get_u64_le();
                offset = entry_cursor.get_u64_le();
                let dtype = entry_cursor.get_u8();
                let name_len = entry_cursor.get_u16_le() as usize;

                if pos + 24 + name_len > data.len() {
                    break;
                }

                let name = String::from_utf8_lossy(&entry_cursor[..name_len]).to_string();
                pos += 24 + name_len;

                if name == "." || name == ".." {
                    continue;
                }

                let kind = if qid_type & 0x80 != 0 {
                    EntryKind::Directory
                } else {
                    EntryKind::File
                };

                let entry_path = if path.segments.is_empty() {
                    VirtualPath::new(&self.id, &name)
                } else {
                    VirtualPath::new(&self.id, &format!("{}/{}", path.segments.join("/"), name))
                };

                entries.push(Entry {
                    path: entry_path,
                    kind,
                    metadata: Metadata::default(),
                });
            }
        }

        drop(conn_guard);
        self.clunk(fid).await?;

        Ok(entries)
    }

    async fn read_file(&self, path: &VirtualPath) -> CfkResult<Bytes> {
        let fid = self.walk(path).await?;

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        // Tlopen
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TLOPEN);
        buf.put_u16_le(7);
        buf.put_u32_le(fid);
        buf.put_u32_le(omode::READ as u32);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        // Read file content
        let mut content = Vec::new();
        let mut offset = 0u64;
        let chunk_size = conn.msize - 24;

        loop {
            let mut buf = BytesMut::new();
            buf.put_u32_le(0);
            buf.put_u8(msg::TREAD);
            buf.put_u16_le(8);
            buf.put_u32_le(fid);
            buf.put_u64_le(offset);
            buf.put_u32_le(chunk_size);

            let size = buf.len() as u32;
            buf[0..4].copy_from_slice(&size.to_le_bytes());

            conn.stream
                .write_all(&buf)
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            let reply = read_message(&mut conn.stream).await?;
            if reply[4] == msg::RERROR {
                let error = parse_error(&reply)?;
                return Err(CfkError::ProviderApi {
                    provider: "9p".into(),
                    message: error,
                });
            }

            let mut cursor = &reply[7..];
            let count = cursor.get_u32_le() as usize;
            if count == 0 {
                break;
            }

            content.extend_from_slice(&cursor[..count]);
            offset += count as u64;
        }

        drop(conn_guard);
        self.clunk(fid).await?;

        Ok(Bytes::from(content))
    }

    async fn write_file(&self, path: &VirtualPath, data: Bytes) -> CfkResult<Entry> {
        // Walk to parent and create file
        let parent = if path.segments.len() > 1 {
            VirtualPath::new(&self.id, &path.segments[..path.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };

        let parent_fid = self.walk(&parent).await?;
        let name = path.segments.last().cloned().unwrap_or_default();

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        // Tlcreate
        let new_fid = self.fid_counter.fetch_add(1, Ordering::SeqCst);
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TLCREATE);
        buf.put_u16_le(9);
        buf.put_u32_le(parent_fid);
        put_string(&mut buf, &name);
        buf.put_u32_le(omode::RDWR as u32 | omode::TRUNC as u32);
        buf.put_u32_le(0o644); // mode
        buf.put_u32_le(0); // gid

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        // Write data
        let mut offset = 0u64;
        let chunk_size = (conn.msize - 24) as usize;

        while offset < data.len() as u64 {
            let end = std::cmp::min(offset as usize + chunk_size, data.len());
            let chunk = &data[offset as usize..end];

            let mut buf = BytesMut::new();
            buf.put_u32_le(0);
            buf.put_u8(msg::TWRITE);
            buf.put_u16_le(10);
            buf.put_u32_le(new_fid);
            buf.put_u64_le(offset);
            buf.put_u32_le(chunk.len() as u32);
            buf.put_slice(chunk);

            let size = buf.len() as u32;
            buf[0..4].copy_from_slice(&size.to_le_bytes());

            conn.stream
                .write_all(&buf)
                .await
                .map_err(|e| CfkError::Network(e.to_string()))?;

            let reply = read_message(&mut conn.stream).await?;
            if reply[4] == msg::RERROR {
                let error = parse_error(&reply)?;
                return Err(CfkError::ProviderApi {
                    provider: "9p".into(),
                    message: error,
                });
            }

            let mut cursor = &reply[7..];
            let written = cursor.get_u32_le() as u64;
            offset += written;
        }

        drop(conn_guard);
        self.clunk(new_fid).await?;

        self.get_metadata(path).await
    }

    async fn delete(&self, path: &VirtualPath) -> CfkResult<()> {
        let fid = self.walk(path).await?;

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(msg::TREMOVE);
        buf.put_u16_le(11);
        buf.put_u32_le(fid);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        // Remove from cache
        {
            let mut cache = self.fid_cache.write().await;
            cache.remove(&path.to_string());
        }

        Ok(())
    }

    async fn create_directory(&self, path: &VirtualPath) -> CfkResult<Entry> {
        let parent = if path.segments.len() > 1 {
            VirtualPath::new(&self.id, &path.segments[..path.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };

        let parent_fid = self.walk(&parent).await?;
        let name = path.segments.last().cloned().unwrap_or_default();

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        // Tmkdir (9P2000.L)
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(72); // Tmkdir
        buf.put_u16_le(12);
        buf.put_u32_le(parent_fid);
        put_string(&mut buf, &name);
        buf.put_u32_le(0o755); // mode
        buf.put_u32_le(0); // gid

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        drop(conn_guard);
        self.get_metadata(path).await
    }

    async fn copy(&self, _from: &VirtualPath, _to: &VirtualPath) -> CfkResult<Entry> {
        Err(CfkError::Unsupported("9P does not support copy".into()))
    }

    async fn rename(&self, from: &VirtualPath, to: &VirtualPath) -> CfkResult<Entry> {
        // 9P2000.L has Trename
        let old_fid = self.walk(from).await?;
        let new_parent = if to.segments.len() > 1 {
            VirtualPath::new(&self.id, &to.segments[..to.segments.len() - 1].join("/"))
        } else {
            VirtualPath::new(&self.id, "")
        };
        let new_parent_fid = self.walk(&new_parent).await?;
        let new_name = to.segments.last().cloned().unwrap_or_default();

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        // Trenameat
        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(74); // Trenameat
        buf.put_u16_le(13);
        buf.put_u32_le(old_fid);
        put_string(&mut buf, from.segments.last().unwrap_or(&String::new()));
        buf.put_u32_le(new_parent_fid);
        put_string(&mut buf, &new_name);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            let error = parse_error(&reply)?;
            return Err(CfkError::ProviderApi {
                provider: "9p".into(),
                message: error,
            });
        }

        // Update cache
        {
            let mut cache = self.fid_cache.write().await;
            cache.remove(&from.to_string());
        }

        drop(conn_guard);
        self.get_metadata(to).await
    }

    async fn get_space_info(&self) -> CfkResult<(u64, u64)> {
        // 9P2000.L has Tstatfs
        let root = VirtualPath::new(&self.id, "");
        let fid = self.walk(&root).await?;

        let mut conn_guard = self.connection.write().await;
        let conn = conn_guard
            .as_mut()
            .ok_or_else(|| CfkError::Network("Not connected".into()))?;

        let mut buf = BytesMut::new();
        buf.put_u32_le(0);
        buf.put_u8(8); // Tstatfs
        buf.put_u16_le(14);
        buf.put_u32_le(fid);

        let size = buf.len() as u32;
        buf[0..4].copy_from_slice(&size.to_le_bytes());

        conn.stream
            .write_all(&buf)
            .await
            .map_err(|e| CfkError::Network(e.to_string()))?;

        let reply = read_message(&mut conn.stream).await?;
        if reply[4] == msg::RERROR {
            return Ok((0, 0));
        }

        let mut cursor = &reply[7..];
        let _type = cursor.get_u32_le();
        let bsize = cursor.get_u32_le() as u64;
        let blocks = cursor.get_u64_le();
        let bfree = cursor.get_u64_le();
        let bavail = cursor.get_u64_le();

        let total = blocks * bsize;
        let available = bavail * bsize;

        Ok((available, total))
    }
}
