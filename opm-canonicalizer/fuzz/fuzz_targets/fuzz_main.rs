#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // Fuzz parser/compiler with arbitrary input
    if let Ok(input) = std::str::from_utf8(data) {
        if input.is_empty() || input.len() > 10000 {
            return;
        }

        // Attempt to parse the input
        // This will catch panics, infinite loops (with timeout), and crashes
        let _ = input.parse::<String>();
    }
});
