// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Synapse Contributors
//
// SYNAPSE - Shared Types Module
// Contains types used across multiple modules to avoid circular imports

pub const SynapseConfig = struct {
    input_path: []const u8,
    output_path: []const u8,
    ios_version: u8 = 17, // Default to iOS 17+ compliance
    generate_previews: bool = true,
    use_observable: bool = true, // iOS 17 @Observable vs legacy @ObservedObject
};

pub const GeneratedOutput = struct {
    swift_code: []const u8,
    struct_count: usize,
    warnings: @import("std").ArrayList([]const u8),
};
