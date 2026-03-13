// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Synapse Contributors
//
// SYNAPSE - Rust-to-SwiftUI Meta-Compiler
// A Zig-based code generator that bridges the Rust↔Swift divide
//
// Philosophy: You describe the "World" in Rust, the "Interface" appears on iPhone.
// When Apple changes SwiftUI syntax, update templates here - not 50 files manually.
//
// USAGE:
//   zig build run -- --input rust_structs.rs --output Generated.swift
//   OR: just gen-ui

const std = @import("std");
const types = @import("types");
const parser = @import("parser");
const templates = @import("templates");

pub const SynapseConfig = types.SynapseConfig;
pub const GeneratedOutput = types.GeneratedOutput;

/// Main entry point for the Synapse generator
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = SynapseConfig{
        .input_path = "examples/rust/models.rs",
        .output_path = "examples/swift/Generated.swift",
    };

    // Parse arguments
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--input") and i + 1 < args.len) {
            config.input_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            config.output_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--ios")) {
            if (i + 1 < args.len) {
                config.ios_version = std.fmt.parseInt(u8, args[i + 1], 10) catch 17;
                i += 1;
            }
        } else if (std.mem.eql(u8, args[i], "--no-previews")) {
            config.generate_previews = false;
        } else if (std.mem.eql(u8, args[i], "--legacy-observable")) {
            config.use_observable = false;
        } else if (std.mem.eql(u8, args[i], "--help")) {
            try printHelp();
            return;
        }
    }

    // Run the generator
    try generateSwiftBindings(allocator, config);
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\SYNAPSE - Rust-to-SwiftUI Meta-Compiler
        \\
        \\Usage: synapse [OPTIONS]
        \\
        \\Options:
        \\  --input <path>       Input Rust file with struct definitions
        \\  --output <path>      Output Swift file path
        \\  --ios <version>      Target iOS version (default: 17)
        \\  --no-previews        Skip generating SwiftUI previews
        \\  --legacy-observable  Use @ObservedObject instead of @Observable
        \\  --help               Show this help message
        \\
        \\Example:
        \\  synapse --input src/models.rs --output ios/Generated.swift --ios 17
        \\
    , .{});
}

/// Core generation logic
pub fn generateSwiftBindings(allocator: std.mem.Allocator, config: SynapseConfig) !void {
    const stdout = std.io.getStdOut().writer();

    // Read input file
    const input_file = std.fs.cwd().openFile(config.input_path, .{}) catch |err| {
        try stdout.print("Error: Could not open input file '{s}': {}\n", .{ config.input_path, err });
        return;
    };
    defer input_file.close();

    const file_size = try input_file.getEndPos();
    const content = try allocator.alloc(u8, file_size);
    defer allocator.free(content);
    _ = try input_file.readAll(content);

    // Parse Rust structs
    var structs = std.ArrayList(parser.RustStruct).init(allocator);
    defer {
        // Clean up each struct's fields and derives before deiniting the list
        for (structs.items) |*s| {
            s.deinit();
        }
        structs.deinit();
    }

    try parser.parseRustStructs(content, &structs, allocator);

    if (structs.items.len == 0) {
        try stdout.print("Warning: No structs marked with #[derive(Synapse)] found in '{s}'\n", .{config.input_path});
        return;
    }

    // Generate Swift code
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    const writer = output.writer();

    // Write header
    try templates.writeHeader(writer, config);

    // Generate ViewModel for each struct
    for (structs.items) |rust_struct| {
        try templates.generateViewModel(writer, rust_struct, config);
    }

    // Generate previews if enabled
    if (config.generate_previews) {
        try templates.generatePreviews(writer, structs.items, config);
    }

    // Write output file
    const output_file = try std.fs.cwd().createFile(config.output_path, .{});
    defer output_file.close();
    try output_file.writeAll(output.items);

    try stdout.print("✓ Synapse generated {d} ViewModels → {s}\n", .{ structs.items.len, config.output_path });
    try stdout.print("  iOS {d}+ compliant, using {s}\n", .{
        config.ios_version,
        if (config.use_observable) "@Observable" else "@ObservedObject (legacy)",
    });
}

test "basic generation" {
    // Test that basic generation works
    const allocator = std.testing.allocator;
    _ = allocator;
}
