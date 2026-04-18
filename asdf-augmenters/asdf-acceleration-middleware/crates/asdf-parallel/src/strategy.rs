//! Execution strategies for parallel operations

use serde::{Deserialize, Serialize};

/// Parallel execution strategy
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum Strategy {
    /// Automatically determine optimal parallelism
    Auto,

    /// Sequential execution (no parallelism)
    Sequential,

    /// Fixed number of parallel jobs
    Fixed(usize),

    /// Parallel with maximum concurrency
    MaxParallel,
}

impl Strategy {
    /// Get the number of threads to use
    pub fn thread_count(&self) -> usize {
        match self {
            Strategy::Auto => crate::optimal_thread_count(),
            Strategy::Sequential => 1,
            Strategy::Fixed(n) => *n,
            Strategy::MaxParallel => num_cpus::get(),
        }
    }
}

impl Default for Strategy {
    fn default() -> Self {
        Strategy::Auto
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strategy_thread_count() {
        assert_eq!(Strategy::Sequential.thread_count(), 1);
        assert!(Strategy::Auto.thread_count() > 0);
        assert_eq!(Strategy::Fixed(4).thread_count(), 4);
    }
}
