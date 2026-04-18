//! Error types for asdf-core

use thiserror::Error;

/// Result type alias using our Error type
pub type Result<T> = std::result::Result<T, Error>;

/// Error types for asdf operations
#[derive(Error, Debug)]
pub enum Error {
    /// asdf is not installed or not found in PATH
    #[error("asdf not found - please install asdf first")]
    AsdfNotFound,

    /// Plugin not found
    #[error("Plugin '{0}' not found")]
    PluginNotFound(String),

    /// Runtime not found
    #[error("Runtime '{plugin}@{version}' not found")]
    RuntimeNotFound { plugin: String, version: String },

    /// Invalid version string
    #[error("Invalid version string: {0}")]
    InvalidVersion(String),

    /// Command execution failed
    #[error("Command '{command}' failed: {error}")]
    CommandFailed { command: String, error: String },

    /// I/O error
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// JSON parsing error
    #[error("JSON parsing error: {0}")]
    Json(#[from] serde_json::Error),

    /// Generic error
    #[error("{0}")]
    Other(String),
}

impl From<String> for Error {
    fn from(s: String) -> Self {
        Error::Other(s)
    }
}

impl From<&str> for Error {
    fn from(s: &str) -> Self {
        Error::Other(s.to_string())
    }
}
