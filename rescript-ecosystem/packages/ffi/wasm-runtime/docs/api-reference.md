# API Reference

Complete API reference for ReScript WASM Runtime.

## Table of Contents

- [Deno Module](#deno-module)
- [Server Module](#server-module)
- [Router Module](#router-module)
- [Middleware Module](#middleware-module)
- [Types](#types)

---

## Deno Module

Runtime bindings for Deno APIs.

### Types

#### `request`
Opaque type representing an HTTP request.

#### `response`
Opaque type representing an HTTP response.

#### `addr`
```rescript
type addr = {
  hostname: string,
  port: int
}
```

### Request

#### `Request.method`
```rescript
let method: request => string
```
Get the HTTP method of the request.

**Example**:
```rescript
let method = Deno.Request.method(req)
// "GET", "POST", "PUT", etc.
```

#### `Request.url`
```rescript
let url: request => string
```
Get the full URL of the request.

**Example**:
```rescript
let url = Deno.Request.url(req)
// "http://localhost:8000/api/users"
```

#### `Request.headers`
```rescript
let headers: request => Js.Dict.t<string>
```
Get request headers as a dictionary.

**Example**:
```rescript
let headers = Deno.Request.headers(req)
switch Js.Dict.get(headers, "authorization") {
| Some(token) => // Use token
| None => // No auth header
}
```

#### `Request.text`
```rescript
let text: request => promise<string>
```
Read request body as text.

**Example**:
```rescript
let body = await Deno.Request.text(req)
```

#### `Request.json`
```rescript
let json: request => promise<Js.Json.t>
```
Parse request body as JSON.

**Example**:
```rescript
try {
  let json = await Deno.Request.json(req)
  // Process JSON
} catch {
| _ => // Invalid JSON
}
```

### Response

#### `Response.text`
```rescript
let text: (
  string,
  ~status: int=?,
  ~headers: Js.Dict.t<string>=?,
  unit
) => response
```
Create a text response.

**Parameters**:
- `data`: Response body
- `status`: HTTP status code (default: 200)
- `headers`: Additional headers

**Example**:
```rescript
Deno.Response.text("Hello, World!", ())
Deno.Response.text("Not Found", ~status=404, ())

let customHeaders = Js.Dict.empty()
Js.Dict.set(customHeaders, "X-Custom", "value")
Deno.Response.text("Data", ~headers=customHeaders, ())
```

#### `Response.json`
```rescript
let json: (
  Js.Json.t,
  ~status: int=?,
  ~headers: Js.Dict.t<string>=?,
  unit
) => response
```
Create a JSON response.

**Example**:
```rescript
let data = Js.Json.object_(Js.Dict.fromArray([
  ("message", Js.Json.string("Success")),
  ("count", Js.Json.number(42.0))
]))

Deno.Response.json(data, ())
Deno.Response.json(data, ~status=201, ())
```

#### `Response.html`
```rescript
let html: (
  string,
  ~status: int=?,
  ~headers: Js.Dict.t<string>=?,
  unit
) => response
```
Create an HTML response.

**Example**:
```rescript
Deno.Response.html("<h1>Hello</h1>", ())
```

### Console

#### `log`, `error`, `warn`, `info`
```rescript
let log: 'a => unit
let error: 'a => unit
let warn: 'a => unit
let info: 'a => unit
```

**Example**:
```rescript
Deno.log("Server started")
Deno.error("Failed to connect")
Deno.warn("Deprecated API used")
Deno.info("Processing request")
```

### Environment

#### `Env.get`
```rescript
let get: string => option<string>
```
Get environment variable.

**Example**:
```rescript
switch Deno.Env.get("PORT") {
| Some(port) => // Use port
| None => // Use default
}
```

#### `Env.set`
```rescript
let set: (string, string) => unit
```
Set environment variable.

### File System

#### `Fs.readTextFile`
```rescript
let readTextFile: string => promise<string>
```
Read file as text.

#### `Fs.writeTextFile`
```rescript
let writeTextFile: (string, string) => promise<unit>
```
Write text to file.

#### `Fs.readFile`
```rescript
let readFile: string => promise<Js.Typed_array.Uint8Array.t>
```
Read file as bytes.

#### `Fs.writeFile`
```rescript
let writeFile: (string, Js.Typed_array.Uint8Array.t) => promise<unit>
```
Write bytes to file.

### URL

#### `Url.make`
```rescript
let make: string => 'url
```
Create URL object.

#### `Url.pathname`
```rescript
let pathname: 'url => string
```
Get URL pathname.

**Example**:
```rescript
let url = Deno.Url.make("http://localhost:8000/api/users?page=1")
let pathname = Deno.Url.pathname(url)  // "/api/users"
```

---

## Server Module

HTTP server creation and management.

### Types

#### `config`
```rescript
type config = {
  port: int,
  hostname: string,
  onListen: option<Deno.addr => unit>
}
```

### Functions

#### `Server.make`
```rescript
let make: (
  ~port: int=?,
  ~hostname: string=?,
  ~onListen: (Deno.addr => unit)=?,
  Deno.request => promise<Deno.response>
) => unit
```
Create an HTTP server with a request handler.

**Parameters**:
- `port`: Port number (default: 8000)
- `hostname`: Host address (default: "127.0.0.1")
- `onListen`: Callback when server starts
- Handler function: `request => promise<response>`

**Example**:
```rescript
Server.make(
  ~port=3000,
  ~onListen=addr => Deno.log(`Server on port ${Int.toString(addr.port)}`),
  async req => Deno.Response.text("Hello", ())
)
```

#### `Server.simple`
```rescript
let simple: (
  ~port: int=?,
  ~hostname: string=?,
  Deno.request => promise<Deno.response>
) => unit
```
Create a simple server (convenience function).

**Example**:
```rescript
Server.simple(
  ~port=8000,
  async _req => Deno.Response.text("Hello", ())
)
```

#### `Server.withRouter`
```rescript
let withRouter: (
  ~port: int=?,
  ~hostname: string=?,
  ~onListen: (Deno.addr => unit)=?,
  Router.t
) => unit
```
Create a server with a router.

**Example**:
```rescript
let router = Router.make()
  ->Router.get("/", handler)

Server.withRouter(~port=8000, router)
```

---

## Router Module

Type-safe routing and middleware composition.

### Types

#### `method`
```rescript
type method = GET | POST | PUT | DELETE | PATCH | OPTIONS | HEAD
```

#### `route`
```rescript
type route = {
  method: method,
  path: string,
  handler: Deno.request => promise<Deno.response>
}
```

#### `middleware`
```rescript
type middleware = (
  Deno.request,
  unit => promise<Deno.response>
) => promise<Deno.response>
```

#### `t`
```rescript
type t = {
  routes: array<route>,
  middlewares: array<middleware>,
  notFoundHandler: option<Deno.request => promise<Deno.response>>
}
```

### Functions

#### `Router.make`
```rescript
let make: unit => t
```
Create an empty router.

**Example**:
```rescript
let router = Router.make()
```

#### `Router.get`
```rescript
let get: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add GET route.

**Example**:
```rescript
let router = Router.make()
  ->Router.get("/users", listUsers)
  ->Router.get("/users/:id", getUser)
```

#### `Router.post`
```rescript
let post: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add POST route.

#### `Router.put`
```rescript
let put: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add PUT route.

#### `Router.del`
```rescript
let del: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add DELETE route.

**Note**: Named `del` instead of `delete` (ReScript keyword).

#### `Router.patch`
```rescript
let patch: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add PATCH route.

#### `Router.options`
```rescript
let options: (
  t,
  string,
  Deno.request => promise<Deno.response>
) => t
```
Add OPTIONS route.

#### `Router.use`
```rescript
let use: (t, middleware) => t
```
Add middleware to router.

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.get("/", handler)
```

#### `Router.notFound`
```rescript
let notFound: (
  t,
  Deno.request => promise<Deno.response>
) => t
```
Set custom 404 handler.

**Example**:
```rescript
let custom404 = async _req => {
  Deno.Response.json(
    Js.Json.object_(Js.Dict.fromArray([
      ("error", Js.Json.string("Route not found"))
    ])),
    ~status=404,
    ()
  )
}

let router = Router.make()
  ->Router.notFound(custom404)
```

#### `Router.handle`
```rescript
let handle: (t, Deno.request) => promise<Deno.response>
```
Handle an HTTP request (used internally).

---

## Middleware Module

Common middleware implementations.

### CORS

#### `Middleware.cors`
```rescript
let cors: (
  ~origin: string=?,
  ~methods: array<string>=?,
  ~headers: array<string>=?,
  ~credentials: bool=?,
  unit
) => Router.middleware
```
CORS middleware.

**Parameters**:
- `origin`: Allowed origin (default: "*")
- `methods`: Allowed methods (default: ["GET", "POST", "PUT", "DELETE", "PATCH"])
- `headers`: Allowed headers (default: ["Content-Type", "Authorization"])
- `credentials`: Allow credentials (default: false)

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.cors(
    ~origin="https://example.com",
    ~methods=["GET", "POST"],
    ~credentials=true,
    ()
  ))
```

### Logger

#### `Middleware.logger`
```rescript
let logger: unit => Router.middleware
```
Request logging middleware.

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.logger())
```

**Output**:
```
GET /api/users - 45.23ms
POST /api/users - 123.45ms
```

### Rate Limiting

#### `Middleware.rateLimit`
```rescript
let rateLimit: (
  ~maxRequests: int=?,
  ~windowMs: float=?,
  unit
) => Router.middleware
```
Rate limiting middleware.

**Parameters**:
- `maxRequests`: Max requests per window (default: 100)
- `windowMs`: Time window in milliseconds (default: 60000)

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.rateLimit(
    ~maxRequests=50,
    ~windowMs=30000.0,  // 30 seconds
    ()
  ))
```

### Authentication

#### `Middleware.auth`
```rescript
let auth: (~secret: string) => Router.middleware
```
JWT authentication middleware helper.

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.auth(~secret="your-secret-key"))
  ->Router.get("/protected", protectedHandler)
```

### Error Handling

#### `Middleware.errorHandler`
```rescript
let errorHandler: unit => Router.middleware
```
Global error handler middleware.

**Example**:
```rescript
let router = Router.make()
  ->Router.use(Middleware.errorHandler())
```

### Compression

#### `Middleware.compress`
```rescript
let compress: unit => Router.middleware
```
Response compression middleware (placeholder).

---

## Types

### Common Type Definitions

#### JSON Types
```rescript
// From Js.Json module
type t = Js.Json.t

// Creating JSON
let obj = Js.Json.object_(Js.Dict.fromArray([...]))
let arr = Js.Json.array([...])
let str = Js.Json.string("value")
let num = Js.Json.number(42.0)
let bool = Js.Json.boolean(true)

// Decoding JSON
let obj = Js.Json.decodeObject(json)
let arr = Js.Json.decodeArray(json)
let str = Js.Json.decodeString(json)
let num = Js.Json.decodeNumber(json)
let bool = Js.Json.decodeBoolean(json)
```

#### Promise Types
```rescript
// From Promise module
type t<'a> = promise<'a>

// Creating promises
Promise.resolve(value)
Promise.reject(error)

// Chaining
promise
  ->Promise.then(result => ...)
  ->Promise.catch(error => ...)

// Async/await
let result = await promise
```

---

## Examples

### Complete API Server

```rescript
// Define handlers
let listUsers = async (_req: Deno.request): promise<Deno.response> => {
  let users = [/* ... */]
  Deno.Response.json(Js.Json.array(users), ())
}

let createUser = async (req: Deno.request): promise<Deno.response> => {
  let body = await Deno.Request.json(req)
  // Process body
  Deno.Response.json(body, ~status=201, ())
}

// Create router
let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.use(Middleware.rateLimit())
  ->Router.get("/api/users", listUsers)
  ->Router.post("/api/users", createUser)
  ->Router.get("/api/users/:id", getUser)
  ->Router.put("/api/users/:id", updateUser)
  ->Router.del("/api/users/:id", deleteUser)

// Start server
Server.withRouter(~port=8000, router)
```

---

**Version**: 0.1.0
**Last Updated**: 2025-01-XX
