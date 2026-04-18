// SPDX-License-Identifier: AGPL-3.0-or-later
//! List plugins

use anyhow::Result;
use colored::Colorize;
use std::path::Path;

use crate::config::Config;
use crate::registry::Registry;

pub fn run(config_path: &Path, all: bool, category: Option<&str>, verbose: bool) -> Result<()> {
    if all {
        list_all_available(category, verbose)?;
    } else {
        list_configured(config_path, verbose)?;
    }

    Ok(())
}

fn list_configured(config_path: &Path, verbose: bool) -> Result<()> {
    if !config_path.exists() {
        println!("{} No configuration file found", "!".yellow());
        println!("  Run 'asdf-config init' to create one");
        println!("  Or use 'asdf-config list --all' to see available plugins");
        return Ok(());
    }

    let config = Config::load(config_path)?;

    println!("{} Configured plugins:", "→".blue());
    println!();

    for (name, plugin) in &config.plugins {
        let optional = if plugin.optional { " (optional)".dimmed().to_string() } else { String::new() };
        println!("  {} {} @ {}{}", "•".cyan(), name.bold(), plugin.version.green(), optional);

        if verbose && !plugin.post_install.is_empty() {
            for cmd in &plugin.post_install {
                println!("    {} {}", "→".dimmed(), cmd.dimmed());
            }
        }
    }

    println!();
    println!("{} Total: {} plugins", "ℹ".blue(), config.plugins.len());

    Ok(())
}

fn list_all_available(category: Option<&str>, verbose: bool) -> Result<()> {
    println!("{} Fetching available plugins...", "→".blue());

    // Try to fetch from registry first
    let registry = Registry::new().ok();
    let dynamic_plugins = registry.and_then(|r| r.get_all_plugins().ok());

    if let Some(ref plugins) = dynamic_plugins {
        if !plugins.is_empty() {
            println!("{} Available plugins from GitHub:", "✓".green());
            println!();

            for (cat, items) in plugins {
                if category.is_some() && category != Some(cat.as_str()) {
                    continue;
                }

                println!("  {} {}:", "▸".cyan(), cat.bold());
                for plugin in items.iter().take(10) {
                    let stars = if plugin.stars > 0 {
                        format!(" ⭐{}", plugin.stars)
                    } else {
                        String::new()
                    };
                    println!("    {} {} - {}{}",
                             "•".dimmed(),
                             plugin.name.green(),
                             plugin.description.chars().take(50).collect::<String>().dimmed(),
                             stars.dimmed());
                    if verbose {
                        println!("      {}", plugin.url.cyan());
                    }
                }
                println!();
            }

            if category.is_none() {
                println!("{} Use --category <name> to filter", "ℹ".blue());
            }
            println!("{} Search for more: asdf-config search <query>", "ℹ".blue());

            return Ok(());
        }
    }

    // Fallback to static list
    println!("{} Available plugins (cached):", "→".blue());
    println!();

    let plugins = get_static_plugin_list();

    for (cat, items) in &plugins {
        if category.is_some() && category != Some(*cat) {
            continue;
        }

        println!("  {} {}:", "▸".cyan(), cat.bold());
        for (name, desc) in items {
            println!("    {} {} - {}", "•".dimmed(), name.green(), desc.dimmed());
        }
        println!();
    }

    if category.is_none() {
        println!("{} Use --category <name> to filter", "ℹ".blue());
    }

    println!("{} Full registry at: {}", "ℹ".blue(), "github.com/asdf-vm/asdf-plugins".cyan());

    Ok(())
}

/// Static list of popular plugins as fallback when network is unavailable
fn get_static_plugin_list() -> Vec<(&'static str, Vec<(&'static str, &'static str)>)> {
    vec![
        ("language", vec![
            ("nodejs", "Node.js JavaScript runtime"),
            ("python", "Python interpreter"),
            ("ruby", "Ruby interpreter"),
            ("rust", "Rust programming language"),
            ("golang", "Go programming language"),
            ("deno", "Deno JavaScript/TypeScript runtime"),
            ("java", "Java Development Kit"),
            ("kotlin", "Kotlin programming language"),
            ("elixir", "Elixir programming language"),
            ("erlang", "Erlang/OTP platform"),
            ("scala", "Scala programming language"),
            ("clojure", "Clojure programming language"),
            ("haskell", "Haskell programming language"),
            ("ocaml", "OCaml programming language"),
            ("julia", "Julia programming language"),
            ("zig", "Zig programming language"),
            ("nim", "Nim programming language"),
            ("crystal", "Crystal programming language"),
        ]),
        ("database", vec![
            ("postgres", "PostgreSQL database"),
            ("mysql", "MySQL database"),
            ("mariadb", "MariaDB database"),
            ("redis", "Redis in-memory data store"),
            ("mongodb", "MongoDB document database"),
            ("sqlite", "SQLite embedded database"),
            ("neo4j", "Neo4j graph database"),
            ("arangodb", "ArangoDB multi-model database"),
            ("cassandra", "Apache Cassandra database"),
            ("couchdb", "CouchDB document database"),
        ]),
        ("devops", vec![
            ("kubectl", "Kubernetes CLI"),
            ("helm", "Kubernetes package manager"),
            ("terraform", "Infrastructure as code"),
            ("packer", "Machine image builder"),
            ("vault", "HashiCorp Vault secrets"),
            ("consul", "HashiCorp Consul service mesh"),
            ("nomad", "HashiCorp Nomad orchestrator"),
            ("docker", "Docker container runtime"),
            ("podman", "Podman container runtime"),
            ("kind", "Kubernetes in Docker"),
            ("minikube", "Local Kubernetes cluster"),
            ("k9s", "Kubernetes TUI"),
            ("argocd", "GitOps for Kubernetes"),
            ("flux", "GitOps toolkit"),
        ]),
        ("security", vec![
            ("trivy", "Vulnerability scanner"),
            ("grype", "Vulnerability scanner for containers"),
            ("syft", "SBOM generator"),
            ("cosign", "Container/artifact signing"),
            ("gitleaks", "Git secrets scanner"),
            ("age", "Modern file encryption"),
            ("sops", "Secrets operations"),
            ("step-ca", "Certificate authority"),
            ("cfssl", "PKI toolkit"),
        ]),
        ("config", vec![
            ("nickel", "Configuration language"),
            ("dhall", "Programmable configuration"),
            ("cue", "Data validation language"),
            ("jsonnet", "Data templating language"),
            ("yq", "YAML processor"),
            ("jq", "JSON processor"),
            ("taplo", "TOML toolkit"),
        ]),
        ("build", vec![
            ("cmake", "Cross-platform build system"),
            ("make", "GNU Make build tool"),
            ("bazel", "Build and test tool"),
            ("gradle", "Build automation tool"),
            ("maven", "Java build tool"),
            ("sbt", "Scala build tool"),
            ("just", "Command runner"),
            ("task", "Task runner"),
        ]),
    ]
}
