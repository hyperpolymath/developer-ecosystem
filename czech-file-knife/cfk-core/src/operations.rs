//! Operation options

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ListOptions {
    pub recursive: bool,
    pub include_hidden: bool,
    pub limit: Option<usize>,
    pub cursor: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ReadOptions {
    pub range: Option<(u64, u64)>,
    pub use_cache: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WriteOptions {
    pub overwrite: bool,
    pub create_parents: bool,
    pub content_hash: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CopyOptions {
    pub overwrite: bool,
    pub preserve_metadata: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MoveOptions {
    pub overwrite: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DeleteOptions {
    pub recursive: bool,
    pub force: bool,
}
