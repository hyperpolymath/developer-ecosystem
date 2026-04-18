//! Plugin management

use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Represents an asdf plugin
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Plugin {
    /// Plugin name
    pub name: String,

    /// Repository URL
    pub url: Option<String>,

    /// Local path to plugin
    pub path: Option<PathBuf>,

    /// Plugin version/ref
    pub ref_: Option<String>,
}

impl Plugin {
    /// Create a new plugin
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            url: None,
            path: None,
            ref_: None,
        }
    }

    /// Set the repository URL
    pub fn with_url(mut self, url: impl Into<String>) -> Self {
        self.url = Some(url.into());
        self
    }

    /// Set the local path
    pub fn with_path(mut self, path: impl Into<PathBuf>) -> Self {
        self.path = Some(path.into());
        self
    }

    /// Set the ref (branch/tag/commit)
    pub fn with_ref(mut self, ref_: impl Into<String>) -> Self {
        self.ref_ = Some(ref_.into());
        self
    }

    /// List all installed plugins
    pub fn list() -> Result<Vec<Plugin>> {
        let output = duct::cmd!("asdf", "plugin", "list", "--urls")
            .read()
            .map_err(|e| Error::CommandFailed {
                command: "asdf plugin list --urls".to_string(),
                error: e.to_string(),
            })?;

        let plugins = output
            .lines()
            .filter(|line| !line.is_empty())
            .map(|line| {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    Plugin::new(parts[0]).with_url(parts[1])
                } else {
                    Plugin::new(parts[0])
                }
            })
            .collect();

        Ok(plugins)
    }

    /// Add this plugin
    pub fn add(&self) -> Result<()> {
        if let Some(url) = &self.url {
            duct::cmd!("asdf", "plugin", "add", &self.name, url)
                .run()
                .map_err(|e| Error::CommandFailed {
                    command: format!("asdf plugin add {} {}", self.name, url),
                    error: e.to_string(),
                })?;
        } else {
            duct::cmd!("asdf", "plugin", "add", &self.name)
                .run()
                .map_err(|e| Error::CommandFailed {
                    command: format!("asdf plugin add {}", self.name),
                    error: e.to_string(),
                })?;
        }

        Ok(())
    }

    /// Remove this plugin
    pub fn remove(&self) -> Result<()> {
        duct::cmd!("asdf", "plugin", "remove", &self.name)
            .run()
            .map_err(|e| Error::CommandFailed {
                command: format!("asdf plugin remove {}", self.name),
                error: e.to_string(),
            })?;

        Ok(())
    }

    /// Update this plugin
    pub fn update(&self) -> Result<()> {
        if let Some(ref_) = &self.ref_ {
            duct::cmd!("asdf", "plugin", "update", &self.name, ref_)
                .run()
                .map_err(|e| Error::CommandFailed {
                    command: format!("asdf plugin update {} {}", self.name, ref_),
                    error: e.to_string(),
                })?;
        } else {
            duct::cmd!("asdf", "plugin", "update", &self.name)
                .run()
                .map_err(|e| Error::CommandFailed {
                    command: format!("asdf plugin update {}", self.name),
                    error: e.to_string(),
                })?;
        }

        Ok(())
    }

    /// List available versions for this plugin
    pub fn list_all_versions(&self) -> Result<Vec<String>> {
        let output = duct::cmd!("asdf", "list", "all", &self.name)
            .read()
            .map_err(|e| Error::CommandFailed {
                command: format!("asdf list all {}", self.name),
                error: e.to_string(),
            })?;

        let versions = output
            .lines()
            .filter(|line| !line.is_empty())
            .map(|line| line.trim().to_string())
            .collect();

        Ok(versions)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_plugin_new() {
        let plugin = Plugin::new("nodejs");
        assert_eq!(plugin.name, "nodejs");
        assert!(plugin.url.is_none());
    }

    #[test]
    fn test_plugin_with_url() {
        let plugin = Plugin::new("nodejs")
            .with_url("https://github.com/asdf-vm/asdf-nodejs.git");

        assert_eq!(plugin.name, "nodejs");
        assert!(plugin.url.is_some());
    }

    #[test]
    fn test_plugin_serialization() {
        let plugin = Plugin::new("nodejs")
            .with_url("https://github.com/asdf-vm/asdf-nodejs.git");

        let json = serde_json::to_string(&plugin).unwrap();
        let deserialized: Plugin = serde_json::from_str(&json).unwrap();

        assert_eq!(plugin, deserialized);
    }
}
