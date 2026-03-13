// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath

//! Resource validators implementation.

use crate::contract::ValidationResult;
use crate::registry::ResourceType;
use anyhow::Result;
use chrono::{DateTime, Utc};
use regex::Regex;
use serde_json::Value;

/// Maximum file size (1 MiB)
const MAX_SIZE: usize = 1024 * 1024;

/// UTF-8 BOM bytes
const UTF8_BOM: [u8; 3] = [0xEF, 0xBB, 0xBF];

/// Validate a resource
pub fn validate(content: &[u8], rtype: ResourceType) -> Result<ValidationResult> {
    let path = format!("{:?}", rtype);
    let mut result = ValidationResult::new(&path, rtype);

    // Core validations (apply to all)
    validate_core(content, &mut result);

    // Resource-specific validations
    match rtype {
        ResourceType::SecurityTxt => validate_security_txt(content, &mut result),
        ResourceType::OpenidConfiguration => validate_openid_configuration(content, &mut result),
        ResourceType::Webfinger => validate_webfinger(content, &mut result),
        ResourceType::Assetlinks => validate_assetlinks(content, &mut result),
        ResourceType::AppleAppSiteAssociation => validate_aasa(content, &mut result),
        ResourceType::Nodeinfo => validate_nodeinfo(content, &mut result),
        ResourceType::MatrixServer => validate_matrix_server(content, &mut result),
        ResourceType::HumansTxt | ResourceType::AiTxt => validate_plain_text(content, &mut result),
        _ => {
            // Generic validation for other types
            result.add_info("No specific validator available for this resource type");
        }
    }

    Ok(result)
}

/// Core validations that apply to all resources
fn validate_core(content: &[u8], result: &mut ValidationResult) {
    // Check size
    if content.len() > MAX_SIZE {
        result.add_error(format!(
            "Resource size {} bytes exceeds maximum {} bytes",
            content.len(),
            MAX_SIZE
        ));
    }

    // Check for empty content
    if content.is_empty() {
        result.add_warning("Resource is empty");
        return;
    }

    // Check UTF-8 encoding
    if std::str::from_utf8(content).is_err() {
        result.add_error("Invalid UTF-8 encoding");
        return;
    }

    // Check for BOM
    if content.len() >= 3 && content[0..3] == UTF8_BOM {
        result.add_warning("UTF-8 BOM detected; remove for compatibility");
    }

    // Check line endings
    if content.windows(2).any(|w| w == b"\r\n") {
        result.add_warning("CRLF line endings detected; prefer LF for consistency");
    }

    // Check trailing newline
    if !content.ends_with(b"\n") {
        result.add_info("File does not end with newline");
    }

    // Check for potential secrets
    let text = String::from_utf8_lossy(content);
    check_for_secrets(&text, result);

    // Check for HTTP URLs (should be HTTPS)
    check_https_only(&text, result);
}

/// Check for potential secrets in content
fn check_for_secrets(text: &str, result: &mut ValidationResult) {
    let secret_patterns = [
        r"(?i)password\s*=\s*['\"]?[^'\"]+",
        r"(?i)api[_-]?key\s*=\s*['\"]?[^'\"]+",
        r"(?i)secret\s*=\s*['\"]?[^'\"]+",
        r"-----BEGIN (RSA |EC )?PRIVATE KEY-----",
    ];

    for pattern in &secret_patterns {
        if let Ok(re) = Regex::new(pattern) {
            if re.is_match(text) {
                result.add_error("Potential secret detected in content");
                break;
            }
        }
    }
}

/// Check that all URLs use HTTPS
fn check_https_only(text: &str, result: &mut ValidationResult) {
    let http_pattern = Regex::new(r"http://(?!localhost|127\.0\.0\.1|\[::1\])").unwrap();

    if let Some(m) = http_pattern.find(text) {
        result.add_error(format!(
            "HTTP URL found (must use HTTPS): {}...",
            &text[m.start()..std::cmp::min(m.end() + 20, text.len())]
        ));
    }
}

/// Validate security.txt (RFC 9116)
fn validate_security_txt(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return, // Already reported in core validation
    };

    // Check for PGP signature
    let is_signed = text.contains("-----BEGIN PGP SIGNED MESSAGE-----");
    if !is_signed {
        result.add_info("PGP signature recommended for authenticity");
    }

    // Check Contact field (required)
    let contact_re = Regex::new(r"(?m)^Contact:\s*(.+)$").unwrap();
    let contacts: Vec<_> = contact_re.captures_iter(text).collect();

    if contacts.is_empty() {
        result.add_error("Missing required Contact field (RFC 9116 Section 2.5.3)");
    } else {
        // Validate Contact format
        for cap in &contacts {
            let contact = cap.get(1).map_or("", |m| m.as_str().trim());
            if !contact.starts_with("mailto:") && !contact.starts_with("https://") {
                result.add_error(format!(
                    "Contact must start with mailto: or https:// - found: {}",
                    contact
                ));
            }
        }
        result.set_metadata("contact_count", contacts.len().to_string());
    }

    // Check Expires field (required)
    let expires_re = Regex::new(r"(?m)^Expires:\s*(.+)$").unwrap();

    if let Some(cap) = expires_re.captures(text) {
        let expires_str = cap.get(1).map_or("", |m| m.as_str().trim());
        result.set_metadata("expires", expires_str.to_string());

        // Parse and validate expiry date
        match DateTime::parse_from_rfc3339(expires_str) {
            Ok(expires) => {
                let now = Utc::now();
                let expires_utc = expires.with_timezone(&Utc);

                if expires_utc < now {
                    result.add_error(format!(
                        "security.txt has expired (Expires: {})",
                        expires_str
                    ));
                } else {
                    let days_until = (expires_utc - now).num_days();
                    result.set_metadata("days_until_expiry", days_until.to_string());

                    if days_until < 30 {
                        result.add_warning(format!(
                            "security.txt expires in {} days",
                            days_until
                        ));
                    } else if days_until > 365 {
                        result.add_warning(format!(
                            "Expires is more than 1 year in the future ({} days)",
                            days_until
                        ));
                    }
                }
            }
            Err(_) => {
                result.add_error(format!(
                    "Expires must be ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ) - found: {}",
                    expires_str
                ));
            }
        }
    } else {
        result.add_error("Missing required Expires field (RFC 9116 Section 2.5.5)");
    }

    // Check optional fields
    let optional_fields = [
        ("Encryption", r"(?m)^Encryption:\s*(.+)$"),
        ("Acknowledgments", r"(?m)^Acknowledgments:\s*(.+)$"),
        ("Preferred-Languages", r"(?m)^Preferred-Languages:\s*(.+)$"),
        ("Canonical", r"(?m)^Canonical:\s*(.+)$"),
        ("Policy", r"(?m)^Policy:\s*(.+)$"),
        ("Hiring", r"(?m)^Hiring:\s*(.+)$"),
    ];

    for (name, pattern) in &optional_fields {
        if let Ok(re) = Regex::new(pattern) {
            if let Some(cap) = re.captures(text) {
                let value = cap.get(1).map_or("", |m| m.as_str().trim());
                result.set_metadata(&name.to_lowercase(), value.to_string());

                // Validate URL fields
                if *name != "Preferred-Languages" && !value.starts_with("https://") {
                    result.add_error(format!("{} URL must use HTTPS - found: {}", name, value));
                }
            }
        }
    }
}

/// Validate OpenID Configuration
fn validate_openid_configuration(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    // Parse JSON
    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_object() {
        result.add_error("Root must be a JSON object");
        return;
    }

    let obj = json.as_object().unwrap();

    // Required fields
    let required = [
        "issuer",
        "authorization_endpoint",
        "token_endpoint",
        "jwks_uri",
        "response_types_supported",
        "subject_types_supported",
        "id_token_signing_alg_values_supported",
    ];

    for field in &required {
        if !obj.contains_key(*field) {
            result.add_error(format!("Missing required field: {}", field));
        }
    }

    // Validate issuer
    if let Some(issuer) = obj.get("issuer").and_then(|v| v.as_str()) {
        if !issuer.starts_with("https://") {
            result.add_error("issuer must use HTTPS");
        }
        if issuer.contains('#') {
            result.add_error("issuer must not contain URL fragment");
        }
        result.set_metadata("issuer", issuer.to_string());
    }

    // Validate signing algorithms
    if let Some(algs) = obj.get("id_token_signing_alg_values_supported").and_then(|v| v.as_array()) {
        let alg_strings: Vec<_> = algs.iter().filter_map(|v| v.as_str()).collect();

        if !alg_strings.contains(&"RS256") {
            result.add_error("RS256 must be in id_token_signing_alg_values_supported");
        }

        if alg_strings.contains(&"none") {
            result.add_error("Algorithm 'none' should not be supported");
        }
    }

    // Validate all endpoints use HTTPS
    let endpoint_fields = [
        "authorization_endpoint",
        "token_endpoint",
        "userinfo_endpoint",
        "jwks_uri",
        "registration_endpoint",
    ];

    for field in &endpoint_fields {
        if let Some(url) = obj.get(*field).and_then(|v| v.as_str()) {
            if !url.starts_with("https://") {
                result.add_error(format!("{} must use HTTPS", field));
            }
        }
    }
}

/// Validate WebFinger (RFC 7033)
fn validate_webfinger(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_object() {
        result.add_error("Root must be a JSON object");
        return;
    }

    let obj = json.as_object().unwrap();

    // Required: subject
    if !obj.contains_key("subject") {
        result.add_error("Missing required field: subject");
    } else if let Some(subject) = obj.get("subject").and_then(|v| v.as_str()) {
        result.set_metadata("subject", subject.to_string());
    }

    // Validate links array if present
    if let Some(links) = obj.get("links") {
        if !links.is_array() {
            result.add_error("links must be an array");
        } else if let Some(links_arr) = links.as_array() {
            for (i, link) in links_arr.iter().enumerate() {
                if !link.is_object() {
                    result.add_error(format!("links[{}] must be an object", i));
                } else if let Some(link_obj) = link.as_object() {
                    if !link_obj.contains_key("rel") {
                        result.add_error(format!("links[{}] missing required rel attribute", i));
                    }
                }
            }
        }
    }
}

/// Validate Asset Links (Android)
fn validate_assetlinks(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_array() {
        result.add_error("Root must be a JSON array");
        return;
    }

    let arr = json.as_array().unwrap();

    for (i, entry) in arr.iter().enumerate() {
        if !entry.is_object() {
            result.add_error(format!("Entry {} must be an object", i));
            continue;
        }

        let obj = entry.as_object().unwrap();

        // Check relation
        if !obj.contains_key("relation") {
            result.add_error(format!("Entry {} missing required relation field", i));
        } else if let Some(relation) = obj.get("relation") {
            if !relation.is_array() {
                result.add_error(format!("Entry {} relation must be an array", i));
            }
        }

        // Check target
        if !obj.contains_key("target") {
            result.add_error(format!("Entry {} missing required target field", i));
        } else if let Some(target) = obj.get("target").and_then(|v| v.as_object()) {
            if !target.contains_key("namespace") {
                result.add_error(format!("Entry {} target missing namespace", i));
            }

            // Android-specific checks
            if target.get("namespace").and_then(|v| v.as_str()) == Some("android_app") {
                if !target.contains_key("package_name") {
                    result.add_error(format!("Entry {} Android target missing package_name", i));
                }
                if !target.contains_key("sha256_cert_fingerprints") {
                    result.add_error(format!(
                        "Entry {} Android target missing sha256_cert_fingerprints",
                        i
                    ));
                }
            }
        }
    }
}

/// Validate Apple App Site Association
fn validate_aasa(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_object() {
        result.add_error("Root must be a JSON object");
        return;
    }

    let obj = json.as_object().unwrap();

    // Must have at least one of: applinks, webcredentials, appclips
    let has_applinks = obj.contains_key("applinks");
    let has_webcredentials = obj.contains_key("webcredentials");
    let has_appclips = obj.contains_key("appclips");

    if !has_applinks && !has_webcredentials && !has_appclips {
        result.add_error("Must contain applinks, webcredentials, or appclips");
    }

    // Validate applinks if present
    if let Some(applinks) = obj.get("applinks").and_then(|v| v.as_object()) {
        // Check apps array (should be empty in new format)
        if let Some(apps) = applinks.get("apps") {
            if let Some(apps_arr) = apps.as_array() {
                if !apps_arr.is_empty() {
                    result.add_warning("applinks.apps should be empty array in new format");
                }
            }
        }

        // Check details array
        if !applinks.contains_key("details") {
            result.add_warning("applinks should have details array");
        }
    }
}

/// Validate NodeInfo
fn validate_nodeinfo(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_object() {
        result.add_error("Root must be a JSON object");
        return;
    }

    let obj = json.as_object().unwrap();

    // Required fields
    let required = ["version", "software", "protocols", "usage", "openRegistrations"];

    for field in &required {
        if !obj.contains_key(*field) {
            result.add_error(format!("Missing required field: {}", field));
        }
    }

    // Validate version
    if let Some(version) = obj.get("version").and_then(|v| v.as_str()) {
        let valid_versions = ["2.0", "2.1", "2.2"];
        if !valid_versions.contains(&version) {
            result.add_error(format!(
                "Invalid version: {} (must be 2.0, 2.1, or 2.2)",
                version
            ));
        }
        result.set_metadata("nodeinfo_version", version.to_string());
    }

    // Validate software
    if let Some(software) = obj.get("software").and_then(|v| v.as_object()) {
        if !software.contains_key("name") {
            result.add_error("software.name is required");
        }
        if !software.contains_key("version") {
            result.add_error("software.version is required");
        }

        if let Some(name) = software.get("name").and_then(|v| v.as_str()) {
            result.set_metadata("software_name", name.to_string());
        }
    }

    // Validate protocols
    if let Some(protocols) = obj.get("protocols") {
        if !protocols.is_array() {
            result.add_error("protocols must be an array");
        }
    }
}

/// Validate Matrix server discovery
fn validate_matrix_server(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    let json: Value = match serde_json::from_str(text) {
        Ok(v) => v,
        Err(e) => {
            result.add_error(format!("Invalid JSON: {}", e));
            return;
        }
    };

    if !json.is_object() {
        result.add_error("Root must be a JSON object");
        return;
    }

    let obj = json.as_object().unwrap();

    // Required: m.server
    if !obj.contains_key("m.server") {
        result.add_error("Missing required field: m.server");
    } else if let Some(server) = obj.get("m.server").and_then(|v| v.as_str()) {
        // Validate format: hostname:port
        let server_re = Regex::new(r"^[a-zA-Z0-9.-]+:[0-9]+$").unwrap();
        if !server_re.is_match(server) {
            result.add_error(format!(
                "m.server must be hostname:port format - found: {}",
                server
            ));
        }
        result.set_metadata("matrix_server", server.to_string());
    }
}

/// Validate plain text files (humans.txt, ai.txt)
fn validate_plain_text(content: &[u8], result: &mut ValidationResult) {
    let text = match std::str::from_utf8(content) {
        Ok(t) => t,
        Err(_) => return,
    };

    // Just check it's not empty
    if text.trim().is_empty() {
        result.add_warning("Resource is empty or contains only whitespace");
    }

    result.set_metadata("line_count", text.lines().count().to_string());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_security_txt_valid() {
        let content = b"Contact: mailto:security@example.com\n\
                        Expires: 2026-12-31T23:59:59Z\n";
        let result = validate(content, ResourceType::SecurityTxt).unwrap();
        assert!(result.valid);
    }

    #[test]
    fn test_validate_security_txt_missing_contact() {
        let content = b"Expires: 2026-12-31T23:59:59Z\n";
        let result = validate(content, ResourceType::SecurityTxt).unwrap();
        assert!(!result.valid);
        assert!(result.errors.iter().any(|e| e.contains("Contact")));
    }

    #[test]
    fn test_validate_security_txt_missing_expires() {
        let content = b"Contact: mailto:security@example.com\n";
        let result = validate(content, ResourceType::SecurityTxt).unwrap();
        assert!(!result.valid);
        assert!(result.errors.iter().any(|e| e.contains("Expires")));
    }

    #[test]
    fn test_validate_security_txt_expired() {
        let content = b"Contact: mailto:security@example.com\n\
                        Expires: 2020-01-01T00:00:00Z\n";
        let result = validate(content, ResourceType::SecurityTxt).unwrap();
        assert!(!result.valid);
        assert!(result.errors.iter().any(|e| e.contains("expired")));
    }

    #[test]
    fn test_validate_openid_configuration_valid() {
        let content = br#"{
            "issuer": "https://example.com",
            "authorization_endpoint": "https://example.com/auth",
            "token_endpoint": "https://example.com/token",
            "jwks_uri": "https://example.com/jwks",
            "response_types_supported": ["code"],
            "subject_types_supported": ["public"],
            "id_token_signing_alg_values_supported": ["RS256"]
        }"#;
        let result = validate(content, ResourceType::OpenidConfiguration).unwrap();
        assert!(result.valid);
    }

    #[test]
    fn test_validate_assetlinks_valid() {
        let content = br#"[{
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": "com.example.app",
                "sha256_cert_fingerprints": ["00:11:22:33"]
            }
        }]"#;
        let result = validate(content, ResourceType::Assetlinks).unwrap();
        assert!(result.valid);
    }

    #[test]
    fn test_validate_http_url_error() {
        let content = b"Contact: http://example.com/security\n\
                        Expires: 2026-12-31T23:59:59Z\n";
        let result = validate(content, ResourceType::SecurityTxt).unwrap();
        assert!(!result.valid);
        assert!(result.errors.iter().any(|e| e.contains("HTTP") || e.contains("HTTPS")));
    }
}
