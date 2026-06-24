<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# VeriSimDB GraphQL Gateway

V-lang GraphQL gateway for the VeriSimDB hexad storage engine.  Exposes a
GraphQL API on port **9092** for storing and querying hexads produced by
[panic-attack](https://github.com/hyperpolymath/panic-attacker) and other
tools in the hyperpolymath ecosystem.

Hexads are persisted as individual JSON files under a configurable data
directory (no external database required).

## Building and Running

```bash
# From this directory:
cd developer-ecosystem/v-ecosystem/v-api-interfaces/verisimdb-graphql

# Run directly (development):
v run src/graphql.v

# Compile then run (production):
v -o verisimdb-graphql src/graphql.v
./verisimdb-graphql
```

The server starts on port **9092** by default.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `VERISIMDB_DATA_DIR` | `verisimdb-data/hexads` | Directory where hexad JSON files are stored |

## GraphQL Schema

All operations go through the `/graphql` endpoint.

### Mutations

#### `storeHexad` -- Store a single hexad

```graphql
mutation {
  storeHexad(hexad: "{...json...}") {
    id
    stored
    path
  }
}
```

### Queries

#### `hexads` -- Query hexads with optional filters

```graphql
query {
  hexads(tool: "panic-attack", limit: 10) {
    id
    schema
    createdAt
    semantic {
      totalWeakPoints
      criticalCount
    }
  }
}
```

#### `hexad` -- Get a single hexad by ID

```graphql
query {
  hexad(id: "pa-20260308-abc") {
    id
    schema
    createdAt
    provenance { tool version }
    semantic { totalWeakPoints criticalCount }
  }
}
```

#### `health` -- Health check

```graphql
query {
  health {
    healthy
    hexadCount
    latestHexad
  }
}
```

### GraphiQL Playground

A `GET /graphql` request returns an interactive GraphiQL playground for
exploring the schema in a browser.

## Connecting panic-attack

See the [verisimdb-rest README](../verisimdb-rest/README.md) for instructions
on connecting panic-attack to VeriSimDB gateways.  The GraphQL gateway listens
on port 9092 instead of 9090.
