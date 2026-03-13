// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath

//! Contract types and validation result structures.

use crate::registry::ResourceType;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Contract version
pub const CONTRACT_VERSION: &str = "1.0.0";

/// Validation severity levels
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    /// Validation fails, resource is non-compliant
    Error,
    /// Issue detected but resource may still function
    Warning,
    /// Informational note, best practice suggestion
    Info,
}

/// Result of validating a single resource
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResult {
    /// Path to the validated resource
    pub resource_path: String,
    /// Detected or specified resource type
    pub resource_type: ResourceType,
    /// Overall validation status
    pub valid: bool,
    /// Error messages (severity: error)
    pub errors: Vec<String>,
    /// Warning messages (severity: warning)
    pub warnings: Vec<String>,
    /// Info messages (severity: info)
    pub info: Vec<String>,
    /// Extracted metadata from the resource
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, String>>,
}

impl ValidationResult {
    /// Create a new validation result
    pub fn new(path: &str, rtype: ResourceType) -> Self {
        Self {
            resource_path: path.to_string(),
            resource_type: rtype,
            valid: true,
            errors: Vec::new(),
            warnings: Vec::new(),
            info: Vec::new(),
            metadata: None,
        }
    }

    /// Add an error and mark as invalid
    pub fn add_error(&mut self, msg: impl Into<String>) {
        self.errors.push(msg.into());
        self.valid = false;
    }

    /// Add a warning
    pub fn add_warning(&mut self, msg: impl Into<String>) {
        self.warnings.push(msg.into());
    }

    /// Add an info message
    pub fn add_info(&mut self, msg: impl Into<String>) {
        self.info.push(msg.into());
    }

    /// Set metadata
    pub fn set_metadata(&mut self, key: impl Into<String>, value: impl Into<String>) {
        if self.metadata.is_none() {
            self.metadata = Some(HashMap::new());
        }
        if let Some(ref mut meta) = self.metadata {
            meta.insert(key.into(), value.into());
        }
    }
}

/// Exit codes for the validator CLI
pub mod exit_codes {
    /// Resource is valid
    pub const VALID: u8 = 0;
    /// Validation errors found
    pub const ERRORS: u8 = 1;
    /// Validation warnings (strict mode)
    pub const WARNINGS_STRICT: u8 = 2;
    /// File not found
    pub const NOT_FOUND: u8 = 3;
    /// Unknown resource type
    pub const UNKNOWN_TYPE: u8 = 4;
    /// Parse error
    pub const PARSE_ERROR: u8 = 5;
}

/// Field specification for resource validation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldSpec {
    /// Field name/identifier
    pub name: String,
    /// Field type
    pub field_type: FieldType,
    /// Whether the field is required
    pub required: bool,
    /// Default value if not provided
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default: Option<String>,
    /// Format pattern (regex)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub format: Option<String>,
    /// Human-readable description
    pub description: String,
}

/// Field types for validation
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FieldType {
    /// UTF-8 text string
    String,
    /// Valid HTTPS URL (RFC 3986)
    Url,
    /// Email address (RFC 5322)
    Email,
    /// ISO 8601 date or datetime
    Date,
    /// Signed integer
    Integer,
    /// Boolean true/false
    Boolean,
    /// Valid JSON object or array
    Json,
    /// Newline or comma-separated values
    List,
    /// OpenPGP public key or URL
    PgpKey,
    /// IETF BCP 47 language tag
    Language,
    /// ISO 8601 duration
    Duration,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validation_result_new() {
        let result = ValidationResult::new("security.txt", ResourceType::SecurityTxt);
        assert!(result.valid);
        assert!(result.errors.is_empty());
        assert!(result.warnings.is_empty());
    }

    #[test]
    fn test_validation_result_add_error() {
        let mut result = ValidationResult::new("security.txt", ResourceType::SecurityTxt);
        result.add_error("Missing Contact field");
        assert!(!result.valid);
        assert_eq!(result.errors.len(), 1);
    }

    #[test]
    fn test_validation_result_metadata() {
        let mut result = ValidationResult::new("security.txt", ResourceType::SecurityTxt);
        result.set_metadata("expires", "2025-12-31T23:59:59Z");
        assert!(result.metadata.is_some());
        assert_eq!(
            result.metadata.as_ref().unwrap().get("expires"),
            Some(&"2025-12-31T23:59:59Z".to_string())
        );
    }
}
