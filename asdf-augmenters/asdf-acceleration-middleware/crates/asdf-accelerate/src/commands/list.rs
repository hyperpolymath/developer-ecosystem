//! Plugin list command

use anyhow::Result;
use asdf_config::AcceleratorConfig;
use asdf_core::Plugin;
use colored::Colorize;

pub fn execute(_config: &AcceleratorConfig, urls: bool, format: &str) -> Result<()> {
    let plugins = Plugin::list()?;

    match format {
        "json" => {
            let json = serde_json::to_string_pretty(&plugins)?;
            println!("{}", json);
        }
        _ => {
            println!("{} Installed plugins:", "→".cyan());
            for plugin in plugins {
                if urls {
                    if let Some(url) = &plugin.url {
                        println!("  {} {}", plugin.name.green(), url.bright_black());
                    } else {
                        println!("  {}", plugin.name.green());
                    }
                } else {
                    println!("  {}", plugin.name.green());
                }
            }
        }
    }

    Ok(())
}
