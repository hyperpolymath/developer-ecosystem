// SPDX-License-Identifier: AGPL-3.0-or-later
//! Validate configuration file

use anyhow::{Context, Result};
use colored::Colorize;
use std::path::Path;

use crate::config::Config;

pub fn run(config_path: &Path, verbose: bool) -> Result<()> {
    if !config_path.exists() {
        println!("{} Configuration file not found: {}", "✗".red(), config_path.display());
        println!("  Run 'asdf-config init' to create one");
        return Ok(());
    }

    if verbose {
        println!("{} Loading configuration from {}", "→".blue(), config_path.display());
    }

    let config = Config::load(config_path)
        .context("Failed to load configuration")?;

    let warnings = config.validate()?;

    if warnings.is_empty() {
        println!("{} Configuration is valid", "✓".green());
        println!("  {} plugins configured", config.plugins.len());
    } else {
        println!("{} Configuration has {} warning(s):", "!".yellow(), warnings.len());
        for warning in &warnings {
            println!("  {} {}", "•".yellow(), warning);
        }
    }

    if verbose {
        println!("\n{}", "Configured plugins:".dimmed());
        for (name, plugin) in &config.plugins {
            println!("  {} {} @ {}", "•".cyan(), name, plugin.version);
        }
    }

    Ok(())
}
