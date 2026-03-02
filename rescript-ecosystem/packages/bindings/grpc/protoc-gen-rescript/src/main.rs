// SPDX-License-Identifier: MPL-2.0
//! protoc-gen-rescript: Protocol Buffer compiler plugin for ReScript
//!
//! This plugin reads a CodeGeneratorRequest from stdin and writes a
//! CodeGeneratorResponse to stdout, generating ReScript types and
//! optional WASM codec bindings.

use std::io::{self, Read, Write};

use anyhow::{Context, Result};
use bytes::Bytes;
use prost::Message;

mod generator;
mod templates;

use generator::Generator;

/// Plugin options parsed from --rescript_opt=...
#[derive(Debug, Default)]
pub struct Options {
    /// Generate WASM codec bindings (default: false, types only)
    pub wasm: bool,
    /// Output directory for generated .res files
    pub out_dir: Option<String>,
    /// Generate gRPC service stubs
    pub grpc: bool,
    /// Use @rescript/core instead of Js.* bindings
    pub use_core: bool,
}

impl Options {
    fn parse(parameter: &str) -> Self {
        let mut opts = Options::default();
        for part in parameter.split(',') {
            let part = part.trim();
            match part {
                "wasm" => opts.wasm = true,
                "grpc" => opts.grpc = true,
                "core" => opts.use_core = true,
                _ if part.starts_with("out=") => {
                    opts.out_dir = Some(part[4..].to_string());
                }
                _ => {} // Ignore unknown options
            }
        }
        opts
    }
}

fn main() -> Result<()> {
    // Read CodeGeneratorRequest from stdin
    let mut input = Vec::new();
    io::stdin()
        .read_to_end(&mut input)
        .context("Failed to read from stdin")?;

    let request = prost_types::compiler::CodeGeneratorRequest::decode(Bytes::from(input))
        .context("Failed to parse CodeGeneratorRequest")?;

    // Parse options
    let options = Options::parse(request.parameter.as_deref().unwrap_or(""));

    // Generate code
    let generator = Generator::new(options);
    let response = generator.generate(&request)?;

    // Write CodeGeneratorResponse to stdout
    let mut output = Vec::new();
    response
        .encode(&mut output)
        .context("Failed to encode CodeGeneratorResponse")?;

    io::stdout()
        .write_all(&output)
        .context("Failed to write to stdout")?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_options() {
        let opts = Options::parse("wasm,grpc,out=./gen");
        assert!(opts.wasm);
        assert!(opts.grpc);
        assert_eq!(opts.out_dir, Some("./gen".to_string()));
    }

    #[test]
    fn test_parse_empty_options() {
        let opts = Options::parse("");
        assert!(!opts.wasm);
        assert!(!opts.grpc);
        assert!(opts.out_dir.is_none());
    }
}
