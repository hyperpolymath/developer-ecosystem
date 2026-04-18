// SPDX-License-Identifier: AGPL-3.0-or-later
//! Export current asdf setup to configuration

use anyhow::{Context, Result};
use colored::Colorize;
use std::collections::HashMap;
use std::path::Path;
use std::process::Command;

use crate::config::{Config, PluginConfig, Settings};

pub fn run(format: &str, output: Option<&Path>, verbose: bool) -> Result<()> {
    println!("{} Exporting current asdf configuration...", "→".blue());

    // Get installed plugins
    let plugins_output = Command::new("asdf")
        .args(["plugin", "list"])
        .output()
        .context("Failed to run asdf plugin list")?;

    if !plugins_output.status.success() {
        println!("{} Failed to list plugins", "✗".red());
        return Ok(());
    }

    let plugins_str = String::from_utf8_lossy(&plugins_output.stdout);
    let plugin_names: Vec<&str> = plugins_str.lines().collect();

    if verbose {
        println!("  Found {} installed plugins", plugin_names.len());
    }

    let mut plugins = HashMap::new();

    for name in plugin_names {
        if name.is_empty() {
            continue;
        }

        // Get current version
        let current_output = Command::new("asdf")
            .args(["current", name])
            .output();

        let version = if let Ok(output) = current_output {
            let stdout = String::from_utf8_lossy(&output.stdout);
            stdout.split_whitespace()
                .nth(1)
                .unwrap_or("latest")
                .to_string()
        } else {
            "latest".to_string()
        };

        if verbose {
            println!("  {} {} @ {}", "•".cyan(), name, version);
        }

        plugins.insert(
            name.to_string(),
            PluginConfig {
                version,
                source: "official".to_string(),
                platforms: HashMap::new(),
                post_install: vec![],
                optional: false,
            },
        );
    }

    let config = Config {
        version: "1".to_string(),
        plugins,
        settings: Settings::default(),
    };

    let content = match format {
        "toml" => toml::to_string_pretty(&config)?,
        _ => serde_yaml::to_string(&config)?,
    };

    if let Some(path) = output {
        std::fs::write(path, &content)?;
        println!("{} Exported to {}", "✓".green(), path.display());
    } else {
        println!();
        println!("{}", content);
    }

    Ok(())
}
