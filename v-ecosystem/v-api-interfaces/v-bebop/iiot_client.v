// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
module main

import net

fn write_u32_le(mut b []u8, v u32) {
    b[0] = u8(v & 0xff)
    b[1] = u8((v >> 8) & 0xff)
    b[2] = u8((v >> 16) & 0xff)
    b[3] = u8((v >> 24) & 0xff)
}

fn main() {
    mut conn := net.dial_tcp('127.0.0.1:8080') or {
        eprintln('dial failed: $err')
        return
    }
    defer { conn.close() or {} }

    // Replace with real Bebop-encoded payload bytes.
    payload := [u8(0x00), 0x01, 0x02]

    mut hdr := []u8{len: 4}
    write_u32_le(mut hdr, u32(payload.len))

    conn.write(hdr) or { return }
    conn.write(payload) or { return }
    println('sent ${payload.len} bytes')
}
