// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
module bebop_bridge

// This module binds to the C ABI defined in include/bebop_v_ffi.h.
// It intentionally uses ptr+len (VBytes) and does not assume NUL-terminated payload strings.

[typedef]
pub struct C.BebopCtx {}

[typedef]
pub struct C.VBytes {
    ptr &u8
    len usize
}

[typedef]
pub struct C.VSensorReading {
    timestamp u64
    sensor_id C.VBytes
    sensor_type u16
    value f64
    unit C.VBytes
    location C.VBytes
    metadata_count usize
    metadata_keys &C.VBytes
    metadata_values &C.VBytes
    error_code int
    error_message &char
}

// C ABI functions
fn C.bebop_ctx_new() &C.BebopCtx
fn C.bebop_ctx_free(ctx &C.BebopCtx)
fn C.bebop_ctx_reset(ctx &C.BebopCtx)

fn C.bebop_decode_sensor_reading(ctx &C.BebopCtx, data &u8, len usize, out &C.VSensorReading) int
fn C.bebop_free_sensor_reading(ctx &C.BebopCtx, reading &C.VSensorReading)
fn C.bebop_encode_batch_readings(ctx &C.BebopCtx, readings &C.VSensorReading, count usize, out_buf &u8, out_len usize) usize

// Helper: bytes -> V string (copies)
[inline]
fn bytes_to_string(b C.VBytes) string {
    if isnil(b.ptr) || b.len == 0 { return '' }
    return unsafe { b.ptr.vstring_with_len(int(b.len)) }
}

// Small safe wrapper type
pub struct BebopCtx {
    ctx &C.BebopCtx
}

pub fn new_ctx() BebopCtx {
    return BebopCtx{ ctx: C.bebop_ctx_new() }
}

pub fn (mut c BebopCtx) free() {
    if !isnil(c.ctx) {
        C.bebop_ctx_free(c.ctx)
        c.ctx = unsafe { nil }
    }
}

pub fn (c &BebopCtx) reset() {
    if !isnil(c.ctx) { C.bebop_ctx_reset(c.ctx) }
}

pub struct SensorReading {
    pub:
    timestamp u64
    sensor_id string
    sensor_type u16
    value f64
    unit string
    location string
    metadata map[string]string
}

pub fn (c &BebopCtx) decode_sensor_reading(data []u8) ?SensorReading {
    mut out := C.VSensorReading{}
    rc := C.bebop_decode_sensor_reading(c.ctx, data.data, data.len, &out)
    if rc != 0 || out.error_code != 0 {
        return none
    }

    mut md := map[string]string{}
    for i := 0; i < out.metadata_count; i++ {
        k := unsafe { out.metadata_keys[i] }
        v := unsafe { out.metadata_values[i] }
        md[bytes_to_string(k)] = bytes_to_string(v)
    }

    // If the implementation needs explicit free per reading, call it here.
    // For pure arena allocation, ctx.reset() will reclaim.
    C.bebop_free_sensor_reading(c.ctx, &out)

    return SensorReading{
        timestamp: out.timestamp
        sensor_id: bytes_to_string(out.sensor_id)
        sensor_type: out.sensor_type
        value: out.value
        unit: bytes_to_string(out.unit)
        location: bytes_to_string(out.location)
        metadata: md
    }
}
