//! Platform-specific abstractions
//!
//! Supports: Linux, macOS, Windows, iOS, Android, Minix, z/OS, RISC-V


/// Platform capabilities
#[derive(Debug, Clone)]
pub struct PlatformCapabilities {
    pub fuse_available: bool,
    pub async_io: bool,
    pub file_watching: bool,
    pub symlinks: bool,
    pub hard_links: bool,
    pub extended_attributes: bool,
    pub sparse_files: bool,
    pub memory_mapping: bool,
}

impl PlatformCapabilities {
    pub fn detect() -> Self {
        #[cfg(target_os = "linux")]
        return Self::linux();

        #[cfg(target_os = "macos")]
        return Self::macos();

        #[cfg(target_os = "windows")]
        return Self::windows();

        #[cfg(target_os = "ios")]
        return Self::ios();

        #[cfg(target_os = "android")]
        return Self::android();

        #[cfg(not(any(
            target_os = "linux",
            target_os = "macos",
            target_os = "windows",
            target_os = "ios",
            target_os = "android"
        )))]
        return Self::minimal();
    }

    pub fn linux() -> Self {
        Self {
            fuse_available: true,
            async_io: true,
            file_watching: true,
            symlinks: true,
            hard_links: true,
            extended_attributes: true,
            sparse_files: true,
            memory_mapping: true,
        }
    }

    pub fn macos() -> Self {
        Self {
            fuse_available: true,  // via macFUSE
            async_io: true,
            file_watching: true,
            symlinks: true,
            hard_links: true,
            extended_attributes: true,
            sparse_files: true,
            memory_mapping: true,
        }
    }

    pub fn windows() -> Self {
        Self {
            fuse_available: true,  // via WinFsp
            async_io: true,
            file_watching: true,
            symlinks: true,  // requires admin or dev mode
            hard_links: true,
            extended_attributes: false,  // different model (ADS)
            sparse_files: true,
            memory_mapping: true,
        }
    }

    pub fn ios() -> Self {
        Self {
            fuse_available: false,
            async_io: true,
            file_watching: false,
            symlinks: false,
            hard_links: false,
            extended_attributes: false,
            sparse_files: false,
            memory_mapping: true,
        }
    }

    pub fn android() -> Self {
        Self {
            fuse_available: false,  // root only
            async_io: true,
            file_watching: true,
            symlinks: true,
            hard_links: false,
            extended_attributes: false,
            sparse_files: false,
            memory_mapping: true,
        }
    }

    pub fn minimal() -> Self {
        Self {
            fuse_available: false,
            async_io: false,
            file_watching: false,
            symlinks: false,
            hard_links: false,
            extended_attributes: false,
            sparse_files: false,
            memory_mapping: false,
        }
    }
}

/// z/OS dataset path conversion
pub mod zos {
    /// Convert VirtualPath to z/OS dataset name
    /// cfk://zos/SYS1/PARMLIB/IEASYS00 → SYS1.PARMLIB(IEASYS00)
    pub fn to_dataset_name(segments: &[String]) -> String {
        if segments.is_empty() {
            return String::new();
        }

        let mut parts = segments.to_vec();
        if let Some(member) = parts.pop() {
            if parts.is_empty() {
                member
            } else {
                format!("{}({})", parts.join("."), member)
            }
        } else {
            String::new()
        }
    }

    /// Convert z/OS dataset name to path segments
    pub fn from_dataset_name(dsn: &str) -> Vec<String> {
        if let Some((prefix, member)) = dsn.rsplit_once('(') {
            let member = member.trim_end_matches(')');
            let mut segments: Vec<String> = prefix.split('.').map(String::from).collect();
            segments.push(member.to_string());
            segments
        } else {
            dsn.split('.').map(String::from).collect()
        }
    }
}

/// EBCDIC/ASCII transcoding for z/OS
pub mod encoding {
    /// Simple EBCDIC to ASCII (US EBCDIC code page 037)
    pub fn ebcdic_to_ascii(input: &[u8]) -> Vec<u8> {
        input.iter().map(|&b| EBCDIC_TO_ASCII[b as usize]).collect()
    }

    /// Simple ASCII to EBCDIC
    pub fn ascii_to_ebcdic(input: &[u8]) -> Vec<u8> {
        input.iter().map(|&b| ASCII_TO_EBCDIC[b as usize]).collect()
    }

    // EBCDIC code page 037 to ASCII mapping (simplified)
    static EBCDIC_TO_ASCII: [u8; 256] = [
        0x00, 0x01, 0x02, 0x03, 0x9C, 0x09, 0x86, 0x7F, // 0x00-0x07
        0x97, 0x8D, 0x8E, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, // 0x08-0x0F
        0x10, 0x11, 0x12, 0x13, 0x9D, 0x85, 0x08, 0x87, // 0x10-0x17
        0x18, 0x19, 0x92, 0x8F, 0x1C, 0x1D, 0x1E, 0x1F, // 0x18-0x1F
        0x80, 0x81, 0x82, 0x83, 0x84, 0x0A, 0x17, 0x1B, // 0x20-0x27
        0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x05, 0x06, 0x07, // 0x28-0x2F
        0x90, 0x91, 0x16, 0x93, 0x94, 0x95, 0x96, 0x04, // 0x30-0x37
        0x98, 0x99, 0x9A, 0x9B, 0x14, 0x15, 0x9E, 0x1A, // 0x38-0x3F
        0x20, 0xA0, 0xE2, 0xE4, 0xE0, 0xE1, 0xE3, 0xE5, // 0x40-0x47
        0xE7, 0xF1, 0xA2, 0x2E, 0x3C, 0x28, 0x2B, 0x7C, // 0x48-0x4F
        0x26, 0xE9, 0xEA, 0xEB, 0xE8, 0xED, 0xEE, 0xEF, // 0x50-0x57
        0xEC, 0xDF, 0x21, 0x24, 0x2A, 0x29, 0x3B, 0xAC, // 0x58-0x5F
        0x2D, 0x2F, 0xC2, 0xC4, 0xC0, 0xC1, 0xC3, 0xC5, // 0x60-0x67
        0xC7, 0xD1, 0xA6, 0x2C, 0x25, 0x5F, 0x3E, 0x3F, // 0x68-0x6F
        0xF8, 0xC9, 0xCA, 0xCB, 0xC8, 0xCD, 0xCE, 0xCF, // 0x70-0x77
        0xCC, 0x60, 0x3A, 0x23, 0x40, 0x27, 0x3D, 0x22, // 0x78-0x7F
        // ... continuing would fill all 256 bytes
        0xD8, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
        0x68, 0x69, 0xAB, 0xBB, 0xF0, 0xFD, 0xFE, 0xB1,
        0xB0, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70,
        0x71, 0x72, 0xAA, 0xBA, 0xE6, 0xB8, 0xC6, 0xA4,
        0xB5, 0x7E, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
        0x79, 0x7A, 0xA1, 0xBF, 0xD0, 0xDD, 0xDE, 0xAE,
        0x5E, 0xA3, 0xA5, 0xB7, 0xA9, 0xA7, 0xB6, 0xBC,
        0xBD, 0xBE, 0x5B, 0x5D, 0xAF, 0xA8, 0xB4, 0xD7,
        0x7B, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
        0x48, 0x49, 0xAD, 0xF4, 0xF6, 0xF2, 0xF3, 0xF5,
        0x7D, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50,
        0x51, 0x52, 0xB9, 0xFB, 0xFC, 0xF9, 0xFA, 0xFF,
        0x5C, 0xF7, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
        0x59, 0x5A, 0xB2, 0xD4, 0xD6, 0xD2, 0xD3, 0xD5,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
        0x38, 0x39, 0xB3, 0xDB, 0xDC, 0xD9, 0xDA, 0x9F,
    ];

    // ASCII to EBCDIC (inverse mapping)
    static ASCII_TO_EBCDIC: [u8; 256] = {
        let mut table = [0x3Fu8; 256];  // Default to '?'
        let mut i = 0;
        while i < 256 {
            let ascii_val = EBCDIC_TO_ASCII[i];
            table[ascii_val as usize] = i as u8;
            i += 1;
        }
        table
    };
}
