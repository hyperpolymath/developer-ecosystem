// SafeDOM FFI Implementation
//
// This module implements the C-compatible FFI declared in src/abi/Foreign.idr
// All types and layouts must match the Idris2 ABI definitions.
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// @author Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

const std = @import("std");

// Version information
const VERSION = "1.0.0";
const ABI_VERSION: u32 = 1;

//==============================================================================
// Result Codes (must match src/abi/Types.idr)
//==============================================================================

const ValidationResult = enum(c_uint) {
    valid = 0,
    empty = 1,
    too_long = 2,
    invalid_chars = 3,
};

const HTMLValidationResult = enum(c_uint) {
    valid = 0,
    too_large = 1,
    unbalanced_tags = 2,
};

const MountResult = enum(c_uint) {
    success = 0,
    null_element = 1,
    mount_failed = 2,
};

//==============================================================================
// CSS Selector Validation
//==============================================================================

/// Validate a CSS selector
/// Returns: 0 = valid, 1 = empty, 2 = too long, 3 = invalid chars
export fn safedom_validate_selector(selector: [*:0]const u8, len: c_uint) c_uint {
    if (len == 0) {
        return @intFromEnum(ValidationResult.empty);
    }

    if (len > 255) {
        return @intFromEnum(ValidationResult.too_long);
    }

    const slice = selector[0..len];

    // Valid CSS selector characters: alphanumeric, hyphen, underscore, hash,
    // dot, space, brackets, colon, parens, greater, tilde, plus, equals
    for (slice) |c| {
        const is_alphanum = (c >= 'a' and c <= 'z') or
                           (c >= 'A' and c <= 'Z') or
                           (c >= '0' and c <= '9');
        const is_special = c == '-' or c == '_' or c == '#' or c == '.' or
                          c == ' ' or c == '[' or c == ']' or c == ':' or
                          c == '(' or c == ')' or c == '>' or c == '~' or
                          c == '+' or c == '=';

        if (!is_alphanum and !is_special) {
            return @intFromEnum(ValidationResult.invalid_chars);
        }
    }

    return @intFromEnum(ValidationResult.valid);
}

//==============================================================================
// HTML Validation
//==============================================================================

/// Count occurrences of a pattern in a string
fn countPattern(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;

    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i..i + needle.len], needle)) {
            count += 1;
        }
    }

    return count;
}

/// Simple check for balanced HTML tags
/// This is a basic heuristic - more sophisticated parsing would be needed for production
fn areTagsBalanced(html: []const u8) bool {
    var open_count: usize = 0;
    var close_count: usize = 0;
    var self_closing_count: usize = 0;
    var i: usize = 0;

    while (i < html.len) : (i += 1) {
        if (html[i] == '<') {
            // Check if it's a closing tag
            if (i + 1 < html.len and html[i + 1] == '/') {
                close_count += 1;
                // Skip to end of tag
                while (i < html.len and html[i] != '>') : (i += 1) {}
            } else {
                // Opening tag or self-closing
                var is_self_closing = false;
                const tag_start = i;
                while (i < html.len and html[i] != '>') : (i += 1) {
                    if (html[i] == '/' and i + 1 < html.len and html[i + 1] == '>') {
                        is_self_closing = true;
                    }
                }
                if (is_self_closing) {
                    self_closing_count += 1;
                } else {
                    // Check it's not a comment or doctype
                    if (tag_start + 1 < html.len and html[tag_start + 1] != '!') {
                        open_count += 1;
                    }
                }
            }
        }
    }

    // Balanced: (open - self_closing) == close
    if (open_count >= self_closing_count) {
        return (open_count - self_closing_count) == close_count;
    }
    return false;
}

/// Validate HTML content
/// Returns: 0 = valid, 1 = too large, 2 = unbalanced tags
export fn safedom_validate_html(html: [*:0]const u8, len: c_uint) c_uint {
    if (len > 1048576) {  // 1MB limit
        return @intFromEnum(HTMLValidationResult.too_large);
    }

    if (len == 0) {
        // Empty HTML is valid
        return @intFromEnum(HTMLValidationResult.valid);
    }

    const slice = html[0..len];

    // Check tag balance
    if (!areTagsBalanced(slice)) {
        return @intFromEnum(HTMLValidationResult.unbalanced_tags);
    }

    return @intFromEnum(HTMLValidationResult.valid);
}

//==============================================================================
// DOM Element Finding (Stub - requires actual DOM API)
//==============================================================================

/// Find DOM element by selector
/// Returns: element pointer (0 = not found)
///
/// NOTE: This is a stub implementation. In a real system, this would:
/// 1. Interface with a browser's DOM implementation
/// 2. Call document.querySelector(selector)
/// 3. Return the actual element pointer
///
/// For now, we return a mock pointer for validation purposes
export fn safedom_find_element(selector: [*:0]const u8) c_ulong {
    // Stub: In production, this would call into browser DOM API
    // For now, return a non-null mock pointer if selector is valid
    const len = std.mem.len(selector);
    const validation = safedom_validate_selector(selector, @intCast(len));

    if (validation == @intFromEnum(ValidationResult.valid)) {
        // Return a mock non-null pointer (would be real DOM element in production)
        return 0x1000;  // Mock pointer
    }

    return 0;  // Not found
}

//==============================================================================
// DOM Mounting (Stub - requires actual DOM API)
//==============================================================================

/// Mount HTML content to DOM element
/// Returns: 0 = success, 1 = null element, 2 = mount failed
///
/// NOTE: This is a stub implementation. In a real system, this would:
/// 1. Verify element is non-null
/// 2. Set element.innerHTML = html
/// 3. Handle any errors
export fn safedom_mount(element: c_ulong, html: [*:0]const u8) c_uint {
    if (element == 0) {
        return @intFromEnum(MountResult.null_element);
    }

    const len = std.mem.len(html);
    const validation = safedom_validate_html(html, @intCast(len));

    if (validation != @intFromEnum(HTMLValidationResult.valid)) {
        return @intFromEnum(MountResult.mount_failed);
    }

    // Stub: In production, this would:
    // ((DOMElement*)element)->innerHTML = html;

    return @intFromEnum(MountResult.success);
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library version
export fn safedom_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get ABI version
export fn safedom_abi_version() c_uint {
    return ABI_VERSION;
}

//==============================================================================
// Tests
//==============================================================================

test "selector validation" {
    // Valid selectors
    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.valid),
        safedom_validate_selector("#app", 4)
    );

    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.valid),
        safedom_validate_selector(".container", 10)
    );

    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.valid),
        safedom_validate_selector("div > p", 7)
    );

    // Invalid selectors
    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.empty),
        safedom_validate_selector("", 0)
    );

    const long_selector = "a" ** 256;
    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.too_long),
        safedom_validate_selector(long_selector.ptr, 256)
    );

    try std.testing.expectEqual(
        @intFromEnum(ValidationResult.invalid_chars),
        safedom_validate_selector("#app<script>", 12)
    );
}

test "HTML validation" {
    // Valid HTML
    try std.testing.expectEqual(
        @intFromEnum(HTMLValidationResult.valid),
        safedom_validate_html("", 0)
    );

    try std.testing.expectEqual(
        @intFromEnum(HTMLValidationResult.valid),
        safedom_validate_html("<div>test</div>", 15)
    );

    try std.testing.expectEqual(
        @intFromEnum(HTMLValidationResult.valid),
        safedom_validate_html("<img src='x' />", 15)
    );

    // Invalid HTML
    try std.testing.expectEqual(
        @intFromEnum(HTMLValidationResult.unbalanced_tags),
        safedom_validate_html("<div>test", 9)
    );

    try std.testing.expectEqual(
        @intFromEnum(HTMLValidationResult.unbalanced_tags),
        safedom_validate_html("</div>", 6)
    );
}

test "element finding" {
    const ptr = safedom_find_element("#app");
    try std.testing.expect(ptr != 0);  // Should return mock pointer

    const null_ptr = safedom_find_element("");
    try std.testing.expectEqual(@as(c_ulong, 0), null_ptr);
}

test "mounting" {
    const result = safedom_mount(0x1000, "<div>test</div>");
    try std.testing.expectEqual(@intFromEnum(MountResult.success), result);

    const null_result = safedom_mount(0, "<div>test</div>");
    try std.testing.expectEqual(@intFromEnum(MountResult.null_element), null_result);
}
