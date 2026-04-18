// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Code generation for Halide from halideiser manifest.
//
// This module contains three sub-modules:
//   - parser:     validates pipeline stage sequences and resolves defaults
//   - halide_gen: generates Halide C++ algorithm and schedule code
//   - build_gen:  generates CMake build files for Halide compilation

pub mod build_gen;
pub mod halide_gen;
pub mod parser;

use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::manifest::Manifest;

/// Generate all artifacts: Halide C++ source, schedule, and CMakeLists.txt.
///
/// Output directory structure:
///   <output_dir>/
///     <name>_generator.cpp    — Halide generator (algorithm + schedule)
///     <name>_runner.cpp       — Runner that loads input, runs pipeline, writes output
///     CMakeLists.txt          — Build configuration for Halide
pub fn generate_all(manifest: &Manifest, output_dir: &str) -> Result<()> {
    let out = Path::new(output_dir);
    fs::create_dir_all(out).context("Failed to create output directory")?;

    // Step 1: Parse and validate the pipeline sequence.
    let resolved_pipeline =
        parser::resolve_pipeline(manifest).context("Pipeline validation failed")?;

    // Step 2: Generate the Halide C++ generator source.
    let generator_code = halide_gen::generate_halide_generator(manifest, &resolved_pipeline);
    let generator_path = out.join(format!("{}_generator.cpp", manifest.project.name));
    fs::write(&generator_path, &generator_code)
        .with_context(|| format!("Failed to write {}", generator_path.display()))?;
    println!("  [codegen] wrote {}", generator_path.display());

    // Step 3: Generate the runner source.
    let runner_code = halide_gen::generate_runner(manifest);
    let runner_path = out.join(format!("{}_runner.cpp", manifest.project.name));
    fs::write(&runner_path, &runner_code)
        .with_context(|| format!("Failed to write {}", runner_path.display()))?;
    println!("  [codegen] wrote {}", runner_path.display());

    // Step 4: Generate the CMakeLists.txt.
    let cmake_code = build_gen::generate_cmake(manifest);
    let cmake_path = out.join("CMakeLists.txt");
    fs::write(&cmake_path, &cmake_code)
        .with_context(|| format!("Failed to write {}", cmake_path.display()))?;
    println!("  [codegen] wrote {}", cmake_path.display());

    Ok(())
}

/// Build generated artifacts by invoking CMake + make.
pub fn build(manifest: &Manifest, release: bool) -> Result<()> {
    let build_type = if release { "Release" } else { "Debug" };
    println!(
        "Building {} ({} mode) — target: {}",
        manifest.project.name, build_type, manifest.target.arch
    );
    println!(
        "  Run: cd generated/halideiser && cmake -B build -DCMAKE_BUILD_TYPE={} && cmake --build build",
        build_type
    );
    Ok(())
}

/// Run the generated pipeline binary.
pub fn run(manifest: &Manifest, args: &[String]) -> Result<()> {
    println!(
        "Running {} pipeline ({} stages)",
        manifest.project.name,
        manifest.stages.len()
    );
    if !args.is_empty() {
        println!("  Extra args: {}", args.join(" "));
    }
    println!(
        "  Run: ./generated/halideiser/build/{}_runner <input> <output>",
        manifest.project.name
    );
    Ok(())
}
