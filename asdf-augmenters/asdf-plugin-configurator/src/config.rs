// SPDX-License-Identifier: AGPL-3.0-or-later
//! Configuration file parsing and validation

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

/// Main configuration structure
#[derive(Debug, Serialize, Deserialize)]
pub struct Config {
    /// Configuration file version
    #[serde(default = "default_version")]
    pub version: String,

    /// Plugin configurations
    #[serde(default)]
    pub plugins: HashMap<String, PluginConfig>,

    /// Global settings
    #[serde(default)]
    pub settings: Settings,
}

fn default_version() -> String {
    "1".to_string()
}

/// Individual plugin configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PluginConfig {
    /// Version constraint (e.g., "^20.0.0", ">=1.70.0", "~3.11.0")
    pub version: String,

    /// Plugin source (official, hyperpolymath, or custom URL)
    #[serde(default = "default_source")]
    pub source: String,

    /// Platform-specific versions
    #[serde(default)]
    pub platforms: HashMap<String, String>,

    /// Post-install commands
    #[serde(default)]
    pub post_install: Vec<String>,

    /// Whether plugin is optional
    #[serde(default)]
    pub optional: bool,
}

fn default_source() -> String {
    "official".to_string()
}

/// Global settings
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Settings {
    /// Prefer hyperpolymath plugins over official
    #[serde(default)]
    pub prefer_hyperpolymath: bool,

    /// Verify checksums when available
    #[serde(default = "default_true")]
    pub verify_checksums: bool,

    /// Parallel installation
    #[serde(default = "default_true")]
    pub parallel: bool,

    /// Maximum parallel jobs
    #[serde(default = "default_jobs")]
    pub jobs: u8,
}

fn default_true() -> bool {
    true
}

fn default_jobs() -> u8 {
    4
}

impl Config {
    /// Load configuration from file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)
            .with_context(|| format!("Failed to read config file: {}", path.display()))?;

        let config: Config = if path.extension().map_or(false, |e| e == "toml") {
            toml::from_str(&content)
                .with_context(|| "Failed to parse TOML configuration")?
        } else {
            serde_yaml::from_str(&content)
                .with_context(|| "Failed to parse YAML configuration")?
        };

        Ok(config)
    }

    /// Save configuration to file
    pub fn save(&self, path: &Path) -> Result<()> {
        let content = if path.extension().map_or(false, |e| e == "toml") {
            toml::to_string_pretty(self)?
        } else {
            serde_yaml::to_string(self)?
        };

        std::fs::write(path, content)
            .with_context(|| format!("Failed to write config file: {}", path.display()))?;

        Ok(())
    }

    /// Validate configuration
    pub fn validate(&self) -> Result<Vec<String>> {
        let mut warnings = Vec::new();

        for (name, plugin) in &self.plugins {
            // Validate version constraint syntax
            if !is_valid_version_constraint(&plugin.version) {
                warnings.push(format!(
                    "Plugin '{}': invalid version constraint '{}'",
                    name, plugin.version
                ));
            }

            // Warn about deprecated sources
            if plugin.source == "deprecated" {
                warnings.push(format!(
                    "Plugin '{}': using deprecated source",
                    name
                ));
            }
        }

        Ok(warnings)
    }
}

/// Check if version constraint is valid
fn is_valid_version_constraint(version: &str) -> bool {
    // Accept common version constraint patterns
    let patterns = [
        r"^\d+\.\d+\.\d+$",           // Exact: 1.2.3
        r"^\^?\d+\.\d+\.\d+$",        // Caret: ^1.2.3
        r"^~\d+\.\d+\.\d+$",          // Tilde: ~1.2.3
        r"^>=?\d+\.\d+\.\d+$",        // Greater: >=1.2.3 or >1.2.3
        r"^<=?\d+\.\d+\.\d+$",        // Less: <=1.2.3 or <1.2.3
        r"^latest$",                   // Latest
        r"^stable$",                   // Stable
    ];

    patterns.iter().any(|p| {
        regex_lite::Regex::new(p)
            .map(|re| re.is_match(version))
            .unwrap_or(false)
    })
}

/// Generate default configuration template
pub fn default_template(format: &str) -> String {
    let config = Config {
        version: "1".to_string(),
        plugins: {
            let mut map = HashMap::new();
            map.insert(
                "nodejs".to_string(),
                PluginConfig {
                    version: "^20.0.0".to_string(),
                    source: "official".to_string(),
                    platforms: HashMap::new(),
                    post_install: vec![],
                    optional: false,
                },
            );
            map.insert(
                "rust".to_string(),
                PluginConfig {
                    version: "stable".to_string(),
                    source: "official".to_string(),
                    platforms: HashMap::new(),
                    post_install: vec!["rustup component add clippy".to_string()],
                    optional: false,
                },
            );
            map
        },
        settings: Settings {
            prefer_hyperpolymath: true,
            verify_checksums: true,
            parallel: true,
            jobs: 4,
        },
    };

    match format {
        "toml" => toml::to_string_pretty(&config).unwrap_or_default(),
        _ => serde_yaml::to_string(&config).unwrap_or_default(),
    }
}
