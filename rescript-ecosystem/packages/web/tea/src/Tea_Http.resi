// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
HTTP commands for TEA applications.
Provides a type-safe way to make HTTP requests and decode responses.
")

@ocaml.doc("HTTP methods")
type method =
  | GET
  | POST
  | PUT
  | PATCH
  | DELETE
  | HEAD
  | OPTIONS

@ocaml.doc("HTTP headers as key-value pairs")
type header = (string, string)

@ocaml.doc("HTTP error types")
type httpError =
  | BadUrl(string)
  | Timeout
  | NetworkError(string)
  | BadStatus(int, string)
  | BadBody(Tea_Json.decodeError)

@ocaml.doc("Request configuration")
type request<'a>

@ocaml.doc("Response type with full metadata")
type response<'a> = {
  url: string,
  status: int,
  statusText: string,
  headers: dict<string>,
  body: 'a,
}

// ============================================================================
// Request builders
// ============================================================================

@ocaml.doc("Create a GET request")
let get: (string, Tea_Json.decoder<'a>) => request<'a>

@ocaml.doc("Create a POST request with JSON body")
let post: (string, JSON.t, Tea_Json.decoder<'a>) => request<'a>

@ocaml.doc("Create a PUT request with JSON body")
let put: (string, JSON.t, Tea_Json.decoder<'a>) => request<'a>

@ocaml.doc("Create a PATCH request with JSON body")
let patch: (string, JSON.t, Tea_Json.decoder<'a>) => request<'a>

@ocaml.doc("Create a DELETE request")
let delete: (string, Tea_Json.decoder<'a>) => request<'a>

// ============================================================================
// Request modifiers
// ============================================================================

@ocaml.doc("Add a header to the request")
let withHeader: (request<'a>, string, string) => request<'a>

@ocaml.doc("Add multiple headers to the request")
let withHeaders: (request<'a>, array<header>) => request<'a>

@ocaml.doc("Set request timeout in milliseconds")
let withTimeout: (request<'a>, int) => request<'a>

@ocaml.doc("Set the request body")
let withBody: (request<'a>, JSON.t) => request<'a>

// ============================================================================
// Error helpers
// ============================================================================

@ocaml.doc("Convert HTTP error to string for display")
let errorToString: httpError => string

// ============================================================================
// Send commands
// ============================================================================

@ocaml.doc("Send an HTTP request and handle the result")
let send: (request<'a>, result<'a, httpError> => 'msg) => Tea_Cmd.t<'msg>

@ocaml.doc("Send a request expecting a full response object")
let sendWithResponse: (request<'a>, result<response<'a>, httpError> => 'msg) => Tea_Cmd.t<'msg>

// ============================================================================
// Convenience functions
// ============================================================================

@ocaml.doc("Simple GET request for a string response")
let getString: (string, result<string, httpError> => 'msg) => Tea_Cmd.t<'msg>

@ocaml.doc("GET request with JSON decoder")
let getJson: (string, Tea_Json.decoder<'a>, result<'a, httpError> => 'msg) => Tea_Cmd.t<'msg>

@ocaml.doc("POST request with JSON body and decoder")
let postJson: (
  string,
  JSON.t,
  Tea_Json.decoder<'a>,
  result<'a, httpError> => 'msg,
) => Tea_Cmd.t<'msg>
