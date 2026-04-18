//! Error types for caching

use thiserror::Error;

/// Result type alias
pub type Result<T> = std::result::Result<T, Error>;

/// Cache error types
#[derive(Error, Debug)]
pub enum Error {
    /// Serialization error
    #[error("Serialization error: {0}")]
    Serialization(String),

    /// Deserialization error
    #[error("Deserialization error: {0}")]
    Deserialization(String),

    /// Database error
    #[error("Database error: {0}")]
    Database(String),

    /// I/O error
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    /// Cache miss (value not found)
    #[error("Cache miss")]
    Miss,

    /// Entry expired
    #[error("Cache entry expired")]
    Expired,

    /// Generic error
    #[error("{0}")]
    Other(String),
}

impl From<sled::Error> for Error {
    fn from(e: sled::Error) -> Self {
        Error::Database(e.to_string())
    }
}

impl From<bincode::Error> for Error {
    fn from(e: bincode::Error) -> Self {
        Error::Serialization(e.to_string())
    }
}
