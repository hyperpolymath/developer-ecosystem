//! Multi-level caching system for asdf operations
//!
//! Provides:
//! - L1: In-memory LRU cache
//! - L2: Sled embedded database
//! - L3: Filesystem cache

pub mod error;
pub mod l1;
pub mod l2;
pub mod manager;

pub use error::{Error, Result};
pub use l1::MemoryCache;
pub use l2::DiskCache;
pub use manager::CacheManager;

use serde::{Deserialize, Serialize};
use std::time::{Duration, SystemTime};

/// Cache entry with TTL
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheEntry<T> {
    /// The cached value
    pub value: T,

    /// When this entry was created
    pub created_at: SystemTime,

    /// Time-to-live in seconds
    pub ttl_secs: u64,
}

impl<T> CacheEntry<T> {
    /// Create a new cache entry
    pub fn new(value: T, ttl: Duration) -> Self {
        Self {
            value,
            created_at: SystemTime::now(),
            ttl_secs: ttl.as_secs(),
        }
    }

    /// Check if this entry is expired
    pub fn is_expired(&self) -> bool {
        if let Ok(elapsed) = self.created_at.elapsed() {
            elapsed.as_secs() > self.ttl_secs
        } else {
            true
        }
    }

    /// Get remaining TTL
    pub fn remaining_ttl(&self) -> Option<Duration> {
        if self.is_expired() {
            None
        } else {
            let elapsed = self.created_at.elapsed().ok()?;
            let ttl = Duration::from_secs(self.ttl_secs);
            ttl.checked_sub(elapsed)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_entry_new() {
        let entry = CacheEntry::new("value", Duration::from_secs(3600));
        assert_eq!(entry.value, "value");
        assert!(!entry.is_expired());
    }

    #[test]
    fn test_cache_entry_expiry() {
        let entry = CacheEntry::new("value", Duration::from_secs(0));
        std::thread::sleep(Duration::from_millis(10));
        assert!(entry.is_expired());
    }

    #[test]
    fn test_remaining_ttl() {
        let entry = CacheEntry::new("value", Duration::from_secs(3600));
        let remaining = entry.remaining_ttl();
        assert!(remaining.is_some());
        assert!(remaining.unwrap().as_secs() <= 3600);
    }
}
