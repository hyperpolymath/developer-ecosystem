// SPDX-License-Identifier: MPL-2.0
//
// Keep only explicitly selected Dependabot ecosystems after project minting.
//
// Ported from prune-dependabot-ecosystems.rb: Ruby is not an estate-authorised
// language, and this runs on every mint. Single file, std only, no
// dependencies — compiled on demand by `just repo-init` (see the rust_tool
// helper in build/just/repo-init.just).
//
// Two rules that are easy to get wrong and are load-bearing:
//
//   * Nix is not a valid Dependabot ecosystem, so it is dropped from the
//     keep-list rather than matched against entries.
//   * Pruning to an EMPTY updates list is refused. A dependabot.yml with no
//     ecosystems is worse than one with unused entries: it silently stops
//     watching everything. Refusing is the safe failure.
//
// Usage: prune-dependabot-ecosystems.rs <file> <keep...>

use std::env;
use std::fs;
use std::path::Path;

/// True for a line that begins a new `updates:` entry, i.e. matches
/// `^[ \t]*-[ \t]*package-ecosystem:`.
fn is_entry_start(line: &str) -> bool {
    let t = line.trim_start_matches(|c| c == ' ' || c == '\t');
    let t = match t.strip_prefix('-') {
        Some(t) => t,
        None => return false,
    };
    t.trim_start_matches(|c| c == ' ' || c == '\t')
        .starts_with("package-ecosystem:")
}

/// Extract the ecosystem name from one entry: `package-ecosystem: "cargo"`.
fn ecosystem_name(entry: &str) -> String {
    let needle = "package-ecosystem:";
    match entry.find(needle) {
        Some(p) => {
            let rest = &entry[p + needle.len()..];
            let rest = rest.trim_start_matches(|c| c == ' ' || c == '\t');
            let rest = rest.trim_start_matches(|c| c == '\'' || c == '"');
            rest.chars()
                .take_while(|c| c.is_ascii_alphabetic() || *c == '-')
                .collect()
        }
        None => "?".to_string(),
    }
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("Usage: prune-dependabot-ecosystems.rs <file> <keep...>");
        std::process::exit(1);
    }
    let path = &args[0];

    // Nix is not a Dependabot ecosystem; keeping it would match nothing and
    // could only ever produce an empty keep-list.
    let keep: Vec<&str> = args[1..]
        .iter()
        .map(|s| s.as_str())
        .filter(|s| *s != "nix")
        .collect();

    if !Path::new(path).is_file() {
        println!("  dependabot: {} absent, nothing to prune", path);
        return;
    }

    let text = match fs::read_to_string(path) {
        Ok(t) => t,
        Err(_) => return,
    };

    // Split the document at each entry start, keeping the preamble separate.
    // `split_inclusive` retains the newline, so re-joining is byte-exact for
    // anything we do not drop.
    let mut head = String::new();
    let mut entries: Vec<String> = Vec::new();
    for line in text.split_inclusive('\n') {
        if is_entry_start(line) {
            entries.push(String::new());
        }
        match entries.last_mut() {
            Some(e) => e.push_str(line),
            None => head.push_str(line),
        }
    }

    if entries.is_empty() {
        println!("  dependabot: no ecosystem entries found");
        return;
    }

    let mut kept: Vec<String> = Vec::new();
    let mut kept_names: Vec<String> = Vec::new();
    let mut dropped_names: Vec<String> = Vec::new();

    for entry in &entries {
        let name = ecosystem_name(entry);
        if keep.contains(&name.as_str()) {
            kept_names.push(name);
            kept.push(entry.clone());
        } else {
            dropped_names.push(name);
        }
    }

    if kept.is_empty() {
        println!("  dependabot: refusing to prune every entry; left unchanged");
        return;
    }
    if dropped_names.is_empty() {
        println!("  dependabot: nothing to prune");
        return;
    }

    let mut out = head;
    for k in &kept {
        out.push_str(k);
    }
    if fs::write(path, out).is_err() {
        return;
    }
    println!(
        "  dependabot: kept {} / dropped {}",
        kept_names.join(", "),
        dropped_names.join(", ")
    );
}
