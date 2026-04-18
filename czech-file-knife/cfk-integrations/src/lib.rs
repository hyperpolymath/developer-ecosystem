//! External tool integrations for Czech File Knife
//!
//! Integrates: aria2, agrep, pandoc, tesseract OCR, eza

#[cfg(feature = "aria2")]
pub mod aria2;

#[cfg(feature = "agrep")]
pub mod agrep;

#[cfg(feature = "pandoc")]
pub mod pandoc;

#[cfg(feature = "ocr")]
pub mod ocr;

#[cfg(feature = "eza")]
pub mod eza;

use cfk_core::error::{CfkError, CfkResult};
use std::process::Output;
use tokio::process::Command;

/// Check if an external tool is available
pub async fn check_tool(name: &str) -> bool {
    Command::new("which")
        .arg(name)
        .output()
        .await
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Run an external command and get output
pub async fn run_command(program: &str, args: &[&str]) -> CfkResult<Output> {
    Command::new(program)
        .args(args)
        .output()
        .await
        .map_err(|e| CfkError::Other(format!("Failed to run {}: {}", program, e)))
}

/// Tool availability status
#[derive(Debug, Clone)]
pub struct ToolStatus {
    pub aria2: bool,
    pub agrep: bool,
    pub pandoc: bool,
    pub tesseract: bool,
    pub eza: bool,
}

impl ToolStatus {
    pub async fn detect() -> Self {
        Self {
            aria2: check_tool("aria2c").await,
            agrep: check_tool("agrep").await,
            pandoc: check_tool("pandoc").await,
            tesseract: check_tool("tesseract").await,
            eza: check_tool("eza").await || check_tool("exa").await,
        }
    }
}
