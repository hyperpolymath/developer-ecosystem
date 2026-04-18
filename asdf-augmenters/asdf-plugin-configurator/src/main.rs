// SPDX-License-Identifier: AGPL-3.0-or-later
//! asdf-config: Declarative configuration management for asdf plugins

use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::Colorize;
use std::path::PathBuf;

mod config;
mod commands;
mod registry;

use commands::{init, validate, list, install, sync, export};

/// Declarative configuration management for asdf plugins
#[derive(Parser)]
#[command(name = "asdf-config")]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Configuration file path (default: .asdf-config.yaml)
    #[arg(short, long, global = true)]
    config: Option<PathBuf>,

    /// Verbose output
    #[arg(short, long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new configuration file
    Init {
        /// Output format (yaml or toml)
        #[arg(short, long, default_value = "yaml")]
        format: String,
    },

    /// Validate configuration file
    Validate,

    /// List configured plugins
    List {
        /// Show all available plugins (from metaiconic registry)
        #[arg(short, long)]
        all: bool,

        /// Filter by category
        #[arg(short = 'c', long)]
        category: Option<String>,
    },

    /// Install plugins from configuration
    Install {
        /// Only install specified plugin
        #[arg(short, long)]
        plugin: Option<String>,

        /// Dry run (show what would be installed)
        #[arg(short, long)]
        dry_run: bool,
    },

    /// Sync plugin versions across team
    Sync {
        /// Pull latest versions
        #[arg(short, long)]
        pull: bool,

        /// Push local versions
        #[arg(short = 'P', long)]
        push: bool,
    },

    /// Export current asdf setup to configuration
    Export {
        /// Output format (yaml or toml)
        #[arg(short, long, default_value = "yaml")]
        format: String,

        /// Output file (default: stdout)
        #[arg(short, long)]
        output: Option<PathBuf>,
    },

    /// Search available plugins (from metaiconic registry)
    Search {
        /// Search query
        query: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let config_path = cli.config.unwrap_or_else(|| {
        PathBuf::from(".asdf-config.yaml")
    });

    match cli.command {
        Commands::Init { format } => {
            init::run(&format, cli.verbose)?;
        }
        Commands::Validate => {
            validate::run(&config_path, cli.verbose)?;
        }
        Commands::List { all, category } => {
            list::run(&config_path, all, category.as_deref(), cli.verbose)?;
        }
        Commands::Install { plugin, dry_run } => {
            install::run(&config_path, plugin.as_deref(), dry_run, cli.verbose)?;
        }
        Commands::Sync { pull, push } => {
            sync::run(&config_path, pull, push, cli.verbose)?;
        }
        Commands::Export { format, output } => {
            export::run(&format, output.as_deref(), cli.verbose)?;
        }
        Commands::Search { query } => {
            search(&query, cli.verbose)?;
        }
    }

    Ok(())
}

fn search(query: &str, verbose: bool) -> Result<()> {
    println!("{} Searching for '{}'...", "→".blue(), query);
    println!();

    let registry = match registry::Registry::new() {
        Ok(r) => r,
        Err(e) => {
            if verbose {
                println!("{} Failed to initialize registry: {}", "!".yellow(), e);
            }
            println!("{} Falling back to local search", "ℹ".blue());
            return search_local(query);
        }
    };

    match registry.search_plugins(query) {
        Ok(plugins) => {
            if plugins.is_empty() {
                println!("{} No plugins found matching '{}'", "!".yellow(), query);
                println!();
                println!("Try searching for:");
                println!("  {} asdf-config search nodejs", "•".dimmed());
                println!("  {} asdf-config search rust", "•".dimmed());
                println!("  {} asdf-config search terraform", "•".dimmed());
            } else {
                println!("{} Found {} plugins:", "✓".green(), plugins.len());
                println!();

                for plugin in &plugins {
                    let stars = if plugin.stars > 0 {
                        format!(" ⭐ {}", plugin.stars)
                    } else {
                        String::new()
                    };
                    println!("  {} {}{}", "•".cyan(), plugin.name.bold(), stars.dimmed());
                    println!("    {}", plugin.description.dimmed());
                    if verbose {
                        println!("    {}", plugin.url.cyan());
                    }
                    println!();
                }

                println!("{} Add a plugin to your config with:", "ℹ".blue());
                println!("  asdf-config init && edit .asdf-config.yaml");
            }
        }
        Err(e) => {
            if verbose {
                println!("{} Search failed: {}", "✗".red(), e);
            }
            println!("{} GitHub API unavailable, using local search", "!".yellow());
            return search_local(query);
        }
    }

    Ok(())
}

/// Local fallback search using known plugins
fn search_local(query: &str) -> Result<()> {
    let known_plugins = vec![
        ("nodejs", "Node.js runtime", "language"),
        ("python", "Python interpreter", "language"),
        ("ruby", "Ruby interpreter", "language"),
        ("rust", "Rust toolchain", "language"),
        ("golang", "Go programming language", "language"),
        ("deno", "Deno runtime", "language"),
        ("java", "Java Development Kit", "language"),
        ("kotlin", "Kotlin compiler", "language"),
        ("elixir", "Elixir language", "language"),
        ("erlang", "Erlang/OTP", "language"),
        ("postgres", "PostgreSQL database", "database"),
        ("mysql", "MySQL database", "database"),
        ("redis", "Redis in-memory store", "database"),
        ("mongodb", "MongoDB database", "database"),
        ("kubectl", "Kubernetes CLI", "tool"),
        ("helm", "Kubernetes package manager", "tool"),
        ("terraform", "Infrastructure as code", "tool"),
        ("packer", "Image builder", "tool"),
        ("vault", "Secrets management", "security"),
        ("trivy", "Security scanner", "security"),
        ("grype", "Vulnerability scanner", "security"),
        ("cosign", "Container signing", "security"),
        ("nickel", "Configuration language", "config"),
        ("dhall", "Programmable configuration", "config"),
        ("yq", "YAML processor", "config"),
    ];

    let query_lower = query.to_lowercase();
    let matches: Vec<_> = known_plugins
        .iter()
        .filter(|(name, desc, _)| {
            name.contains(&query_lower) || desc.to_lowercase().contains(&query_lower)
        })
        .collect();

    if matches.is_empty() {
        println!("{} No local plugins found matching '{}'", "!".yellow(), query);
    } else {
        println!("{} Found {} plugins (local cache):", "✓".green(), matches.len());
        println!();

        for (name, desc, category) in matches {
            println!("  {} {} [{}]", "•".cyan(), name.bold(), category.dimmed());
            println!("    {}", desc.dimmed());
            println!();
        }
    }

    println!("{} For more plugins, visit: {}", "ℹ".blue(),
             "https://github.com/asdf-vm/asdf-plugins".cyan());

    Ok(())
}
