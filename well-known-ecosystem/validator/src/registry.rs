// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath

//! Well-known resource type registry.

use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Registry version
pub const REGISTRY_VERSION: &str = "1.0.0";

/// Supported well-known resource types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ResourceType {
    /// RFC 9116 security.txt
    SecurityTxt,
    /// OpenID Connect Discovery
    OpenidConfiguration,
    /// RFC 7033 WebFinger
    Webfinger,
    /// RFC 6415 Host Metadata
    HostMeta,
    /// WICG Change Password
    ChangePassword,
    /// Google Digital Asset Links
    Assetlinks,
    /// Apple App Site Association
    AppleAppSiteAssociation,
    /// W3C Do Not Track Policy
    DntPolicy,
    /// Matrix Server Discovery
    MatrixServer,
    /// Matrix Client Discovery
    MatrixClient,
    /// NodeInfo (Fediverse)
    Nodeinfo,
    /// Humans.txt
    HumansTxt,
    /// AI Policy Disclosure (RSR)
    AiTxt,
}

/// Resource registry entry with full metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceEntry {
    /// Unique identifier
    pub id: String,
    /// Human-readable name
    pub name: String,
    /// Version of this entry
    pub version: String,
    /// Path under /.well-known/
    pub uri_path: String,
    /// MIME content type
    pub content_type: String,
    /// Standard or specification
    pub standard: String,
    /// URL to specification
    #[serde(skip_serializing_if = "Option::is_none")]
    pub specification_uri: Option<String>,
    /// Registrant organization
    pub registered_by: String,
    /// Registration date (ISO 8601)
    pub registration_date: String,
    /// Status: active, deprecated, proposed
    pub status: String,
    /// Listed in IANA registry
    pub iana_registered: bool,
    /// Has expiration field
    pub has_expiry: bool,
    /// Required fields
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub required_fields: Vec<String>,
    /// Optional fields
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub optional_fields: Vec<String>,
    /// Additional notes
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
}

/// Get all registered resource entries
pub fn all_resources() -> Vec<ResourceEntry> {
    vec![
        ResourceEntry {
            id: "security-txt".to_string(),
            name: "security.txt".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "security.txt".to_string(),
            content_type: "text/plain; charset=utf-8".to_string(),
            standard: "RFC 9116".to_string(),
            specification_uri: Some("https://www.rfc-editor.org/rfc/rfc9116".to_string()),
            registered_by: "IETF".to_string(),
            registration_date: "2022-04-01".to_string(),
            status: "active".to_string(),
            iana_registered: true,
            has_expiry: true,
            required_fields: vec!["Contact".to_string(), "Expires".to_string()],
            optional_fields: vec![
                "Encryption".to_string(),
                "Acknowledgments".to_string(),
                "Preferred-Languages".to_string(),
                "Canonical".to_string(),
                "Policy".to_string(),
                "Hiring".to_string(),
            ],
            notes: Some("Mandatory for RSR compliance".to_string()),
        },
        ResourceEntry {
            id: "openid-configuration".to_string(),
            name: "OpenID Connect Discovery".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "openid-configuration".to_string(),
            content_type: "application/json".to_string(),
            standard: "OpenID Connect Discovery 1.0".to_string(),
            specification_uri: Some(
                "https://openid.net/specs/openid-connect-discovery-1_0.html".to_string(),
            ),
            registered_by: "OpenID Foundation".to_string(),
            registration_date: "2014-11-08".to_string(),
            status: "active".to_string(),
            iana_registered: true,
            has_expiry: false,
            required_fields: vec![
                "issuer".to_string(),
                "authorization_endpoint".to_string(),
                "token_endpoint".to_string(),
                "jwks_uri".to_string(),
                "response_types_supported".to_string(),
                "subject_types_supported".to_string(),
                "id_token_signing_alg_values_supported".to_string(),
            ],
            optional_fields: vec![
                "userinfo_endpoint".to_string(),
                "registration_endpoint".to_string(),
                "scopes_supported".to_string(),
                "claims_supported".to_string(),
            ],
            notes: None,
        },
        ResourceEntry {
            id: "webfinger".to_string(),
            name: "WebFinger".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "webfinger".to_string(),
            content_type: "application/jrd+json".to_string(),
            standard: "RFC 7033".to_string(),
            specification_uri: Some("https://www.rfc-editor.org/rfc/rfc7033".to_string()),
            registered_by: "IETF".to_string(),
            registration_date: "2013-09-01".to_string(),
            status: "active".to_string(),
            iana_registered: true,
            has_expiry: false,
            required_fields: vec!["subject".to_string()],
            optional_fields: vec![
                "aliases".to_string(),
                "properties".to_string(),
                "links".to_string(),
            ],
            notes: Some("Query-based resource".to_string()),
        },
        ResourceEntry {
            id: "host-meta".to_string(),
            name: "Host Metadata".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "host-meta".to_string(),
            content_type: "application/xrd+xml".to_string(),
            standard: "RFC 6415".to_string(),
            specification_uri: Some("https://www.rfc-editor.org/rfc/rfc6415".to_string()),
            registered_by: "IETF".to_string(),
            registration_date: "2012-10-01".to_string(),
            status: "active".to_string(),
            iana_registered: true,
            has_expiry: false,
            required_fields: vec![],
            optional_fields: vec![],
            notes: Some("JSON variant: host-meta.json".to_string()),
        },
        ResourceEntry {
            id: "assetlinks".to_string(),
            name: "Digital Asset Links".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "assetlinks.json".to_string(),
            content_type: "application/json".to_string(),
            standard: "Google Asset Links".to_string(),
            specification_uri: Some(
                "https://developers.google.com/digital-asset-links".to_string(),
            ),
            registered_by: "Google".to_string(),
            registration_date: "2015-01-01".to_string(),
            status: "active".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec!["relation".to_string(), "target".to_string()],
            optional_fields: vec![],
            notes: Some("Android App Links verification".to_string()),
        },
        ResourceEntry {
            id: "apple-app-site-association".to_string(),
            name: "Apple App Site Association".to_string(),
            version: "2.0.0".to_string(),
            uri_path: "apple-app-site-association".to_string(),
            content_type: "application/json".to_string(),
            standard: "Apple Universal Links".to_string(),
            specification_uri: Some(
                "https://developer.apple.com/documentation/xcode/supporting-associated-domains"
                    .to_string(),
            ),
            registered_by: "Apple".to_string(),
            registration_date: "2015-01-01".to_string(),
            status: "active".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec![],
            optional_fields: vec![
                "applinks".to_string(),
                "webcredentials".to_string(),
                "appclips".to_string(),
            ],
            notes: Some("iOS Universal Links".to_string()),
        },
        ResourceEntry {
            id: "matrix-server".to_string(),
            name: "Matrix Server".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "matrix/server".to_string(),
            content_type: "application/json".to_string(),
            standard: "Matrix Spec".to_string(),
            specification_uri: Some("https://spec.matrix.org/".to_string()),
            registered_by: "Matrix.org Foundation".to_string(),
            registration_date: "2019-01-01".to_string(),
            status: "active".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec!["m.server".to_string()],
            optional_fields: vec![],
            notes: Some("Matrix federation discovery".to_string()),
        },
        ResourceEntry {
            id: "nodeinfo".to_string(),
            name: "NodeInfo".to_string(),
            version: "2.2.0".to_string(),
            uri_path: "nodeinfo".to_string(),
            content_type: "application/json".to_string(),
            standard: "NodeInfo 2.0".to_string(),
            specification_uri: Some("https://nodeinfo.diaspora.software/".to_string()),
            registered_by: "Diaspora Foundation".to_string(),
            registration_date: "2018-01-01".to_string(),
            status: "active".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec![
                "version".to_string(),
                "software".to_string(),
                "protocols".to_string(),
                "usage".to_string(),
                "openRegistrations".to_string(),
            ],
            optional_fields: vec!["services".to_string(), "metadata".to_string()],
            notes: Some("Fediverse server metadata".to_string()),
        },
        ResourceEntry {
            id: "humans-txt".to_string(),
            name: "Humans.txt".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "humans.txt".to_string(),
            content_type: "text/plain; charset=utf-8".to_string(),
            standard: "humanstxt.org".to_string(),
            specification_uri: Some("https://humanstxt.org/".to_string()),
            registered_by: "humanstxt.org".to_string(),
            registration_date: "2010-01-01".to_string(),
            status: "active".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec![],
            optional_fields: vec![],
            notes: Some("RSR recommended".to_string()),
        },
        ResourceEntry {
            id: "ai-txt".to_string(),
            name: "AI Policy Disclosure".to_string(),
            version: "1.0.0".to_string(),
            uri_path: "ai.txt".to_string(),
            content_type: "text/plain; charset=utf-8".to_string(),
            standard: "RSR Standard".to_string(),
            specification_uri: None,
            registered_by: "hyperpolymath".to_string(),
            registration_date: "2025-01-01".to_string(),
            status: "proposed".to_string(),
            iana_registered: false,
            has_expiry: false,
            required_fields: vec![],
            optional_fields: vec![
                "AI-Policy".to_string(),
                "Training-Opt-Out".to_string(),
                "Contact".to_string(),
            ],
            notes: Some("RSR-mandated AI policy disclosure".to_string()),
        },
    ]
}

/// Parse a resource type string to enum
pub fn parse_resource_type(s: &str) -> Result<ResourceType> {
    match s.to_lowercase().replace('_', "-").as_str() {
        "security-txt" | "security.txt" | "securitytxt" => Ok(ResourceType::SecurityTxt),
        "openid-configuration" | "openid" | "oidc" => Ok(ResourceType::OpenidConfiguration),
        "webfinger" => Ok(ResourceType::Webfinger),
        "host-meta" | "hostmeta" => Ok(ResourceType::HostMeta),
        "change-password" | "changepassword" => Ok(ResourceType::ChangePassword),
        "assetlinks" | "assetlinks.json" => Ok(ResourceType::Assetlinks),
        "apple-app-site-association" | "aasa" => Ok(ResourceType::AppleAppSiteAssociation),
        "dnt-policy" | "dnt-policy.txt" | "dnt" => Ok(ResourceType::DntPolicy),
        "matrix-server" | "matrix/server" => Ok(ResourceType::MatrixServer),
        "matrix-client" | "matrix/client" => Ok(ResourceType::MatrixClient),
        "nodeinfo" => Ok(ResourceType::Nodeinfo),
        "humans-txt" | "humans.txt" | "humanstxt" => Ok(ResourceType::HumansTxt),
        "ai-txt" | "ai.txt" | "aitxt" => Ok(ResourceType::AiTxt),
        _ => Err(anyhow!("Unknown resource type: {}", s)),
    }
}

/// Detect resource type from file path
pub fn detect_resource_type(path: &Path) -> Result<ResourceType> {
    let filename = path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| anyhow!("Invalid file path"))?;

    match filename {
        "security.txt" => Ok(ResourceType::SecurityTxt),
        "openid-configuration" => Ok(ResourceType::OpenidConfiguration),
        "webfinger" => Ok(ResourceType::Webfinger),
        "host-meta" | "host-meta.json" => Ok(ResourceType::HostMeta),
        "change-password" => Ok(ResourceType::ChangePassword),
        "assetlinks.json" => Ok(ResourceType::Assetlinks),
        "apple-app-site-association" => Ok(ResourceType::AppleAppSiteAssociation),
        "dnt-policy.txt" => Ok(ResourceType::DntPolicy),
        "server" if path.to_string_lossy().contains("matrix") => Ok(ResourceType::MatrixServer),
        "client" if path.to_string_lossy().contains("matrix") => Ok(ResourceType::MatrixClient),
        "nodeinfo" => Ok(ResourceType::Nodeinfo),
        "humans.txt" => Ok(ResourceType::HumansTxt),
        "ai.txt" => Ok(ResourceType::AiTxt),
        _ => Err(anyhow!("Could not detect resource type for: {}", filename)),
    }
}

/// Get resource entry by type
pub fn get_resource_entry(rtype: ResourceType) -> ResourceEntry {
    let all = all_resources();
    let id = match rtype {
        ResourceType::SecurityTxt => "security-txt",
        ResourceType::OpenidConfiguration => "openid-configuration",
        ResourceType::Webfinger => "webfinger",
        ResourceType::HostMeta => "host-meta",
        ResourceType::ChangePassword => "change-password",
        ResourceType::Assetlinks => "assetlinks",
        ResourceType::AppleAppSiteAssociation => "apple-app-site-association",
        ResourceType::DntPolicy => "dnt-policy",
        ResourceType::MatrixServer => "matrix-server",
        ResourceType::MatrixClient => "matrix-client",
        ResourceType::Nodeinfo => "nodeinfo",
        ResourceType::HumansTxt => "humans-txt",
        ResourceType::AiTxt => "ai-txt",
    };

    all.into_iter()
        .find(|r| r.id == id)
        .expect("Resource entry not found")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_resource_type() {
        assert_eq!(
            parse_resource_type("security-txt").unwrap(),
            ResourceType::SecurityTxt
        );
        assert_eq!(
            parse_resource_type("security.txt").unwrap(),
            ResourceType::SecurityTxt
        );
        assert_eq!(
            parse_resource_type("openid-configuration").unwrap(),
            ResourceType::OpenidConfiguration
        );
        assert_eq!(
            parse_resource_type("oidc").unwrap(),
            ResourceType::OpenidConfiguration
        );
    }

    #[test]
    fn test_detect_resource_type() {
        assert_eq!(
            detect_resource_type(Path::new("security.txt")).unwrap(),
            ResourceType::SecurityTxt
        );
        assert_eq!(
            detect_resource_type(Path::new("assetlinks.json")).unwrap(),
            ResourceType::Assetlinks
        );
    }

    #[test]
    fn test_all_resources_not_empty() {
        let resources = all_resources();
        assert!(!resources.is_empty());
        assert!(resources.len() >= 10);
    }
}
