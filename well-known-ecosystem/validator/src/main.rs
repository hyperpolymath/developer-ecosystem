// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath

//! Well-Known Ecosystem Validator CLI
//!
//! Validates well-known resources against RFC standards and best practices.

mod contract;
mod registry;
mod rules;
mod validators;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand, ValueEnum};
use colored::Colorize;
use std::path::PathBuf;
use std::process::ExitCode;

use contract::ValidationResult;
use registry::ResourceType;

/// Well-Known Ecosystem Validator
#[derive(Parser)]
#[command(name = "wke-validator")]
#[command(author = "hyperpolymath")]
#[command(version)]
#[command(about = "Validate well-known resources", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Validate a well-known resource file
    Validate {
        /// Path to the resource file
        #[arg(value_name = "FILE")]
        path: PathBuf,

        /// Resource type (auto-detected if omitted)
        #[arg(short = 't', long)]
        resource_type: Option<String>,

        /// Treat warnings as errors
        #[arg(short, long)]
        strict: bool,

        /// Output format
        #[arg(short, long, value_enum, default_value = "text")]
        format: OutputFormat,
    },

    /// Validate all well-known resources in a directory
    ValidateDir {
        /// Path to .well-known directory
        #[arg(value_name = "DIR", default_value = ".well-known")]
        path: PathBuf,

        /// Treat warnings as errors
        #[arg(short, long)]
        strict: bool,

        /// Output format
        #[arg(short, long, value_enum, default_value = "text")]
        format: OutputFormat,
    },

    /// List supported resource types
    List {
        /// Show detailed information
        #[arg(short, long)]
        detailed: bool,

        /// Output format
        #[arg(short, long, value_enum, default_value = "text")]
        format: OutputFormat,
    },

    /// Show validation rules for a resource type
    Rules {
        /// Resource type
        resource_type: String,

        /// Filter by severity
        #[arg(short, long)]
        severity: Option<String>,
    },
}

#[derive(Copy, Clone, PartialEq, Eq, ValueEnum)]
enum OutputFormat {
    /// Human-readable text output
    Text,
    /// JSON output
    Json,
    /// S-expression output (Scheme-compatible)
    Sexp,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match run(cli) {
        Ok(code) => code,
        Err(e) => {
            eprintln!("{}: {:#}", "Error".red().bold(), e);
            ExitCode::from(5)
        }
    }
}

fn run(cli: Cli) -> Result<ExitCode> {
    match cli.command {
        Commands::Validate {
            path,
            resource_type,
            strict,
            format,
        } => validate_file(&path, resource_type.as_deref(), strict, format),

        Commands::ValidateDir {
            path,
            strict,
            format,
        } => validate_directory(&path, strict, format),

        Commands::List { detailed, format } => {
            list_resources(detailed, format);
            Ok(ExitCode::SUCCESS)
        }

        Commands::Rules {
            resource_type,
            severity,
        } => {
            show_rules(&resource_type, severity.as_deref());
            Ok(ExitCode::SUCCESS)
        }
    }
}

fn validate_file(
    path: &PathBuf,
    resource_type: Option<&str>,
    strict: bool,
    format: OutputFormat,
) -> Result<ExitCode> {
    // Check file exists
    if !path.exists() {
        return Ok(ExitCode::from(3)); // File not found
    }

    // Read file content
    let content = std::fs::read(path).context("Failed to read file")?;

    // Detect or use specified resource type
    let rtype = match resource_type {
        Some(t) => registry::parse_resource_type(t).context("Unknown resource type")?,
        None => registry::detect_resource_type(path).context("Could not detect resource type")?,
    };

    // Validate
    let result = validators::validate(&content, rtype)?;

    // Output result
    output_result(&result, format);

    // Determine exit code
    if !result.errors.is_empty() {
        Ok(ExitCode::from(1))
    } else if strict && !result.warnings.is_empty() {
        Ok(ExitCode::from(2))
    } else {
        Ok(ExitCode::SUCCESS)
    }
}

fn validate_directory(path: &PathBuf, strict: bool, format: OutputFormat) -> Result<ExitCode> {
    if !path.exists() || !path.is_dir() {
        eprintln!("{}: Directory not found: {}", "Error".red().bold(), path.display());
        return Ok(ExitCode::from(3));
    }

    let mut all_results: Vec<ValidationResult> = Vec::new();
    let mut has_errors = false;
    let mut has_warnings = false;

    // Scan for known well-known files
    for entry in std::fs::read_dir(path)? {
        let entry = entry?;
        let file_path = entry.path();

        if file_path.is_file() {
            if let Ok(rtype) = registry::detect_resource_type(&file_path) {
                let content = std::fs::read(&file_path)?;
                if let Ok(result) = validators::validate(&content, rtype) {
                    if !result.errors.is_empty() {
                        has_errors = true;
                    }
                    if !result.warnings.is_empty() {
                        has_warnings = true;
                    }
                    all_results.push(result);
                }
            }
        }
    }

    // Output all results
    for result in &all_results {
        output_result(result, format);
        if format == OutputFormat::Text {
            println!();
        }
    }

    if all_results.is_empty() {
        eprintln!("{}: No well-known resources found in {}", "Warning".yellow().bold(), path.display());
    }

    if has_errors {
        Ok(ExitCode::from(1))
    } else if strict && has_warnings {
        Ok(ExitCode::from(2))
    } else {
        Ok(ExitCode::SUCCESS)
    }
}

fn output_result(result: &ValidationResult, format: OutputFormat) {
    match format {
        OutputFormat::Text => output_text(result),
        OutputFormat::Json => output_json(result),
        OutputFormat::Sexp => output_sexp(result),
    }
}

fn output_text(result: &ValidationResult) {
    println!(
        "{} {}",
        "Validating:".bold(),
        result.resource_path.cyan()
    );
    println!(
        "  {} {}",
        "Type:".bold(),
        format!("{:?}", result.resource_type)
    );

    if result.valid {
        println!("  {} {}", "Status:".bold(), "VALID".green().bold());
    } else {
        println!("  {} {}", "Status:".bold(), "INVALID".red().bold());
    }

    if !result.errors.is_empty() {
        println!("\n  {}:", "Errors".red().bold());
        for error in &result.errors {
            println!("    {} {}", "✗".red(), error);
        }
    }

    if !result.warnings.is_empty() {
        println!("\n  {}:", "Warnings".yellow().bold());
        for warning in &result.warnings {
            println!("    {} {}", "⚠".yellow(), warning);
        }
    }

    if !result.info.is_empty() {
        println!("\n  {}:", "Info".blue().bold());
        for info in &result.info {
            println!("    {} {}", "ℹ".blue(), info);
        }
    }

    // Print metadata
    if let Some(metadata) = &result.metadata {
        println!("\n  {}:", "Metadata".bold());
        for (key, value) in metadata {
            println!("    {}: {}", key.bold(), value);
        }
    }
}

fn output_json(result: &ValidationResult) {
    println!("{}", serde_json::to_string_pretty(result).unwrap());
}

fn output_sexp(result: &ValidationResult) {
    println!("(validation-result");
    println!("  (resource-path . \"{}\")", result.resource_path);
    println!("  (resource-type . {:?})", result.resource_type);
    println!("  (valid . {})", if result.valid { "#t" } else { "#f" });

    println!("  (errors . (");
    for error in &result.errors {
        println!("    \"{}\"", error.replace('\"', "\\\""));
    }
    println!("  ))");

    println!("  (warnings . (");
    for warning in &result.warnings {
        println!("    \"{}\"", warning.replace('\"', "\\\""));
    }
    println!("  ))");

    println!("  (info . (");
    for info in &result.info {
        println!("    \"{}\"", info.replace('\"', "\\\""));
    }
    println!("  ))");

    println!(")");
}

fn list_resources(detailed: bool, format: OutputFormat) {
    let resources = registry::all_resources();

    match format {
        OutputFormat::Text => {
            println!("{}", "Supported Well-Known Resources".bold().underline());
            println!();

            for resource in resources {
                if detailed {
                    println!("{}", resource.name.cyan().bold());
                    println!("  URI:      /.well-known/{}", resource.uri_path);
                    println!("  Standard: {}", resource.standard);
                    println!("  Type:     {}", resource.content_type);
                    println!("  IANA:     {}", if resource.iana_registered { "Yes" } else { "No" });
                    if let Some(notes) = &resource.notes {
                        println!("  Notes:    {}", notes);
                    }
                    println!();
                } else {
                    println!(
                        "  {} - {}",
                        resource.id.green(),
                        resource.name
                    );
                }
            }
        }
        OutputFormat::Json => {
            println!("{}", serde_json::to_string_pretty(&resources).unwrap());
        }
        OutputFormat::Sexp => {
            println!("(well-known-resources");
            for resource in resources {
                println!("  ((id . {}) (name . \"{}\") (uri-path . \"{}\"))",
                    resource.id, resource.name, resource.uri_path);
            }
            println!(")");
        }
    }
}

fn show_rules(resource_type: &str, severity: Option<&str>) {
    let rules = rules::get_rules_for_type(resource_type);

    println!("{} {}", "Validation Rules for".bold(), resource_type.cyan().bold());
    println!();

    for rule in rules {
        if let Some(sev) = severity {
            if rule.severity != sev {
                continue;
            }
        }

        let sev_colored = match rule.severity.as_str() {
            "error" => rule.severity.red().bold(),
            "warning" => rule.severity.yellow().bold(),
            "info" => rule.severity.blue().bold(),
            _ => rule.severity.normal(),
        };

        println!("  {} [{}]", rule.id.green(), sev_colored);
        println!("    {}", rule.description);
        println!();
    }
}
