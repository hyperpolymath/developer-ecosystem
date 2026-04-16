// SPDX-License-Identifier: PMPL-1.0-or-later
// build.zig -- Build configuration for IDApTIK UMS Zig FFI shared library.
// Author: Jonathan D.A. Jewell
//
// Produces `libidaptik_ums` as a shared (.so / .dylib / .dll) and static (.a)
// library exposing the C-compatible FFI surface defined by the Idris2 ABI
// modules in `../../src/abi/`.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -- Shared modules used by both library targets and tests --

    const types_mod = b.addModule("types", .{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    const validate_mod = b.addModule("validate", .{
        .root_source_file = b.path("src/validate.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // ---------------------------------------------------------------
    // Shared library: libidaptik_ums
    // ---------------------------------------------------------------
    const shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "idaptik_ums",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "validate", .module = validate_mod },
            },
        }),
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    b.installArtifact(shared_lib);

    // ---------------------------------------------------------------
    // Static library (for embedding in Gossamer / Dioxus / Rust hosts)
    // ---------------------------------------------------------------
    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "idaptik_ums",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "validate", .module = validate_mod },
            },
        }),
    });
    b.installArtifact(static_lib);

    // ---------------------------------------------------------------
    // Main module (for test imports)
    // ---------------------------------------------------------------
    const main_mod = b.addModule("main", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "validate", .module = validate_mod },
        },
    });

    // ---------------------------------------------------------------
    // Integration tests
    // ---------------------------------------------------------------
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/integration_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "validate", .module = validate_mod },
                .{ .name = "main", .module = main_mod },
            },
        }),
    });

    const run_tests = b.addRunArtifact(integration_tests);
    const test_step = b.step("test", "Run IDApTIK UMS FFI integration tests");
    test_step.dependOn(&run_tests.step);
}
