//! Error types for metrics

use thiserror::Error;

/// Result type alias
pub type Result<T> = std::result::Result<T, Error>;

/// Metrics error types
#[derive(Error, Debug)]
pub enum Error {
    /// Metric collection failed
    #[error("Metric collection failed: {0}")]
    CollectionFailed(String),

    /// Export failed
    #[error("Export failed: {0}")]
    ExportFailed(String),

    /// I/O error
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// JSON error
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    /// Generic error
    #[error("{0}")]
    Other(String),
}
