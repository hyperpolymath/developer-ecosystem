# Architecture Documentation

## Overview

ReScript WASM Runtime is a high-performance, type-safe HTTP server runtime that combines ReScript's functional programming paradigm with modern runtime environments (Deno, Bun, WASM).

## Design Principles

### 1. Type Safety First

Every component is fully type-safe from ReScript source to runtime:

```rescript
// Type-safe request handler
let handler: Deno.request => promise<Deno.response> = async (req) => {
  // TypeScript: (req: Request) => Promise<Response>
  Deno.Response.text("Hello", ())
}
```

### 2. Minimal Bundle Size

- **No framework bloat**: Direct Deno bindings
- **Tree-shaking friendly**: ES modules only
- **Optimized compilation**: ReScript's dead code elimination
- **Target**: <10KB for typical applications

### 3. Zero-Cost Abstractions

- **Compile-time optimizations**: ReScript eliminates overhead
- **Direct bindings**: No wrapper layers
- **Monomorphization**: Generic code specialized at compile time

### 4. Composability

- **Middleware pipeline**: Standard functional composition
- **Router combinators**: Build complex routes from simple parts
- **Module system**: Clean boundaries and interfaces

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                 User Application                     │
│              (ReScript Source Code)                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│              ReScript Compiler                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  Parser  │→│Type Check│→│Code Generation   │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│           Optimized ES Modules (.mjs)                │
│  - Tree-shaken code                                  │
│  - Inlined functions                                 │
│  - Dead code eliminated                              │
└────────────────────┬────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
    ┌────────┐  ┌────────┐  ┌─────────┐
    │  Deno  │  │  Bun   │  │  WASM   │
    │Runtime │  │Runtime │  │ Runtime │
    └────────┘  └────────┘  └─────────┘
```

### Component Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Application Layer                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Examples │  │  Custom  │  │   User Apps      │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│                 Framework Layer                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  Router  │  │  Server  │  │   Middleware     │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│                 Runtime Layer                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │Deno APIs │  │ Bun APIs │  │   WASM APIs      │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Core Modules

### 1. Deno Module (`src/Deno.res`)

**Purpose**: Type-safe bindings to Deno runtime APIs

**Key Types**:
```rescript
type request  // HTTP request
type response // HTTP response
type server   // HTTP server instance
```

**Key Functions**:
```rescript
module Request = {
  external method: request => string
  external url: request => string
  external json: request => promise<Js.Json.t>
}

module Response = {
  let text: (string, ~status=?, ~headers=?) => response
  let json: (Js.Json.t, ~status=?, ~headers=?) => response
  let html: (string, ~status=?, ~headers=?) => response
}
```

**Design Notes**:
- Uses `@val`, `@scope` for external bindings
- No runtime overhead - direct JavaScript calls
- Type safety enforced at compile time

### 2. Server Module (`src/Server.res`)

**Purpose**: HTTP server creation and lifecycle management

**Architecture**:
```rescript
type config = {
  port: int,
  hostname: string,
  onListen: option<addr => unit>
}

// Simple API
let simple: (
  ~port: int,
  ~hostname: string,
  handler: request => promise<response>
) => unit

// Router-based API
let withRouter: (
  ~port: int,
  ~hostname: string,
  router: Router.t
) => unit
```

**Design Notes**:
- Minimal API surface
- Sensible defaults
- Composable with routers

### 3. Router Module (`src/Router.res`)

**Purpose**: Type-safe request routing and middleware composition

**Types**:
```rescript
type method = GET | POST | PUT | DELETE | PATCH | OPTIONS | HEAD
type route = {
  method: method,
  path: string,
  handler: request => promise<response>
}
type middleware = (request, unit => promise<response>) => promise<response>
type t = {
  routes: array<route>,
  middlewares: array<middleware>,
  notFoundHandler: option<request => promise<response>>
}
```

**Path Matching Algorithm**:
```rescript
// Pattern: /users/:id
// Path: /users/123
// Result: Some({ id: "123" })

let matchPath = (pattern: string, path: string): option<Js.Dict.t<string>> => {
  // 1. Split by "/"
  // 2. Compare segments
  // 3. Extract parameters (segments starting with ":")
  // 4. Return params dict or None
}
```

**Middleware Execution**:
```rescript
// Middlewares are executed right-to-left (reverse order)
// This creates a nested call chain:
//
// middleware1(req, () =>
//   middleware2(req, () =>
//     middleware3(req, () =>
//       handler(req))))

let wrappedHandler = Array.reduceReverse(
  middlewares,
  finalHandler,
  (next, middleware) => () => middleware(req, next)
)
```

### 4. Middleware Module (`src/Middleware.res`)

**Purpose**: Common middleware implementations

**Available Middleware**:

1. **CORS**: Cross-Origin Resource Sharing
2. **Logger**: Request logging
3. **Rate Limiter**: Request rate limiting
4. **Auth**: Authentication helpers
5. **Error Handler**: Error catching and formatting
6. **Compress**: Response compression

**Middleware Pattern**:
```rescript
type middleware = (request, next: unit => promise<response>) => promise<response>

// Example implementation
let logger = (): middleware => {
  (req, next) => {
    let start = Deno.now()
    next()->Promise.thenResolve(response => {
      let duration = Deno.now() -. start
      Deno.log(`Request took ${duration}ms`)
      response
    })
  }
}
```

## Data Flow

### Request Processing Flow

```
1. Client Request
        │
        ▼
2. Deno Runtime
        │
        ▼
3. Server Handler
        │
        ▼
4. Middleware Chain
    │
    ├─→ CORS
    ├─→ Logger
    ├─→ Auth
    └─→ ...
        │
        ▼
5. Router
    │
    ├─→ Path Matching
    └─→ Method Matching
        │
        ▼
6. Route Handler
        │
        ▼
7. Response
        │
        ▼
8. Middleware Chain (reverse)
        │
        ▼
9. Client Response
```

### Middleware Execution Order

```
Request Flow (top to bottom):
┌─────────────────┐
│   CORS Check    │ ← Middleware 1
└────────┬────────┘
         ▼
┌─────────────────┐
│   Rate Limit    │ ← Middleware 2
└────────┬────────┘
         ▼
┌─────────────────┐
│   Auth Check    │ ← Middleware 3
└────────┬────────┘
         ▼
┌─────────────────┐
│  Route Handler  │ ← Final Handler
└────────┬────────┘
         ▼
Response Flow (bottom to top):
         │
         ▼
     [Response]
```

## Performance Optimizations

### 1. Compile-Time Optimizations

- **Monomorphization**: Generic code specialized for each type
- **Inlining**: Small functions inlined at call sites
- **Dead code elimination**: Unused code removed
- **Constant folding**: Compile-time constant evaluation

### 2. Runtime Optimizations

- **Zero-copy operations**: Direct buffer access where possible
- **Lazy evaluation**: Defer work until needed
- **Connection pooling**: Reuse connections (planned)
- **Response streaming**: Stream large responses (planned)

### 3. Bundle Size Optimizations

- **Tree shaking**: Only include used code
- **ES modules**: Enable better optimization
- **No dependencies**: Avoid framework bloat
- **Minimal runtime**: Direct runtime bindings

## Security Model

### Type Safety

- **No null/undefined**: Option type for nullable values
- **No runtime errors**: Exhaustive pattern matching
- **No type coercion**: Explicit conversions only

### Runtime Security (Deno)

- **Permissions system**: Explicit capabilities
- **Sandboxed execution**: Limited file system access
- **Secure defaults**: No ambient access

### Middleware Security

- **CORS validation**: Prevent unauthorized origins
- **Rate limiting**: Prevent abuse
- **Auth checks**: Token validation
- **Input validation**: Type-safe parsing

## Scalability

### Horizontal Scaling

- **Stateless design**: No shared state between requests
- **Load balancing**: Standard HTTP load balancing
- **Container-friendly**: Small container images

### Vertical Scaling

- **Low memory footprint**: ~12MB idle
- **Fast startup**: <100ms cold start
- **High throughput**: Event-driven I/O

## Testing Strategy

### Unit Tests

- Test individual functions
- Mock external dependencies
- Focus on business logic

### Integration Tests

- Test full request/response cycle
- Use real HTTP requests
- Verify middleware composition

### Benchmark Tests

- Measure performance characteristics
- Compare against baselines
- Prevent regressions

## Deployment Architecture

### Container Deployment

```dockerfile
# Multi-stage build
FROM builder AS build
RUN npm install && npm run build

FROM runtime
COPY --from=build /app/dist /app
CMD ["deno", "run", "--allow-net", "server.mjs"]
```

### Serverless Deployment

```
┌──────────────────┐
│   Deno Deploy    │
│   ┌──────────┐   │
│   │  Edge 1  │   │
│   │  Edge 2  │   │
│   │  Edge 3  │   │
│   └──────────┘   │
└──────────────────┘
```

## Future Architecture

### WASM Compilation

```
ReScript Source
      │
      ▼
  ReScript IR
      │
      ▼
   WASM Backend
      │
      ▼
 WebAssembly Module
      │
      ▼
  WASM Runtime
```

### Plugin System

```
┌─────────────────────────┐
│   Core Runtime          │
├─────────────────────────┤
│   Plugin Manager        │
├─────────────────────────┤
│ ┌─────────┐ ┌─────────┐│
│ │Plugin 1 │ │Plugin 2 ││
│ └─────────┘ └─────────┘│
└─────────────────────────┘
```

## References

- [ReScript Language Reference](https://rescript-lang.org/)
- [Deno Manual](https://deno.land/manual)
- [WebAssembly Specification](https://webassembly.github.io/spec/)

---

**Last Updated**: 2025-01-XX
