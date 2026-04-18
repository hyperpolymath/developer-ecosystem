// SPDX-License-Identifier: AGPL-3.0-or-later
//! Sync plugin versions across team

use anyhow::{Context, Result};
use colored::Colorize;
use std::collections::HashMap;
use std::path::Path;
use std::process::Command;

use crate::config::Config;

/// Remote configuration source
#[derive(Debug, Clone)]
pub struct RemoteConfig {
    pub url: String,
    pub branch: Option<String>,
    pub path: String,
}

impl RemoteConfig {
    /// Parse a remote URL string into components
    /// Supports formats:
    /// - https://github.com/user/repo
    /// - https://github.com/user/repo#branch
    /// - https://github.com/user/repo:path/to/config.yaml
    /// - https://github.com/user/repo#branch:path/to/config.yaml
    pub fn parse(remote: &str) -> Result<Self> {
        let mut url = remote.to_string();
        let mut branch = None;
        let mut path = ".asdf-config.yaml".to_string();

        // Extract path after ':'
        if let Some(colon_idx) = url.rfind(':') {
            if !url[colon_idx..].starts_with("://") {
                path = url[colon_idx + 1..].to_string();
                url = url[..colon_idx].to_string();
            }
        }

        // Extract branch after '#'
        if let Some(hash_idx) = url.rfind('#') {
            branch = Some(url[hash_idx + 1..].to_string());
            url = url[..hash_idx].to_string();
        }

        Ok(Self { url, branch, path })
    }

    /// Get the raw file URL for GitHub/GitLab repositories
    fn get_raw_url(&self) -> Result<String> {
        let branch = self.branch.as_deref().unwrap_or("main");

        if self.url.contains("github.com") {
            // Convert GitHub URL to raw content URL
            let raw_url = self.url
                .replace("github.com", "raw.githubusercontent.com")
                .trim_end_matches(".git")
                .to_string();
            Ok(format!("{}/{}/{}", raw_url, branch, self.path))
        } else if self.url.contains("gitlab.com") {
            // Convert GitLab URL to raw content URL
            let raw_url = self.url.trim_end_matches(".git");
            Ok(format!("{}/-/raw/{}/{}", raw_url, branch, self.path))
        } else if self.url.contains("codeberg.org") {
            // Codeberg raw URL format
            let raw_url = self.url.trim_end_matches(".git");
            Ok(format!("{}/raw/branch/{}/{}", raw_url, branch, self.path))
        } else {
            // Assume it's a direct URL
            Ok(self.url.clone())
        }
    }
}

pub fn run(config_path: &Path, pull: bool, push: bool, verbose: bool) -> Result<()> {
    if !pull && !push {
        println!("{} Specify --pull or --push", "!".yellow());
        println!();
        println!("  {} Pull remote configuration", "--pull".cyan());
        println!("  {} Push local versions to remote", "--push".cyan());
        println!();
        println!("Configure remote in .asdf-config.yaml:");
        println!("  settings:");
        println!("    remote: https://github.com/org/config-repo");
        return Ok(());
    }

    // Load local config to get remote settings
    let config = if config_path.exists() {
        Config::load(config_path)?
    } else {
        if pull {
            // For pull, we can start with empty config
            Config {
                version: "1".to_string(),
                plugins: HashMap::new(),
                settings: Default::default(),
            }
        } else {
            println!("{} No local configuration found", "✗".red());
            println!("  Run 'asdf-config init' first");
            return Ok(());
        }
    };

    // Get remote URL from environment or try to detect from git
    let remote_url = std::env::var("ASDF_CONFIG_REMOTE")
        .or_else(|_| detect_git_remote())
        .context("No remote configured. Set ASDF_CONFIG_REMOTE or run from a git repository")?;

    let remote = RemoteConfig::parse(&remote_url)?;

    if verbose {
        println!("{} Remote: {}", "ℹ".blue(), remote.url);
        if let Some(ref branch) = remote.branch {
            println!("{} Branch: {}", "ℹ".blue(), branch);
        }
        println!("{} Config path: {}", "ℹ".blue(), remote.path);
    }

    if pull {
        sync_pull(config_path, &config, &remote, verbose)?;
    }

    if push {
        sync_push(config_path, &config, &remote, verbose)?;
    }

    Ok(())
}

/// Pull remote configuration and merge with local
fn sync_pull(config_path: &Path, local_config: &Config, remote: &RemoteConfig, verbose: bool) -> Result<()> {
    println!("{} Pulling remote configuration...", "→".blue());

    let raw_url = remote.get_raw_url()?;

    if verbose {
        println!("  Fetching: {}", raw_url);
    }

    // Fetch remote config
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .user_agent("asdf-config/0.1.0")
        .build()?;

    let response = client.get(&raw_url).send();

    let remote_content = match response {
        Ok(resp) if resp.status().is_success() => {
            resp.text().context("Failed to read response")?
        }
        Ok(resp) => {
            let status = resp.status();
            if status.as_u16() == 404 {
                println!("{} Remote config not found at {}", "!".yellow(), raw_url);
                println!("  Creating new remote config on push");
                return Ok(());
            }
            anyhow::bail!("HTTP error: {}", status);
        }
        Err(e) => {
            // Try git clone as fallback
            if verbose {
                println!("  HTTP fetch failed: {}, trying git clone...", e);
            }
            return sync_pull_via_git(config_path, local_config, remote, verbose);
        }
    };

    // Parse remote config
    let remote_config: Config = if remote.path.ends_with(".toml") {
        toml::from_str(&remote_content).context("Failed to parse remote TOML config")?
    } else {
        serde_yaml::from_str(&remote_content).context("Failed to parse remote YAML config")?
    };

    // Merge configurations
    let merged = merge_configs(local_config, &remote_config, verbose);

    // Save merged config
    merged.save(config_path)?;

    println!("{} Merged {} plugins from remote", "✓".green(), remote_config.plugins.len());
    println!("  Local config updated: {}", config_path.display());

    Ok(())
}

/// Fallback to git clone for pulling
fn sync_pull_via_git(config_path: &Path, local_config: &Config, remote: &RemoteConfig, verbose: bool) -> Result<()> {
    let temp_dir = tempfile::tempdir().context("Failed to create temp directory")?;
    let temp_path = temp_dir.path();

    println!("  Cloning repository...");

    let mut git_args = vec!["clone", "--depth", "1"];
    if let Some(ref branch) = remote.branch {
        git_args.extend(["--branch", branch]);
    }
    git_args.extend([&remote.url, temp_path.to_str().unwrap()]);

    let clone_result = Command::new("git")
        .args(&git_args)
        .output()
        .context("Failed to run git clone")?;

    if !clone_result.status.success() {
        let stderr = String::from_utf8_lossy(&clone_result.stderr);
        anyhow::bail!("Git clone failed: {}", stderr.trim());
    }

    // Read remote config from cloned repo
    let remote_config_path = temp_path.join(&remote.path);
    if !remote_config_path.exists() {
        println!("{} Remote config file not found: {}", "!".yellow(), remote.path);
        return Ok(());
    }

    let remote_config = Config::load(&remote_config_path)?;

    // Merge configurations
    let merged = merge_configs(local_config, &remote_config, verbose);

    // Save merged config
    merged.save(config_path)?;

    println!("{} Merged {} plugins from remote", "✓".green(), remote_config.plugins.len());

    Ok(())
}

/// Push local configuration to remote repository
fn sync_push(config_path: &Path, config: &Config, remote: &RemoteConfig, verbose: bool) -> Result<()> {
    println!("{} Pushing local configuration...", "→".blue());

    // Check if we're in a git repo that matches the remote
    let current_remote = detect_git_remote().ok();
    let is_same_repo = current_remote.as_ref().map_or(false, |r| r.contains(&remote.url) || remote.url.contains(r));

    if is_same_repo {
        // We're in the config repo, just commit and push
        push_via_git_commit(config_path, config, remote, verbose)?;
    } else {
        // Clone the remote, update config, commit and push
        push_via_git_clone(config_path, config, remote, verbose)?;
    }

    Ok(())
}

/// Push by committing to current git repo
fn push_via_git_commit(config_path: &Path, _config: &Config, _remote: &RemoteConfig, verbose: bool) -> Result<()> {
    // Stage the config file
    let add_result = Command::new("git")
        .args(["add", config_path.to_str().unwrap()])
        .output()
        .context("Failed to stage config file")?;

    if !add_result.status.success() {
        let stderr = String::from_utf8_lossy(&add_result.stderr);
        anyhow::bail!("Git add failed: {}", stderr.trim());
    }

    // Check if there are changes to commit
    let status_output = Command::new("git")
        .args(["status", "--porcelain", config_path.to_str().unwrap()])
        .output()?;

    let status = String::from_utf8_lossy(&status_output.stdout);
    if status.trim().is_empty() {
        println!("{} No changes to push", "ℹ".blue());
        return Ok(());
    }

    // Commit
    let commit_result = Command::new("git")
        .args(["commit", "-m", "chore: sync asdf-config plugins"])
        .output()
        .context("Failed to commit")?;

    if verbose {
        let stdout = String::from_utf8_lossy(&commit_result.stdout);
        if !stdout.is_empty() {
            println!("  {}", stdout.trim());
        }
    }

    // Push
    println!("  Pushing to remote...");
    let push_result = Command::new("git")
        .args(["push"])
        .output()
        .context("Failed to push")?;

    if !push_result.status.success() {
        let stderr = String::from_utf8_lossy(&push_result.stderr);
        anyhow::bail!("Git push failed: {}", stderr.trim());
    }

    println!("{} Configuration pushed successfully", "✓".green());

    Ok(())
}

/// Push by cloning remote, updating, and pushing
fn push_via_git_clone(_config_path: &Path, config: &Config, remote: &RemoteConfig, verbose: bool) -> Result<()> {
    let temp_dir = tempfile::tempdir().context("Failed to create temp directory")?;
    let temp_path = temp_dir.path();

    println!("  Cloning remote repository...");

    let mut git_args = vec!["clone", "--depth", "1"];
    if let Some(ref branch) = remote.branch {
        git_args.extend(["--branch", branch]);
    }
    git_args.extend([&remote.url, temp_path.to_str().unwrap()]);

    let clone_result = Command::new("git")
        .args(&git_args)
        .output()
        .context("Failed to clone remote")?;

    if !clone_result.status.success() {
        let stderr = String::from_utf8_lossy(&clone_result.stderr);
        anyhow::bail!("Git clone failed: {}", stderr.trim());
    }

    // Copy config to cloned repo
    let remote_config_path = temp_path.join(&remote.path);

    // Create parent directories if needed
    if let Some(parent) = remote_config_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Save config in appropriate format
    config.save(&remote_config_path)?;

    if verbose {
        println!("  Updated: {}", remote.path);
    }

    // Stage, commit, push
    let git_commands = vec![
        vec!["add", remote.path.as_str()],
        vec!["commit", "-m", "chore: sync asdf-config plugins"],
        vec!["push"],
    ];

    for args in git_commands {
        let result = Command::new("git")
            .current_dir(temp_path)
            .args(&args)
            .output()
            .context(format!("Failed to run git {}", args[0]))?;

        if !result.status.success() {
            let stderr = String::from_utf8_lossy(&result.stderr);
            // Skip if nothing to commit
            if args[0] == "commit" && stderr.contains("nothing to commit") {
                println!("{} No changes to push", "ℹ".blue());
                return Ok(());
            }
            anyhow::bail!("Git {} failed: {}", args[0], stderr.trim());
        }
    }

    println!("{} Configuration pushed successfully", "✓".green());

    Ok(())
}

/// Merge two configurations, preferring remote for conflicts
fn merge_configs(local: &Config, remote: &Config, verbose: bool) -> Config {
    let mut merged_plugins = local.plugins.clone();

    for (name, remote_plugin) in &remote.plugins {
        if let Some(local_plugin) = merged_plugins.get(name) {
            // Compare versions - keep newer or remote if different
            if local_plugin.version != remote_plugin.version {
                if verbose {
                    println!("  {} {} {} → {}",
                             "↔".cyan(), name,
                             local_plugin.version.dimmed(),
                             remote_plugin.version.green());
                }
                merged_plugins.insert(name.clone(), remote_plugin.clone());
            }
        } else {
            // Plugin only in remote, add it
            if verbose {
                println!("  {} {} @ {}",
                         "+".green(), name,
                         remote_plugin.version);
            }
            merged_plugins.insert(name.clone(), remote_plugin.clone());
        }
    }

    Config {
        version: remote.version.clone(),
        plugins: merged_plugins,
        settings: remote.settings.clone(),
    }
}

/// Detect git remote URL from current repository
fn detect_git_remote() -> Result<String> {
    let output = Command::new("git")
        .args(["remote", "get-url", "origin"])
        .output()
        .context("Failed to get git remote")?;

    if output.status.success() {
        let url = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(url)
    } else {
        anyhow::bail!("No git remote found")
    }
}
