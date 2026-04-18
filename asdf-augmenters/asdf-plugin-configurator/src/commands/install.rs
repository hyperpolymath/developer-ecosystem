// SPDX-License-Identifier: AGPL-3.0-or-later
//! Install plugins from configuration

use anyhow::{Context, Result};
use colored::Colorize;
use std::path::Path;
use std::process::Command;

use crate::config::Config;
use crate::registry::{Registry, Version, resolve_version};

pub fn run(config_path: &Path, plugin: Option<&str>, dry_run: bool, verbose: bool) -> Result<()> {
    if !config_path.exists() {
        println!("{} Configuration file not found: {}", "✗".red(), config_path.display());
        return Ok(());
    }

    let config = Config::load(config_path)?;

    let plugins_to_install: Vec<_> = if let Some(name) = plugin {
        config.plugins.iter()
            .filter(|(n, _)| *n == name)
            .collect()
    } else {
        config.plugins.iter().collect()
    };

    if plugins_to_install.is_empty() {
        println!("{} No plugins to install", "!".yellow());
        return Ok(());
    }

    // Initialize registry for version resolution
    let registry = Registry::new().ok();

    println!("{} Installing {} plugin(s){}",
        "→".blue(),
        plugins_to_install.len(),
        if dry_run { " (dry run)" } else { "" }
    );
    println!();

    for (name, plugin_config) in &plugins_to_install {
        let source = get_plugin_source(name, &plugin_config.source);

        // Resolve version constraint to actual version
        let resolved_version = resolve_version_for_plugin(
            name,
            &plugin_config.version,
            registry.as_ref(),
            verbose
        );

        if dry_run {
            println!("  {} Would install {} @ {} from {}",
                "→".cyan(),
                name.bold(),
                resolved_version.green(),
                source.dimmed()
            );
            if plugin_config.version != resolved_version {
                println!("    {} {} → {}",
                    "ℹ".blue(),
                    plugin_config.version.dimmed(),
                    resolved_version.green()
                );
            }
            continue;
        }

        // Add plugin
        println!("  {} Adding plugin {}...", "→".cyan(), name);

        if verbose {
            println!("    Source: {}", source);
        }

        let add_result = Command::new("asdf")
            .args(["plugin", "add", name, &source])
            .output()
            .context("Failed to run asdf")?;

        if !add_result.status.success() {
            let stderr = String::from_utf8_lossy(&add_result.stderr);
            if !stderr.contains("already added") {
                println!("  {} Failed to add {}: {}", "✗".red(), name, stderr.trim());
                continue;
            }
        }

        // Install version
        println!("  {} Installing {} @ {}...", "→".cyan(), name, resolved_version);

        let install_result = Command::new("asdf")
            .args(["install", name, &resolved_version])
            .output()
            .context("Failed to run asdf install")?;

        if !install_result.status.success() {
            let stderr = String::from_utf8_lossy(&install_result.stderr);
            println!("  {} Failed to install {}: {}", "✗".red(), name, stderr.trim());
            continue;
        }

        // Set global version
        let _ = Command::new("asdf")
            .args(["global", name, &resolved_version])
            .output();

        // Run post-install commands
        for cmd in &plugin_config.post_install {
            if verbose {
                println!("    Running: {}", cmd);
            }
            let post_result = Command::new("sh")
                .args(["-c", cmd])
                .output();

            if let Ok(output) = post_result {
                if !output.status.success() && verbose {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    println!("    {} Post-install warning: {}", "!".yellow(), stderr.trim());
                }
            }
        }

        println!("  {} Installed {} @ {}", "✓".green(), name.bold(), resolved_version.green());
    }

    println!();
    println!("{} Installation complete", "✓".green());

    Ok(())
}

fn get_plugin_source(name: &str, source: &str) -> String {
    match source {
        "official" => format!("https://github.com/asdf-vm/asdf-{}.git", name),
        "hyperpolymath" => format!("https://github.com/hyperpolymath/asdf-{}-plugin.git", name),
        url if url.starts_with("http") => url.to_string(),
        _ => format!("https://github.com/hyperpolymath/asdf-{}-plugin.git", name),
    }
}

/// Resolve version constraint to an actual version string
fn resolve_version_for_plugin(
    plugin: &str,
    constraint: &str,
    registry: Option<&Registry>,
    verbose: bool
) -> String {
    // If it's already a specific version (no operator), use it directly
    if !constraint.starts_with('^')
        && !constraint.starts_with('~')
        && !constraint.starts_with('>')
        && !constraint.starts_with('<')
        && constraint != "latest"
        && constraint != "stable"
    {
        return constraint.to_string();
    }

    // Try to get available versions and resolve
    if let Some(registry) = registry {
        if let Ok(versions) = registry.get_available_versions(plugin) {
            if !versions.is_empty() {
                if let Some(resolved) = resolve_version(constraint, &versions) {
                    if verbose {
                        println!("    Resolved {} to {}", constraint, resolved);
                    }
                    return resolved;
                }
            }
        }
    }

    // Fallback: try asdf list-all directly
    if let Ok(output) = Command::new("asdf")
        .args(["list", "all", plugin])
        .output()
    {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let versions: Vec<Version> = stdout
                .lines()
                .filter_map(|line| Version::parse(line.trim()))
                .collect();

            if !versions.is_empty() {
                if let Some(resolved) = resolve_version(constraint, &versions) {
                    if verbose {
                        println!("    Resolved {} to {} (via asdf)", constraint, resolved);
                    }
                    return resolved;
                }
            }
        }
    }

    // Final fallback for special constraints
    match constraint {
        "latest" | "stable" => "latest".to_string(),
        c if c.starts_with('^') || c.starts_with('~') => {
            // Try to extract base version and use latest
            if verbose {
                println!("    Could not resolve {}, using 'latest'", constraint);
            }
            "latest".to_string()
        }
        c if c.starts_with(">=") => {
            // Use the minimum version as fallback
            c.trim_start_matches(">=").to_string()
        }
        c if c.starts_with('>') => {
            // Use the minimum version as fallback
            c.trim_start_matches('>').to_string()
        }
        _ => constraint.to_string(),
    }
}
