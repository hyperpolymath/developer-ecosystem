//! Cache management command

use anyhow::Result;
use asdf_cache::DiskCache;
use asdf_config::AcceleratorConfig;
use colored::Colorize;

pub fn execute(config: &AcceleratorConfig, clear: bool, stats: bool) -> Result<()> {
    let cache = DiskCache::open(&config.cache.directory)?;

    if clear {
        println!("{} Clearing cache...", "→".cyan());
        cache.clear()?;
        println!("{} Cache cleared", "✓".green());
    }

    if stats {
        println!("\n{} Cache Statistics:", "→".cyan());
        println!("  Location: {}", config.cache.directory.display());
        println!("  Entries:  {}", cache.len());
        println!("  TTL:      {}s", config.cache.ttl_secs);

        // Clean expired entries
        let removed = cache.clean_expired()?;
        if removed > 0 {
            println!("  Cleaned:  {} expired entries", removed);
        }
    }

    Ok(())
}
