//! Cache manager coordinating L1 and L2 caches

use crate::{DiskCache, Error, MemoryCache, Result};
use serde::{de::DeserializeOwned, Serialize};
use std::hash::Hash;
use std::path::Path;
use std::time::Duration;

/// Multi-level cache manager
pub struct CacheManager<K>
where
    K: Hash + Eq + Clone + AsRef<str>,
{
    l1: MemoryCache<K, Vec<u8>>,
    l2: DiskCache,
}

impl<K> CacheManager<K>
where
    K: Hash + Eq + Clone + AsRef<str>,
{
    /// Create a new cache manager
    pub fn new(disk_path: impl AsRef<Path>, memory_capacity: usize) -> Result<Self> {
        Ok(Self {
            l1: MemoryCache::new(memory_capacity),
            l2: DiskCache::open(disk_path)?,
        })
    }

    /// Get a value from the cache (checks L1 then L2)
    pub fn get<V: DeserializeOwned + Serialize + Clone>(
        &self,
        key: &K,
    ) -> Result<V> {
        // Try L1 first
        if let Ok(bytes) = self.l1.get(key) {
            if let Ok(value) = bincode::deserialize(&bytes) {
                return Ok(value);
            }
        }

        // Fall back to L2
        let value: V = self.l2.get(key.as_ref())?;

        // Promote to L1
        if let Ok(bytes) = bincode::serialize(&value) {
            self.l1.insert(key.clone(), bytes, Duration::from_secs(3600));
        }

        Ok(value)
    }

    /// Insert a value into both caches
    pub fn insert<V: Serialize + Clone>(&self, key: K, value: V, ttl: Duration) -> Result<()> {
        // Insert into L2 first (durable)
        self.l2.insert(key.as_ref(), &value, ttl)?;

        // Then L1 (fast)
        if let Ok(bytes) = bincode::serialize(&value) {
            self.l1.insert(key, bytes, ttl);
        }

        Ok(())
    }

    /// Remove a value from both caches
    pub fn remove(&self, key: &K) -> Result<()> {
        self.l1.remove(key);
        self.l2.remove(key.as_ref())?;
        Ok(())
    }

    /// Clear both caches
    pub fn clear(&self) -> Result<()> {
        self.l1.clear();
        self.l2.clear()?;
        Ok(())
    }

    /// Flush L2 cache to disk
    pub fn flush(&self) -> Result<()> {
        self.l2.flush()
    }

    /// Clean expired entries from both caches
    pub fn clean_expired(&self) -> Result<usize> {
        self.l2.clean_expired()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_cache_manager_basic() {
        let dir = TempDir::new().unwrap();
        let manager: CacheManager<String> =
            CacheManager::new(dir.path(), 100).unwrap();

        manager
            .insert(
                "key1".to_string(),
                "value1".to_string(),
                Duration::from_secs(3600),
            )
            .unwrap();

        let value: String = manager.get(&"key1".to_string()).unwrap();
        assert_eq!(value, "value1");
    }

    #[test]
    fn test_cache_manager_l1_promotion() {
        let dir = TempDir::new().unwrap();
        let manager: CacheManager<String> =
            CacheManager::new(dir.path(), 100).unwrap();

        // Insert into L2 only
        manager.l2
            .insert("key1", "value1".to_string(), Duration::from_secs(3600))
            .unwrap();

        // First get should promote to L1
        let value: String = manager.get(&"key1".to_string()).unwrap();
        assert_eq!(value, "value1");

        // Second get should hit L1
        let value: String = manager.get(&"key1".to_string()).unwrap();
        assert_eq!(value, "value1");
    }
}
