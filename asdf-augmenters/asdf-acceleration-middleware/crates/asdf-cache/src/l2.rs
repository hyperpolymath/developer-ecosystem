//! L2: Sled embedded database cache

use crate::{CacheEntry, Error, Result};
use serde::{de::DeserializeOwned, Serialize};
use std::path::Path;
use std::time::Duration;

/// Disk-backed cache using Sled
pub struct DiskCache {
    db: sled::Db,
}

impl DiskCache {
    /// Open or create a disk cache at the given path
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let db = sled::open(path)?;
        Ok(Self { db })
    }

    /// Get a value from the cache
    pub fn get<V: DeserializeOwned>(&self, key: &str) -> Result<V> {
        let bytes = self.db.get(key)?.ok_or(Error::Miss)?;

        let entry: CacheEntry<V> = bincode::deserialize(&bytes)?;

        if entry.is_expired() {
            self.db.remove(key)?;
            Err(Error::Expired)
        } else {
            Ok(entry.value)
        }
    }

    /// Insert a value into the cache
    pub fn insert<V: Serialize>(&self, key: &str, value: V, ttl: Duration) -> Result<()> {
        let entry = CacheEntry::new(value, ttl);
        let bytes = bincode::serialize(&entry)?;
        self.db.insert(key, bytes)?;
        Ok(())
    }

    /// Remove a value from the cache
    pub fn remove(&self, key: &str) -> Result<bool> {
        Ok(self.db.remove(key)?.is_some())
    }

    /// Clear all entries
    pub fn clear(&self) -> Result<()> {
        self.db.clear()?;
        Ok(())
    }

    /// Flush to disk
    pub fn flush(&self) -> Result<()> {
        self.db.flush()?;
        Ok(())
    }

    /// Get the number of entries
    pub fn len(&self) -> usize {
        self.db.len()
    }

    /// Check if the cache is empty
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Clean expired entries
    pub fn clean_expired(&self) -> Result<usize> {
        let mut removed = 0;

        for item in self.db.iter() {
            let (key, value) = item?;

            // Try to deserialize as a generic entry to check expiry
            if let Ok(entry) = bincode::deserialize::<CacheEntry<Vec<u8>>>(&value) {
                if entry.is_expired() {
                    self.db.remove(key)?;
                    removed += 1;
                }
            }
        }

        Ok(removed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_disk_cache_basic() {
        let dir = TempDir::new().unwrap();
        let cache = DiskCache::open(dir.path()).unwrap();

        cache
            .insert("key1", "value1".to_string(), Duration::from_secs(3600))
            .unwrap();

        let value: String = cache.get("key1").unwrap();
        assert_eq!(value, "value1");
    }

    #[test]
    fn test_disk_cache_miss() {
        let dir = TempDir::new().unwrap();
        let cache = DiskCache::open(dir.path()).unwrap();

        let result: Result<String> = cache.get("nonexistent");
        assert!(result.is_err());
    }

    #[test]
    fn test_disk_cache_expiry() {
        let dir = TempDir::new().unwrap();
        let cache = DiskCache::open(dir.path()).unwrap();

        cache
            .insert("key1", "value1".to_string(), Duration::from_secs(0))
            .unwrap();

        std::thread::sleep(Duration::from_millis(10));

        let result: Result<String> = cache.get("key1");
        assert!(result.is_err());
    }

    #[test]
    fn test_disk_cache_persistence() {
        let dir = TempDir::new().unwrap();

        {
            let cache = DiskCache::open(dir.path()).unwrap();
            cache
                .insert("key1", "value1".to_string(), Duration::from_secs(3600))
                .unwrap();
            cache.flush().unwrap();
        }

        // Reopen and verify data persisted
        {
            let cache = DiskCache::open(dir.path()).unwrap();
            let value: String = cache.get("key1").unwrap();
            assert_eq!(value, "value1");
        }
    }
}
