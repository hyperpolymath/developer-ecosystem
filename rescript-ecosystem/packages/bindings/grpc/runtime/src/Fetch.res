// SPDX-License-Identifier: MPL-2.0
// Fetch API bindings for gRPC-web client

// Response type
module Response = {
  type t

  @send external ok: t => bool = "ok"
  @send external status: t => int = "status"
  @send external json: t => promise<Js.Json.t> = "json"
  @send external text: t => promise<string> = "text"
}

// Headers type
module Headers = {
  type t

  @new external make: unit => t = "Headers"
  @send external set: (t, string, string) => unit = "set"
  @send external get: (t, string) => Nullable.t<string> = "get"

  let fromDict = (dict: Js.Dict.t<string>): t => {
    let headers = make()
    Js.Dict.entries(dict)->Array.forEach(((k, v)) => set(headers, k, v))
    headers
  }
}

// Body type
module Body = {
  type t

  external string: string => t = "%identity"
  external json: Js.Json.t => t = "%identity"
}

// Request init options
type requestInit = {
  method: [#GET | #POST | #PUT | #DELETE | #PATCH],
  headers: Headers.t,
  body: Body.t,
}

// Fetch function
@val external fetch: (string, requestInit) => promise<Response.t> = "fetch"

// Simple GET fetch
@val external fetchGet: string => promise<Response.t> = "fetch"

// Streaming support types
type readableStream
type streamReader
type textDecoder
