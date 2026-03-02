// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

type method =
  | @as("GET") Get
  | @as("POST") Post
  | @as("PUT") Put
  | @as("PATCH") Patch
  | @as("DELETE") Delete
  | @as("HEAD") Head
  | @as("OPTIONS") Options

type server
type request = Fetch.Request.t
type response = Fetch.Response.t

type responseInit = {
  status?: int,
  statusText?: string,
  headers?: Dict.t<string>,
}

type serveOptions = {
  port?: int,
  hostname?: string,
  onListen?: {"port": int, "hostname": string} => unit,
  onError?: Error.t => response,
}

type handler = request => promise<response>

type listenInfo = {
  port: int,
  hostname: string,
}

let serve: (serveOptions, handler) => server
let serveHandler: handler => server
let shutdown: server => promise<unit>
let finished: server => promise<unit>
let addr: server => listenInfo

let method: request => method
let path: request => string
let searchParams: request => URLSearchParams.t
let header: (request, string) => option<string>
let text: request => promise<string>
let json: request => promise<JSON.t>
let requestUrl: request => string
let requestMethod: request => string
let requestHeaders: request => Fetch.Headers.t

let respond: (~status: int=?, ~headers: Dict.t<string>=?, string) => response
let respondJson: (~status: int=?, ~headers: Dict.t<string>=?, JSON.t) => response
let respondHtml: (~status: int=?, ~headers: Dict.t<string>=?, string) => response
let redirect: (~status: int=?, string) => response
let notFound: (~body: string=?) => response
let badRequest: (~body: string=?) => response
let serverError: (~body: string=?) => response
let unauthorized: (~body: string=?) => response
let forbidden: (~body: string=?) => response

type route = {
  method: method,
  pattern: string,
  handler: request => promise<response>,
}

let router: array<route> => handler
let matchPath: (string, string) => bool
let get: (string, request => promise<response>) => route
let post: (string, request => promise<response>) => route
let put: (string, request => promise<response>) => route
let patch: (string, request => promise<response>) => route
let delete: (string, request => promise<response>) => route

type middleware = (request, handler) => promise<response>
let withMiddleware: (handler, middleware) => handler
let cors: (~origin: string=?, ~methods: string=?, ~headers: string=?) => middleware
let logging: unit => middleware
