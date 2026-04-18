//! Exotic protocol support
//!
//! Additional protocols beyond standard cloud/file systems:
//! - NNTP/NNTPS: Usenet
//! - Gopher/Gopher+: Pre-web protocol
//! - Gemini: Modern minimalist protocol
//! - RTSP: Streaming
//! - BitTorrent: P2P file sharing
//! - DAT/Hypercore: P2P versioned data
//! - Freenet: Anonymous storage
//! - I2P: Anonymous network
//! - Tor: Onion services
//! - MTP: Mobile devices
//! - AFP: Apple Filing
//! - DLNA/UPnP: Media discovery

use cfk_core::{CfkError, CfkResult};

/// Protocol capabilities
#[derive(Debug, Clone, Default)]
pub struct ProtocolInfo {
    pub name: &'static str,
    pub scheme: &'static str,
    pub default_port: u16,
    pub encrypted: bool,
    pub bidirectional: bool,  // can upload
    pub streaming: bool,
    pub anonymous: bool,
}

/// Supported exotic protocols
pub const PROTOCOLS: &[ProtocolInfo] = &[
    ProtocolInfo {
        name: "Usenet (NNTP)",
        scheme: "nntp",
        default_port: 119,
        encrypted: false,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
    ProtocolInfo {
        name: "Usenet Secure (NNTPS)",
        scheme: "nntps",
        default_port: 563,
        encrypted: true,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
    ProtocolInfo {
        name: "Gopher",
        scheme: "gopher",
        default_port: 70,
        encrypted: false,
        bidirectional: false,
        streaming: false,
        anonymous: true,
    },
    ProtocolInfo {
        name: "Gemini",
        scheme: "gemini",
        default_port: 1965,
        encrypted: true,
        bidirectional: false,
        streaming: false,
        anonymous: true,
    },
    ProtocolInfo {
        name: "RTSP (Streaming)",
        scheme: "rtsp",
        default_port: 554,
        encrypted: false,
        bidirectional: false,
        streaming: true,
        anonymous: false,
    },
    ProtocolInfo {
        name: "BitTorrent",
        scheme: "magnet",
        default_port: 6881,
        encrypted: false,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
    ProtocolInfo {
        name: "DAT/Hypercore",
        scheme: "dat",
        default_port: 3282,
        encrypted: true,
        bidirectional: true,
        streaming: true,
        anonymous: false,
    },
    ProtocolInfo {
        name: "Freenet",
        scheme: "freenet",
        default_port: 8888,
        encrypted: true,
        bidirectional: true,
        streaming: false,
        anonymous: true,
    },
    ProtocolInfo {
        name: "I2P",
        scheme: "i2p",
        default_port: 7657,
        encrypted: true,
        bidirectional: true,
        streaming: false,
        anonymous: true,
    },
    ProtocolInfo {
        name: "Tor Onion",
        scheme: "onion",
        default_port: 9050,
        encrypted: true,
        bidirectional: true,
        streaming: false,
        anonymous: true,
    },
    ProtocolInfo {
        name: "MTP (Mobile)",
        scheme: "mtp",
        default_port: 0,
        encrypted: false,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
    ProtocolInfo {
        name: "AFP (Apple)",
        scheme: "afp",
        default_port: 548,
        encrypted: false,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
    ProtocolInfo {
        name: "DLNA/UPnP",
        scheme: "dlna",
        default_port: 1900,
        encrypted: false,
        bidirectional: false,
        streaming: true,
        anonymous: false,
    },
    ProtocolInfo {
        name: "Matrix",
        scheme: "matrix",
        default_port: 8448,
        encrypted: true,
        bidirectional: true,
        streaming: false,
        anonymous: false,
    },
];

/// Find protocol info by scheme
pub fn get_protocol(scheme: &str) -> Option<&'static ProtocolInfo> {
    PROTOCOLS.iter().find(|p| p.scheme == scheme)
}

/// List all supported protocol schemes
pub fn list_schemes() -> Vec<&'static str> {
    PROTOCOLS.iter().map(|p| p.scheme).collect()
}

/// Gopher client stub
pub mod gopher {
    use super::*;

    /// Gopher item types
    #[derive(Debug, Clone, Copy)]
    pub enum ItemType {
        TextFile,      // 0
        Directory,     // 1
        CsoServer,     // 2
        Error,         // 3
        BinHex,        // 4
        DosBinary,     // 5
        UuEncoded,     // 6
        IndexSearch,   // 7
        Telnet,        // 8
        Binary,        // 9
        Mirror,        // +
        Gif,           // g
        Image,         // I
        Html,          // h
        Info,          // i
        Sound,         // s
    }

    /// Gopher directory entry
    #[derive(Debug, Clone)]
    pub struct GopherEntry {
        pub item_type: ItemType,
        pub display: String,
        pub selector: String,
        pub host: String,
        pub port: u16,
    }

    /// Fetch a gopher URL
    pub async fn fetch(_url: &str) -> CfkResult<Vec<u8>> {
        // TODO: Implement gopher client
        Err(CfkError::Unsupported("Gopher client not yet implemented".into()))
    }

    /// Parse gopher directory listing
    pub fn parse_directory(_data: &[u8]) -> Vec<GopherEntry> {
        // TODO: Parse gopher menu format
        Vec::new()
    }
}

/// Gemini client stub
pub mod gemini {
    use super::*;

    /// Gemini response status
    #[derive(Debug, Clone, Copy)]
    pub enum Status {
        Input = 10,
        Success = 20,
        Redirect = 30,
        TemporaryFailure = 40,
        PermanentFailure = 50,
        ClientCertRequired = 60,
    }

    /// Fetch a gemini URL
    pub async fn fetch(_url: &str) -> CfkResult<(Status, String, Vec<u8>)> {
        // TODO: Implement gemini client with TLS
        Err(CfkError::Unsupported("Gemini client not yet implemented".into()))
    }
}

/// NNTP client stub
pub mod nntp {
    use super::*;

    /// NNTP article
    #[derive(Debug, Clone)]
    pub struct Article {
        pub message_id: String,
        pub subject: String,
        pub from: String,
        pub date: String,
        pub newsgroups: Vec<String>,
        pub body: String,
    }

    /// Connect to NNTP server
    pub async fn connect(_host: &str, _port: u16, _tls: bool) -> CfkResult<()> {
        Err(CfkError::Unsupported("NNTP client not yet implemented".into()))
    }

    /// List newsgroups
    pub async fn list_groups() -> CfkResult<Vec<String>> {
        Err(CfkError::Unsupported("NNTP client not yet implemented".into()))
    }
}
