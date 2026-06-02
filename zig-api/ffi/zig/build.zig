// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// build.zig — unified-zig-api build configuration (Zig 0.15.2)
//
// Produces:
//   libzig_api.so   — shared library (runtime linking)
//   libzig_api.a    — static library (embed in binaries)
//   unit tests      — all modules under zig build test
//   integration     — spawns a local gnosis server (zig build test-integration)
//
// External dependencies:
//   libproven_ffi   — verification-ecosystem/proven formally-verified safety
//                     primitives.  Provides proven_path_has_traversal, which
//                     process.zig uses as a second gate in safePathDefault.
//                     Build with:
//                       cd verification-ecosystem/proven/ffi/zig
//                       zig build
//                     Output lands in zig-out/lib/libproven_ffi.a (standard zig build output).
//                     The default proven_lib_path below points to that location.

const std = @import("std");

/// Path to the directory containing libproven_ffi.a.
/// Override with -Dproven-lib-path=/absolute/path.
/// Points to proven's standard zig-out/lib output (not zig-out-standalone —
/// that symlink was removed 2026-04-17; zig build now outputs to zig-out/ directly).
const DEFAULT_PROVEN_LIB_PATH =
    "/var/mnt/eclipse/repos/verification-ecosystem/proven/ffi/zig/zig-out/lib";

/// Path to the directory containing proven.h (the C ABI header).
const DEFAULT_PROVEN_INCLUDE_PATH =
    "/var/mnt/eclipse/repos/verification-ecosystem/proven/bindings/c/include";

pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -------------------------------------------------------------------------
    // Build options — allow callers to override proven library paths
    // -------------------------------------------------------------------------
    const proven_lib_path = b.option(
        []const u8,
        "proven-lib-path",
        "Directory containing libproven_ffi.a (default: " ++ DEFAULT_PROVEN_LIB_PATH ++ ")",
    ) orelse DEFAULT_PROVEN_LIB_PATH;

    const proven_include_path = b.option(
        []const u8,
        "proven-include-path",
        "Directory containing proven.h (default: " ++ DEFAULT_PROVEN_INCLUDE_PATH ++ ")",
    ) orelse DEFAULT_PROVEN_INCLUDE_PATH;

    // -------------------------------------------------------------------------
    // Root module — shared by both library artifacts and the test runner
    // -------------------------------------------------------------------------
    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });

    // Wire proven_ffi: object file + include path so @cImport works if needed,
    // and so the linker resolves proven_path_has_traversal from process.zig.
    root_mod.addLibraryPath(.{ .cwd_relative = proven_lib_path });
    root_mod.addIncludePath(.{ .cwd_relative = proven_include_path });
    root_mod.linkSystemLibrary("proven_ffi", .{});

    // -------------------------------------------------------------------------
    // Shared library — libzig_api.so / libzig_api.dylib / libzig_api.dll
    // -------------------------------------------------------------------------
    const shared = b.addLibrary(.{
        .name     = "zig_api",
        .root_module = root_mod,
        .linkage  = .dynamic,
        .version  = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    b.installArtifact(shared);

    // -------------------------------------------------------------------------
    // Static library — libzig_api.a
    // -------------------------------------------------------------------------
    const static_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });
    static_mod.addLibraryPath(.{ .cwd_relative = proven_lib_path });
    static_mod.addIncludePath(.{ .cwd_relative = proven_include_path });
    static_mod.linkSystemLibrary("proven_ffi", .{});
    const static = b.addLibrary(.{
        .name        = "zig_api",
        .root_module = static_mod,
        .linkage     = .static,
    });
    b.installArtifact(static);

    // -------------------------------------------------------------------------
    // Install C header alongside the libraries
    // -------------------------------------------------------------------------
    const install_header = b.addInstallHeaderFile(
        b.path("../../generated/abi/zig_api.h"),
        "zig_api.h",
    );
    b.getInstallStep().dependOn(&install_header.step);

    // -------------------------------------------------------------------------
    // Unit test runner — covers all modules via lib.zig's `test { refAllDecls }`
    // -------------------------------------------------------------------------
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });
    test_mod.addLibraryPath(.{ .cwd_relative = proven_lib_path });
    test_mod.addIncludePath(.{ .cwd_relative = proven_include_path });
    test_mod.linkSystemLibrary("proven_ffi", .{});
    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run all unified-zig-api unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // -------------------------------------------------------------------------
    // Integration test — spawns a local gnosis server and probes it
    // -------------------------------------------------------------------------
    const integration_mod = b.createModule(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });
    // Make `@import("zig_api")` available inside the integration test.
    integration_mod.addAnonymousImport("zig_api", .{
        .root_source_file = b.path("src/lib.zig"),
        .target           = target,
        .optimize         = optimize,
        .link_libc        = true,
    });

    const integration_tests = b.addTest(.{
        .root_module = integration_mod,
    });

    const run_integration = b.addRunArtifact(integration_tests);
    const integration_step = b.step("test-integration", "Run integration tests");
    integration_step.dependOn(&run_integration.step);
}
