// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! OpenAPI specification parser
//!
//! Handles parsing of OpenAPI 3.x specifications in JSON and YAML formats.

use anyhow::{Context, Result};
use openapiv3::OpenAPI;
use std::path::Path;

/// Parse an OpenAPI specification from a file
pub fn parse_spec(path: &Path) -> Result<OpenAPI> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read OpenAPI spec from {:?}", path))?;

    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");

    match ext {
        "json" => serde_json::from_str(&content)
            .with_context(|| "Failed to parse OpenAPI spec as JSON"),
        "yaml" | "yml" => serde_yaml::from_str(&content)
            .with_context(|| "Failed to parse OpenAPI spec as YAML"),
        _ => {
            // Try JSON first, then YAML
            serde_json::from_str(&content)
                .or_else(|_| serde_yaml::from_str(&content))
                .with_context(|| "Failed to parse OpenAPI spec (tried JSON and YAML)")
        }
    }
}

/// Diagnostic message for validation issues
#[derive(Debug)]
pub struct Diagnostic {
    pub severity: Severity,
    pub message: String,
    pub path: Option<String>,
}

#[derive(Debug)]
pub enum Severity {
    Error,
    Warning,
}

impl std::fmt::Display for Diagnostic {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let prefix = match self.severity {
            Severity::Error => "error",
            Severity::Warning => "warning",
        };
        if let Some(path) = &self.path {
            write!(f, "{}: {} (at {})", prefix, self.message, path)
        } else {
            write!(f, "{}: {}", prefix, self.message)
        }
    }
}

/// Validate an OpenAPI specification for ReScript codegen compatibility
pub fn validate(spec: &OpenAPI) -> Vec<Diagnostic> {
    let mut diagnostics = Vec::new();

    // Check for operationId on all operations
    for (path, item) in spec.paths.iter() {
        if let openapiv3::ReferenceOr::Item(path_item) = item {
            for (method, op) in path_item.iter() {
                if op.operation_id.is_none() {
                    diagnostics.push(Diagnostic {
                        severity: Severity::Warning,
                        message: format!(
                            "Missing operationId for {} {} - will generate from path",
                            method, path
                        ),
                        path: Some(format!("paths.{}.{}", path, method)),
                    });
                }
            }
        }
    }

    // Check for unsupported features
    if let Some(components) = &spec.components {
        for (name, schema) in &components.schemas {
            if let openapiv3::ReferenceOr::Item(schema) = schema {
                check_schema_compatibility(name, schema, &mut diagnostics);
            }
        }
    }

    diagnostics
}

fn check_schema_compatibility(
    name: &str,
    schema: &openapiv3::Schema,
    diagnostics: &mut Vec<Diagnostic>,
) {
    match &schema.schema_kind {
        openapiv3::SchemaKind::OneOf { .. } => {
            diagnostics.push(Diagnostic {
                severity: Severity::Warning,
                message: format!(
                    "Schema '{}' uses oneOf - will generate as variant type",
                    name
                ),
                path: Some(format!("components.schemas.{}", name)),
            });
        }
        openapiv3::SchemaKind::AnyOf { .. } => {
            diagnostics.push(Diagnostic {
                severity: Severity::Warning,
                message: format!(
                    "Schema '{}' uses anyOf - support is experimental",
                    name
                ),
                path: Some(format!("components.schemas.{}", name)),
            });
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_json_spec() {
        let spec_json = r#"{
            "openapi": "3.0.0",
            "info": { "title": "Test", "version": "1.0.0" },
            "paths": {}
        }"#;

        let temp = tempfile::NamedTempFile::with_suffix(".json").expect("TODO: handle error");
        std::fs::write(temp.path(), spec_json).expect("TODO: handle error");

        let spec = parse_spec(temp.path()).expect("TODO: handle error");
        assert_eq!(spec.info.title, "Test");
    }
}
