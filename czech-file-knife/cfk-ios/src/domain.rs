//! File Provider Domain management
//!
//! Maps to NSFileProviderDomain in iOS.

use crate::error::{IosError, IosResult};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Unique domain identifier
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct DomainIdentifier(pub String);

impl DomainIdentifier {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// File Provider Domain
///
/// Represents a storage location (e.g., a Dropbox account, Google Drive).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileDomain {
    /// Unique identifier
    pub identifier: DomainIdentifier,
    /// Display name shown in Files app
    pub display_name: String,
    /// Backend type (dropbox, gdrive, onedrive, etc.)
    pub backend_type: String,
    /// Backend configuration as JSON
    pub config_json: String,
    /// Whether the domain is currently enabled
    pub enabled: bool,
    /// Path prefix for this domain
    pub path_prefix: Option<String>,
    /// Custom metadata
    #[serde(default)]
    pub metadata: HashMap<String, String>,
}

impl FileDomain {
    /// Create a new domain
    pub fn new(
        identifier: impl Into<String>,
        display_name: impl Into<String>,
        backend_type: impl Into<String>,
    ) -> Self {
        Self {
            identifier: DomainIdentifier::new(identifier),
            display_name: display_name.into(),
            backend_type: backend_type.into(),
            config_json: "{}".to_string(),
            enabled: true,
            path_prefix: None,
            metadata: HashMap::new(),
        }
    }

    /// Set configuration JSON
    pub fn with_config(mut self, config: impl Into<String>) -> Self {
        self.config_json = config.into();
        self
    }

    /// Set path prefix
    pub fn with_prefix(mut self, prefix: impl Into<String>) -> Self {
        self.path_prefix = Some(prefix.into());
        self
    }

    /// Check if this is a cloud backend
    pub fn is_cloud(&self) -> bool {
        matches!(
            self.backend_type.as_str(),
            "dropbox" | "gdrive" | "onedrive" | "box" | "icloud" | "s3" | "webdav"
        )
    }
}

/// Domain manager
pub struct DomainManager {
    domains: Arc<RwLock<HashMap<DomainIdentifier, FileDomain>>>,
    storage_path: std::path::PathBuf,
}

impl DomainManager {
    /// Create a new domain manager
    pub fn new(storage_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            domains: Arc::new(RwLock::new(HashMap::new())),
            storage_path: storage_path.into(),
        }
    }

    /// Load domains from persistent storage
    pub async fn load(&self) -> IosResult<()> {
        let path = self.storage_path.join("domains.json");
        if path.exists() {
            let data = tokio::fs::read_to_string(&path)
                .await
                .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

            let domains: Vec<FileDomain> = serde_json::from_str(&data)
                .map_err(|e| IosError::Ffi(format!("Failed to parse domains: {}", e)))?;

            let mut map = self.domains.write().await;
            for domain in domains {
                map.insert(domain.identifier.clone(), domain);
            }
        }
        Ok(())
    }

    /// Save domains to persistent storage
    pub async fn save(&self) -> IosResult<()> {
        let domains: Vec<FileDomain> = self.domains.read().await.values().cloned().collect();
        let data = serde_json::to_string_pretty(&domains)
            .map_err(|e| IosError::Ffi(format!("Failed to serialize domains: {}", e)))?;

        tokio::fs::create_dir_all(&self.storage_path)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

        let path = self.storage_path.join("domains.json");
        tokio::fs::write(&path, data)
            .await
            .map_err(|e| IosError::Core(cfk_core::CfkError::Io(e)))?;

        Ok(())
    }

    /// Add a domain
    pub async fn add(&self, domain: FileDomain) -> IosResult<()> {
        let mut domains = self.domains.write().await;
        domains.insert(domain.identifier.clone(), domain);
        drop(domains);
        self.save().await
    }

    /// Remove a domain
    pub async fn remove(&self, id: &DomainIdentifier) -> IosResult<Option<FileDomain>> {
        let mut domains = self.domains.write().await;
        let removed = domains.remove(id);
        drop(domains);
        self.save().await?;
        Ok(removed)
    }

    /// Get a domain by ID
    pub async fn get(&self, id: &DomainIdentifier) -> Option<FileDomain> {
        self.domains.read().await.get(id).cloned()
    }

    /// List all domains
    pub async fn list(&self) -> Vec<FileDomain> {
        self.domains.read().await.values().cloned().collect()
    }

    /// Get enabled domains only
    pub async fn list_enabled(&self) -> Vec<FileDomain> {
        self.domains
            .read()
            .await
            .values()
            .filter(|d| d.enabled)
            .cloned()
            .collect()
    }

    /// Enable/disable a domain
    pub async fn set_enabled(&self, id: &DomainIdentifier, enabled: bool) -> IosResult<()> {
        let mut domains = self.domains.write().await;
        if let Some(domain) = domains.get_mut(id) {
            domain.enabled = enabled;
        }
        drop(domains);
        self.save().await
    }
}

/// Domain change notification type
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum DomainChangeType {
    Added = 0,
    Removed = 1,
    Updated = 2,
}
