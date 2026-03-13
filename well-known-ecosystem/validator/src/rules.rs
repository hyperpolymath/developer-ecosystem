// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath

//! Validation rule definitions.

use serde::{Deserialize, Serialize};

/// A validation rule definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    /// Unique rule identifier
    pub id: String,
    /// Severity: error, warning, info
    pub severity: String,
    /// Resource types this rule applies to
    pub applies_to: Vec<String>,
    /// Human-readable description
    pub description: String,
}

/// Get all validation rules
pub fn all_rules() -> Vec<Rule> {
    let mut rules = Vec::new();

    // Core rules (apply to all)
    rules.extend(core_rules());

    // Resource-specific rules
    rules.extend(security_txt_rules());
    rules.extend(openid_configuration_rules());
    rules.extend(json_rules());
    rules.extend(webfinger_rules());
    rules.extend(assetlinks_rules());
    rules.extend(nodeinfo_rules());

    rules
}

/// Get rules for a specific resource type
pub fn get_rules_for_type(resource_type: &str) -> Vec<Rule> {
    all_rules()
        .into_iter()
        .filter(|rule| {
            rule.applies_to.contains(&"all".to_string())
                || rule.applies_to.contains(&resource_type.to_string())
        })
        .collect()
}

/// Core validation rules that apply to all resources
fn core_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "core/utf8-encoding".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Resource content must be valid UTF-8".to_string(),
        },
        Rule {
            id: "core/no-bom".to_string(),
            severity: "warning".to_string(),
            applies_to: vec!["all".to_string()],
            description: "UTF-8 BOM (Byte Order Mark) should not be present".to_string(),
        },
        Rule {
            id: "core/line-endings".to_string(),
            severity: "warning".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Use LF line endings, not CRLF".to_string(),
        },
        Rule {
            id: "core/trailing-newline".to_string(),
            severity: "info".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Files should end with a newline".to_string(),
        },
        Rule {
            id: "core/max-size".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Resource must not exceed 1 MiB".to_string(),
        },
        Rule {
            id: "core/https-only".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["all".to_string()],
            description: "All URLs must use HTTPS protocol".to_string(),
        },
        Rule {
            id: "core/no-localhost".to_string(),
            severity: "warning".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Production resources should not reference localhost".to_string(),
        },
        Rule {
            id: "core/no-secrets".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["all".to_string()],
            description: "Resources must not contain secrets or credentials".to_string(),
        },
    ]
}

/// Validation rules for security.txt (RFC 9116)
fn security_txt_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "security-txt/contact-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Contact field is mandatory (RFC 9116 Section 2.5.3)".to_string(),
        },
        Rule {
            id: "security-txt/expires-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Expires field is mandatory (RFC 9116 Section 2.5.5)".to_string(),
        },
        Rule {
            id: "security-txt/contact-format".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Contact must be mailto: or https:// URL".to_string(),
        },
        Rule {
            id: "security-txt/expires-format".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Expires must be ISO 8601 datetime with timezone".to_string(),
        },
        Rule {
            id: "security-txt/expires-not-past".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Expires date must be in the future".to_string(),
        },
        Rule {
            id: "security-txt/expires-within-year".to_string(),
            severity: "warning".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Expires should be within one year".to_string(),
        },
        Rule {
            id: "security-txt/expires-soon".to_string(),
            severity: "warning".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "Warn when expiration is within 30 days".to_string(),
        },
        Rule {
            id: "security-txt/signature-recommended".to_string(),
            severity: "info".to_string(),
            applies_to: vec!["security-txt".to_string()],
            description: "PGP signature recommended for authenticity".to_string(),
        },
    ]
}

/// Validation rules for OpenID Configuration
fn openid_configuration_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "oidc/issuer-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "issuer field is required".to_string(),
        },
        Rule {
            id: "oidc/issuer-https".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "issuer must be HTTPS URL".to_string(),
        },
        Rule {
            id: "oidc/authorization-endpoint-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "authorization_endpoint is required".to_string(),
        },
        Rule {
            id: "oidc/token-endpoint-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "token_endpoint is required".to_string(),
        },
        Rule {
            id: "oidc/jwks-uri-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "jwks_uri is required".to_string(),
        },
        Rule {
            id: "oidc/rs256-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "RS256 must be supported for ID token signing".to_string(),
        },
        Rule {
            id: "oidc/no-none-alg".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["openid-configuration".to_string()],
            description: "Algorithm 'none' should not be supported".to_string(),
        },
    ]
}

/// JSON validation rules
fn json_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "json/valid-syntax".to_string(),
            severity: "error".to_string(),
            applies_to: vec![
                "openid-configuration".to_string(),
                "webfinger".to_string(),
                "assetlinks".to_string(),
                "apple-app-site-association".to_string(),
                "nodeinfo".to_string(),
                "matrix-server".to_string(),
            ],
            description: "Content must be valid JSON".to_string(),
        },
        Rule {
            id: "json/object-or-array".to_string(),
            severity: "error".to_string(),
            applies_to: vec![
                "openid-configuration".to_string(),
                "webfinger".to_string(),
                "assetlinks".to_string(),
                "apple-app-site-association".to_string(),
                "nodeinfo".to_string(),
            ],
            description: "Root must be object or array".to_string(),
        },
    ]
}

/// WebFinger validation rules
fn webfinger_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "webfinger/subject-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["webfinger".to_string()],
            description: "subject field is required".to_string(),
        },
        Rule {
            id: "webfinger/links-array".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["webfinger".to_string()],
            description: "links must be an array if present".to_string(),
        },
    ]
}

/// Asset Links validation rules
fn assetlinks_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "assetlinks/array-root".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["assetlinks".to_string()],
            description: "Root must be a JSON array".to_string(),
        },
        Rule {
            id: "assetlinks/relation-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["assetlinks".to_string()],
            description: "Each entry must have relation array".to_string(),
        },
        Rule {
            id: "assetlinks/target-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["assetlinks".to_string()],
            description: "Each entry must have target object".to_string(),
        },
    ]
}

/// NodeInfo validation rules
fn nodeinfo_rules() -> Vec<Rule> {
    vec![
        Rule {
            id: "nodeinfo/version-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["nodeinfo".to_string()],
            description: "version field is required".to_string(),
        },
        Rule {
            id: "nodeinfo/version-valid".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["nodeinfo".to_string()],
            description: "version must be 2.0, 2.1, or 2.2".to_string(),
        },
        Rule {
            id: "nodeinfo/software-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["nodeinfo".to_string()],
            description: "software object is required".to_string(),
        },
        Rule {
            id: "nodeinfo/protocols-required".to_string(),
            severity: "error".to_string(),
            applies_to: vec!["nodeinfo".to_string()],
            description: "protocols array is required".to_string(),
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_all_rules_not_empty() {
        let rules = all_rules();
        assert!(!rules.is_empty());
    }

    #[test]
    fn test_get_rules_for_security_txt() {
        let rules = get_rules_for_type("security-txt");
        assert!(rules.iter().any(|r| r.id == "security-txt/contact-required"));
        assert!(rules.iter().any(|r| r.id == "core/utf8-encoding"));
    }

    #[test]
    fn test_core_rules_apply_to_all() {
        let rules = get_rules_for_type("some-random-type");
        assert!(rules.iter().any(|r| r.id == "core/utf8-encoding"));
    }
}
