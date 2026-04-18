// SPDX-License-Identifier: AGPL-3.0-or-later
//! Sled database backend for cache storage

use sled::Db;
use std::path::Path;

use crate::{CacheError, CacheResult};

/// Sled-based storage backend
pub struct SledBackend {
    db: Db,
}

impl SledBackend {
    /// Open or create a sled database at the given path
    pub fn open(path: impl AsRef<Path>) -> CacheResult<Self> {
        let db = sled::open(path).map_err(|e| CacheError::Database(e.to_string()))?;
        Ok(Self { db })
    }

    /// Get a value by key
    pub fn get(&self, key: &[u8]) -> CacheResult<Option<Vec<u8>>> {
        self.db
            .get(key)
            .map_err(|e| CacheError::Database(e.to_string()))
            .map(|opt| opt.map(|v| v.to_vec()))
    }

    /// Insert a key-value pair
    pub fn insert(&self, key: &[u8], value: &[u8]) -> CacheResult<()> {
        self.db
            .insert(key, value)
            .map_err(|e| CacheError::Database(e.to_string()))?;
        Ok(())
    }

    /// Remove a key
    pub fn remove(&self, key: &[u8]) -> CacheResult<Option<Vec<u8>>> {
        self.db
            .remove(key)
            .map_err(|e| CacheError::Database(e.to_string()))
            .map(|opt| opt.map(|v| v.to_vec()))
    }

    /// Flush to disk
    pub fn flush(&self) -> CacheResult<()> {
        self.db
            .flush()
            .map_err(|e| CacheError::Database(e.to_string()))?;
        Ok(())
    }

    /// Iterate over all keys with a given prefix
    pub fn scan_prefix(&self, prefix: &[u8]) -> impl Iterator<Item = CacheResult<(Vec<u8>, Vec<u8>)>> + '_ {
        self.db.scan_prefix(prefix).map(|result| {
            result
                .map(|(k, v)| (k.to_vec(), v.to_vec()))
                .map_err(|e| CacheError::Database(e.to_string()))
        })
    }

    /// Clear all data
    pub fn clear(&self) -> CacheResult<()> {
        self.db
            .clear()
            .map_err(|e| CacheError::Database(e.to_string()))?;
        Ok(())
    }

    /// Get database size on disk
    pub fn size_on_disk(&self) -> CacheResult<u64> {
        self.db
            .size_on_disk()
            .map_err(|e| CacheError::Database(e.to_string()))
    }
}
