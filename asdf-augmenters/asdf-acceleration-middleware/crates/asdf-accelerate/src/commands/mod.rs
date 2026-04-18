//! Command execution

mod cache;
mod install;
mod list;
mod sync;
mod update;

use crate::cli::{Cli, Commands};
use anyhow::Result;
use asdf_config::{AcceleratorConfig, ConfigLoader};
use colored::Colorize;

/// Execute the CLI command
pub fn execute(cli: Cli) -> Result<()> {
    // Load configuration
    let config = load_config(cli.config.as_ref())?;

    // Execute subcommand
    match cli.command {
        Commands::Update {
            all,
            plugins,
            exclude,
            cache_ttl,
            background,
        } => update::execute(&config, all, plugins, exclude, cache_ttl, background, cli.jobs),

        Commands::Install { runtimes, parallel } => {
            install::execute(&config, runtimes, parallel, cli.jobs)
        }

        Commands::Sync {
            exclude,
            only,
            background,
        } => sync::execute(&config, exclude, only, background, cli.jobs),

        Commands::List { urls, format } => list::execute(&config, urls, &format),

        Commands::Cache { clear, stats } => cache::execute(&config, clear, stats),
    }
}

/// Load configuration from file or defaults
fn load_config(path: Option<&std::path::PathBuf>) -> Result<AcceleratorConfig> {
    let mut loader = ConfigLoader::new();

    if let Some(p) = path {
        println!("{} Loading configuration from {}", "→".cyan(), p.display());
        Ok(loader.load_file(p)?)
    } else {
        Ok(loader.load_with_defaults(None::<&std::path::Path>)?)
    }
}
