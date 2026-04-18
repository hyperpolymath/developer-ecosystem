//! aria2 integration for high-speed downloads
//!
//! aria2 supports: HTTP/HTTPS, FTP, SFTP, BitTorrent, Metalink

use crate::{run_command, CfkResult};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// aria2 download options
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Aria2Options {
    pub connections: u8,        // max connections per server (default: 5)
    pub split: u8,              // split file into N parts (default: 5)
    pub min_split_size: String, // minimum split size (default: "20M")
    pub continue_download: bool,
    pub max_speed: Option<String>,  // e.g., "1M"
    pub user_agent: Option<String>,
    pub headers: Vec<(String, String)>,
}

/// Download a file using aria2
pub async fn download(
    url: &str,
    output: &Path,
    options: &Aria2Options,
) -> CfkResult<()> {
    let mut args = vec![
        url,
        "-d", output.parent().unwrap_or(Path::new(".")).to_str().unwrap(),
        "-o", output.file_name().unwrap().to_str().unwrap(),
        "-x", &options.connections.to_string(),
        "-s", &options.split.to_string(),
        "-k", &options.min_split_size,
    ];

    if options.continue_download {
        args.push("-c");
    }

    let output = run_command("aria2c", &args).await?;
    if !output.status.success() {
        return Err(cfk_core::CfkError::Other(
            String::from_utf8_lossy(&output.stderr).to_string()
        ));
    }
    Ok(())
}

/// Download multiple files in parallel
pub async fn download_batch(urls: &[&str], output_dir: &Path) -> CfkResult<()> {
    let mut args = vec![
        "-d", output_dir.to_str().unwrap(),
        "-x", "5",
        "-s", "5",
        "-j", "5",  // concurrent downloads
    ];
    args.extend(urls.iter().map(|s| *s));

    let output = run_command("aria2c", &args).await?;
    if !output.status.success() {
        return Err(cfk_core::CfkError::Other(
            String::from_utf8_lossy(&output.stderr).to_string()
        ));
    }
    Ok(())
}

/// Check aria2 version
pub async fn version() -> CfkResult<String> {
    let output = run_command("aria2c", &["--version"]).await?;
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .next()
        .unwrap_or("unknown")
        .to_string())
}
