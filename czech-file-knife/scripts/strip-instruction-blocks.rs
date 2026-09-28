// SPDX-License-Identifier: MPL-2.0
//
// Remove only HTML comments containing TEMPLATE INSTRUCTIONS after minting.
//
// Ported from strip-instruction-blocks.rb: Ruby is not an estate-authorised
// language, and this runs on every mint. Single file, std only, no
// dependencies — compiled on demand by `just repo-init` (see the rust_tool
// helper in build/just/repo-init.just).
//
// The match is deliberately tempered: an HTML comment is only removed when the
// marker appears BEFORE its own `-->`, so a block cannot swallow the
// terminator of a preceding comment. That is what keeps an SPDX comment that
// sits immediately above an instructions block intact.
//
// Usage: strip-instruction-blocks.rs [ROOT]        (default ROOT = .)

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const MARKER: &str = "TEMPLATE INSTRUCTIONS";
const OPEN: &str = "<!--";
const CLOSE: &str = "-->";

/// Directories never descended into. Mirrors the Ruby original.
const SKIP_DIRS: [&str; 5] = [".git", "node_modules", ".venv", "target", "dist"];

/// Remove every HTML comment whose body contains MARKER, then collapse runs of
/// three or more newlines to two.
///
/// Indexing is by byte, which is safe because every boundary we slice at is an
/// ASCII delimiter (`<!--`, `-->`); a multi-byte character can never be split.
fn strip_blocks(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut out = String::with_capacity(text.len());
    let mut i = 0usize;

    while i < bytes.len() {
        let start = match find_from(text, OPEN, i) {
            Some(p) => p,
            None => {
                out.push_str(&text[i..]);
                break;
            }
        };
        // Everything before this comment is copied verbatim.
        out.push_str(&text[i..start]);

        let end = match find_from(text, CLOSE, start + OPEN.len()) {
            Some(p) => p,
            // Unterminated comment: not ours to touch.
            None => {
                out.push_str(&text[start..]);
                break;
            }
        };

        let body = &text[start + OPEN.len()..end];
        if body.contains(MARKER) {
            // Drop the comment, plus trailing horizontal space, plus one
            // newline, so a removed block does not leave a blank line behind.
            let mut j = end + CLOSE.len();
            while j < bytes.len() && (bytes[j] == b' ' || bytes[j] == b'\t') {
                j += 1;
            }
            if j < bytes.len() && bytes[j] == b'\n' {
                j += 1;
            }
            i = j;
        } else {
            // A comment without the marker is preserved exactly.
            out.push_str(&text[start..end + CLOSE.len()]);
            i = end + CLOSE.len();
        }
    }

    collapse_blank_runs(&out)
}

fn find_from(haystack: &str, needle: &str, from: usize) -> Option<usize> {
    haystack[from..].find(needle).map(|p| from + p)
}

/// Ruby's `gsub(/\n{3,}/, "\n\n")`: three or more newlines become two.
fn collapse_blank_runs(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut run = 0usize;
    for ch in s.chars() {
        if ch == '\n' {
            run += 1;
            if run <= 2 {
                out.push(ch);
            }
        } else {
            run = 0;
            out.push(ch);
        }
    }
    out
}

fn process(path: &Path, changed: &mut usize) {
    let bytes = match fs::read(path) {
        Ok(b) => b,
        Err(_) => return,
    };
    // Non-UTF-8 and unreadable files are skipped, never rewritten blind.
    let text = match String::from_utf8(bytes) {
        Ok(t) => t,
        Err(_) => return,
    };
    if !text.contains(MARKER) {
        return;
    }
    let updated = strip_blocks(&text);
    if updated == text {
        return;
    }
    if fs::write(path, updated).is_err() {
        return;
    }
    println!("  instruction block: stripped from {}", path.display());
    *changed += 1;
}

fn walk(root: &Path, changed: &mut usize) {
    // Explicit stack rather than recursion: deep trees must not blow the stack.
    let mut stack: Vec<PathBuf> = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let entries = match fs::read_dir(&dir) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let ft = match entry.file_type() {
                Ok(ft) => ft,
                Err(_) => continue,
            };
            if ft.is_symlink() {
                continue;
            }
            if ft.is_dir() {
                let skip = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .map(|n| SKIP_DIRS.contains(&n))
                    .unwrap_or(false);
                if skip {
                    continue;
                }
                stack.push(path);
                continue;
            }
            if ft.is_file() {
                process(&path, changed);
            }
        }
    }
}

fn main() {
    let root = env::args().nth(1).unwrap_or_else(|| ".".to_string());
    let mut changed = 0usize;
    walk(Path::new(&root), &mut changed);
    if changed > 0 {
        println!("  instruction blocks: {} file(s) cleaned", changed);
    } else {
        println!("  instruction blocks: none found");
    }
}
