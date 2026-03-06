// Deno Runtime Bindings for ReScript

// Core types
type request
type response
type responseInit = {
  status: int,
  statusText: string,
  headers: Js.Dict.t<string>,
}
type server
type serveOptions = {
  hostname: string,
  port: int,
  onListen: {"hostname": string, "port": int} => unit,
}
type addr = {hostname: string, port: int}

// HTTP Request bindings
module Request = {
  @get external method: request => string = "method"
  @get external url: request => string = "url"
  @get external headers: request => Js.Dict.t<string> = "headers"
  @send external text: request => promise<string> = "text"
  @send external json: request => promise<Js.Json.t> = "json"
  @send external arrayBuffer: request => promise<Js.Typed_array.ArrayBuffer.t> = "arrayBuffer"
  @send external formData: request => promise<'a> = "formData"
}

// HTTP Response bindings
module Response = {
  @new external make: (string, ~init: responseInit=?) => response = "Response"
  @new external makeWithJson: (Js.Json.t, ~init: responseInit=?) => response = "Response"

  type t = response

  let json = (data: Js.Json.t, ~status=200, ~headers=?, ()): response => {
    let headersDict = Js.Dict.empty()
    Js.Dict.set(headersDict, "content-type", "application/json")

    switch headers {
    | Some(h) =>
      Js.Dict.entries(h)->Array.forEach(((key, value)) => {
        Js.Dict.set(headersDict, key, value)
      })
    | None => ()
    }

    let init = {
      status: status,
      statusText: "OK",
      headers: headersDict
    }

    makeWithJson(data, ~init)
  }

  let text = (data: string, ~status=200, ~headers=?, ()): response => {
    let headersDict = Js.Dict.empty()
    Js.Dict.set(headersDict, "content-type", "text/plain; charset=utf-8")

    switch headers {
    | Some(h) =>
      Js.Dict.entries(h)->Array.forEach(((key, value)) => {
        Js.Dict.set(headersDict, key, value)
      })
    | None => ()
    }

    let init = {
      status: status,
      statusText: "OK",
      headers: headersDict
    }

    make(data, ~init)
  }

  let html = (data: string, ~status=200, ~headers=?, ()): response => {
    let headersDict = Js.Dict.empty()
    Js.Dict.set(headersDict, "content-type", "text/html; charset=utf-8")

    switch headers {
    | Some(h) =>
      Js.Dict.entries(h)->Array.forEach(((key, value)) => {
        Js.Dict.set(headersDict, key, value)
      })
    | None => ()
    }

    let init = {
      status: status,
      statusText: "OK",
      headers: headersDict
    }

    make(data, ~init)
  }
}

// Server bindings
@scope("Deno") @val
external serve: (
  request => promise<response>,
  ~options: serveOptions=?
) => server = "serve"

@scope("Deno") @val
external serveWithOptions: (
  request => promise<response>,
  serveOptions
) => server = "serve"

// Console bindings
@scope("console") @val external log: 'a => unit = "log"
@scope("console") @val external error: 'a => unit = "error"
@scope("console") @val external warn: 'a => unit = "warn"
@scope("console") @val external info: 'a => unit = "info"

// Environment bindings
module Env = {
  @scope("Deno") @val external get: string => option<string> = "env.get"
  @scope("Deno") @val external set: (string, string) => unit = "env.set"
}

// File system bindings
module Fs = {
  @scope("Deno") @val external readTextFile: string => promise<string> = "readTextFile"
  @scope("Deno") @val external writeTextFile: (string, string) => promise<unit> = "writeTextFile"
  @scope("Deno") @val external readFile: string => promise<Js.Typed_array.Uint8Array.t> = "readFile"
  @scope("Deno") @val external writeFile: (string, Js.Typed_array.Uint8Array.t) => promise<unit> = "writeFile"
}

// Date/Time
@val external now: unit => float = "Date.now"

// URL utilities
module Url = {
  @new external make: string => 'url = "URL"
  @get external pathname: 'url => string = "pathname"
  @get external search: 'url => string = "search"
  @get external searchParams: 'url => 'searchParams = "searchParams"
  @send external get: ('searchParams, string) => option<string> = "get"
  @send external getAll: ('searchParams, string) => array<string> = "getAll"
}
