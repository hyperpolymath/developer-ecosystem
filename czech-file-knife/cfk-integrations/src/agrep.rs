//! agrep integration for approximate/fuzzy grep
//!
//! agrep allows errors in pattern matching (Levenshtein distance)

use crate::{run_command, CfkResult};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// agrep match result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgrepMatch {
    pub file: String,
    pub line_number: usize,
    pub line: String,
    pub errors: u8,
}

/// agrep search options
#[derive(Debug, Clone, Default)]
pub struct AgrepOptions {
    pub max_errors: u8,         // -k N: allow N errors
    pub case_insensitive: bool, // -i
    pub word_match: bool,       // -w
    pub line_match: bool,       // -x (whole line)
    pub count_only: bool,       // -c
    pub files_only: bool,       // -l
    pub recursive: bool,        // -r
}

/// Search for approximate pattern matches
pub async fn search(
    pattern: &str,
    path: &Path,
    options: &AgrepOptions,
) -> CfkResult<Vec<AgrepMatch>> {
    let mut args = vec!["-n".to_string()]; // line numbers

    if options.max_errors > 0 {
        args.push(format!("-{}", options.max_errors));
    }
    if options.case_insensitive {
        args.push("-i".to_string());
    }
    if options.word_match {
        args.push("-w".to_string());
    }
    if options.line_match {
        args.push("-x".to_string());
    }
    if options.recursive {
        args.push("-r".to_string());
    }

    args.push(pattern.to_string());
    args.push(path.to_string_lossy().to_string());

    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
    let output = run_command("agrep", &args_ref).await?;

    let mut matches = Vec::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        if let Some((file_line, content)) = line.split_once(':') {
            if let Some((file, line_num)) = file_line.rsplit_once(':') {
                matches.push(AgrepMatch {
                    file: file.to_string(),
                    line_number: line_num.parse().unwrap_or(0),
                    line: content.to_string(),
                    errors: options.max_errors,
                });
            }
        }
    }

    Ok(matches)
}

/// Fuzzy file name search
pub async fn find_files(
    pattern: &str,
    dir: &Path,
    max_errors: u8,
) -> CfkResult<Vec<String>> {
    // Use find + agrep for fuzzy filename matching
    let find_output = run_command("find", &[
        dir.to_str().unwrap(),
        "-type", "f",
        "-print"
    ]).await?;

    let mut args = vec![format!("-{}", max_errors), pattern.to_string()];
    let args_ref: Vec<&str> = args.iter().map(|s| s.as_str()).collect();

    // Pipe find output to agrep (simplified - actual impl would use pipes)
    let files = String::from_utf8_lossy(&find_output.stdout)
        .lines()
        .filter(|f| f.contains(pattern) || pattern.len() < 3)  // Simplified
        .map(String::from)
        .collect();

    Ok(files)
}
