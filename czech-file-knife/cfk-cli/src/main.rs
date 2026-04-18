// SPDX-License-Identifier: AGPL-3.0-or-later
//! Czech File Knife CLI
//!
//! A cloud-native, universal file management tool.

mod commands;

use clap::{Parser, Subcommand};
use std::process::ExitCode;

#[derive(Parser)]
#[command(name = "cfk")]
#[command(author, version, about = "Czech File Knife - Universal file management", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Verbose output
    #[arg(short, long, global = true)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// List directory contents
    #[command(alias = "dir")]
    Ls {
        /// Path to list (defaults to current directory)
        #[arg(default_value = ".")]
        path: String,

        /// Long format with details
        #[arg(short, long)]
        long: bool,

        /// Show all files including hidden
        #[arg(short, long)]
        all: bool,

        /// Human-readable sizes
        #[arg(short = 'H', long)]
        human: bool,
    },

    /// Display file contents
    Cat {
        /// File to display
        path: String,
    },

    /// Copy files or directories
    Cp {
        /// Source path
        source: String,

        /// Destination path
        dest: String,

        /// Recursive copy for directories
        #[arg(short, long)]
        recursive: bool,

        /// Force overwrite existing files
        #[arg(short, long)]
        force: bool,
    },

    /// Move or rename files
    Mv {
        /// Source path
        source: String,

        /// Destination path
        dest: String,

        /// Force overwrite existing files
        #[arg(short, long)]
        force: bool,
    },

    /// Remove files or directories
    Rm {
        /// Path(s) to remove
        #[arg(required = true)]
        paths: Vec<String>,

        /// Recursive removal for directories
        #[arg(short, long)]
        recursive: bool,

        /// Force removal without confirmation
        #[arg(short, long)]
        force: bool,
    },

    /// Create directories
    Mkdir {
        /// Directory path(s) to create
        #[arg(required = true)]
        paths: Vec<String>,

        /// Create parent directories as needed
        #[arg(short, long)]
        parents: bool,
    },

    /// Show file or directory information
    Stat {
        /// Path to inspect
        path: String,
    },

    /// List registered backends
    Backends,

    /// Show storage space information
    Df {
        /// Backend to query (defaults to local)
        #[arg(default_value = "local")]
        backend: String,
    },
}

#[tokio::main]
async fn main() -> ExitCode {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::Ls { path, long, all, human } => {
            commands::ls(&path, long, all, human, cli.verbose).await
        }
        Commands::Cat { path } => {
            commands::cat(&path, cli.verbose).await
        }
        Commands::Cp { source, dest, recursive, force } => {
            commands::cp(&source, &dest, recursive, force, cli.verbose).await
        }
        Commands::Mv { source, dest, force } => {
            commands::mv(&source, &dest, force, cli.verbose).await
        }
        Commands::Rm { paths, recursive, force } => {
            commands::rm(&paths, recursive, force, cli.verbose).await
        }
        Commands::Mkdir { paths, parents } => {
            commands::mkdir(&paths, parents, cli.verbose).await
        }
        Commands::Stat { path } => {
            commands::stat(&path, cli.verbose).await
        }
        Commands::Backends => {
            commands::backends(cli.verbose).await
        }
        Commands::Df { backend } => {
            commands::df(&backend, cli.verbose).await
        }
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("Error: {e}");
            ExitCode::FAILURE
        }
    }
}
