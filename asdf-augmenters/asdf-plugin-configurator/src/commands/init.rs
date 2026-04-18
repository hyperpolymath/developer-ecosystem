// SPDX-License-Identifier: AGPL-3.0-or-later
//! Initialize a new configuration file

use anyhow::Result;
use colored::Colorize;
use std::path::Path;

use crate::config;

pub fn run(format: &str, verbose: bool) -> Result<()> {
    let filename = match format {
        "toml" => ".asdf-config.toml",
        _ => ".asdf-config.yaml",
    };

    let path = Path::new(filename);

    if path.exists() {
        println!("{} Configuration file already exists: {}", "!".yellow(), filename);
        return Ok(());
    }

    let template = config::default_template(format);
    std::fs::write(path, &template)?;

    println!("{} Created {}", "✓".green(), filename.cyan());

    if verbose {
        println!("\n{}", "Template contents:".dimmed());
        println!("{}", template);
    }

    println!("\n{}", "Next steps:".bold());
    println!("  1. Edit {} to add your plugins", filename);
    println!("  2. Run 'asdf-config validate' to check configuration");
    println!("  3. Run 'asdf-config install' to install plugins");

    Ok(())
}
