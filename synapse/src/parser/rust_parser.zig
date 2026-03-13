// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Synapse Contributors
//
// SYNAPSE - Rust Struct Parser
// Parses Rust struct definitions marked with #[derive(Synapse)]
//
// This module extracts:
// - Struct names
// - Field names and types
// - Documentation comments
// - Visibility modifiers

const std = @import("std");

pub const RustType = enum {
    i8,
    i16,
    i32,
    i64,
    u8,
    u16,
    u32,
    u64,
    f32,
    f64,
    bool,
    String,
    Vec,
    Option,
    custom,

    pub fn toSwiftType(self: RustType) []const u8 {
        return switch (self) {
            .i8, .i16, .i32 => "Int32",
            .i64 => "Int64",
            .u8, .u16, .u32 => "UInt32",
            .u64 => "UInt64",
            .f32 => "Float",
            .f64 => "Double",
            .bool => "Bool",
            .String => "String",
            .Vec => "Array",
            .Option => "Optional",
            .custom => "Any", // Will be overridden with actual type name
        };
    }
};

pub const RustField = struct {
    name: []const u8,
    type_name: []const u8,
    rust_type: RustType,
    is_optional: bool = false,
    is_public: bool = true,
    doc_comment: ?[]const u8 = null,
    generic_param: ?[]const u8 = null, // For Vec<T>, Option<T>

    pub fn toSwiftType(self: RustField) []const u8 {
        if (self.rust_type == .custom) {
            return self.type_name;
        }
        return self.rust_type.toSwiftType();
    }
};

pub const RustStruct = struct {
    name: []const u8,
    fields: std.ArrayList(RustField),
    doc_comment: ?[]const u8 = null,
    is_public: bool = true,
    derives: std.ArrayList([]const u8),

    pub fn deinit(self: *RustStruct) void {
        // Free allocated derive strings
        for (self.derives.items) |derive| {
            self.derives.allocator.free(derive);
        }
        self.fields.deinit();
        self.derives.deinit();
    }

    pub fn hasSynapseDerive(self: RustStruct) bool {
        for (self.derives.items) |derive| {
            if (std.mem.eql(u8, derive, "Synapse") or
                std.mem.eql(u8, derive, "DriftUI") or
                std.mem.eql(u8, derive, "SwiftBridge"))
            {
                return true;
            }
        }
        return false;
    }
};

/// Parse Rust source code and extract structs marked with Synapse derive
pub fn parseRustStructs(content: []const u8, out_structs: *std.ArrayList(RustStruct), allocator: std.mem.Allocator) !void {
    var lines = std.mem.splitSequence(u8, content, "\n");
    var current_derives = std.ArrayList([]const u8).init(allocator);
    var current_doc: ?[]const u8 = null;
    var in_struct = false;
    var current_struct: ?RustStruct = null;
    var brace_depth: usize = 0;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Parse doc comments
        if (std.mem.startsWith(u8, trimmed, "///")) {
            const doc = std.mem.trim(u8, trimmed[3..], " ");
            current_doc = doc;
            continue;
        }

        // Parse derive attributes
        if (std.mem.startsWith(u8, trimmed, "#[derive(")) {
            try parseDerive(trimmed, &current_derives, allocator);
            continue;
        }

        // Parse struct declaration
        if (!in_struct and (std.mem.startsWith(u8, trimmed, "pub struct ") or std.mem.startsWith(u8, trimmed, "struct "))) {
            const is_pub = std.mem.startsWith(u8, trimmed, "pub ");
            const after_struct = if (is_pub)
                trimmed["pub struct ".len..]
            else
                trimmed["struct ".len..];

            // Extract struct name (until { or whitespace)
            var name_end: usize = 0;
            for (after_struct, 0..) |c, idx| {
                if (c == '{' or c == ' ' or c == '<') {
                    name_end = idx;
                    break;
                }
            }
            if (name_end == 0) name_end = after_struct.len;

            const struct_name = after_struct[0..name_end];

            // Check if this struct should be processed
            var should_process = false;
            for (current_derives.items) |derive| {
                if (std.mem.eql(u8, derive, "Synapse") or
                    std.mem.eql(u8, derive, "DriftUI") or
                    std.mem.eql(u8, derive, "SwiftBridge"))
                {
                    should_process = true;
                    break;
                }
            }

            if (should_process) {
                current_struct = RustStruct{
                    .name = struct_name,
                    .fields = std.ArrayList(RustField).init(allocator),
                    .doc_comment = current_doc,
                    .is_public = is_pub,
                    .derives = current_derives,
                };
                current_derives = std.ArrayList([]const u8).init(allocator);
                in_struct = true;
                brace_depth = 1;
            } else {
                // Free derive strings before clearing
                for (current_derives.items) |derive| {
                    allocator.free(derive);
                }
                current_derives.clearRetainingCapacity();
            }
            current_doc = null;
            continue;
        }

        // Parse struct fields
        if (in_struct) {
            // Track brace depth
            for (trimmed) |c| {
                if (c == '{') brace_depth += 1;
                if (c == '}') {
                    if (brace_depth > 0) brace_depth -= 1;
                }
            }

            // End of struct
            if (brace_depth == 0) {
                if (current_struct) |*s| {
                    try out_structs.append(s.*);
                }
                current_struct = null;
                in_struct = false;
                continue;
            }

            // Parse field
            if (current_struct) |*s| {
                if (try parseField(trimmed, allocator)) |field| {
                    try s.fields.append(field);
                }
            }
        }
    }

    // Clean up any remaining derives at end of file
    for (current_derives.items) |derive| {
        allocator.free(derive);
    }
    current_derives.deinit();
}

fn parseDerive(line: []const u8, derives: *std.ArrayList([]const u8), allocator: std.mem.Allocator) !void {
    // Find content between #[derive( and )]
    const start = std.mem.indexOf(u8, line, "(") orelse return;
    const end = std.mem.lastIndexOf(u8, line, ")") orelse return;

    if (start >= end) return;

    const content = line[start + 1 .. end];
    var parts = std.mem.splitSequence(u8, content, ",");

    while (parts.next()) |part| {
        const derive_name = std.mem.trim(u8, part, " \t");
        if (derive_name.len > 0) {
            // Copy the string to owned memory
            const owned = try allocator.dupe(u8, derive_name);
            try derives.append(owned);
        }
    }
}

fn parseField(line: []const u8, allocator: std.mem.Allocator) !?RustField {
    _ = allocator;

    // Skip empty lines, comments, closing braces
    if (line.len == 0 or
        std.mem.startsWith(u8, line, "//") or
        std.mem.startsWith(u8, line, "}") or
        std.mem.startsWith(u8, line, "{"))
    {
        return null;
    }

    // Check for pub modifier
    const is_pub = std.mem.startsWith(u8, line, "pub ");
    const field_start: usize = if (is_pub) 4 else 0;
    const field_line = line[field_start..];

    // Find the colon separator
    const colon_pos = std.mem.indexOf(u8, field_line, ":") orelse return null;

    // Extract field name
    const field_name = std.mem.trim(u8, field_line[0..colon_pos], " \t");
    if (field_name.len == 0) return null;

    // Extract type (until comma or end of line)
    var type_end = field_line.len;
    if (std.mem.indexOf(u8, field_line[colon_pos + 1 ..], ",")) |comma| {
        type_end = colon_pos + 1 + comma;
    }

    const type_str = std.mem.trim(u8, field_line[colon_pos + 1 .. type_end], " \t,");

    // Determine Rust type
    const rust_type = parseRustType(type_str);
    const is_optional = std.mem.startsWith(u8, type_str, "Option<");

    return RustField{
        .name = field_name,
        .type_name = type_str,
        .rust_type = rust_type,
        .is_optional = is_optional,
        .is_public = is_pub,
    };
}

fn parseRustType(type_str: []const u8) RustType {
    if (std.mem.eql(u8, type_str, "i8")) return .i8;
    if (std.mem.eql(u8, type_str, "i16")) return .i16;
    if (std.mem.eql(u8, type_str, "i32")) return .i32;
    if (std.mem.eql(u8, type_str, "i64")) return .i64;
    if (std.mem.eql(u8, type_str, "u8")) return .u8;
    if (std.mem.eql(u8, type_str, "u16")) return .u16;
    if (std.mem.eql(u8, type_str, "u32")) return .u32;
    if (std.mem.eql(u8, type_str, "u64")) return .u64;
    if (std.mem.eql(u8, type_str, "f32")) return .f32;
    if (std.mem.eql(u8, type_str, "f64")) return .f64;
    if (std.mem.eql(u8, type_str, "bool")) return .bool;
    if (std.mem.eql(u8, type_str, "String")) return .String;
    if (std.mem.startsWith(u8, type_str, "Vec<")) return .Vec;
    if (std.mem.startsWith(u8, type_str, "Option<")) return .Option;
    return .custom;
}

test "parse simple struct" {
    const allocator = std.testing.allocator;
    const source =
        \\#[derive(Synapse)]
        \\pub struct Player {
        \\    pub name: String,
        \\    pub score: i32,
        \\}
    ;

    var structs = std.ArrayList(RustStruct).init(allocator);
    defer {
        for (structs.items) |*s| s.deinit();
        structs.deinit();
    }

    try parseRustStructs(source, &structs, allocator);

    try std.testing.expectEqual(@as(usize, 1), structs.items.len);
    try std.testing.expectEqualStrings("Player", structs.items[0].name);
}
