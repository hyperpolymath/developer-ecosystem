//! Parallel execution engine for asdf operations using Rayon

pub mod error;
pub mod executor;
pub mod strategy;

pub use error::{Error, Result};
pub use executor::{Executor, ExecutorConfig};
pub use strategy::Strategy;

use rayon::ThreadPoolBuilder;

/// Initialize the global thread pool with custom configuration
pub fn init_thread_pool(num_threads: Option<usize>) -> Result<()> {
    let mut builder = ThreadPoolBuilder::new();

    if let Some(n) = num_threads {
        builder = builder.num_threads(n);
    }

    builder
        .build_global()
        .map_err(|e| Error::ThreadPoolInit(e.to_string()))?;

    Ok(())
}

/// Get the optimal number of threads based on system resources
pub fn optimal_thread_count() -> usize {
    num_cpus::get_physical()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_optimal_thread_count() {
        let count = optimal_thread_count();
        assert!(count > 0);
    }
}
