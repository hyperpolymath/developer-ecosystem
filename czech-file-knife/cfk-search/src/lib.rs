// SPDX-License-Identifier: AGPL-3.0-or-later
//! Full-text search for Czech File Knife
//!
//! This module provides full-text search capabilities using Tantivy.
//! Currently a stub - full implementation coming in a future release.

use async_trait::async_trait;
use cfk_core::{CfkResult, Entry, VirtualPath};
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Search index errors
#[derive(Error, Debug)]
pub enum SearchError {
    #[error("Index not found: {0}")]
    IndexNotFound(String),

    #[error("Index error: {0}")]
    IndexError(String),

    #[error("Query parse error: {0}")]
    QueryError(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// Search result with relevance score
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    /// The matching entry
    pub entry: Entry,
    /// Relevance score (0.0 - 1.0)
    pub score: f32,
    /// Matching snippets with highlights
    pub snippets: Vec<String>,
}

/// Search query options
#[derive(Debug, Clone, Default)]
pub struct SearchQuery {
    /// The search query string
    pub query: String,
    /// Limit search to specific backends
    pub backends: Option<Vec<String>>,
    /// Limit search to specific path prefixes
    pub paths: Option<Vec<VirtualPath>>,
    /// Maximum number of results
    pub limit: Option<usize>,
    /// Offset for pagination
    pub offset: Option<usize>,
    /// File type filters (e.g., "pdf", "txt")
    pub file_types: Option<Vec<String>>,
    /// Search in file contents (not just names)
    pub search_contents: bool,
}

/// Search index trait
#[async_trait]
pub trait SearchIndex: Send + Sync {
    /// Index a file or directory
    async fn index(&self, entry: &Entry, content: Option<&[u8]>) -> CfkResult<()>;

    /// Remove an entry from the index
    async fn remove(&self, path: &VirtualPath) -> CfkResult<()>;

    /// Search the index
    async fn search(&self, query: &SearchQuery) -> CfkResult<Vec<SearchResult>>;

    /// Clear the entire index
    async fn clear(&self) -> CfkResult<()>;

    /// Get index statistics
    async fn stats(&self) -> CfkResult<IndexStats>;
}

/// Index statistics
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct IndexStats {
    /// Number of indexed documents
    pub document_count: u64,
    /// Index size in bytes
    pub size_bytes: u64,
    /// Last update timestamp
    pub last_updated: Option<chrono::DateTime<chrono::Utc>>,
}

/// Tantivy-based search index (stub)
/// Enable the `tantivy` feature to use this.
#[cfg(feature = "tantivy")]
pub struct TantivyIndex {
    _path: PathBuf,
}

#[cfg(feature = "tantivy")]
impl TantivyIndex {
    /// Create a new Tantivy index at the given path
    pub fn new(_path: impl Into<PathBuf>) -> CfkResult<Self> {
        Err(CfkError::Unsupported(
            "Tantivy search index not yet implemented".into(),
        ))
    }

    /// Open an existing index
    pub fn open(_path: impl Into<PathBuf>) -> CfkResult<Self> {
        Err(CfkError::Unsupported(
            "Tantivy search index not yet implemented".into(),
        ))
    }
}

#[cfg(feature = "tantivy")]
#[async_trait]
impl SearchIndex for TantivyIndex {
    async fn index(&self, _entry: &Entry, _content: Option<&[u8]>) -> CfkResult<()> {
        Err(CfkError::Unsupported("Search indexing not yet implemented".into()))
    }

    async fn remove(&self, _path: &VirtualPath) -> CfkResult<()> {
        Err(CfkError::Unsupported("Search indexing not yet implemented".into()))
    }

    async fn search(&self, _query: &SearchQuery) -> CfkResult<Vec<SearchResult>> {
        Err(CfkError::Unsupported("Search not yet implemented".into()))
    }

    async fn clear(&self) -> CfkResult<()> {
        Err(CfkError::Unsupported("Search indexing not yet implemented".into()))
    }

    async fn stats(&self) -> CfkResult<IndexStats> {
        Err(CfkError::Unsupported("Search indexing not yet implemented".into()))
    }
}

/// Simple filename-based search (works without full-text index)
pub async fn search_by_name(
    pattern: &str,
    entries: impl IntoIterator<Item = Entry>,
) -> Vec<Entry> {
    let pattern_lower = pattern.to_lowercase();
    entries
        .into_iter()
        .filter(|e| {
            e.name()
                .map(|n| n.to_lowercase().contains(&pattern_lower))
                .unwrap_or(false)
        })
        .collect()
}

/// Glob-style pattern matching
pub fn matches_glob(pattern: &str, name: &str) -> bool {
    let pattern = pattern.to_lowercase();
    let name = name.to_lowercase();

    if pattern == "*" {
        return true;
    }

    if let Some(suffix) = pattern.strip_prefix("*.") {
        return name.ends_with(&format!(".{}", suffix));
    }

    if let Some(prefix) = pattern.strip_suffix(".*") {
        return name.starts_with(prefix);
    }

    name.contains(&pattern)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_matches_glob() {
        assert!(matches_glob("*", "anything.txt"));
        assert!(matches_glob("*.txt", "file.txt"));
        assert!(matches_glob("*.TXT", "file.txt"));
        assert!(!matches_glob("*.txt", "file.pdf"));
        assert!(matches_glob("file.*", "file.txt"));
        assert!(matches_glob("test", "my_test_file.txt"));
    }
}
