//! Error types for configuration

use thiserror::Error;

/// Result type alias
pub type Result<T> = std::result::Result<T, Error>;

/// Configuration error types
#[derive(Error, Debug)]
pub enum Error {
    /// Configuration file not found
    #[error("Configuration file not found: {0}")]
    NotFound(String),

    /// Invalid configuration
    #[error("Invalid configuration: {0}")]
    Invalid(String),

    /// Parse error
    #[error("Parse error: {0}")]
    Parse(String),

    /// I/O error
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// Config library error
    #[error("Config error: {0}")]
    Config(#[from] config::ConfigError),

    /// Generic error
    #[error("{0}")]
    Other(String),
}
