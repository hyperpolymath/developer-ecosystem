//! Error types for parallel execution

use thiserror::Error;

/// Result type alias
pub type Result<T> = std::result::Result<T, Error>;

/// Parallel execution error types
#[derive(Error, Debug)]
pub enum Error {
    /// Thread pool initialization failed
    #[error("Thread pool initialization failed: {0}")]
    ThreadPoolInit(String),

    /// Execution failed
    #[error("Execution failed: {0}")]
    ExecutionFailed(String),

    /// Task failed
    #[error("Task '{task}' failed: {error}")]
    TaskFailed { task: String, error: String },

    /// asdf-core error
    #[error("asdf-core error: {0}")]
    Core(#[from] asdf_core::Error),

    /// Generic error
    #[error("{0}")]
    Other(String),
}
