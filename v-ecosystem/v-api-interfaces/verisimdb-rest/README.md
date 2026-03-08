<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# VeriSimDB REST Gateway

V-lang HTTP gateway for the VeriSimDB hexad storage engine.  Exposes a
JSON REST API on port **9090** for storing and querying hexads produced by
[panic-attack](https://github.com/hyperpolymath/panic-attacker) and other
tools in the hyperpolymath ecosystem.

Hexads are persisted as individual JSON files under a configurable data
directory (no external database required).

## Building and Running

```bash
# From this directory:
cd developer-ecosystem/v-ecosystem/v-api-interfaces/verisimdb-rest

# Run directly (development):
v run src/rest.v

# Compile then run (production):
v -o verisimdb-rest src/rest.v
./verisimdb-rest
```

The server starts on port **9090** by default.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `VERISIMDB_DATA_DIR` | `verisimdb-data/hexads` | Directory where hexad JSON files are stored |

## API Endpoints

### `GET /` — API Discovery

Returns service metadata and available endpoints.

```json
{
  "service": "verisimdb-rest",
  "version": "1.0.0",
  "description": "VeriSimDB hexad storage gateway for panic-attack",
  "endpoints": ["/api/v1/hexads", "/api/v1/hexads/batch", "/api/v1/hexads/:id", "/api/v1/health"]
}
```

### `GET /api/v1/health` — Health Check

Returns gateway health status including stored hexad count.

```json
{
  "healthy": true,
  "service": "verisimdb-rest",
  "hexad_count": 42,
  "latest_hexad": "pa-20260308120000-0019a3e8f0c00",
  "data_dir": "verisimdb-data/hexads"
}
```

### `POST /api/v1/hexads` — Store Single Hexad

Stores a single hexad.  The request body must be a JSON object with an `id`
field.

**Request:**

```bash
curl -X POST http://localhost:9090/api/v1/hexads \
  -H "Content-Type: application/json" \
  -d '{"schema":"verisimdb.hexad.v1","id":"pa-20260308-abc","provenance":{"tool":"panic-attack","version":"2.1.0","program_path":"/src","language":"Rust"},"semantic":{"total_weak_points":5,"critical_count":1,"high_count":2,"total_crashes":0,"robustness_score":0.85,"categories":["UnsafeCode","PanicPath"]},"document":{}}'
```

**Response (201):**

```json
{"stored": true, "id": "pa-20260308-abc", "path": "verisimdb-data/hexads/pa-20260308-abc.json"}
```

### `POST /api/v1/hexads/batch` — Store Multiple Hexads

Stores an array of hexads in one request.  Each element must have an `id` field.

**Request:**

```bash
curl -X POST http://localhost:9090/api/v1/hexads/batch \
  -H "Content-Type: application/json" \
  -d '[{"schema":"verisimdb.hexad.v1","id":"h1","provenance":{"tool":"panic-attack","version":"2.1.0","program_path":"/a","language":"Rust"},"semantic":{"total_weak_points":1,"critical_count":0,"high_count":0,"total_crashes":0,"robustness_score":0.99,"categories":[]},"document":{}},{"schema":"verisimdb.hexad.v1","id":"h2","provenance":{"tool":"panic-attack","version":"2.1.0","program_path":"/b","language":"Gleam"},"semantic":{"total_weak_points":0,"critical_count":0,"high_count":0,"total_crashes":0,"robustness_score":1.0,"categories":[]},"document":{}}]'
```

**Response (201):**

```json
{"stored": 2, "ids": ["h1", "h2"]}
```

### `GET /api/v1/hexads` — Query Hexads

Returns stored hexads, optionally filtered by tool name.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `tool` | string | *(none)* | Filter by `provenance.tool` value |
| `limit` | int | 100 | Maximum number of results |

**Request:**

```bash
curl "http://localhost:9090/api/v1/hexads?tool=panic-attack&limit=10"
```

**Response (200):**

```json
{
  "hexads": [ { ... }, { ... } ],
  "count": 2
}
```

### `GET /api/v1/hexads/:id` — Get Hexad by ID

Retrieves a single hexad by its ID.

```bash
curl http://localhost:9090/api/v1/hexads/pa-20260308-abc
```

Returns the full hexad JSON (200) or `{"error":"Hexad not found"}` (404).

## Hexad JSON Format

The hexad is the VeriSimDB unit of storage.  For panic-attack reports it
contains six facets:

```json
{
  "schema": "verisimdb.hexad.v1",
  "id": "pa-20260308120000-0019a3e8f0c00",
  "created_at": "2026-03-08T12:00:00Z",
  "provenance": {
    "tool": "panic-attack",
    "version": "2.1.0",
    "program_path": "/path/to/scanned/repo",
    "language": "Rust",
    "attestation_hash": null
  },
  "semantic": {
    "total_weak_points": 7,
    "critical_count": 1,
    "high_count": 2,
    "total_crashes": 0,
    "robustness_score": 0.78,
    "categories": ["UnsafeCode", "PanicPath", "UnsafeFFI"],
    "migration": null
  },
  "document": {
    "program_path": "/path/to/scanned/repo",
    "total_files_scanned": 42,
    "total_weak_points": 7
  }
}
```

### Facet Summary

| Facet | Field | Content |
|---|---|---|
| **Identity** | `id` | Unique ID (timestamp + hash) |
| **Temporal** | `created_at` | ISO 8601 creation timestamp |
| **Provenance** | `provenance` | Tool name, version, scan parameters |
| **Semantic** | `semantic` | Weak point counts, severity breakdown, categories |
| **Document** | `document` | Full JSON-encoded AssaultReport |
| **Structural** | *(embedded)* | Dependency graph edges in the document payload |

## Connecting panic-attack

panic-attack can push hexads to this gateway via HTTP when built with the
`http` feature flag:

```bash
# Build panic-attack with HTTP support
cargo build --release --features http

# Set the gateway URL (defaults to http://localhost:9090)
export VERISIM_API_URL=http://localhost:9090

# Run a scan — results are pushed to VeriSimDB automatically
panic-attack assail /path/to/repo --storage verisimdb
```

### Environment Variables (panic-attack side)

| Variable | Default | Description |
|---|---|---|
| `VERISIM_API_URL` | `http://localhost:9090` | Gateway base URL |
| `VERISIM_GATEWAY_URL` | `http://localhost:9090` | Alias (used by `push_hexad_with_fallback`) |
| `VERISIM_API_TOKEN` | *(none)* | Optional Bearer token for auth |

When the gateway is unreachable, panic-attack falls back to writing hexad
files locally under `verisimdb-data/hexads/`.

## E2E Integration Test

An end-to-end test script lives in the panic-attacker repo:

```bash
cd panic-attacker

# Run the test (skips gracefully if gateway is not running):
just e2e-verisimdb

# Or directly:
bash tests/verisimdb_e2e.sh
```

The test creates sample hexads, POSTs them to the gateway, queries them back,
and verifies responses.  It uses only `curl` and requires no compilation.
