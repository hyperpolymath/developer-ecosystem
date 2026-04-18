//! Plugin update command

use anyhow::Result;
use asdf_config::AcceleratorConfig;
use asdf_core::Plugin;
use asdf_metrics::MetricsCollector;
use asdf_parallel::{Executor, ExecutorConfig, Strategy};
use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};

pub fn execute(
    config: &AcceleratorConfig,
    all: bool,
    plugins: Vec<String>,
    exclude: Vec<String>,
    cache_ttl: u64,
    background: bool,
    jobs: Option<usize>,
) -> Result<()> {
    println!("{} Updating asdf plugins...", "→".cyan());

    // Get list of plugins
    let mut plugin_list = if all {
        Plugin::list()?
    } else if !plugins.is_empty() {
        plugins
            .into_iter()
            .map(|name| Plugin::new(name))
            .collect()
    } else {
        println!("{} Please specify --all or plugin names", "✗".red());
        return Ok(());
    };

    // Filter excluded plugins
    plugin_list.retain(|p| !exclude.contains(&p.name));

    println!(
        "{} Found {} plugins to update",
        "✓".green(),
        plugin_list.len()
    );

    // Create executor
    let strategy = jobs
        .map(Strategy::Fixed)
        .unwrap_or(config.parallel.strategy);

    let executor_config = ExecutorConfig {
        strategy,
        fail_fast: config.parallel.fail_fast,
        max_retries: config.parallel.max_retries,
    };

    let executor = Executor::new(executor_config);

    // Create progress bar
    let pb = ProgressBar::new(plugin_list.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("#>-"),
    );

    // Initialize metrics
    let mut metrics = MetricsCollector::new();
    metrics.start();

    // Execute updates
    let results = executor.execute(plugin_list, |plugin| {
        pb.set_message(format!("Updating {}", plugin.name));
        let result = plugin.update().map_err(asdf_parallel::Error::from);
        pb.inc(1);
        result
    });

    pb.finish_with_message("Done");

    // Report results
    match results {
        Ok(updated) => {
            for _ in updated {
                metrics.record_success();
            }
            println!(
                "\n{} Successfully updated {} plugins",
                "✓".green(),
                metrics.metrics().operations_succeeded
            );
        }
        Err(e) => {
            metrics.record_failure();
            println!("\n{} Update failed: {}", "✗".red(), e);
        }
    }

    Ok(())
}
