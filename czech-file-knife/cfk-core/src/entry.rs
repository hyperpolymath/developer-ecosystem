//! File system entries

use crate::{Metadata, VirtualPath};
use serde::{Deserialize, Serialize};

/// Entry kind
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EntryKind {
    File,
    Directory,
    Symlink,
    Unknown,
}

/// A file system entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub path: VirtualPath,
    pub kind: EntryKind,
    pub metadata: Metadata,
}

impl Entry {
    pub fn file(path: VirtualPath, metadata: Metadata) -> Self {
        Self { path, kind: EntryKind::File, metadata }
    }

    pub fn directory(path: VirtualPath, metadata: Metadata) -> Self {
        Self { path, kind: EntryKind::Directory, metadata }
    }

    pub fn is_file(&self) -> bool {
        self.kind == EntryKind::File
    }

    pub fn is_directory(&self) -> bool {
        self.kind == EntryKind::Directory
    }

    pub fn name(&self) -> Option<&str> {
        self.path.name()
    }

    pub fn size(&self) -> Option<u64> {
        self.metadata.size
    }
}

/// Directory listing result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectoryListing {
    pub path: VirtualPath,
    pub entries: Vec<Entry>,
    pub cursor: Option<String>,
    pub has_more: bool,
}

impl DirectoryListing {
    pub fn new(path: VirtualPath, entries: Vec<Entry>) -> Self {
        Self { path, entries, cursor: None, has_more: false }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_path(p: &str) -> VirtualPath {
        VirtualPath::new("local", p)
    }

    #[test]
    fn test_entry_file() {
        let entry = Entry::file(make_path("/home/user/file.txt"), Metadata::new());
        assert!(entry.is_file());
        assert!(!entry.is_directory());
        assert_eq!(entry.kind, EntryKind::File);
    }

    #[test]
    fn test_entry_directory() {
        let entry = Entry::directory(make_path("/home/user"), Metadata::new());
        assert!(entry.is_directory());
        assert!(!entry.is_file());
        assert_eq!(entry.kind, EntryKind::Directory);
    }

    #[test]
    fn test_entry_name() {
        let entry = Entry::file(make_path("/home/user/document.pdf"), Metadata::new());
        assert_eq!(entry.name(), Some("document.pdf"));
    }

    #[test]
    fn test_entry_size() {
        let mut meta = Metadata::new();
        meta.size = Some(1024);
        let entry = Entry::file(make_path("/file.txt"), meta);
        assert_eq!(entry.size(), Some(1024));
    }

    #[test]
    fn test_directory_listing() {
        let root = make_path("/home");
        let entries = vec![
            Entry::directory(make_path("/home/user1"), Metadata::new()),
            Entry::directory(make_path("/home/user2"), Metadata::new()),
        ];
        let listing = DirectoryListing::new(root.clone(), entries);

        assert_eq!(listing.path, root);
        assert_eq!(listing.entries.len(), 2);
        assert!(!listing.has_more);
        assert!(listing.cursor.is_none());
    }
}
