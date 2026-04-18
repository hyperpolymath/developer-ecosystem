//! Runtime version management

use crate::{Error, Result, Version};
use serde::{Deserialize, Serialize};

/// Represents an installed runtime version
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Runtime {
    /// Plugin name
    pub plugin: String,

    /// Version
    pub version: Version,

    /// Whether this is currently active
    pub active: bool,
}

impl Runtime {
    /// Create a new runtime
    pub fn new(plugin: impl Into<String>, version: Version) -> Self {
        Self {
            plugin: plugin.into(),
            version,
            active: false,
        }
    }

    /// List installed runtimes for a plugin
    pub fn list_for_plugin(plugin: &str) -> Result<Vec<Runtime>> {
        let output = duct::cmd!("asdf", "list", plugin)
            .read()
            .map_err(|e| Error::CommandFailed {
                command: format!("asdf list {}", plugin),
                error: e.to_string(),
            })?;

        let runtimes = output
            .lines()
            .filter(|line| !line.is_empty())
            .filter_map(|line| {
                let trimmed = line.trim();
                let (version_str, active) = if trimmed.starts_with('*') {
                    (trimmed.trim_start_matches('*').trim(), true)
                } else {
                    (trimmed, false)
                };

                Version::parse(version_str).ok().map(|version| Runtime {
                    plugin: plugin.to_string(),
                    version,
                    active,
                })
            })
            .collect();

        Ok(runtimes)
    }

    /// Install this runtime
    pub fn install(&self) -> Result<()> {
        duct::cmd!(
            "asdf",
            "install",
            &self.plugin,
            self.version.to_string()
        )
        .run()
        .map_err(|e| Error::CommandFailed {
            command: format!("asdf install {} {}", self.plugin, self.version),
            error: e.to_string(),
        })?;

        Ok(())
    }

    /// Uninstall this runtime
    pub fn uninstall(&self) -> Result<()> {
        duct::cmd!(
            "asdf",
            "uninstall",
            &self.plugin,
            self.version.to_string()
        )
        .run()
        .map_err(|e| Error::CommandFailed {
            command: format!("asdf uninstall {} {}", self.plugin, self.version),
            error: e.to_string(),
        })?;

        Ok(())
    }

    /// Set this runtime as global default
    pub fn set_global(&self) -> Result<()> {
        duct::cmd!(
            "asdf",
            "global",
            &self.plugin,
            self.version.to_string()
        )
        .run()
        .map_err(|e| Error::CommandFailed {
            command: format!("asdf global {} {}", self.plugin, self.version),
            error: e.to_string(),
        })?;

        Ok(())
    }

    /// Set this runtime as local default
    pub fn set_local(&self) -> Result<()> {
        duct::cmd!(
            "asdf",
            "local",
            &self.plugin,
            self.version.to_string()
        )
        .run()
        .map_err(|e| Error::CommandFailed {
            command: format!("asdf local {} {}", self.plugin, self.version),
            error: e.to_string(),
        })?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_runtime_new() {
        let runtime = Runtime::new("nodejs", Version::parse("20.0.0").unwrap());
        assert_eq!(runtime.plugin, "nodejs");
        assert!(!runtime.active);
    }

    #[test]
    fn test_runtime_serialization() {
        let runtime = Runtime::new("nodejs", Version::parse("20.0.0").unwrap());
        let json = serde_json::to_string(&runtime).unwrap();
        let deserialized: Runtime = serde_json::from_str(&json).unwrap();
        assert_eq!(runtime, deserialized);
    }
}
