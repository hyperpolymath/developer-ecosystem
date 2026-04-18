//! Content-addressed blob storage
//!
//! Stores file content using BLAKE3 hashes for deduplication.

use blake3::Hasher;
use bytes::Bytes;
use lz4_flex::{compress_prepend_size, decompress_size_prepended};
use std::path::{Path, PathBuf};
use tokio::fs;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

use crate::{CacheError, CacheResult};

/// Content identifier (BLAKE3 hash)
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ContentId(pub [u8; 32]);

impl ContentId {
    /// Create from raw bytes
    pub fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// Create from hex string
    pub fn from_hex(hex: &str) -> CacheResult<Self> {
        if hex.len() != 64 {
            return Err(CacheError::InvalidContentId);
        }

        let mut bytes = [0u8; 32];
        hex::decode_to_slice(hex, &mut bytes)
            .map_err(|_| CacheError::InvalidContentId)?;

        Ok(Self(bytes))
    }

    /// Convert to hex string
    pub fn to_hex(&self) -> String {
        hex::encode(self.0)
    }

    /// Get the storage path for this content ID
    fn storage_path(&self, base: &Path) -> PathBuf {
        let hex = self.to_hex();
        // Use first 2 chars as directory for sharding
        base.join(&hex[0..2]).join(&hex[2..])
    }
}

impl std::fmt::Display for ContentId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.to_hex())
    }
}

/// Blob storage configuration
#[derive(Debug, Clone)]
pub struct BlobStoreConfig {
    /// Base directory for blob storage
    pub path: PathBuf,
    /// Compress blobs with LZ4
    pub compress: bool,
    /// Minimum size to compress (bytes)
    pub compress_threshold: usize,
    /// Verify content on read
    pub verify_on_read: bool,
}

impl Default for BlobStoreConfig {
    fn default() -> Self {
        let cache_dir = directories::ProjectDirs::from("com", "cfk", "czech-file-knife")
            .map(|d| d.cache_dir().to_path_buf())
            .unwrap_or_else(|| PathBuf::from("/tmp/cfk-cache"));

        Self {
            path: cache_dir.join("blobs"),
            compress: true,
            compress_threshold: 1024, // 1KB
            verify_on_read: true,
        }
    }
}

/// Content-addressed blob store
pub struct BlobStore {
    config: BlobStoreConfig,
}

impl BlobStore {
    /// Create a new blob store
    pub async fn new(config: BlobStoreConfig) -> CacheResult<Self> {
        // Ensure base directory exists
        fs::create_dir_all(&config.path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        Ok(Self { config })
    }

    /// Create with default configuration
    pub async fn default_store() -> CacheResult<Self> {
        Self::new(BlobStoreConfig::default()).await
    }

    /// Compute content ID for data
    pub fn hash(data: &[u8]) -> ContentId {
        let hash = blake3::hash(data);
        ContentId(*hash.as_bytes())
    }

    /// Store blob and return content ID
    pub async fn put(&self, data: Bytes) -> CacheResult<ContentId> {
        let content_id = Self::hash(&data);
        let path = content_id.storage_path(&self.config.path);

        // Check if already exists
        if path.exists() {
            return Ok(content_id);
        }

        // Create parent directory
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;
        }

        // Compress if enabled and above threshold
        let stored_data = if self.config.compress && data.len() >= self.config.compress_threshold {
            let compressed = compress_prepend_size(&data);
            // Only use compressed if it's smaller
            if compressed.len() < data.len() {
                Bytes::from(compressed)
            } else {
                data
            }
        } else {
            data
        };

        // Write atomically using temp file
        let temp_path = path.with_extension("tmp");
        let mut file = fs::File::create(&temp_path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        file.write_all(&stored_data)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        file.sync_all()
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        // Rename to final path
        fs::rename(&temp_path, &path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        Ok(content_id)
    }

    /// Retrieve blob by content ID
    pub async fn get(&self, content_id: &ContentId) -> CacheResult<Bytes> {
        let path = content_id.storage_path(&self.config.path);

        if !path.exists() {
            return Err(CacheError::NotFound(content_id.to_string()));
        }

        let mut file = fs::File::open(&path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        let mut data = Vec::new();
        file.read_to_end(&mut data)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        // Try to decompress
        let decompressed = match decompress_size_prepended(&data) {
            Ok(d) => Bytes::from(d),
            Err(_) => Bytes::from(data), // Not compressed
        };

        // Verify content if enabled
        if self.config.verify_on_read {
            let computed_id = Self::hash(&decompressed);
            if computed_id != *content_id {
                return Err(CacheError::CorruptedContent(content_id.to_string()));
            }
        }

        Ok(decompressed)
    }

    /// Check if blob exists
    pub async fn exists(&self, content_id: &ContentId) -> bool {
        let path = content_id.storage_path(&self.config.path);
        path.exists()
    }

    /// Delete blob by content ID
    pub async fn delete(&self, content_id: &ContentId) -> CacheResult<()> {
        let path = content_id.storage_path(&self.config.path);

        if path.exists() {
            fs::remove_file(&path)
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;
        }

        Ok(())
    }

    /// Get size of stored blob (compressed size)
    pub async fn size(&self, content_id: &ContentId) -> CacheResult<u64> {
        let path = content_id.storage_path(&self.config.path);

        let metadata = fs::metadata(&path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        Ok(metadata.len())
    }

    /// Get total size of blob store
    pub async fn total_size(&self) -> CacheResult<u64> {
        let mut total = 0u64;

        let mut entries = fs::read_dir(&self.config.path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        while let Some(entry) = entries
            .next_entry()
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?
        {
            if entry.path().is_dir() {
                let mut subdir = fs::read_dir(entry.path())
                    .await
                    .map_err(|e| CacheError::Io(e.to_string()))?;

                while let Some(file) = subdir
                    .next_entry()
                    .await
                    .map_err(|e| CacheError::Io(e.to_string()))?
                {
                    if let Ok(meta) = file.metadata().await {
                        total += meta.len();
                    }
                }
            }
        }

        Ok(total)
    }

    /// List all content IDs
    pub async fn list(&self) -> CacheResult<Vec<ContentId>> {
        let mut ids = Vec::new();

        let mut entries = fs::read_dir(&self.config.path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        while let Some(entry) = entries
            .next_entry()
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?
        {
            let dir_name = entry.file_name().to_string_lossy().to_string();
            if dir_name.len() != 2 || !entry.path().is_dir() {
                continue;
            }

            let mut subdir = fs::read_dir(entry.path())
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;

            while let Some(file) = subdir
                .next_entry()
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?
            {
                let file_name = file.file_name().to_string_lossy().to_string();
                let hex = format!("{}{}", dir_name, file_name);

                if let Ok(id) = ContentId::from_hex(&hex) {
                    ids.push(id);
                }
            }
        }

        Ok(ids)
    }

    /// Garbage collect blobs not in the provided set
    pub async fn gc(&self, keep: &std::collections::HashSet<ContentId>) -> CacheResult<u64> {
        let mut freed = 0u64;

        let all_ids = self.list().await?;

        for id in all_ids {
            if !keep.contains(&id) {
                if let Ok(size) = self.size(&id).await {
                    freed += size;
                }
                self.delete(&id).await?;
            }
        }

        Ok(freed)
    }
}

/// Streaming blob writer for large files
pub struct BlobWriter {
    hasher: Hasher,
    temp_path: PathBuf,
    file: Option<fs::File>,
    compress: bool,
    buffer: Vec<u8>,
}

impl BlobWriter {
    /// Create a new blob writer
    pub async fn new(store: &BlobStore) -> CacheResult<Self> {
        let temp_path = store
            .config
            .path
            .join(format!("upload_{}", uuid_simple()));

        let file = fs::File::create(&temp_path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        Ok(Self {
            hasher: Hasher::new(),
            temp_path,
            file: Some(file),
            compress: store.config.compress,
            buffer: Vec::new(),
        })
    }

    /// Write data chunk
    pub async fn write(&mut self, data: &[u8]) -> CacheResult<()> {
        self.hasher.update(data);

        if let Some(ref mut file) = self.file {
            file.write_all(data)
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;
        }

        Ok(())
    }

    /// Finish writing and return content ID
    pub async fn finish(mut self, store: &BlobStore) -> CacheResult<ContentId> {
        if let Some(mut file) = self.file.take() {
            file.sync_all()
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;
        }

        let hash = self.hasher.finalize();
        let content_id = ContentId(*hash.as_bytes());

        let final_path = content_id.storage_path(&store.config.path);

        // Create parent directory
        if let Some(parent) = final_path.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;
        }

        // Compress if needed
        if self.compress {
            let data = fs::read(&self.temp_path)
                .await
                .map_err(|e| CacheError::Io(e.to_string()))?;

            let compressed = compress_prepend_size(&data);
            if compressed.len() < data.len() {
                fs::write(&final_path, &compressed)
                    .await
                    .map_err(|e| CacheError::Io(e.to_string()))?;
                fs::remove_file(&self.temp_path)
                    .await
                    .map_err(|e| CacheError::Io(e.to_string()))?;
                return Ok(content_id);
            }
        }

        // Move temp file to final location
        fs::rename(&self.temp_path, &final_path)
            .await
            .map_err(|e| CacheError::Io(e.to_string()))?;

        Ok(content_id)
    }
}

/// Generate a simple UUID-like string
fn uuid_simple() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};

    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();

    format!("{:x}{:x}", duration.as_secs(), duration.subsec_nanos())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_blob_store() {
        let config = BlobStoreConfig {
            path: PathBuf::from("/tmp/cfk-test-blobs"),
            compress: true,
            compress_threshold: 10,
            verify_on_read: true,
        };

        let store = BlobStore::new(config).await.unwrap();

        // Store data
        let data = Bytes::from("Hello, World!");
        let id = store.put(data.clone()).await.unwrap();

        // Retrieve data
        let retrieved = store.get(&id).await.unwrap();
        assert_eq!(data, retrieved);

        // Check exists
        assert!(store.exists(&id).await);

        // Delete
        store.delete(&id).await.unwrap();
        assert!(!store.exists(&id).await);
    }
}
