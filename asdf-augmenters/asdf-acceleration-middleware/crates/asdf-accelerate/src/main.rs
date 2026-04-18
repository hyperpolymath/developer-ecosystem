//! asdf-accelerate - High-performance CLI for accelerating asdf operations

mod cli;
mod commands;

use anyhow::Result;
use clap::Parser;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "asdf_accelerate=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Parse command-line arguments
    let cli = cli::Cli::parse();

    // Execute command
    commands::execute(cli)?;

    Ok(())
}
