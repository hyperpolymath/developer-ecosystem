// SPDX-License-Identifier: AGPL-3.0-or-later
//! File metadata caching
//!
//! Caches file and directory metadata for offline access and performance.

use cfk_core::{Entry, EntryKind, Metadata, VirtualPath};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::blob_store::ContentId;
use crate::{CacheError, CacheResult};

/// Cached entry metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CachedEntry {
    /// Virtual path
    pub path: String,
    /// Backend ID
    pub backend_id: String,
    /// Entry kind
    pub kind: CachedEntryKind,
    /// File size (for files)
    pub size: Option<u64>,
    /// Last modified time
    pub modified: Option<DateTime<Utc>>,
    /// Created time
    pub created: Option<DateTime<Utc>>,
    /// Content hash/checksum from provider
    pub checksum: Option<String>,
    /// MIME type
    pub mime_type: Option<String>,
    /// Local blob content ID (if cached)
    pub content_id: Option<String>,
    /// When this entry was cached
    pub cached_at: DateTime<Utc>,
    /// When this entry expires
    pub expires_at: Option<DateTime<Utc>>,
    /// Custom metadata
    #[serde(default)]
    pub custom: HashMap<String, String>,
}

/// Cached entry kind
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum CachedEntryKind {
    File,
    Directory,
    Symlink,
    Unknown,
}

impl From<EntryKind> for CachedEntryKind {
    fn from(kind: EntryKind) -> Self {
        match kind {
            EntryKind::File => CachedEntryKind::File,
            EntryKind::Directory => CachedEntryKind::Directory,
            EntryKind::Symlink => CachedEntryKind::Symlink,
            EntryKind::Unknown => CachedEntryKind::Unknown,
        }
    }
}

impl From<CachedEntryKind> for EntryKind {
    fn from(kind: CachedEntryKind) -> Self {
        match kind {
            CachedEntryKind::File => EntryKind::File,
            CachedEntryKind::Directory => EntryKind::Directory,
            CachedEntryKind::Symlink => EntryKind::Symlink,
            CachedEntryKind::Unknown => EntryKind::Unknown,
        }
    }
}

impl CachedEntry {
    /// Create from cfk_core Entry
    pub fn from_entry(entry: &Entry, ttl_secs: Option<i64>) -> Self {
        Self {
            path: entry.path.to_string(),
            backend_id: entry.path.backend.clone(),
            kind: entry.kind.into(),
            size: entry.metadata.size,
            modified: entry.metadata.modified,
            created: entry.metadata.created,
            checksum: entry.metadata.content_hash.clone(),
            mime_type: entry.metadata.mime_type.clone(),
            content_id: None,
            cached_at: Utc::now(),
            expires_at: ttl_secs.map(|secs| Utc::now() + chrono::Duration::seconds(secs)),
            custom: entry.metadata.custom.clone(),
        }
    }

    /// Convert back to cfk_core Entry
    pub fn to_entry(&self) -> Entry {
        let mut metadata = Metadata::default();
        metadata.size = self.size;
        metadata.modified = self.modified;
        metadata.created = self.created;
        metadata.content_hash = self.checksum.clone();
        metadata.mime_type = self.mime_type.clone();
        metadata.custom = self.custom.clone();

        Entry {
            path: VirtualPath::parse_uri(&self.path).unwrap_or_else(|| {
                VirtualPath::new(&self.backend_id, &self.path)
            }),
            kind: self.kind.into(),
            metadata,
        }
    }

    /// Check if entry is expired
    pub fn is_expired(&self) -> bool {
        if let Some(expires) = self.expires_at {
            Utc::now() > expires
        } else {
            false
        }
    }

    /// Set content ID after caching content
    pub fn with_content_id(mut self, content_id: &ContentId) -> Self {
        self.content_id = Some(content_id.to_hex());
        self
    }
}

/// Cached directory listing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CachedDirectory {
    /// Directory path
    pub path: String,
    /// Backend ID
    pub backend_id: String,
    /// Child entry paths
    pub children: Vec<String>,
    /// When this listing was cached
    pub cached_at: DateTime<Utc>,
    /// When this listing expires
    pub expires_at: Option<DateTime<Utc>>,
}

impl CachedDirectory {
    /// Create new cached directory
    pub fn new(path: &VirtualPath, children: Vec<String>, ttl_secs: Option<i64>) -> Self {
        Self {
            path: path.to_string(),
            backend_id: path.backend.clone(),
            children,
            cached_at: Utc::now(),
            expires_at: ttl_secs.map(|secs| Utc::now() + chrono::Duration::seconds(secs)),
        }
    }

    /// Check if listing is expired
    pub fn is_expired(&self) -> bool {
        if let Some(expires) = self.expires_at {
            Utc::now() > expires
        } else {
            false
        }
    }
}

/// Metadata cache configuration
#[derive(Debug, Clone)]
pub struct MetadataCacheConfig {
    /// Database path (sled)
    pub db_path: PathBuf,
    /// Default TTL for entries (seconds)
    pub default_ttl: i64,
    /// Maximum entries to cache
    pub max_entries: usize,
}

impl Default for MetadataCacheConfig {
    fn default() -> Self {
        let cache_dir = directories::ProjectDirs::from("com", "cfk", "czech-file-knife")
            .map(|d| d.cache_dir().to_path_buf())
            .unwrap_or_else(|| PathBuf::from("/tmp/cfk-cache"));

        Self {
            db_path: cache_dir.join("metadata.db"),
            default_ttl: 3600, // 1 hour
            max_entries: 100000,
        }
    }
}

/// Metadata cache
pub struct MetadataCache {
    config: MetadataCacheConfig,
    db: sled::Db,
    /// In-memory LRU cache for hot entries
    memory_cache: Arc<RwLock<lru::LruCache<String, CachedEntry>>>,
}

impl MetadataCache {
    /// Create new metadata cache
    pub fn new(config: MetadataCacheConfig) -> CacheResult<Self> {
        let db = sled::open(&config.db_path)
            .map_err(|e| CacheError::Database(e.to_string()))?;

        let memory_cache = Arc::new(RwLock::new(lru::LruCache::new(
            std::num::NonZeroUsize::new(10000).unwrap(),
        )));

        Ok(Self {
            config,
            db,
            memory_cache,
        })
    }

    /// Create with default configuration
    pub fn default_cache() -> CacheResult<Self> {
        Self::new(MetadataCacheConfig::default())
    }

    /// Cache entry metadata
    pub async fn put_entry(&self, entry: &Entry) -> CacheResult<()> {
        let cached = CachedEntry::from_entry(entry, Some(self.config.default_ttl));
        let key = entry.path.to_string();
        let value = serde_json::to_vec(&cached)
            .map_err(|e| CacheError::Serialization(e.to_string()))?;

        self.db
            .insert(format!("entry:{}", key), value)
            .map_err(|e| CacheError::Database(e.to_string()))?;

        // Update memory cache
        self.memory_cache.write().await.put(key, cached);

        Ok(())
    }

    /// Cache entry with custom TTL
    pub async fn put_entry_with_ttl(&self, entry: &Entry, ttl_secs: i64) -> CacheResult<()> {
        let cached = CachedEntry::from_entry(entry, Some(ttl_secs));
        let key = entry.path.to_string();
        let value = serde_json::to_vec(&cached)
            .map_err(|e| CacheError::Serialization(e.to_string()))?;

        self.db
            .insert(format!("entry:{}", key), value)
            .map_err(|e| CacheError::Database(e.to_string()))?;

        self.memory_cache.write().await.put(key, cached);

        Ok(())
    }

    /// Get cached entry
    pub async fn get_entry(&self, path: &VirtualPath) -> CacheResult<Option<CachedEntry>> {
        let key = path.to_string();

        // Check memory cache first
        {
            let mut cache = self.memory_cache.write().await;
            if let Some(entry) = cache.get(&key) {
                if !entry.is_expired() {
                    return Ok(Some(entry.clone()));
                }
            }
        }

        // Check database
        let db_key = format!("entry:{}", key);
        if let Some(data) = self.db.get(&db_key).map_err(|e| CacheError::Database(e.to_string()))? {
            let cached: CachedEntry = serde_json::from_slice(&data)
                .map_err(|e| CacheError::Serialization(e.to_string()))?;

            if cached.is_expired() {
                // Remove expired entry
                self.db
                    .remove(&db_key)
                    .map_err(|e| CacheError::Database(e.to_string()))?;
                return Ok(None);
            }

            // Add to memory cache
            self.memory_cache.write().await.put(key, cached.clone());

            return Ok(Some(cached));
        }

        Ok(None)
    }

    /// Cache directory listing
    pub async fn put_directory(&self, path: &VirtualPath, entries: &[Entry]) -> CacheResult<()> {
        let children: Vec<String> = entries.iter().map(|e| e.path.to_string()).collect();
        let cached = CachedDirectory::new(path, children, Some(self.config.default_ttl));

        let key = format!("dir:{}", path);
        let value = serde_json::to_vec(&cached)
            .map_err(|e| CacheError::Serialization(e.to_string()))?;

        self.db
            .insert(key, value)
            .map_err(|e| CacheError::Database(e.to_string()))?;

        // Also cache individual entries
        for entry in entries {
            self.put_entry(entry).await?;
        }

        Ok(())
    }

    /// Get cached directory listing
    pub async fn get_directory(&self, path: &VirtualPath) -> CacheResult<Option<Vec<Entry>>> {
        let key = format!("dir:{}", path);

        if let Some(data) = self.db.get(&key).map_err(|e| CacheError::Database(e.to_string()))? {
            let cached: CachedDirectory = serde_json::from_slice(&data)
                .map_err(|e| CacheError::Serialization(e.to_string()))?;

            if cached.is_expired() {
                self.db
                    .remove(&key)
                    .map_err(|e| CacheError::Database(e.to_string()))?;
                return Ok(None);
            }

            // Fetch individual entries
            let mut entries = Vec::new();
            for child_path in &cached.children {
                let virtual_path = VirtualPath::parse_uri(child_path).unwrap_or_else(|| {
                    VirtualPath::new(&cached.backend_id, child_path)
                });

                if let Some(entry) = self.get_entry(&virtual_path).await? {
                    entries.push(entry.to_entry());
                }
            }

            return Ok(Some(entries));
        }

        Ok(None)
    }

    /// Invalidate entry
    pub async fn invalidate(&self, path: &VirtualPath) -> CacheResult<()> {
        let key = path.to_string();

        self.db
            .remove(format!("entry:{}", key))
            .map_err(|e| CacheError::Database(e.to_string()))?;

        self.memory_cache.write().await.pop(&key);

        Ok(())
    }

    /// Invalidate directory and all children
    pub async fn invalidate_directory(&self, path: &VirtualPath) -> CacheResult<()> {
        let prefix = format!("entry:{}:", path);

        // Remove all entries with this prefix
        for result in self.db.scan_prefix(&prefix) {
            if let Ok((key, _)) = result {
                self.db
                    .remove(&key)
                    .map_err(|e| CacheError::Database(e.to_string()))?;
            }
        }

        // Remove directory listing
        self.db
            .remove(format!("dir:{}", path))
            .map_err(|e| CacheError::Database(e.to_string()))?;

        Ok(())
    }

    /// Clear all cached data for a backend
    pub async fn clear_backend(&self, backend_id: &str) -> CacheResult<()> {
        let prefix = format!("entry:{}:", backend_id);

        for result in self.db.scan_prefix(&prefix) {
            if let Ok((key, _)) = result {
                self.db
                    .remove(&key)
                    .map_err(|e| CacheError::Database(e.to_string()))?;
            }
        }

        let dir_prefix = format!("dir:{}:", backend_id);
        for result in self.db.scan_prefix(&dir_prefix) {
            if let Ok((key, _)) = result {
                self.db
                    .remove(&key)
                    .map_err(|e| CacheError::Database(e.to_string()))?;
            }
        }

        self.memory_cache.write().await.clear();

        Ok(())
    }

    /// Clear all cached data
    pub async fn clear_all(&self) -> CacheResult<()> {
        self.db.clear().map_err(|e| CacheError::Database(e.to_string()))?;
        self.memory_cache.write().await.clear();
        Ok(())
    }

    /// Get cache statistics
    pub async fn stats(&self) -> CacheStats {
        let entry_count = self.db.scan_prefix("entry:").count();
        let dir_count = self.db.scan_prefix("dir:").count();
        let memory_size = self.memory_cache.read().await.len();
        let db_size = self.db.size_on_disk().unwrap_or(0);

        CacheStats {
            entry_count,
            directory_count: dir_count,
            memory_entries: memory_size,
            disk_size_bytes: db_size,
        }
    }

    /// Prune expired entries
    pub async fn prune_expired(&self) -> CacheResult<usize> {
        let mut pruned = 0;

        for result in self.db.scan_prefix("entry:") {
            if let Ok((key, value)) = result {
                if let Ok(cached) = serde_json::from_slice::<CachedEntry>(&value) {
                    if cached.is_expired() {
                        self.db
                            .remove(&key)
                            .map_err(|e| CacheError::Database(e.to_string()))?;
                        pruned += 1;
                    }
                }
            }
        }

        for result in self.db.scan_prefix("dir:") {
            if let Ok((key, value)) = result {
                if let Ok(cached) = serde_json::from_slice::<CachedDirectory>(&value) {
                    if cached.is_expired() {
                        self.db
                            .remove(&key)
                            .map_err(|e| CacheError::Database(e.to_string()))?;
                        pruned += 1;
                    }
                }
            }
        }

        Ok(pruned)
    }
}

/// Cache statistics
#[derive(Debug, Clone, Default)]
pub struct CacheStats {
    pub entry_count: usize,
    pub directory_count: usize,
    pub memory_entries: usize,
    pub disk_size_bytes: u64,
}

/// Simple LRU cache implementation
mod lru {
    use std::collections::HashMap;
    use std::hash::Hash;
    use std::num::NonZeroUsize;

    pub struct LruCache<K, V> {
        map: HashMap<K, V>,
        order: Vec<K>,
        capacity: usize,
    }

    impl<K: Eq + Hash + Clone, V> LruCache<K, V> {
        pub fn new(capacity: NonZeroUsize) -> Self {
            Self {
                map: HashMap::new(),
                order: Vec::new(),
                capacity: capacity.get(),
            }
        }

        pub fn get(&mut self, key: &K) -> Option<&V> {
            if self.map.contains_key(key) {
                // Move to front
                self.order.retain(|k| k != key);
                self.order.push(key.clone());
                self.map.get(key)
            } else {
                None
            }
        }

        pub fn put(&mut self, key: K, value: V) {
            if self.map.contains_key(&key) {
                self.order.retain(|k| k != &key);
            } else if self.map.len() >= self.capacity {
                // Evict oldest
                if let Some(oldest) = self.order.first().cloned() {
                    self.map.remove(&oldest);
                    self.order.remove(0);
                }
            }

            self.map.insert(key.clone(), value);
            self.order.push(key);
        }

        pub fn pop(&mut self, key: &K) -> Option<V> {
            self.order.retain(|k| k != key);
            self.map.remove(key)
        }

        pub fn len(&self) -> usize {
            self.map.len()
        }

        pub fn clear(&mut self) {
            self.map.clear();
            self.order.clear();
        }
    }
}
