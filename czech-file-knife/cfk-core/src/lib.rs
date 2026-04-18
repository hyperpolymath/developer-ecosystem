//! Czech File Knife Core
//!
//! Core traits, types, and abstractions for the unified filesystem interface.

pub mod backend;
pub mod entry;
pub mod error;
pub mod metadata;
pub mod operations;
pub mod path;
pub mod platform;

pub use backend::{StorageBackend, StorageCapabilities};
pub use entry::{Entry, EntryKind};
pub use error::{CfkError, CfkResult};
pub use metadata::Metadata;
pub use path::VirtualPath;
