//! L1: In-memory LRU cache

use crate::{CacheEntry, Error, Result};
use lru::LruCache;
use std::num::NonZeroUsize;
use std::sync::{Arc, Mutex};
use std::time::Duration;

/// In-memory LRU cache
pub struct MemoryCache<K, V>
where
    K: std::hash::Hash + Eq + Clone,
    V: Clone,
{
    cache: Arc<Mutex<LruCache<K, CacheEntry<V>>>>,
}

impl<K, V> MemoryCache<K, V>
where
    K: std::hash::Hash + Eq + Clone,
    V: Clone,
{
    /// Create a new memory cache with given capacity
    pub fn new(capacity: usize) -> Self {
        let cap = NonZeroUsize::new(capacity).unwrap_or(NonZeroUsize::new(1000).unwrap());
        Self {
            cache: Arc::new(Mutex::new(LruCache::new(cap))),
        }
    }

    /// Get a value from the cache
    pub fn get(&self, key: &K) -> Result<V> {
        let mut cache = self.cache.lock().unwrap();

        if let Some(entry) = cache.get(key) {
            if entry.is_expired() {
                cache.pop(key);
                Err(Error::Expired)
            } else {
                Ok(entry.value.clone())
            }
        } else {
            Err(Error::Miss)
        }
    }

    /// Insert a value into the cache
    pub fn insert(&self, key: K, value: V, ttl: Duration) {
        let entry = CacheEntry::new(value, ttl);
        let mut cache = self.cache.lock().unwrap();
        cache.put(key, entry);
    }

    /// Remove a value from the cache
    pub fn remove(&self, key: &K) -> Option<V> {
        let mut cache = self.cache.lock().unwrap();
        cache.pop(key).map(|entry| entry.value)
    }

    /// Clear all entries
    pub fn clear(&self) {
        let mut cache = self.cache.lock().unwrap();
        cache.clear();
    }

    /// Get the number of entries
    pub fn len(&self) -> usize {
        let cache = self.cache.lock().unwrap();
        cache.len()
    }

    /// Check if the cache is empty
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

impl<K, V> Clone for MemoryCache<K, V>
where
    K: std::hash::Hash + Eq + Clone,
    V: Clone,
{
    fn clone(&self) -> Self {
        Self {
            cache: Arc::clone(&self.cache),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_memory_cache_basic() {
        let cache: MemoryCache<String, String> = MemoryCache::new(100);

        cache.insert(
            "key1".to_string(),
            "value1".to_string(),
            Duration::from_secs(3600),
        );

        let value = cache.get(&"key1".to_string()).unwrap();
        assert_eq!(value, "value1");
    }

    #[test]
    fn test_memory_cache_miss() {
        let cache: MemoryCache<String, String> = MemoryCache::new(100);
        let result = cache.get(&"nonexistent".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_memory_cache_expiry() {
        let cache: MemoryCache<String, String> = MemoryCache::new(100);

        cache.insert(
            "key1".to_string(),
            "value1".to_string(),
            Duration::from_secs(0),
        );

        std::thread::sleep(Duration::from_millis(10));

        let result = cache.get(&"key1".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn test_memory_cache_remove() {
        let cache: MemoryCache<String, String> = MemoryCache::new(100);

        cache.insert(
            "key1".to_string(),
            "value1".to_string(),
            Duration::from_secs(3600),
        );

        let removed = cache.remove(&"key1".to_string());
        assert_eq!(removed, Some("value1".to_string()));

        let result = cache.get(&"key1".to_string());
        assert!(result.is_err());
    }
}
