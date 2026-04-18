//! Version parsing and comparison

use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::fmt;

/// Represents a semantic version
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Version {
    /// Major version
    pub major: u32,

    /// Minor version
    pub minor: u32,

    /// Patch version
    pub patch: u32,

    /// Pre-release identifier
    pub pre: Option<String>,

    /// Build metadata
    pub build: Option<String>,

    /// Original string representation
    pub original: String,
}

impl Version {
    /// Parse a version string
    ///
    /// # Examples
    ///
    /// ```
    /// use asdf_core::Version;
    ///
    /// let v = Version::parse("1.2.3").unwrap();
    /// assert_eq!(v.major, 1);
    /// assert_eq!(v.minor, 2);
    /// assert_eq!(v.patch, 3);
    /// ```
    pub fn parse(s: &str) -> Result<Self> {
        let original = s.to_string();

        // Split on '+' to separate build metadata
        let (version_part, build) = if let Some(pos) = s.find('+') {
            let (v, b) = s.split_at(pos);
            (v, Some(b[1..].to_string()))
        } else {
            (s, None)
        };

        // Split on '-' to separate pre-release
        let (version_nums, pre) = if let Some(pos) = version_part.find('-') {
            let (v, p) = version_part.split_at(pos);
            (v, Some(p[1..].to_string()))
        } else {
            (version_part, None)
        };

        // Parse version numbers
        let parts: Vec<&str> = version_nums.split('.').collect();
        if parts.is_empty() || parts.len() > 3 {
            return Err(Error::InvalidVersion(original));
        }

        let major = parts[0]
            .parse()
            .map_err(|_| Error::InvalidVersion(original.clone()))?;

        let minor = parts
            .get(1)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        let patch = parts
            .get(2)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);

        Ok(Version {
            major,
            minor,
            patch,
            pre,
            build,
            original,
        })
    }

    /// Check if this is a pre-release version
    pub fn is_prerelease(&self) -> bool {
        self.pre.is_some()
    }

    /// Get the version without pre-release or build metadata
    pub fn base_version(&self) -> String {
        format!("{}.{}.{}", self.major, self.minor, self.patch)
    }
}

impl fmt::Display for Version {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.original)
    }
}

impl PartialOrd for Version {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Version {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.major.cmp(&other.major) {
            Ordering::Equal => match self.minor.cmp(&other.minor) {
                Ordering::Equal => match self.patch.cmp(&other.patch) {
                    Ordering::Equal => {
                        // Pre-release versions have lower precedence
                        match (&self.pre, &other.pre) {
                            (None, None) => Ordering::Equal,
                            (None, Some(_)) => Ordering::Greater,
                            (Some(_), None) => Ordering::Less,
                            (Some(a), Some(b)) => a.cmp(b),
                        }
                    }
                    other => other,
                },
                other => other,
            },
            other => other,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_parse() {
        let v = Version::parse("1.2.3").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
        assert!(v.pre.is_none());
        assert!(v.build.is_none());
    }

    #[test]
    fn test_version_parse_pre() {
        let v = Version::parse("1.2.3-beta.1").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.minor, 2);
        assert_eq!(v.patch, 3);
        assert_eq!(v.pre, Some("beta.1".to_string()));
    }

    #[test]
    fn test_version_parse_build() {
        let v = Version::parse("1.2.3+build.123").unwrap();
        assert_eq!(v.major, 1);
        assert_eq!(v.build, Some("build.123".to_string()));
    }

    #[test]
    fn test_version_compare() {
        let v1 = Version::parse("1.2.3").unwrap();
        let v2 = Version::parse("1.2.4").unwrap();
        assert!(v1 < v2);

        let v3 = Version::parse("2.0.0").unwrap();
        assert!(v2 < v3);
    }

    #[test]
    fn test_version_prerelease() {
        let v1 = Version::parse("1.2.3").unwrap();
        let v2 = Version::parse("1.2.3-beta").unwrap();
        assert!(v2 < v1); // Pre-release has lower precedence
        assert!(v2.is_prerelease());
        assert!(!v1.is_prerelease());
    }

    #[test]
    fn test_version_display() {
        let v = Version::parse("1.2.3-beta.1+build.123").unwrap();
        assert_eq!(v.to_string(), "1.2.3-beta.1+build.123");
    }

    #[test]
    fn test_base_version() {
        let v = Version::parse("1.2.3-beta.1+build.123").unwrap();
        assert_eq!(v.base_version(), "1.2.3");
    }
}
