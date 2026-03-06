// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Http.res - ReScript bindings for @tauri-apps/plugin-http

open RescriptCore

// ============================================================================
// HTTP Types
// ============================================================================

/** HTTP Methods */
type httpMethod =
  | @as("GET") Get
  | @as("POST") Post
  | @as("PUT") Put
  | @as("PATCH") Patch
  | @as("DELETE") Delete
  | @as("HEAD") Head
  | @as("OPTIONS") Options

/** Response type for how to handle the response body */
type responseType =
  | @as(1) Text
  | @as(2) Json
  | @as(3) Binary

/** Request body type */
type rec body =
  | @as("Text") TextBody(string)
  | @as("Bytes") BytesBody(Uint8Array.t)
  | @as("Form") FormBody(Dict.t<string>)
  | @as("Json") JsonBody(JSON.t)

/** HTTP request options */
and requestOptions = {
  method?: httpMethod,
  headers?: Dict.t<string>,
  query?: Dict.t<string>,
  body?: body,
  timeout?: int,
  responseType?: responseType,
  maxRedirections?: int,
  connectTimeout?: int,
}

/** HTTP Response */
type response = {
  url: string,
  status: int,
  ok: bool,
  headers: Dict.t<string>,
}

// ============================================================================
// Raw Response Access
// ============================================================================

/** Raw response with body access methods */
type rawResponse

@send external responseUrl: rawResponse => string = "url"
@send external responseStatus: rawResponse => int = "status"
@send external responseOk: rawResponse => bool = "ok"
@send external responseHeaders: rawResponse => Dict.t<string> = "headers"
@send external responseText: rawResponse => promise<string> = "text"
@send external responseJson: rawResponse => promise<JSON.t> = "json"
@send external responseBytes: rawResponse => promise<Uint8Array.t> = "bytes"

// ============================================================================
// HTTP Client Functions
// ============================================================================

/** Make an HTTP request and return raw response */
@module("@tauri-apps/plugin-http")
external fetch: (string, ~options: requestOptions=?) => promise<rawResponse> = "fetch"

// ============================================================================
// Helper Functions
// ============================================================================

/** Simple GET request returning text */
let getText = async (url: string) => {
  let res = await fetch(url, ~options={method: Get})
  await responseText(res)
}

/** Simple GET request returning JSON */
let getJson = async (url: string) => {
  let res = await fetch(url, ~options={method: Get})
  await responseJson(res)
}

/** Simple GET request returning bytes */
let getBytes = async (url: string) => {
  let res = await fetch(url, ~options={method: Get})
  await responseBytes(res)
}

/** POST request with JSON body */
let postJson = async (url: string, body: JSON.t) => {
  let res = await fetch(url, ~options={
    method: Post,
    headers: Dict.fromArray([("Content-Type", "application/json")]),
    body: JsonBody(body),
  })
  await responseJson(res)
}

/** POST request with form data */
let postForm = async (url: string, data: Dict.t<string>) => {
  let res = await fetch(url, ~options={
    method: Post,
    headers: Dict.fromArray([("Content-Type", "application/x-www-form-urlencoded")]),
    body: FormBody(data),
  })
  await responseJson(res)
}

/** PUT request with JSON body */
let putJson = async (url: string, body: JSON.t) => {
  let res = await fetch(url, ~options={
    method: Put,
    headers: Dict.fromArray([("Content-Type", "application/json")]),
    body: JsonBody(body),
  })
  await responseJson(res)
}

/** DELETE request */
let delete = async (url: string) => {
  let res = await fetch(url, ~options={method: Delete})
  {
    url: responseUrl(res),
    status: responseStatus(res),
    ok: responseOk(res),
    headers: responseHeaders(res),
  }
}

// Base64 encoding helper
@val external btoa: string => string = "btoa"

// ============================================================================
// Request Builder Pattern
// ============================================================================

module Request = {
  type t = {
    url: string,
    mutable method_: httpMethod,
    mutable headers: Dict.t<string>,
    mutable query: Dict.t<string>,
    mutable body: option<body>,
    mutable timeout: option<int>,
    mutable maxRedirections: option<int>,
  }

  /** Create a new request builder */
  let make = (url: string) => {
    {
      url,
      method_: Get,
      headers: Dict.make(),
      query: Dict.make(),
      body: None,
      timeout: None,
      maxRedirections: None,
    }
  }

  /** Set the HTTP method */
  let method = (req: t, method: httpMethod) => {
    req.method_ = method
    req
  }

  /** Set a header */
  let header = (req: t, key: string, value: string) => {
    Dict.set(req.headers, key, value)
    req
  }

  /** Set multiple headers */
  let headers = (req: t, newHeaders: Dict.t<string>) => {
    Dict.forEachWithKey(newHeaders, (key, value) => {
      Dict.set(req.headers, key, value)
    })
    req
  }

  /** Set a query parameter */
  let query = (req: t, key: string, value: string) => {
    Dict.set(req.query, key, value)
    req
  }

  /** Set the request body as JSON */
  let json = (req: t, data: JSON.t) => {
    req.body = Some(JsonBody(data))
    Dict.set(req.headers, "Content-Type", "application/json")
    req
  }

  /** Set the request body as text */
  let text = (req: t, data: string) => {
    req.body = Some(TextBody(data))
    req
  }

  /** Set the request body as form data */
  let form = (req: t, data: Dict.t<string>) => {
    req.body = Some(FormBody(data))
    Dict.set(req.headers, "Content-Type", "application/x-www-form-urlencoded")
    req
  }

  /** Set the request body as bytes */
  let bytes = (req: t, data: Uint8Array.t) => {
    req.body = Some(BytesBody(data))
    req
  }

  /** Set request timeout in milliseconds */
  let timeout = (req: t, ms: int) => {
    req.timeout = Some(ms)
    req
  }

  /** Set max redirections */
  let maxRedirections = (req: t, count: int) => {
    req.maxRedirections = Some(count)
    req
  }

  /** Set bearer token auth */
  let bearerAuth = (req: t, token: string) => {
    header(req, "Authorization", `Bearer ${token}`)
  }

  /** Set basic auth */
  let basicAuth = (req: t, username: string, password: string) => {
    let encoded = btoa(`${username}:${password}`)
    header(req, "Authorization", `Basic ${encoded}`)
  }

  /** Send the request and get raw response */
  let send = async (req: t) => {
    let options: requestOptions = {
      method: req.method_,
      headers: req.headers,
      query: req.query,
      body: ?req.body,
      timeout: ?req.timeout,
      maxRedirections: ?req.maxRedirections,
    }
    await fetch(req.url, ~options)
  }

  /** Send and get text response */
  let sendText = async (req: t) => {
    let res = await send(req)
    await responseText(res)
  }

  /** Send and get JSON response */
  let sendJson = async (req: t) => {
    let res = await send(req)
    await responseJson(res)
  }

  /** Send and get bytes response */
  let sendBytes = async (req: t) => {
    let res = await send(req)
    await responseBytes(res)
  }
}
