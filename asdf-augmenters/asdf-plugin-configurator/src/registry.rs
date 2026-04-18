// SPDX-License-Identifier: AGPL-3.0-or-later
//! Plugin registry and remote data fetching

use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::time::Duration;

/// GitHub API response for repository search
#[derive(Debug, Deserialize)]
struct GitHubSearchResponse {
    items: Vec<GitHubRepo>,
}

/// GitHub repository info
#[derive(Debug, Deserialize)]
struct GitHubRepo {
    name: String,
    description: Option<String>,
    html_url: String,
    stargazers_count: u32,
}

/// GitHub release info
#[derive(Debug, Deserialize)]
struct GitHubRelease {
    tag_name: String,
}

/// Plugin information from registry
#[derive(Debug, Clone)]
pub struct PluginInfo {
    pub name: String,
    pub description: String,
    pub url: String,
    pub stars: u32,
    pub category: String,
}

/// Available version from asdf plugin
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    pub prerelease: Option<String>,
}

impl Version {
    /// Parse version string like "1.2.3" or "v1.2.3"
    pub fn parse(s: &str) -> Option<Self> {
        let s = s.trim_start_matches('v');
        let parts: Vec<&str> = s.split('-').collect();
        let version_part = parts[0];
        let prerelease = parts.get(1).map(|s| s.to_string());

        let nums: Vec<u32> = version_part
            .split('.')
            .filter_map(|p| p.parse().ok())
            .collect();

        if nums.len() >= 3 {
            Some(Version {
                major: nums[0],
                minor: nums[1],
                patch: nums[2],
                prerelease,
            })
        } else if nums.len() == 2 {
            Some(Version {
                major: nums[0],
                minor: nums[1],
                patch: 0,
                prerelease,
            })
        } else {
            None
        }
    }

    /// Format as string
    pub fn to_string(&self) -> String {
        match &self.prerelease {
            Some(pre) => format!("{}.{}.{}-{}", self.major, self.minor, self.patch, pre),
            None => format!("{}.{}.{}", self.major, self.minor, self.patch),
        }
    }

    /// Check if this version satisfies a constraint
    pub fn satisfies(&self, constraint: &str) -> bool {
        if constraint == "latest" || constraint == "stable" {
            return self.prerelease.is_none();
        }

        let (op, version_str) = if constraint.starts_with(">=") {
            (">=", &constraint[2..])
        } else if constraint.starts_with("<=") {
            ("<=", &constraint[2..])
        } else if constraint.starts_with('>') {
            (">", &constraint[1..])
        } else if constraint.starts_with('<') {
            ("<", &constraint[1..])
        } else if constraint.starts_with('^') {
            ("^", &constraint[1..])
        } else if constraint.starts_with('~') {
            ("~", &constraint[1..])
        } else {
            ("=", constraint)
        };

        let Some(target) = Version::parse(version_str) else {
            return false;
        };

        match op {
            "=" => self == &target,
            ">=" => self >= &target,
            "<=" => self <= &target,
            ">" => self > &target,
            "<" => self < &target,
            "^" => {
                // Caret: compatible with (same major, >= minor.patch)
                self.major == target.major
                    && (self.minor > target.minor
                        || (self.minor == target.minor && self.patch >= target.patch))
            }
            "~" => {
                // Tilde: same major.minor, >= patch
                self.major == target.major
                    && self.minor == target.minor
                    && self.patch >= target.patch
            }
            _ => false,
        }
    }
}

/// Registry client for fetching plugin information
pub struct Registry {
    client: reqwest::blocking::Client,
}

impl Registry {
    /// Create a new registry client
    pub fn new() -> Result<Self> {
        let client = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(30))
            .user_agent("asdf-config/0.1.0")
            .build()
            .context("Failed to create HTTP client")?;

        Ok(Self { client })
    }

    /// Search for asdf plugins on GitHub
    pub fn search_plugins(&self, query: &str) -> Result<Vec<PluginInfo>> {
        let search_query = format!("asdf-{} in:name OR asdf {} plugin in:description", query, query);
        let url = format!(
            "https://api.github.com/search/repositories?q={}&sort=stars&per_page=20",
            urlencoding::encode(&search_query)
        );

        let response: GitHubSearchResponse = self.client
            .get(&url)
            .header("Accept", "application/vnd.github.v3+json")
            .send()
            .context("Failed to search GitHub")?
            .json()
            .context("Failed to parse search results")?;

        let plugins: Vec<PluginInfo> = response.items
            .into_iter()
            .filter(|repo| repo.name.starts_with("asdf-") || repo.name.contains("-plugin"))
            .map(|repo| {
                let name = repo.name
                    .trim_start_matches("asdf-")
                    .trim_end_matches("-plugin")
                    .to_string();
                let category = categorize_plugin(&name);

                PluginInfo {
                    name,
                    description: repo.description.unwrap_or_else(|| "No description".to_string()),
                    url: repo.html_url,
                    stars: repo.stargazers_count,
                    category,
                }
            })
            .collect();

        Ok(plugins)
    }

    /// Get available versions for a plugin from asdf
    pub fn get_available_versions(&self, plugin: &str) -> Result<Vec<Version>> {
        // First try to get versions from asdf itself
        let output = std::process::Command::new("asdf")
            .args(["list", "all", plugin])
            .output();

        if let Ok(output) = output {
            if output.status.success() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let versions: Vec<Version> = stdout
                    .lines()
                    .filter_map(|line| Version::parse(line.trim()))
                    .collect();

                if !versions.is_empty() {
                    return Ok(versions);
                }
            }
        }

        // Fallback: try GitHub releases for common plugins
        let repo = match plugin {
            "nodejs" => Some("nodejs/node"),
            "rust" => Some("rust-lang/rust"),
            "python" => Some("python/cpython"),
            "ruby" => Some("ruby/ruby"),
            "golang" | "go" => Some("golang/go"),
            "deno" => Some("denoland/deno"),
            _ => None,
        };

        if let Some(repo) = repo {
            return self.get_github_releases(repo);
        }

        Ok(vec![])
    }

    /// Get releases from a GitHub repository
    fn get_github_releases(&self, repo: &str) -> Result<Vec<Version>> {
        let url = format!("https://api.github.com/repos/{}/releases?per_page=50", repo);

        let response: Vec<GitHubRelease> = self.client
            .get(&url)
            .header("Accept", "application/vnd.github.v3+json")
            .send()
            .context("Failed to fetch releases")?
            .json()
            .context("Failed to parse releases")?;

        let versions: Vec<Version> = response
            .into_iter()
            .filter_map(|r| Version::parse(&r.tag_name))
            .collect();

        Ok(versions)
    }

    /// Get all available plugins from known sources
    pub fn get_all_plugins(&self) -> Result<HashMap<String, Vec<PluginInfo>>> {
        let mut categories: HashMap<String, Vec<PluginInfo>> = HashMap::new();

        // Search for different categories
        let searches = vec![
            ("language", vec!["nodejs", "python", "ruby", "rust", "golang", "deno"]),
            ("database", vec!["postgres", "mysql", "redis", "mongodb"]),
            ("tool", vec!["kubectl", "helm", "terraform", "docker"]),
            ("security", vec!["trivy", "grype", "cosign"]),
        ];

        for (category, keywords) in searches {
            for keyword in keywords {
                if let Ok(plugins) = self.search_plugins(keyword) {
                    for mut plugin in plugins {
                        plugin.category = category.to_string();
                        categories
                            .entry(category.to_string())
                            .or_default()
                            .push(plugin);
                    }
                }
            }
        }

        // Deduplicate by name
        for plugins in categories.values_mut() {
            plugins.sort_by(|a, b| b.stars.cmp(&a.stars));
            plugins.dedup_by(|a, b| a.name == b.name);
        }

        Ok(categories)
    }
}

/// Categorize a plugin by its name
fn categorize_plugin(name: &str) -> String {
    let languages = ["nodejs", "python", "ruby", "rust", "golang", "go", "java", "kotlin",
                     "scala", "elixir", "erlang", "crystal", "nim", "zig", "deno", "bun",
                     "lua", "perl", "php", "r", "julia", "ocaml", "haskell", "clojure"];

    let databases = ["postgres", "mysql", "mariadb", "redis", "mongodb", "sqlite",
                     "cassandra", "neo4j", "arangodb", "couchdb", "influxdb"];

    let tools = ["kubectl", "helm", "terraform", "packer", "vault", "consul",
                 "nomad", "docker", "podman", "k9s", "kind", "minikube"];

    let security = ["trivy", "grype", "syft", "cosign", "gitleaks", "age",
                    "sops", "sealed-secrets", "vault"];

    if languages.contains(&name) {
        "language".to_string()
    } else if databases.contains(&name) {
        "database".to_string()
    } else if tools.contains(&name) {
        "tool".to_string()
    } else if security.contains(&name) {
        "security".to_string()
    } else {
        "other".to_string()
    }
}

/// Resolve a version constraint to a specific version
pub fn resolve_version(constraint: &str, available: &[Version]) -> Option<String> {
    if constraint == "latest" {
        // Get latest stable version
        return available
            .iter()
            .filter(|v| v.prerelease.is_none())
            .max()
            .map(|v| v.to_string());
    }

    if constraint == "stable" {
        // Get latest stable version
        return available
            .iter()
            .filter(|v| v.prerelease.is_none())
            .max()
            .map(|v| v.to_string());
    }

    // Find the best matching version for the constraint
    let mut matching: Vec<&Version> = available
        .iter()
        .filter(|v| v.satisfies(constraint))
        .collect();

    matching.sort();
    matching.last().map(|v| v.to_string())
}

// Simple URL encoding (we could use a crate, but this is minimal)
mod urlencoding {
    pub fn encode(s: &str) -> String {
        let mut result = String::with_capacity(s.len() * 3);
        for c in s.chars() {
            match c {
                'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' | '.' | '~' => result.push(c),
                ' ' => result.push_str("%20"),
                _ => {
                    for byte in c.to_string().as_bytes() {
                        result.push_str(&format!("%{:02X}", byte));
                    }
                }
            }
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parse() {
        assert_eq!(
            Version::parse("1.2.3"),
            Some(Version { major: 1, minor: 2, patch: 3, prerelease: None })
        );
        assert_eq!(
            Version::parse("v20.10.0"),
            Some(Version { major: 20, minor: 10, patch: 0, prerelease: None })
        );
        assert_eq!(
            Version::parse("1.2.3-beta"),
            Some(Version { major: 1, minor: 2, patch: 3, prerelease: Some("beta".to_string()) })
        );
    }

    #[test]
    fn test_version_satisfies() {
        let v = Version::parse("1.5.0").unwrap();
        assert!(v.satisfies(">=1.0.0"));
        assert!(v.satisfies("^1.0.0"));
        assert!(v.satisfies("~1.5.0"));
        assert!(!v.satisfies("~1.4.0"));
        assert!(!v.satisfies(">=2.0.0"));
    }

    #[test]
    fn test_resolve_version() {
        let versions = vec![
            Version::parse("1.0.0").unwrap(),
            Version::parse("1.5.0").unwrap(),
            Version::parse("2.0.0").unwrap(),
            Version::parse("2.1.0-beta").unwrap(),
        ];

        assert_eq!(resolve_version("latest", &versions), Some("2.0.0".to_string()));
        assert_eq!(resolve_version("^1.0.0", &versions), Some("1.5.0".to_string()));
        assert_eq!(resolve_version(">=2.0.0", &versions), Some("2.1.0-beta".to_string()));
    }
}
