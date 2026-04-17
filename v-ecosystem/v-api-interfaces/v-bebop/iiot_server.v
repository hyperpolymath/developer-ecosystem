// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
module main

import net
import bebop_bridge

fn read_exact(mut conn net.TcpConn, mut buf []u8, n int) ? {
    mut got := 0
    for got < n {
        m := conn.read(mut buf[got..n]) or { return none }
        if m <= 0 { return none }
        got += m
    }
}

fn read_u32_le(b []u8) u32 {
    return u32(b[0]) | (u32(b[1]) << 8) | (u32(b[2]) << 16) | (u32(b[3]) << 24)
}

fn main() {
    mut listener := net.listen_tcp(.ip, ':8080') or {
        eprintln('Failed to listen: $err')
        return
    }
    println('Listening on :8080')

    for {
        mut conn := listener.accept() or { continue }
        go handle(mut conn)
    }
}

fn handle(mut conn net.TcpConn) {
    defer { conn.close() or {} }

    mut ctx := bebop_bridge.new_ctx()
    defer { ctx.free() }

    mut hdr := []u8{len: 4}
    for {
        read_exact(mut conn, mut hdr, 4) or { break }
        msg_len := int(read_u32_le(hdr))
        if msg_len <= 0 || msg_len > 1_000_000 {
            eprintln('Bad length: $msg_len')
            break
        }
        mut payload := []u8{len: msg_len}
        read_exact(mut conn, mut payload, msg_len) or { break }

        reading := ctx.decode_sensor_reading(payload) or {
            eprintln('Decode failed')
            ctx.reset()
            continue
        }

        println('sensor_id=${reading.sensor_id} value=${reading.value} unit=${reading.unit}')
        ctx.reset()
    }
}
