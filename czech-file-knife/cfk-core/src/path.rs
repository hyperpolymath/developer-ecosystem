//! Virtual path abstraction

use serde::{Deserialize, Serialize};
use std::fmt;

/// Virtual path representing a location across any backend
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct VirtualPath {
    /// Backend identifier (e.g., "local", "dropbox", "gdrive")
    pub backend: String,
    /// Path segments
    pub segments: Vec<String>,
}

impl VirtualPath {
    pub fn new(backend: impl Into<String>, path: impl AsRef<str>) -> Self {
        let path = path.as_ref();
        let segments = path
            .split('/')
            .filter(|s| !s.is_empty())
            .map(String::from)
            .collect();
        Self {
            backend: backend.into(),
            segments,
        }
    }

    pub fn root(backend: impl Into<String>) -> Self {
        Self {
            backend: backend.into(),
            segments: Vec::new(),
        }
    }

    pub fn join(&self, name: impl AsRef<str>) -> Self {
        let mut segments = self.segments.clone();
        for part in name.as_ref().split('/').filter(|s| !s.is_empty()) {
            if part == ".." {
                segments.pop();
            } else if part != "." {
                segments.push(part.to_string());
            }
        }
        Self {
            backend: self.backend.clone(),
            segments,
        }
    }

    pub fn parent(&self) -> Option<Self> {
        if self.segments.is_empty() {
            None
        } else {
            let mut segments = self.segments.clone();
            segments.pop();
            Some(Self {
                backend: self.backend.clone(),
                segments,
            })
        }
    }

    pub fn name(&self) -> Option<&str> {
        self.segments.last().map(|s| s.as_str())
    }

    pub fn extension(&self) -> Option<&str> {
        self.name().and_then(|n| n.rsplit_once('.')).map(|(_, ext)| ext)
    }

    pub fn is_root(&self) -> bool {
        self.segments.is_empty()
    }

    pub fn to_path_string(&self) -> String {
        if self.segments.is_empty() {
            "/".to_string()
        } else {
            format!("/{}", self.segments.join("/"))
        }
    }

    pub fn to_uri(&self) -> String {
        format!("cfk://{}{}", self.backend, self.to_path_string())
    }

    pub fn parse_uri(uri: &str) -> Option<Self> {
        let uri = uri.strip_prefix("cfk://")?;
        let (backend, path) = uri.split_once('/').unwrap_or((uri, ""));
        Some(Self::new(backend, path))
    }
}

impl fmt::Display for VirtualPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_uri())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new() {
        let path = VirtualPath::new("local", "/home/user/docs");
        assert_eq!(path.backend, "local");
        assert_eq!(path.segments, vec!["home", "user", "docs"]);
    }

    #[test]
    fn test_new_handles_empty_segments() {
        let path = VirtualPath::new("local", "//home//user//");
        assert_eq!(path.segments, vec!["home", "user"]);
    }

    #[test]
    fn test_root() {
        let path = VirtualPath::root("dropbox");
        assert_eq!(path.backend, "dropbox");
        assert!(path.segments.is_empty());
        assert!(path.is_root());
    }

    #[test]
    fn test_join() {
        let root = VirtualPath::root("local");
        let path = root.join("home").join("user");
        assert_eq!(path.segments, vec!["home", "user"]);
    }

    #[test]
    fn test_join_with_dotdot() {
        let path = VirtualPath::new("local", "/home/user/docs");
        let new_path = path.join("../pictures");
        assert_eq!(new_path.segments, vec!["home", "user", "pictures"]);
    }

    #[test]
    fn test_join_with_dot() {
        let path = VirtualPath::new("local", "/home/user");
        let new_path = path.join("./docs");
        assert_eq!(new_path.segments, vec!["home", "user", "docs"]);
    }

    #[test]
    fn test_parent() {
        let path = VirtualPath::new("local", "/home/user/docs");
        let parent = path.parent().unwrap();
        assert_eq!(parent.segments, vec!["home", "user"]);
    }

    #[test]
    fn test_parent_of_root() {
        let root = VirtualPath::root("local");
        assert!(root.parent().is_none());
    }

    #[test]
    fn test_name() {
        let path = VirtualPath::new("local", "/home/user/file.txt");
        assert_eq!(path.name(), Some("file.txt"));
    }

    #[test]
    fn test_name_of_root() {
        let root = VirtualPath::root("local");
        assert!(root.name().is_none());
    }

    #[test]
    fn test_extension() {
        let path = VirtualPath::new("local", "/home/user/file.txt");
        assert_eq!(path.extension(), Some("txt"));

        let path_no_ext = VirtualPath::new("local", "/home/user/file");
        assert!(path_no_ext.extension().is_none());

        let path_multi = VirtualPath::new("local", "/archive.tar.gz");
        assert_eq!(path_multi.extension(), Some("gz"));
    }

    #[test]
    fn test_to_path_string() {
        let root = VirtualPath::root("local");
        assert_eq!(root.to_path_string(), "/");

        let path = VirtualPath::new("local", "/home/user");
        assert_eq!(path.to_path_string(), "/home/user");
    }

    #[test]
    fn test_to_uri() {
        let path = VirtualPath::new("dropbox", "/Documents/file.txt");
        assert_eq!(path.to_uri(), "cfk://dropbox/Documents/file.txt");

        let root = VirtualPath::root("gdrive");
        assert_eq!(root.to_uri(), "cfk://gdrive/");
    }

    #[test]
    fn test_parse_uri() {
        let path = VirtualPath::parse_uri("cfk://local/home/user").unwrap();
        assert_eq!(path.backend, "local");
        assert_eq!(path.segments, vec!["home", "user"]);
    }

    #[test]
    fn test_parse_uri_root() {
        let path = VirtualPath::parse_uri("cfk://dropbox").unwrap();
        assert_eq!(path.backend, "dropbox");
        assert!(path.segments.is_empty());
    }

    #[test]
    fn test_parse_uri_invalid() {
        assert!(VirtualPath::parse_uri("http://example.com").is_none());
        assert!(VirtualPath::parse_uri("/local/path").is_none());
    }

    #[test]
    fn test_display() {
        let path = VirtualPath::new("s3", "/bucket/key");
        assert_eq!(format!("{}", path), "cfk://s3/bucket/key");
    }

    #[test]
    fn test_equality() {
        let path1 = VirtualPath::new("local", "/home/user");
        let path2 = VirtualPath::new("local", "home/user");
        assert_eq!(path1, path2);
    }
}
