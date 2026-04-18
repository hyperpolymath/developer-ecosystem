//! asdf-discover - Auto-discovery tool for asdf runtimes

use anyhow::Result;
use asdf_core::{Plugin, Runtime};
use clap::{Parser, Subcommand};
use colored::Colorize;

#[derive(Parser)]
#[command(name = "asdf-discover")]
#[command(about = "Auto-discovery tool for asdf runtimes")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Scan system for installed runtimes
    Scan {
        /// Deep scan (slower but more thorough)
        #[arg(long)]
        deep: bool,

        /// Output format (text, json, nickel)
        #[arg(long, default_value = "text")]
        format: String,
    },

    /// Generate configuration file
    Generate {
        /// Output format (nickel, json, toml)
        #[arg(long, default_value = "nickel")]
        format: String,

        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Validate existing setup
    Validate,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Scan { deep, format } => scan(deep, &format),
        Commands::Generate { format, output } => generate(&format, output.as_deref()),
        Commands::Validate => validate(),
    }
}

fn scan(deep: bool, format: &str) -> Result<()> {
    println!("{} Scanning system for runtimes...", "→".cyan());

    if deep {
        println!("{} Running deep scan...", "→".cyan());
    }

    let plugins = Plugin::list()?;

    println!("{} Found {} plugins", "✓".green(), plugins.len());

    for plugin in &plugins {
        if let Ok(runtimes) = Runtime::list_for_plugin(&plugin.name) {
            println!("\n  {} ({} versions)", plugin.name.bright_white(), runtimes.len());
            for runtime in runtimes {
                let marker = if runtime.active { "*" } else { " " };
                println!(
                    "    {} {}",
                    marker.green(),
                    runtime.version.to_string().bright_black()
                );
            }
        }
    }

    if format == "json" {
        let json = serde_json::to_string_pretty(&plugins)?;
        println!("\n{}", json);
    }

    Ok(())
}

fn generate(format: &str, output: Option<&str>) -> Result<()> {
    println!("{} Generating configuration...", "→".cyan());

    let plugins = Plugin::list()?;

    let config = match format {
        "nickel" => generate_nickel_config(&plugins),
        "json" => serde_json::to_string_pretty(&plugins)?,
        "toml" => toml::to_string_pretty(&plugins)?,
        _ => anyhow::bail!("Unsupported format: {}", format),
    };

    if let Some(path) = output {
        std::fs::write(path, &config)?;
        println!("{} Configuration written to {}", "✓".green(), path);
    } else {
        println!("{}", config);
    }

    Ok(())
}

fn generate_nickel_config(plugins: &[Plugin]) -> String {
    let mut config = String::from("{\n  asdf = {\n    plugins = [\n");

    for plugin in plugins {
        config.push_str(&format!("      \"{}\",\n", plugin.name));
    }

    config.push_str("    ],\n  },\n}\n");
    config
}

fn validate() -> Result<()> {
    println!("{} Validating asdf setup...", "→".cyan());

    if !asdf_core::is_asdf_installed() {
        println!("{} asdf is not installed", "✗".red());
        return Ok(());
    }

    println!("{} asdf is installed", "✓".green());

    let version = asdf_core::asdf_version()?;
    println!("  Version: {}", version);

    let dir = asdf_core::asdf_dir()?;
    println!("  Directory: {}", dir.display());

    let plugins = Plugin::list()?;
    println!("  Plugins: {}", plugins.len());

    println!("\n{} Setup is valid", "✓".green().bold());

    Ok(())
}
