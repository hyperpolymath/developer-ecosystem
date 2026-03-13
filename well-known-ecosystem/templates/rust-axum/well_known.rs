// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024-2025 hyperpolymath
//
// Rust Axum Well-Known Routes
// Add this module to your Axum project

use axum::{
    extract::State,
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    routing::get,
    Router,
};
use chrono::{DateTime, Utc};
use std::sync::Arc;

/// Well-known resource configuration
#[derive(Clone)]
pub struct WellKnownConfig {
    pub security: SecurityConfig,
    pub ai: Option<AiConfig>,
    pub humans: Option<HumansConfig>,
}

#[derive(Clone)]
pub struct SecurityConfig {
    pub contact: Vec<String>,
    pub expires: DateTime<Utc>,
    pub encryption: Option<String>,
    pub acknowledgments: Option<String>,
    pub preferred_languages: Vec<String>,
    pub canonical: Option<String>,
    pub policy: Option<String>,
    pub hiring: Option<String>,
}

#[derive(Clone)]
pub struct AiConfig {
    pub policy: Option<String>,
    pub training_opt_out: Option<bool>,
    pub contact: Option<String>,
}

#[derive(Clone)]
pub struct HumansConfig {
    pub team: Vec<TeamMember>,
    pub thanks: Vec<Thanks>,
}

#[derive(Clone)]
pub struct TeamMember {
    pub name: String,
    pub role: String,
    pub location: Option<String>,
}

#[derive(Clone)]
pub struct Thanks {
    pub name: String,
    pub role: Option<String>,
}

impl WellKnownConfig {
    /// Create a new configuration with required security settings
    pub fn new(contact: Vec<String>, expires: DateTime<Utc>) -> Self {
        Self {
            security: SecurityConfig {
                contact,
                expires,
                encryption: None,
                acknowledgments: None,
                preferred_languages: vec![],
                canonical: None,
                policy: None,
                hiring: None,
            },
            ai: None,
            humans: None,
        }
    }

    /// Builder pattern for security encryption URL
    pub fn with_encryption(mut self, url: impl Into<String>) -> Self {
        self.security.encryption = Some(url.into());
        self
    }

    /// Builder pattern for security policy URL
    pub fn with_policy(mut self, url: impl Into<String>) -> Self {
        self.security.policy = Some(url.into());
        self
    }

    /// Builder pattern for canonical URL
    pub fn with_canonical(mut self, url: impl Into<String>) -> Self {
        self.security.canonical = Some(url.into());
        self
    }

    /// Builder pattern for AI configuration
    pub fn with_ai(mut self, ai: AiConfig) -> Self {
        self.ai = Some(ai);
        self
    }

    /// Builder pattern for humans configuration
    pub fn with_humans(mut self, humans: HumansConfig) -> Self {
        self.humans = Some(humans);
        self
    }
}

/// Generate security.txt content
fn generate_security_txt(config: &SecurityConfig) -> String {
    let mut lines = Vec::new();

    for contact in &config.contact {
        lines.push(format!("Contact: {}", contact));
    }

    lines.push(format!("Expires: {}", config.expires.to_rfc3339()));

    if let Some(ref enc) = config.encryption {
        lines.push(format!("Encryption: {}", enc));
    }
    if let Some(ref ack) = config.acknowledgments {
        lines.push(format!("Acknowledgments: {}", ack));
    }
    if !config.preferred_languages.is_empty() {
        lines.push(format!(
            "Preferred-Languages: {}",
            config.preferred_languages.join(", ")
        ));
    }
    if let Some(ref can) = config.canonical {
        lines.push(format!("Canonical: {}", can));
    }
    if let Some(ref pol) = config.policy {
        lines.push(format!("Policy: {}", pol));
    }
    if let Some(ref hir) = config.hiring {
        lines.push(format!("Hiring: {}", hir));
    }

    lines.join("\n") + "\n"
}

/// Generate ai.txt content
fn generate_ai_txt(config: &AiConfig) -> String {
    let mut lines = Vec::new();

    if let Some(ref policy) = config.policy {
        lines.push(format!("AI-Policy: {}", policy));
    }
    if let Some(opt_out) = config.training_opt_out {
        lines.push(format!("Training-Opt-Out: {}", opt_out));
    }
    if let Some(ref contact) = config.contact {
        lines.push(format!("Contact: {}", contact));
    }

    lines.join("\n") + "\n"
}

/// Generate humans.txt content
fn generate_humans_txt(config: &HumansConfig) -> String {
    let mut lines = vec!["/* TEAM */".to_string()];

    for member in &config.team {
        lines.push(format!("Name: {}", member.name));
        lines.push(format!("Role: {}", member.role));
        if let Some(ref loc) = member.location {
            lines.push(format!("Location: {}", loc));
        }
        lines.push(String::new());
    }

    if !config.thanks.is_empty() {
        lines.push("/* THANKS */".to_string());
        for t in &config.thanks {
            lines.push(format!("Name: {}", t.name));
            if let Some(ref role) = t.role {
                lines.push(format!("Role: {}", role));
            }
            lines.push(String::new());
        }
    }

    lines.push("/* SITE */".to_string());
    lines.push(format!(
        "Last update: {}",
        Utc::now().format("%Y-%m-%d")
    ));
    lines.push("Standards: RFC 8615, RFC 9116".to_string());

    lines.join("\n") + "\n"
}

/// Plain text response helper
fn plain_text(content: String) -> Response {
    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
        content,
    )
        .into_response()
}

/// Handler for /.well-known/security.txt
async fn security_txt_handler(State(config): State<Arc<WellKnownConfig>>) -> Response {
    plain_text(generate_security_txt(&config.security))
}

/// Handler for /.well-known/ai.txt
async fn ai_txt_handler(State(config): State<Arc<WellKnownConfig>>) -> Response {
    match &config.ai {
        Some(ai) => plain_text(generate_ai_txt(ai)),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

/// Handler for /.well-known/humans.txt
async fn humans_txt_handler(State(config): State<Arc<WellKnownConfig>>) -> Response {
    match &config.humans {
        Some(humans) => plain_text(generate_humans_txt(humans)),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

/// Create router for well-known resources
pub fn well_known_router(config: WellKnownConfig) -> Router {
    let config = Arc::new(config);

    Router::new()
        .route("/security.txt", get(security_txt_handler))
        .route("/ai.txt", get(ai_txt_handler))
        .route("/humans.txt", get(humans_txt_handler))
        .with_state(config)
}

/// Nest the well-known router under /.well-known
pub fn nest_well_known(app: Router, config: WellKnownConfig) -> Router {
    app.nest("/.well-known", well_known_router(config))
}

// Example usage:
//
// use chrono::{Duration, Utc};
//
// let config = WellKnownConfig::new(
//     vec!["mailto:security@example.com".to_string()],
//     Utc::now() + Duration::days(365),
// )
// .with_policy("https://example.com/security/policy")
// .with_ai(AiConfig {
//     policy: Some("https://example.com/ai-policy".to_string()),
//     training_opt_out: Some(true),
//     contact: None,
// });
//
// let app = Router::new()
//     .route("/", get(|| async { "Hello, World!" }));
//
// let app = nest_well_known(app, config);
