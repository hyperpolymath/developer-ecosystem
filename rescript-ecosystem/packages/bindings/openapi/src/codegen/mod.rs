// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! ReScript code generation from IR
//!
//! Generates:
//! - Type definitions (records, variants, aliases)
//! - rescript-schema validators
//! - HTTP client functions using fetch

pub mod client;
pub mod schema;
pub mod types;

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum ClientMode {
    /// OOTB: Includes both the Functor and a default Fetch implementation
    Full,
    /// Streamlined: Includes only the Functor (user must provide their own HttpClient)
    FunctorOnly,
    /// Minimum: Generates no HTTP client code at all
    None,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum VariantMode {
    /// Use polymorphic variants: [ #Admin | #User ]
    Polymorphic,
    /// Use standard variants with @as: | @as("admin") Admin | @as("user") User
    Standard,
}

pub struct Config {
    pub output_dir: PathBuf,
    pub module_prefix: String,
    pub generate_schema: bool,
    pub generate_client: bool,
    pub unified_module: bool,
    pub client_mode: ClientMode,
    pub variant_mode: VariantMode,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectConfig {
    pub input: Option<PathBuf>,
    pub output: Option<PathBuf>,
    pub module: Option<String>,
    pub with_schema: Option<bool>,
    pub with_client: Option<bool>,
    pub unified: Option<bool>,
    pub client_mode: Option<ClientMode>,
    pub variant_mode: Option<VariantMode>,
}

impl ProjectConfig {
    pub fn load(path: &std::path::Path) -> Result<Self> {
        let content = fs::read_to_string(path)?;
        let config: Self = toml::from_str(&content)?;
        Ok(config)
    }
}

