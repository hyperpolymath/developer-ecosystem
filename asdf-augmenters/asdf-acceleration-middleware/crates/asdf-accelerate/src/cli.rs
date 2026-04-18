//! CLI argument parsing

use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "asdf-accelerate")]
#[command(about = "High-performance CLI for accelerating asdf operations", long_about = None)]
#[command(version)]
pub struct Cli {
    /// Configuration file path
    #[arg(short, long, global = true)]
    pub config: Option<PathBuf>,

    /// Verbosity level (can be repeated)
    #[arg(short, long, global = true, action = clap::ArgAction::Count)]
    pub verbose: u8,

    /// Number of parallel jobs
    #[arg(short, long, global = true)]
    pub jobs: Option<usize>,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Update asdf plugins
    Update {
        /// Update all plugins
        #[arg(long)]
        all: bool,

        /// Specific plugins to update
        plugins: Vec<String>,

        /// Exclude specific plugins
        #[arg(long)]
        exclude: Vec<String>,

        /// Cache TTL in seconds
        #[arg(long, default_value = "3600")]
        cache_ttl: u64,

        /// Run in background
        #[arg(long)]
        background: bool,
    },

    /// Install runtimes
    Install {
        /// Runtimes to install (format: plugin@version)
        runtimes: Vec<String>,

        /// Install in parallel
        #[arg(long)]
        parallel: bool,
    },

    /// Sync plugins
    Sync {
        /// Exclude specific plugins
        #[arg(long)]
        exclude: Vec<String>,

        /// Only sync specific plugins
        #[arg(long)]
        only: Vec<String>,

        /// Run in background
        #[arg(long)]
        background: bool,
    },

    /// List plugins
    List {
        /// Show URLs
        #[arg(long)]
        urls: bool,

        /// Output format (text, json)
        #[arg(long, default_value = "text")]
        format: String,
    },

    /// Clear cache
    Cache {
        /// Clear all cache
        #[arg(long)]
        clear: bool,

        /// Show cache statistics
        #[arg(long)]
        stats: bool,
    },
}
