//! Plugin sync command
//!
//! Synchronizes all plugins by fetching latest updates from their repositories.

use anyhow::Result;
use asdf_config::AcceleratorConfig;
use asdf_core::Plugin;
use asdf_metrics::MetricsCollector;
use asdf_parallel::{Executor, ExecutorConfig, Strategy};
use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

pub fn execute(
    config: &AcceleratorConfig,
    exclude: Vec<String>,
    only: Vec<String>,
    background: bool,
    jobs: Option<usize>,
) -> Result<()> {
    println!("{} Syncing plugins...", "→".cyan());

    // Get list of installed plugins
    let mut plugins = Plugin::list()?;

    // Filter to only specified plugins if provided
    if !only.is_empty() {
        plugins.retain(|p| only.contains(&p.name));
    }

    // Exclude specified plugins
    plugins.retain(|p| !exclude.contains(&p.name));

    if plugins.is_empty() {
        println!("{} No plugins to sync", "!".yellow());
        return Ok(());
    }

    println!(
        "{} Found {} plugins to sync",
        "✓".green(),
        plugins.len()
    );

    if background {
        println!("{} Running in background mode", "→".cyan());
        return execute_background(config, plugins, jobs);
    }

    // Create executor with configured strategy
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
    let pb = ProgressBar::new(plugins.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("#>-"),
    );

    // Initialize metrics
    let mut metrics = MetricsCollector::new();
    metrics.start();

    // Track sync results
    let success_count = Arc::new(AtomicUsize::new(0));
    let failure_count = Arc::new(AtomicUsize::new(0));
    let success_counter = success_count.clone();
    let failure_counter = failure_count.clone();

    // Execute sync operations in parallel
    let results = executor.execute(plugins, |plugin| {
        pb.set_message(format!("Syncing {}", plugin.name));

        // Sync operation = update plugin to latest
        let result = plugin.update().map_err(asdf_parallel::Error::from);

        match &result {
            Ok(_) => {
                success_counter.fetch_add(1, Ordering::SeqCst);
            }
            Err(_) => {
                failure_counter.fetch_add(1, Ordering::SeqCst);
            }
        }

        pb.inc(1);
        result
    });

    pb.finish_with_message("Done");

    // Record metrics
    let successes = success_count.load(Ordering::SeqCst);
    let failures = failure_count.load(Ordering::SeqCst);

    for _ in 0..successes {
        metrics.record_success();
    }
    for _ in 0..failures {
        metrics.record_failure();
    }

    // Report results
    println!();
    match results {
        Ok(_) => {
            println!(
                "{} Sync complete: {} succeeded, {} failed",
                "✓".green(),
                successes.to_string().green(),
                failures.to_string().red()
            );
        }
        Err(e) => {
            println!(
                "{} Sync completed with errors: {}",
                "!".yellow(),
                e
            );
            println!(
                "  {} succeeded, {} failed",
                successes.to_string().green(),
                failures.to_string().red()
            );
        }
    }

    // Show timing info
    let timing = metrics.metrics();
    if timing.operations_total > 0 {
        println!(
            "{} Total time: {:.2}s (avg: {:.2}s per plugin)",
            "→".cyan(),
            timing.total_duration.as_secs_f64(),
            timing.average_duration.as_secs_f64()
        );
    }

    Ok(())
}

/// Execute sync in background mode (daemonized)
fn execute_background(
    config: &AcceleratorConfig,
    plugins: Vec<Plugin>,
    jobs: Option<usize>,
) -> Result<()> {
    use std::process::Command;
    use std::env;

    // Get the current executable path
    let exe = env::current_exe()?;

    // Build the command arguments
    let mut args = vec!["sync".to_string()];

    // Add plugin names
    for plugin in &plugins {
        args.push("--only".to_string());
        args.push(plugin.name.clone());
    }

    // Add jobs if specified
    if let Some(j) = jobs {
        args.push("--jobs".to_string());
        args.push(j.to_string());
    }

    // Spawn background process
    let child = Command::new(&exe)
        .args(&args)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();

    match child {
        Ok(c) => {
            println!(
                "{} Background sync started (PID: {})",
                "✓".green(),
                c.id()
            );
            println!("{} Plugins will be synced in the background", "→".cyan());
        }
        Err(e) => {
            println!(
                "{} Failed to start background sync: {}",
                "✗".red(),
                e
            );
            // Fall back to foreground execution
            println!("{} Falling back to foreground sync...", "→".yellow());
            return execute(config, vec![], plugins.iter().map(|p| p.name.clone()).collect(), false, jobs);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_execute_empty_plugins() {
        // Test would require mocking Plugin::list()
        // This is a placeholder for integration tests
        assert!(true);
    }
}
