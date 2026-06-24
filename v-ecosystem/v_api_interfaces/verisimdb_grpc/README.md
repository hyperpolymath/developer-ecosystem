<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# VeriSimDB gRPC-Web Gateway

V-lang gRPC-Web gateway for the VeriSimDB hexad storage engine.  Exposes
gRPC-style RPC endpoints on port **9091** for storing and querying hexads
produced by [panic-attack](https://github.com/hyperpolymath/panic-attacker)
and other tools in the hyperpolymath ecosystem.

Uses JSON-over-HTTP as transport (gRPC-Web compatible).  Full HTTP/2 + Protobuf
transport is planned via the Zig FFI layer.

Hexads are persisted as individual JSON files under a configurable data
directory (no external database required).

## Building and Running

```bash
# From this directory:
cd developer-ecosystem/v-ecosystem/v-api-interfaces/verisimdb-grpc

# Run directly (development):
v run src/grpc.v

# Compile then run (production):
v -o verisimdb-grpc src/grpc.v
./verisimdb-grpc
```

The server starts on port **9091** by default.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `VERISIMDB_DATA_DIR` | `verisimdb-data/hexads` | Directory where hexad JSON files are stored |

## RPC Endpoints

All endpoints accept `POST` with JSON bodies.

### `POST /verisimdb.HexadService/Store` -- Store a single hexad

**Request:**

```bash
curl -X POST http://localhost:9091/verisimdb.HexadService/Store \
  -H "Content-Type: application/json" \
  -d '{"schema":"verisimdb.hexad.v1","id":"pa-20260308-abc","provenance":{"tool":"panic-attack","version":"2.1.0","program_path":"/src","language":"Rust"},"semantic":{"total_weak_points":5,"critical_count":1,"high_count":2,"total_crashes":0,"robustness_score":0.85,"categories":["UnsafeCode","PanicPath"]},"document":{}}'
```

**Response (200):**

```json
{"stored": true, "id": "pa-20260308-abc", "path": "verisimdb-data/hexads/pa-20260308-abc.json"}
```

### `POST /verisimdb.HexadService/StoreBatch` -- Store multiple hexads

Accepts a JSON array of hexads.

### `POST /verisimdb.HexadService/Query` -- Query hexads

**Request:**

```json
{"tool": "panic-attack", "limit": 10}
```

### `POST /verisimdb.HexadService/Get` -- Get hexad by ID

**Request:**

```json
{"id": "pa-20260308-abc"}
```

### `POST /verisimdb.HexadService/Health` -- Health check

Returns gateway health status including stored hexad count.

## Connecting panic-attack

See the [verisimdb-rest README](../verisimdb-rest/README.md) for instructions
on connecting panic-attack to VeriSimDB gateways.  The gRPC gateway listens
on port 9091 instead of 9090.
