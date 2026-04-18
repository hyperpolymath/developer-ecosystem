//! pandoc integration for document format conversion
//!
//! Supports: markdown, docx, pdf, html, epub, rst, latex, and 40+ formats

use crate::{run_command, CfkResult};
use std::path::Path;

/// Supported input/output formats
#[derive(Debug, Clone, Copy)]
pub enum Format {
    Markdown,
    Html,
    Docx,
    Pdf,
    Epub,
    Rst,
    Latex,
    Org,
    Asciidoc,
    Json,
    Plain,
}

impl Format {
    pub fn as_str(&self) -> &'static str {
        match self {
            Format::Markdown => "markdown",
            Format::Html => "html",
            Format::Docx => "docx",
            Format::Pdf => "pdf",
            Format::Epub => "epub",
            Format::Rst => "rst",
            Format::Latex => "latex",
            Format::Org => "org",
            Format::Asciidoc => "asciidoc",
            Format::Json => "json",
            Format::Plain => "plain",
        }
    }
}

/// Convert a file between formats
pub async fn convert(
    input: &Path,
    output: &Path,
    from: Option<Format>,
    to: Option<Format>,
) -> CfkResult<()> {
    let mut args = vec![
        input.to_str().unwrap(),
        "-o", output.to_str().unwrap(),
    ];

    let from_str;
    let to_str;

    if let Some(f) = from {
        from_str = f.as_str().to_string();
        args.extend(["-f", &from_str]);
    }
    if let Some(t) = to {
        to_str = t.as_str().to_string();
        args.extend(["-t", &to_str]);
    }

    let output = run_command("pandoc", &args).await?;
    if !output.status.success() {
        return Err(cfk_core::CfkError::Other(
            String::from_utf8_lossy(&output.stderr).to_string()
        ));
    }
    Ok(())
}

/// Convert string content between formats
pub async fn convert_string(
    content: &str,
    from: Format,
    to: Format,
) -> CfkResult<String> {
    use tokio::process::Command;
    use tokio::io::AsyncWriteExt;

    let mut child = Command::new("pandoc")
        .args(["-f", from.as_str(), "-t", to.as_str()])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| cfk_core::CfkError::Other(e.to_string()))?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(content.as_bytes()).await
            .map_err(|e| cfk_core::CfkError::Other(e.to_string()))?;
    }

    let output = child.wait_with_output().await
        .map_err(|e| cfk_core::CfkError::Other(e.to_string()))?;

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

/// Get pandoc version
pub async fn version() -> CfkResult<String> {
    let output = run_command("pandoc", &["--version"]).await?;
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .next()
        .unwrap_or("unknown")
        .to_string())
}
