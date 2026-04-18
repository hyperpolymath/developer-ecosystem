// SPDX-License-Identifier: AGPL-3.0-or-later
//! Fuzz target for VirtualPath parsing and manipulation

#![no_main]

use libfuzzer_sys::fuzz_target;
use cfk_core::path::VirtualPath;

fuzz_target!(|data: &[u8]| {
    // Convert bytes to string for path operations
    if let Ok(input) = std::str::from_utf8(data) {
        // Fuzz URI parsing
        let _ = VirtualPath::parse_uri(input);

        // Fuzz path construction and manipulation
        if let Some((backend, path)) = input.split_once('/') {
            let vpath = VirtualPath::new(backend, path);

            // Exercise various operations
            let _ = vpath.to_uri();
            let _ = vpath.to_path_string();
            let _ = vpath.name();
            let _ = vpath.extension();
            let _ = vpath.parent();
            let _ = vpath.is_root();

            // Fuzz join with remaining data
            if input.len() > 10 {
                let _ = vpath.join(&input[..10]);
            }
        }
    }
});
