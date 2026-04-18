//! Configuration management for asdf-acceleration-middleware

pub mod error;
pub mod loader;
pub mod schema;

pub use error::{Error, Result};
pub use loader::ConfigLoader;
pub use schema::{AcceleratorConfig, CacheConfig, ParallelConfig, NotificationConfig};

use std::path::Path;

/// Load configuration from file
pub fn load_config(path: impl AsRef<Path>) -> Result<AcceleratorConfig> {
    ConfigLoader::new().load_file(path)
}

/// Load configuration with defaults
pub fn load_or_default() -> AcceleratorConfig {
    ConfigLoader::new()
        .load_from_env()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_or_default() {
        let config = load_or_default();
        assert!(config.cache.enabled);
    }
}
