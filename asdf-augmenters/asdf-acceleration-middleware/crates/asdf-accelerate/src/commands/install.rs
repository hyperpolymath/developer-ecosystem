//! Runtime installation command

use anyhow::{Context, Result};
use asdf_config::AcceleratorConfig;
use asdf_core::{Runtime, Version};
use asdf_parallel::{Executor, ExecutorConfig, Strategy};
use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};

pub fn execute(
    config: &AcceleratorConfig,
    runtimes: Vec<String>,
    parallel: bool,
    jobs: Option<usize>,
) -> Result<()> {
    println!("{} Installing runtimes...", "→".cyan());

    // Parse runtime specifications
    let runtime_list: Result<Vec<Runtime>> = runtimes
        .iter()
        .map(|spec| parse_runtime_spec(spec))
        .collect();

    let runtime_list = runtime_list?;

    println!(
        "{} Installing {} runtimes",
        "✓".green(),
        runtime_list.len()
    );

    // Create executor
    let strategy = if parallel {
        jobs.map(Strategy::Fixed)
            .unwrap_or(config.parallel.strategy)
    } else {
        Strategy::Sequential
    };

    let executor_config = ExecutorConfig {
        strategy,
        fail_fast: config.parallel.fail_fast,
        max_retries: config.parallel.max_retries,
    };

    let executor = Executor::new(executor_config);

    // Create progress bar
    let pb = ProgressBar::new(runtime_list.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("#>-"),
    );

    // Execute installations
    let results = executor.execute(runtime_list, |runtime| {
        pb.set_message(format!("Installing {}@{}", runtime.plugin, runtime.version));
        let result = runtime.install().map_err(asdf_parallel::Error::from);
        pb.inc(1);
        result
    });

    pb.finish_with_message("Done");

    // Report results
    match results {
        Ok(installed) => {
            println!(
                "\n{} Successfully installed {} runtimes",
                "✓".green(),
                installed.len()
            );
        }
        Err(e) => {
            println!("\n{} Installation failed: {}", "✗".red(), e);
        }
    }

    Ok(())
}

/// Parse runtime specification (format: plugin@version)
fn parse_runtime_spec(spec: &str) -> Result<Runtime> {
    let parts: Vec<&str> = spec.split('@').collect();

    if parts.len() != 2 {
        anyhow::bail!(
            "Invalid runtime specification: {}. Expected format: plugin@version",
            spec
        );
    }

    let plugin = parts[0];
    let version = Version::parse(parts[1])
        .with_context(|| format!("Invalid version: {}", parts[1]))?;

    Ok(Runtime::new(plugin, version))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_runtime_spec() {
        let runtime = parse_runtime_spec("nodejs@20.0.0").unwrap();
        assert_eq!(runtime.plugin, "nodejs");
        assert_eq!(runtime.version.to_string(), "20.0.0");
    }

    #[test]
    fn test_parse_invalid_spec() {
        let result = parse_runtime_spec("nodejs");
        assert!(result.is_err());
    }
}
