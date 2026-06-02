// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// main.rs — CLI entry point for opm-canonicalizer.
// Reads JSON from stdin, emits canonical form to stdout.

#![forbid(unsafe_code)]

use opm_canonicalizer::canonicalize;
use std::io::{self, Read};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    let out = canonicalize(&input).map_err(|e| e)?;
    println!("{out}");
    Ok(())
}
