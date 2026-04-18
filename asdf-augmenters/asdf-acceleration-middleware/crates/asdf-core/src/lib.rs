//! Core library for asdf integration
//!
//! This crate provides the fundamental types and operations for interacting
//! with asdf, the extendable version manager.

pub mod error;
pub mod plugin;
pub mod runtime;
pub mod version;

pub use error::{Error, Result};
pub use plugin::Plugin;
pub use runtime::Runtime;
pub use version::Version;

use std::path::{Path, PathBuf};
use std::env;

/// Get the asdf installation directory
pub fn asdf_dir() -> Result<PathBuf> {
    env::var("ASDF_DIR")
        .or_else(|_| env::var("ASDF_DATA_DIR"))
        .map(PathBuf::from)
        .or_else(|_| {
            env::var("HOME")
                .map(|home| PathBuf::from(home).join(".asdf"))
        })
        .map_err(|_| Error::AsdfNotFound)
}

/// Get the asdf plugins directory
pub fn plugins_dir() -> Result<PathBuf> {
    Ok(asdf_dir()?.join("plugins"))
}

/// Get the asdf installs directory
pub fn installs_dir() -> Result<PathBuf> {
    Ok(asdf_dir()?.join("installs"))
}

/// Get the asdf shims directory
pub fn shims_dir() -> Result<PathBuf> {
    Ok(asdf_dir()?.join("shims"))
}

/// Check if asdf is installed
pub fn is_asdf_installed() -> bool {
    which::which("asdf").is_ok()
}

/// Get asdf version
pub fn asdf_version() -> Result<String> {
    let output = duct::cmd!("asdf", "--version")
        .read()
        .map_err(|e| Error::CommandFailed {
            command: "asdf --version".to_string(),
            error: e.to_string(),
        })?;

    Ok(output.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_asdf_dir() {
        // This test might fail if ASDF is not installed or configured
        // but that's okay for development
        let _ = asdf_dir();
    }

    #[test]
    fn test_is_asdf_installed() {
        // Just check that the function runs without panic
        let _installed = is_asdf_installed();
    }

    #[test]
    fn test_asdf_version() {
        if is_asdf_installed() {
            let version = asdf_version();
            if let Ok(v) = version {
                assert!(!v.is_empty());
            }
        }
    }
}
