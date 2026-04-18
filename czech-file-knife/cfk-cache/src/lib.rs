//! Offline caching layer for Czech File Knife
//!
//! Features:
//! - Content-addressed blob storage with BLAKE3 hashing
//! - LZ4 compression for efficient storage
//! - Metadata caching with TTL support
//! - Multiple eviction policies (LRU, LFU, FIFO, etc.)
//!
//! Supports multiple backends:
//! - sled: Pure Rust embedded KV (default)
//! - SurrealDB: Multi-model with graph queries
//! - redb: Pure Rust alternative to sled
//! - LMDB: Ultra-fast memory-mapped (via heed)
//! - DragonflyDB: Redis-compatible (via redis crate)

#![allow(dead_code)] // Placeholder structs for future implementation

use async_trait::async_trait;
use cfk_core::{CfkResult, VirtualPath, Entry};
use bytes::Bytes;
use thiserror::Error;

pub mod blob_store;
pub mod metadata_cache;
pub mod policy;

pub use blob_store::{BlobStore, BlobStoreConfig, ContentId};
pub use metadata_cache::{MetadataCache, MetadataCacheConfig, CachedEntry};
pub use policy::{CachePolicy, PolicyConfig, EvictionPolicy};

/// Cache-specific errors
#[derive(Debug, Error)]
pub enum CacheError {
    #[error("I/O error: {0}")]
    Io(String),

    #[error("Database error: {0}")]
    Database(String),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Content not found: {0}")]
    NotFound(String),

    #[error("Invalid content ID")]
    InvalidContentId,

    #[error("Corrupted content: {0}")]
    CorruptedContent(String),

    #[error("Cache full")]
    CacheFull,
}

/// Cache result type
pub type CacheResult<T> = Result<T, CacheError>;

/// Cache trait for different backends
#[async_trait]
pub trait CacheBackend: Send + Sync {
    /// Get cached entry metadata
    async fn get_metadata(&self, path: &VirtualPath) -> CfkResult<Option<Entry>>;

    /// Store entry metadata
    async fn put_metadata(&self, path: &VirtualPath, entry: &Entry) -> CfkResult<()>;

    /// Get cached file content
    async fn get_content(&self, content_hash: &str) -> CfkResult<Option<Bytes>>;

    /// Store file content (content-addressed)
    async fn put_content(&self, data: &[u8]) -> CfkResult<String>;

    /// Delete cached entry
    async fn delete(&self, path: &VirtualPath) -> CfkResult<()>;

    /// Clear all cache
    async fn clear(&self) -> CfkResult<()>;

    /// Get cache statistics
    async fn stats(&self) -> CfkResult<CacheStats>;
}

/// Cache statistics
#[derive(Debug, Clone, Default)]
pub struct CacheStats {
    pub entries: u64,
    pub total_size: u64,
    pub hit_count: u64,
    pub miss_count: u64,
}

impl CacheStats {
    pub fn hit_rate(&self) -> f64 {
        let total = self.hit_count + self.miss_count;
        if total == 0 { 0.0 } else { self.hit_count as f64 / total as f64 }
    }
}

/// Content-addressed blob storage
pub mod blob {
    use super::*;
    use blake3::Hasher;
    use lz4_flex::{compress_prepend_size, decompress_size_prepended};

    /// Hash content using BLAKE3
    pub fn hash_content(data: &[u8]) -> String {
        let mut hasher = Hasher::new();
        hasher.update(data);
        hasher.finalize().to_hex().to_string()
    }

    /// Compress data using LZ4
    pub fn compress(data: &[u8]) -> Vec<u8> {
        compress_prepend_size(data)
    }

    /// Decompress LZ4 data
    pub fn decompress(data: &[u8]) -> CfkResult<Vec<u8>> {
        decompress_size_prepended(data)
            .map_err(|e| cfk_core::CfkError::Cache(e.to_string()))
    }
}

/// LRU eviction policy
pub mod eviction {
    use std::collections::VecDeque;

    pub struct LruPolicy {
        max_size: u64,
        max_entries: usize,
        entries: VecDeque<(String, u64)>,  // (hash, size)
    }

    impl LruPolicy {
        pub fn new(max_size: u64, max_entries: usize) -> Self {
            Self {
                max_size,
                max_entries,
                entries: VecDeque::new(),
            }
        }

        pub fn access(&mut self, hash: &str, size: u64) {
            // Move to front
            self.entries.retain(|(h, _)| h != hash);
            self.entries.push_front((hash.to_string(), size));
        }

        pub fn evict_candidates(&self, needed_space: u64) -> Vec<String> {
            let mut freed = 0u64;
            let mut to_evict = Vec::new();

            for (hash, size) in self.entries.iter().rev() {
                if freed >= needed_space {
                    break;
                }
                to_evict.push(hash.clone());
                freed += size;
            }

            to_evict
        }
    }
}

#[cfg(feature = "sled")]
pub mod sled_backend;

#[cfg(feature = "surrealdb")]
pub mod surreal_backend;

#[cfg(feature = "lmdb")]
pub mod lmdb_backend;

#[cfg(feature = "dragonfly")]
pub mod dragonfly_backend;
