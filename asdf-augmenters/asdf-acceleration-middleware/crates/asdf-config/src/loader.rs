//! Configuration loader

use crate::{AcceleratorConfig, Error, Result};
use config::{Config, Environment, File};
use std::path::Path;

/// Configuration loader
pub struct ConfigLoader {
    builder: Config,
}

impl ConfigLoader {
    /// Create a new configuration loader
    pub fn new() -> Self {
        Self {
            builder: Config::builder().build().unwrap(),
        }
    }

    /// Load configuration from a file
    pub fn load_file(&mut self, path: impl AsRef<Path>) -> Result<AcceleratorConfig> {
        let path = path.as_ref();

        if !path.exists() {
            return Err(Error::NotFound(path.display().to_string()));
        }

        self.builder = Config::builder()
            .add_source(File::from(path))
            .build()?;

        self.builder
            .clone()
            .try_deserialize()
            .map_err(|e| Error::Parse(e.to_string()))
    }

    /// Load configuration from environment variables
    pub fn load_from_env(&mut self) -> Result<AcceleratorConfig> {
        self.builder = Config::builder()
            .add_source(
                Environment::with_prefix("ASDF_ACCEL")
                    .separator("__")
                    .try_parsing(true),
            )
            .build()?;

        self.builder
            .clone()
            .try_deserialize()
            .map_err(|e| Error::Parse(e.to_string()))
    }

    /// Load configuration from multiple sources with precedence
    pub fn load_with_defaults(
        &mut self,
        config_path: Option<impl AsRef<Path>>,
    ) -> Result<AcceleratorConfig> {
        let mut builder = Config::builder();

        // Start with defaults
        let defaults = AcceleratorConfig::default();
        builder = builder.add_source(config::File::from_str(
            &serde_json::to_string(&defaults).unwrap(),
            config::FileFormat::Json,
        ));

        // Add config file if provided
        if let Some(path) = config_path {
            let path = path.as_ref();
            if path.exists() {
                builder = builder.add_source(File::from(path));
            }
        }

        // Add environment variables (highest precedence)
        builder = builder.add_source(
            Environment::with_prefix("ASDF_ACCEL")
                .separator("__")
                .try_parsing(true),
        );

        self.builder = builder.build()?;

        self.builder
            .clone()
            .try_deserialize()
            .map_err(|e| Error::Parse(e.to_string()))
    }
}

impl Default for ConfigLoader {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;
    use std::io::Write;

    #[test]
    fn test_load_nonexistent_file() {
        let mut loader = ConfigLoader::new();
        let result = loader.load_file("/nonexistent/config.toml");
        assert!(result.is_err());
    }

    #[test]
    fn test_load_from_file() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(
            file,
            r#"
[cache]
enabled = true
ttl_secs = 7200

[parallel]
fail_fast = true

[notifications]
enabled = false
            "#
        )
        .unwrap();

        let mut loader = ConfigLoader::new();
        let config = loader.load_file(file.path()).unwrap();

        assert!(config.cache.enabled);
        assert_eq!(config.cache.ttl_secs, 7200);
        assert!(config.parallel.fail_fast);
        assert!(!config.notifications.enabled);
    }
}
