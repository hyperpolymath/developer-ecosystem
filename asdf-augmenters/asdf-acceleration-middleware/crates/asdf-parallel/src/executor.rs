//! Task executor for parallel operations

use crate::{Error, Result, Strategy};
use rayon::prelude::*;
use std::sync::Arc;
use tracing::{debug, info, warn};

/// Configuration for the executor
#[derive(Debug, Clone)]
pub struct ExecutorConfig {
    /// Execution strategy
    pub strategy: Strategy,

    /// Whether to fail fast on first error
    pub fail_fast: bool,

    /// Maximum retries per task
    pub max_retries: usize,
}

impl Default for ExecutorConfig {
    fn default() -> Self {
        Self {
            strategy: Strategy::Auto,
            fail_fast: false,
            max_retries: 0,
        }
    }
}

/// Task executor
pub struct Executor {
    config: Arc<ExecutorConfig>,
}

impl Executor {
    /// Create a new executor with the given configuration
    pub fn new(config: ExecutorConfig) -> Self {
        Self {
            config: Arc::new(config),
        }
    }

    /// Execute a collection of tasks in parallel
    pub fn execute<T, F, R>(&self, tasks: Vec<T>, f: F) -> Result<Vec<R>>
    where
        T: Send + Sync + std::fmt::Debug,
        F: Fn(&T) -> Result<R> + Send + Sync,
        R: Send,
    {
        info!(
            "Executing {} tasks with strategy {:?}",
            tasks.len(),
            self.config.strategy
        );

        let thread_count = self.config.strategy.thread_count();
        debug!("Using {} threads", thread_count);

        let results: Vec<_> = if thread_count == 1 {
            // Sequential execution
            tasks
                .iter()
                .map(|task| self.execute_with_retry(task, &f))
                .collect()
        } else {
            // Parallel execution
            tasks
                .par_iter()
                .map(|task| self.execute_with_retry(task, &f))
                .collect()
        };

        // Handle errors based on fail_fast setting
        if self.config.fail_fast {
            results.into_iter().collect()
        } else {
            // Collect successes and log failures
            let mut successes = Vec::new();
            let mut failures = 0;

            for result in results {
                match result {
                    Ok(r) => successes.push(r),
                    Err(e) => {
                        warn!("Task failed: {}", e);
                        failures += 1;
                    }
                }
            }

            if failures > 0 {
                warn!("{} tasks failed", failures);
            }

            if successes.is_empty() && failures > 0 {
                Err(Error::ExecutionFailed(format!(
                    "All {} tasks failed",
                    failures
                )))
            } else {
                Ok(successes)
            }
        }
    }

    /// Execute a single task with retry logic
    fn execute_with_retry<T, F, R>(&self, task: &T, f: &F) -> Result<R>
    where
        T: std::fmt::Debug,
        F: Fn(&T) -> Result<R>,
    {
        let mut attempts = 0;
        let max_attempts = self.config.max_retries + 1;

        loop {
            attempts += 1;

            match f(task) {
                Ok(result) => return Ok(result),
                Err(e) if attempts < max_attempts => {
                    debug!(
                        "Task {:?} failed (attempt {}/{}): {}",
                        task, attempts, max_attempts, e
                    );
                    continue;
                }
                Err(e) => {
                    return Err(Error::TaskFailed {
                        task: format!("{:?}", task),
                        error: e.to_string(),
                    });
                }
            }
        }
    }

    /// Execute tasks and return both successes and failures
    pub fn execute_all<T, F, R>(
        &self,
        tasks: Vec<T>,
        f: F,
    ) -> (Vec<R>, Vec<(T, Error)>)
    where
        T: Send + Sync + std::fmt::Debug,
        F: Fn(&T) -> Result<R> + Send + Sync,
        R: Send,
    {
        let thread_count = self.config.strategy.thread_count();

        let results: Vec<_> = if thread_count == 1 {
            tasks
                .into_iter()
                .map(|task| {
                    let result = self.execute_with_retry(&task, &f);
                    (task, result)
                })
                .collect()
        } else {
            tasks
                .into_par_iter()
                .map(|task| {
                    let result = self.execute_with_retry(&task, &f);
                    (task, result)
                })
                .collect()
        };

        let mut successes = Vec::new();
        let mut failures = Vec::new();

        for (task, result) in results {
            match result {
                Ok(r) => successes.push(r),
                Err(e) => failures.push((task, e)),
            }
        }

        (successes, failures)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_executor_sequential() {
        let config = ExecutorConfig {
            strategy: Strategy::Sequential,
            ..Default::default()
        };

        let executor = Executor::new(config);
        let tasks = vec![1, 2, 3, 4, 5];

        let results = executor
            .execute(tasks, |x| Ok(x * 2))
            .unwrap();

        assert_eq!(results, vec![2, 4, 6, 8, 10]);
    }

    #[test]
    fn test_executor_parallel() {
        let config = ExecutorConfig {
            strategy: Strategy::Fixed(2),
            ..Default::default()
        };

        let executor = Executor::new(config);
        let tasks = vec![1, 2, 3, 4, 5];

        let results = executor
            .execute(tasks, |x| Ok(x * 2))
            .unwrap();

        assert_eq!(results.len(), 5);
    }

    #[test]
    fn test_executor_error_handling() {
        let config = ExecutorConfig {
            strategy: Strategy::Sequential,
            fail_fast: false,
            ..Default::default()
        };

        let executor = Executor::new(config);
        let tasks = vec![1, 2, 3, 4, 5];

        let results = executor.execute(tasks, |x| {
            if x % 2 == 0 {
                Err(Error::Other("even number".to_string()))
            } else {
                Ok(x * 2)
            }
        });

        // Should return successes only
        assert!(results.is_ok());
        let results = results.unwrap();
        assert_eq!(results, vec![2, 6, 10]);
    }

    #[test]
    fn test_executor_retry() {
        let config = ExecutorConfig {
            strategy: Strategy::Sequential,
            max_retries: 2,
            ..Default::default()
        };

        let executor = Executor::new(config);
        let tasks = vec![1];

        // This should fail even with retries
        let result = executor.execute(tasks, |_| {
            Err(Error::Other("always fails".to_string()))
        });

        assert!(result.is_err());
    }
}
