//! Configuration schema

use asdf_parallel::Strategy;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::time::Duration;

/// Main configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AcceleratorConfig {
    /// Cache configuration
    pub cache: CacheConfig,

    /// Parallel execution configuration
    pub parallel: ParallelConfig,

    /// Notification configuration
    pub notifications: NotificationConfig,

    /// Plugin configuration
    pub plugins: PluginConfig,
}

impl Default for AcceleratorConfig {
    fn default() -> Self {
        Self {
            cache: CacheConfig::default(),
            parallel: ParallelConfig::default(),
            notifications: NotificationConfig::default(),
            plugins: PluginConfig::default(),
        }
    }
}

/// Cache configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheConfig {
    /// Whether caching is enabled
    pub enabled: bool,

    /// Cache directory
    pub directory: PathBuf,

    /// Default TTL in seconds
    pub ttl_secs: u64,

    /// Maximum cache size in MB
    pub max_size_mb: usize,

    /// L1 (memory) cache capacity
    pub l1_capacity: usize,
}

impl Default for CacheConfig {
    fn default() -> Self {
        let cache_dir = dirs::cache_dir()
            .unwrap_or_else(|| PathBuf::from(".cache"))
            .join("asdf-acceleration");

        Self {
            enabled: true,
            directory: cache_dir,
            ttl_secs: 3600, // 1 hour
            max_size_mb: 500,
            l1_capacity: 1000,
        }
    }
}

impl CacheConfig {
    /// Get TTL as Duration
    pub fn ttl(&self) -> Duration {
        Duration::from_secs(self.ttl_secs)
    }
}

/// Parallel execution configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParallelConfig {
    /// Execution strategy
    #[serde(default)]
    pub strategy: Strategy,

    /// Maximum number of parallel jobs
    pub max_jobs: Option<usize>,

    /// Whether to fail fast on first error
    pub fail_fast: bool,

    /// Maximum retries per task
    pub max_retries: usize,
}

impl Default for ParallelConfig {
    fn default() -> Self {
        Self {
            strategy: Strategy::Auto,
            max_jobs: None,
            fail_fast: false,
            max_retries: 0,
        }
    }
}

/// Notification configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationConfig {
    /// Whether notifications are enabled
    pub enabled: bool,

    /// Notification level
    pub level: NotificationLevel,

    /// Whether to show desktop notifications
    pub desktop: bool,
}

impl Default for NotificationConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            level: NotificationLevel::ErrorsOnly,
            desktop: true,
        }
    }
}

/// Notification level
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum NotificationLevel {
    /// Notify on all events
    All,

    /// Notify only on errors
    ErrorsOnly,

    /// Notify on completion
    Completion,

    /// No notifications
    None,
}

/// Plugin configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginConfig {
    /// Plugins to exclude from operations
    pub exclude: Vec<String>,

    /// Only operate on these plugins (if specified)
    pub only: Vec<String>,

    /// Whether to auto-update plugins
    pub auto_update: bool,
}

impl Default for PluginConfig {
    fn default() -> Self {
        Self {
            exclude: Vec::new(),
            only: Vec::new(),
            auto_update: true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_default() {
        let config = AcceleratorConfig::default();
        assert!(config.cache.enabled);
        assert_eq!(config.cache.ttl_secs, 3600);
    }

    #[test]
    fn test_config_serialization() {
        let config = AcceleratorConfig::default();
        let json = serde_json::to_string(&config).unwrap();
        let deserialized: AcceleratorConfig = serde_json::from_str(&json).unwrap();
        assert_eq!(config.cache.ttl_secs, deserialized.cache.ttl_secs);
    }

    #[test]
    fn test_cache_ttl() {
        let config = CacheConfig::default();
        assert_eq!(config.ttl(), Duration::from_secs(3600));
    }
}
