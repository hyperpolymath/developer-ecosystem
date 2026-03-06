// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Http.resi - Interface for Tauri HTTP plugin bindings

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

let responseUrl: rawResponse => string
let responseStatus: rawResponse => int
let responseOk: rawResponse => bool
let responseHeaders: rawResponse => Dict.t<string>
let responseText: rawResponse => promise<string>
let responseJson: rawResponse => promise<JSON.t>
let responseBytes: rawResponse => promise<Uint8Array.t>

// ============================================================================
// HTTP Client Functions
// ============================================================================

/** Make an HTTP request and return raw response */
let fetch: (string, ~options: requestOptions=?) => promise<rawResponse>

// ============================================================================
// Helper Functions
// ============================================================================

/** Simple GET request returning text */
let getText: string => promise<string>

/** Simple GET request returning JSON */
let getJson: string => promise<JSON.t>

/** Simple GET request returning bytes */
let getBytes: string => promise<Uint8Array.t>

/** POST request with JSON body */
let postJson: (string, JSON.t) => promise<JSON.t>

/** POST request with form data */
let postForm: (string, Dict.t<string>) => promise<JSON.t>

/** PUT request with JSON body */
let putJson: (string, JSON.t) => promise<JSON.t>

/** DELETE request */
let delete: string => promise<response>

// ============================================================================
// Request Builder Pattern
// ============================================================================

module Request: {
  type t

  /** Create a new request builder */
  let make: string => t

  /** Set the HTTP method */
  let method: (t, httpMethod) => t

  /** Set a header */
  let header: (t, string, string) => t

  /** Set multiple headers */
  let headers: (t, Dict.t<string>) => t

  /** Set a query parameter */
  let query: (t, string, string) => t

  /** Set the request body as JSON */
  let json: (t, JSON.t) => t

  /** Set the request body as text */
  let text: (t, string) => t

  /** Set the request body as form data */
  let form: (t, Dict.t<string>) => t

  /** Set the request body as bytes */
  let bytes: (t, Uint8Array.t) => t

  /** Set request timeout in milliseconds */
  let timeout: (t, int) => t

  /** Set max redirections */
  let maxRedirections: (t, int) => t

  /** Set bearer token auth */
  let bearerAuth: (t, string) => t

  /** Set basic auth */
  let basicAuth: (t, string, string) => t

  /** Send the request and get raw response */
  let send: t => promise<rawResponse>

  /** Send and get text response */
  let sendText: t => promise<string>

  /** Send and get JSON response */
  let sendJson: t => promise<JSON.t>

  /** Send and get bytes response */
  let sendBytes: t => promise<Uint8Array.t>
}
