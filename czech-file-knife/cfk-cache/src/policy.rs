// SPDX-License-Identifier: AGPL-3.0-or-later
//! Cache eviction policies
//!
//! LRU, LFU, FIFO, and size-based eviction strategies.

use chrono::{DateTime, Utc};
use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;

use crate::blob_store::ContentId;

/// Cache entry info for eviction decisions
#[derive(Debug, Clone)]
pub struct CacheEntryInfo {
    pub content_id: ContentId,
    pub size: u64,
    pub last_accessed: DateTime<Utc>,
    pub access_count: u64,
    pub created: DateTime<Utc>,
    /// Priority (higher = more important)
    pub priority: i32,
}

impl CacheEntryInfo {
    pub fn new(content_id: ContentId, size: u64) -> Self {
        let now = Utc::now();
        Self {
            content_id,
            size,
            last_accessed: now,
            access_count: 1,
            created: now,
            priority: 0,
        }
    }

    pub fn touch(&mut self) {
        self.last_accessed = Utc::now();
        self.access_count += 1;
    }

    pub fn with_priority(mut self, priority: i32) -> Self {
        self.priority = priority;
        self
    }
}

/// Eviction policy type
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvictionPolicy {
    /// Least Recently Used
    Lru,
    /// Least Frequently Used
    Lfu,
    /// First In First Out
    Fifo,
    /// Largest First
    LargestFirst,
    /// Smallest First
    SmallestFirst,
    /// Adaptive Replacement Cache (ARC-like)
    Adaptive,
}

impl Default for EvictionPolicy {
    fn default() -> Self {
        Self::Lru
    }
}

/// Cache policy configuration
#[derive(Debug, Clone)]
pub struct PolicyConfig {
    /// Maximum total size in bytes
    pub max_size: u64,
    /// Maximum number of entries
    pub max_entries: usize,
    /// Eviction policy
    pub policy: EvictionPolicy,
    /// Target utilization (0.0-1.0) after eviction
    pub target_utilization: f64,
    /// Minimum TTL (seconds) - don't evict entries newer than this
    pub min_ttl: i64,
}

impl Default for PolicyConfig {
    fn default() -> Self {
        Self {
            max_size: 10 * 1024 * 1024 * 1024, // 10GB
            max_entries: 100000,
            policy: EvictionPolicy::Lru,
            target_utilization: 0.9,
            min_ttl: 60, // 1 minute
        }
    }
}

/// Eviction result
#[derive(Debug, Clone)]
pub struct EvictionResult {
    /// Content IDs to evict
    pub evicted: Vec<ContentId>,
    /// Total size freed
    pub size_freed: u64,
    /// Number of entries evicted
    pub count: usize,
}

/// Cache policy manager
pub struct CachePolicy {
    config: PolicyConfig,
    entries: HashMap<ContentId, CacheEntryInfo>,
    total_size: u64,
}

impl CachePolicy {
    pub fn new(config: PolicyConfig) -> Self {
        Self {
            config,
            entries: HashMap::new(),
            total_size: 0,
        }
    }

    /// Record an entry being added to cache
    pub fn record_add(&mut self, info: CacheEntryInfo) {
        self.total_size += info.size;
        self.entries.insert(info.content_id.clone(), info);
    }

    /// Record an entry being accessed
    pub fn record_access(&mut self, content_id: &ContentId) {
        if let Some(entry) = self.entries.get_mut(content_id) {
            entry.touch();
        }
    }

    /// Record an entry being removed
    pub fn record_remove(&mut self, content_id: &ContentId) {
        if let Some(entry) = self.entries.remove(content_id) {
            self.total_size = self.total_size.saturating_sub(entry.size);
        }
    }

    /// Check if eviction is needed
    pub fn needs_eviction(&self) -> bool {
        self.total_size > self.config.max_size || self.entries.len() > self.config.max_entries
    }

    /// Get entries to evict
    pub fn select_evictions(&self) -> EvictionResult {
        if !self.needs_eviction() {
            return EvictionResult {
                evicted: vec![],
                size_freed: 0,
                count: 0,
            };
        }

        let target_size = (self.config.max_size as f64 * self.config.target_utilization) as u64;
        let size_to_free = self.total_size.saturating_sub(target_size);

        let target_entries =
            (self.config.max_entries as f64 * self.config.target_utilization) as usize;
        let entries_to_free = self.entries.len().saturating_sub(target_entries);

        let mut evicted = Vec::new();
        let mut size_freed = 0u64;

        // Get candidates sorted by eviction policy
        let mut candidates: Vec<_> = self
            .entries
            .values()
            .filter(|e| {
                // Don't evict entries newer than min_ttl
                let age = Utc::now()
                    .signed_duration_since(e.created)
                    .num_seconds();
                age >= self.config.min_ttl
            })
            .collect();

        // Sort by policy
        match self.config.policy {
            EvictionPolicy::Lru => {
                candidates.sort_by(|a, b| a.last_accessed.cmp(&b.last_accessed));
            }
            EvictionPolicy::Lfu => {
                candidates.sort_by(|a, b| a.access_count.cmp(&b.access_count));
            }
            EvictionPolicy::Fifo => {
                candidates.sort_by(|a, b| a.created.cmp(&b.created));
            }
            EvictionPolicy::LargestFirst => {
                candidates.sort_by(|a, b| b.size.cmp(&a.size));
            }
            EvictionPolicy::SmallestFirst => {
                candidates.sort_by(|a, b| a.size.cmp(&b.size));
            }
            EvictionPolicy::Adaptive => {
                // ARC-like: balance between LRU and LFU
                candidates.sort_by(|a, b| {
                    let a_score = adaptive_score(a);
                    let b_score = adaptive_score(b);
                    a_score.partial_cmp(&b_score).unwrap_or(Ordering::Equal)
                });
            }
        }

        // Select entries to evict
        for candidate in candidates {
            if size_freed >= size_to_free && evicted.len() >= entries_to_free {
                break;
            }

            evicted.push(candidate.content_id.clone());
            size_freed += candidate.size;
        }

        let count = evicted.len();
        EvictionResult {
            evicted,
            size_freed,
            count,
        }
    }

    /// Get current cache statistics
    pub fn stats(&self) -> PolicyStats {
        let avg_size = if self.entries.is_empty() {
            0
        } else {
            self.total_size / self.entries.len() as u64
        };

        let avg_access = if self.entries.is_empty() {
            0.0
        } else {
            self.entries.values().map(|e| e.access_count).sum::<u64>() as f64
                / self.entries.len() as f64
        };

        PolicyStats {
            total_size: self.total_size,
            entry_count: self.entries.len(),
            max_size: self.config.max_size,
            max_entries: self.config.max_entries,
            utilization: self.total_size as f64 / self.config.max_size as f64,
            avg_entry_size: avg_size,
            avg_access_count: avg_access,
        }
    }

    /// Update policy configuration
    pub fn set_config(&mut self, config: PolicyConfig) {
        self.config = config;
    }
}

/// Calculate adaptive eviction score (lower = more likely to evict)
fn adaptive_score(entry: &CacheEntryInfo) -> f64 {
    let age_hours = Utc::now()
        .signed_duration_since(entry.last_accessed)
        .num_hours() as f64;

    let frequency = entry.access_count as f64;
    let size_penalty = (entry.size as f64).ln();
    let priority_bonus = entry.priority as f64 * 100.0;

    // Higher score = less likely to evict
    frequency / (age_hours + 1.0) - size_penalty / 10.0 + priority_bonus
}

/// Policy statistics
#[derive(Debug, Clone, Default)]
pub struct PolicyStats {
    pub total_size: u64,
    pub entry_count: usize,
    pub max_size: u64,
    pub max_entries: usize,
    pub utilization: f64,
    pub avg_entry_size: u64,
    pub avg_access_count: f64,
}

/// Priority queue for eviction candidates
struct EvictionCandidate {
    content_id: ContentId,
    score: f64,
    size: u64,
}

impl PartialEq for EvictionCandidate {
    fn eq(&self, other: &Self) -> bool {
        self.content_id == other.content_id
    }
}

impl Eq for EvictionCandidate {}

impl PartialOrd for EvictionCandidate {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for EvictionCandidate {
    fn cmp(&self, other: &Self) -> Ordering {
        // Lower score = higher priority for eviction
        other
            .score
            .partial_cmp(&self.score)
            .unwrap_or(Ordering::Equal)
    }
}

/// Size-tiered caching strategy
pub struct TieredPolicy {
    /// Hot tier (frequently accessed, small)
    hot_tier: CachePolicy,
    /// Warm tier (occasionally accessed)
    warm_tier: CachePolicy,
    /// Cold tier (rarely accessed, large)
    cold_tier: CachePolicy,
}

impl TieredPolicy {
    pub fn new(total_size: u64) -> Self {
        // 10% hot, 30% warm, 60% cold
        let hot_size = total_size / 10;
        let warm_size = (total_size * 3) / 10;
        let cold_size = (total_size * 6) / 10;

        Self {
            hot_tier: CachePolicy::new(PolicyConfig {
                max_size: hot_size,
                max_entries: 10000,
                policy: EvictionPolicy::Lfu,
                ..Default::default()
            }),
            warm_tier: CachePolicy::new(PolicyConfig {
                max_size: warm_size,
                max_entries: 50000,
                policy: EvictionPolicy::Lru,
                ..Default::default()
            }),
            cold_tier: CachePolicy::new(PolicyConfig {
                max_size: cold_size,
                max_entries: 100000,
                policy: EvictionPolicy::LargestFirst,
                ..Default::default()
            }),
        }
    }

    /// Determine tier for an entry based on size and access pattern
    pub fn determine_tier(&self, info: &CacheEntryInfo) -> Tier {
        if info.access_count > 10 && info.size < 1024 * 1024 {
            Tier::Hot
        } else if info.access_count > 2 || info.size < 10 * 1024 * 1024 {
            Tier::Warm
        } else {
            Tier::Cold
        }
    }

    /// Record entry in appropriate tier
    pub fn record_add(&mut self, info: CacheEntryInfo) {
        match self.determine_tier(&info) {
            Tier::Hot => self.hot_tier.record_add(info),
            Tier::Warm => self.warm_tier.record_add(info),
            Tier::Cold => self.cold_tier.record_add(info),
        }
    }

    /// Get evictions from all tiers
    pub fn select_evictions(&self) -> Vec<EvictionResult> {
        vec![
            self.cold_tier.select_evictions(),
            self.warm_tier.select_evictions(),
            self.hot_tier.select_evictions(),
        ]
    }
}

/// Cache tier
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tier {
    Hot,
    Warm,
    Cold,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lru_eviction() {
        let config = PolicyConfig {
            max_size: 1000,
            max_entries: 10,
            policy: EvictionPolicy::Lru,
            target_utilization: 0.8,
            min_ttl: 0,
        };

        let mut policy = CachePolicy::new(config);

        // Add entries
        for i in 0..15 {
            let id = ContentId::from_bytes([i as u8; 32]);
            let info = CacheEntryInfo::new(id, 100);
            policy.record_add(info);
        }

        assert!(policy.needs_eviction());

        let result = policy.select_evictions();
        assert!(!result.evicted.is_empty());
        assert!(result.size_freed > 0);
    }
}
