// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Type-safe HTTP server for ReScript using Deno.serve.
 */

/** HTTP method */
type method =
  | @as("GET") Get
  | @as("POST") Post
  | @as("PUT") Put
  | @as("PATCH") Patch
  | @as("DELETE") Delete
  | @as("HEAD") Head
  | @as("OPTIONS") Options

/** Deno server instance */
type server

/** Request object */
type request = Fetch.Request.t

/** Response object */
type response = Fetch.Response.t

/** Response init */
type responseInit = {
  status?: int,
  statusText?: string,
  headers?: Dict.t<string>,
}

/** Server options */
type serveOptions = {
  port?: int,
  hostname?: string,
  onListen?: {"port": int, "hostname": string} => unit,
  onError?: Error.t => response,
}

/** Handler function type */
type handler = request => promise<response>

/** Info about listening server */
type listenInfo = {
  port: int,
  hostname: string,
}

// FFI bindings
@val @scope("Deno")
external serve: (serveOptions, handler) => server = "serve"

@val @scope("Deno")
external serveHandler: handler => server = "serve"

@send
external shutdown: server => promise<unit> = "shutdown"

@send
external finished: server => promise<unit> = "finished"

@get
external addr: server => listenInfo = "addr"

// Request helpers
@get external requestMethod: request => string = "method"
@get external requestUrl: request => string = "url"
@get external requestHeaders: request => Fetch.Headers.t = "headers"
@send external requestText: request => promise<string> = "text"
@send external requestJson: request => promise<JSON.t> = "json"
@send external requestArrayBuffer: request => promise<ArrayBuffer.t> = "arrayBuffer"
@send external requestFormData: request => promise<FormData.t> = "formData"

/** Get the HTTP method */
let method = (req: request): method => {
  switch requestMethod(req) {
  | "GET" => Get
  | "POST" => Post
  | "PUT" => Put
  | "PATCH" => Patch
  | "DELETE" => Delete
  | "HEAD" => Head
  | "OPTIONS" => Options
  | _ => Get
  }
}

/** Get URL path */
let path = (req: request): string => {
  let url = requestUrl(req)
  try {
    let urlObj = URL.make(url)
    urlObj->URL.pathname
  } catch {
  | _ => url
  }
}

/** Get URL search params */
let searchParams = (req: request): URLSearchParams.t => {
  let url = requestUrl(req)
  try {
    let urlObj = URL.make(url)
    urlObj->URL.searchParams
  } catch {
  | _ => URLSearchParams.make("")
  }
}

/** Get a header value */
let header = (req: request, name: string): option<string> => {
  requestHeaders(req)->Fetch.Headers.get(name)
}

/** Read body as text */
let text = (req: request): promise<string> => requestText(req)

/** Read body as JSON */
let json = (req: request): promise<JSON.t> => requestJson(req)

// Response helpers
@new external makeResponse: (string, responseInit) => response = "Response"
@new external makeResponseWithBody: (string) => response = "Response"

/** Create a text response */
let respond = (~status: int=200, ~headers: Dict.t<string>=Dict.make(), body: string): response => {
  headers->Dict.set("Content-Type", "text/plain; charset=utf-8")
  makeResponse(body, {status, headers})
}

/** Create a JSON response */
let respondJson = (~status: int=200, ~headers: Dict.t<string>=Dict.make(), data: JSON.t): response => {
  headers->Dict.set("Content-Type", "application/json; charset=utf-8")
  makeResponse(JSON.stringify(data), {status, headers})
}

/** Create an HTML response */
let respondHtml = (~status: int=200, ~headers: Dict.t<string>=Dict.make(), html: string): response => {
  headers->Dict.set("Content-Type", "text/html; charset=utf-8")
  makeResponse(html, {status, headers})
}

/** Create a redirect response */
let redirect = (~status: int=302, location: string): response => {
  makeResponse("", {status, headers: Dict.fromArray([("Location", location)])})
}

/** Create a 404 response */
let notFound = (~body: string="Not Found"): response => {
  respond(~status=404, body)
}

/** Create a 400 response */
let badRequest = (~body: string="Bad Request"): response => {
  respond(~status=400, body)
}

/** Create a 500 response */
let serverError = (~body: string="Internal Server Error"): response => {
  respond(~status=500, body)
}

/** Create a 401 response */
let unauthorized = (~body: string="Unauthorized"): response => {
  respond(~status=401, body)
}

/** Create a 403 response */
let forbidden = (~body: string="Forbidden"): response => {
  respond(~status=403, body)
}

/** Route definition */
type route = {
  method: method,
  pattern: string,
  handler: request => promise<response>,
}

/** Simple path matcher */
let matchPath = (pattern: string, requestPath: string): bool => {
  if pattern == requestPath {
    true
  } else if pattern->String.endsWith("*") {
    let prefix = pattern->String.slice(~start=0, ~end=-1)
    requestPath->String.startsWith(prefix)
  } else {
    false
  }
}

/** Create a simple router */
let router = (routes: array<route>): handler => {
  async request => {
    let reqMethod = method(request)
    let reqPath = path(request)

    let matchedRoute = routes->Array.find(route => {
      route.method == reqMethod && matchPath(route.pattern, reqPath)
    })

    switch matchedRoute {
    | Some(route) => await route.handler(request)
    | None => notFound()
    }
  }
}

/** Route helper for GET */
let get = (pattern: string, handler: request => promise<response>): route => {
  {method: Get, pattern, handler}
}

/** Route helper for POST */
let post = (pattern: string, handler: request => promise<response>): route => {
  {method: Post, pattern, handler}
}

/** Route helper for PUT */
let put = (pattern: string, handler: request => promise<response>): route => {
  {method: Put, pattern, handler}
}

/** Route helper for PATCH */
let patch = (pattern: string, handler: request => promise<response>): route => {
  {method: Patch, pattern, handler}
}

/** Route helper for DELETE */
let delete = (pattern: string, handler: request => promise<response>): route => {
  {method: Delete, pattern, handler}
}

/** Middleware type */
type middleware = (request, handler) => promise<response>

/** Apply middleware to a handler */
let withMiddleware = (handler: handler, middleware: middleware): handler => {
  async request => {
    await middleware(request, handler)
  }
}

/** CORS middleware */
let cors = (
  ~origin: string="*",
  ~methods: string="GET, POST, PUT, PATCH, DELETE, OPTIONS",
  ~headers: string="Content-Type, Authorization",
): middleware => {
  async (request, next) => {
    if method(request) == Options {
      makeResponse(
        "",
        {
          status: 204,
          headers: Dict.fromArray([
            ("Access-Control-Allow-Origin", origin),
            ("Access-Control-Allow-Methods", methods),
            ("Access-Control-Allow-Headers", headers),
          ]),
        },
      )
    } else {
      let response = await next(request)
      response
    }
  }
}

/** Logging middleware */
let logging = (): middleware => {
  async (request, next) => {
    let start = Date.now()
    let response = await next(request)
    let duration = Date.now() -. start
    Console.log(
      `${requestMethod(request)} ${path(request)} - ${Float.toString(duration)}ms`,
    )
    response
  }
}
