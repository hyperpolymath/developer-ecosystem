// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
HTTP commands for TEA applications.
Provides a type-safe way to make HTTP requests and decode responses.
")

// ============================================================================
// Types
// ============================================================================

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
type request<'a> = {
  method: method,
  url: string,
  headers: array<header>,
  body: option<JSON.t>,
  timeout: option<int>,
  decoder: Tea_Json.decoder<'a>,
}

@ocaml.doc("Response type")
type response<'a> = {
  url: string,
  status: int,
  statusText: string,
  headers: dict<string>,
  body: 'a,
}

// ============================================================================
// Internal: Fetch bindings
// ============================================================================

module Internal = {
  type fetchResponse

  @val external fetch: (string, 'options) => promise<fetchResponse> = "fetch"

  @get external responseOk: fetchResponse => bool = "ok"
  @get external responseStatus: fetchResponse => int = "status"
  @get external responseStatusText: fetchResponse => string = "statusText"
  @get external responseUrl: fetchResponse => string = "url"
  @send external responseText: fetchResponse => promise<string> = "text"
  @send external responseJson: fetchResponse => promise<JSON.t> = "json"

  // Get headers as dict
  let getHeaders: fetchResponse => dict<string> = %raw(`
    function(response) {
      const headers = {};
      response.headers.forEach((value, key) => {
        headers[key] = value;
      });
      return headers;
    }
  `)

  let methodToString = method =>
    switch method {
    | GET => "GET"
    | POST => "POST"
    | PUT => "PUT"
    | PATCH => "PATCH"
    | DELETE => "DELETE"
    | HEAD => "HEAD"
    | OPTIONS => "OPTIONS"
    }

  let buildFetchOptions = (request: request<'a>) => {
    let options = Dict.make()

    Dict.set(options, "method", JSON.Encode.string(methodToString(request.method)))

    // Headers
    if Belt.Array.length(request.headers) > 0 {
      let headersDict = Dict.make()
      Belt.Array.forEach(request.headers, ((key, value)) => {
        Dict.set(headersDict, key, value)
      })
      Dict.set(options, "headers", Obj.magic(headersDict))
    }

    // Body
    switch request.body {
    | Some(body) => Dict.set(options, "body", Obj.magic(JSON.stringify(body)))
    | None => ()
    }

    options
  }

  // Timeout wrapper
  let withTimeout = (promise: promise<'a>, timeoutMs: int): promise<'a> => {
    %raw(`
      function(promise, timeoutMs) {
        return new Promise((resolve, reject) => {
          const timer = setTimeout(() => {
            reject(new Error('TIMEOUT'));
          }, timeoutMs);

          promise.then(
            (value) => {
              clearTimeout(timer);
              resolve(value);
            },
            (error) => {
              clearTimeout(timer);
              reject(error);
            }
          );
        });
      }
    `)(promise, timeoutMs)
  }
}

// ============================================================================
// Request builders
// ============================================================================

@ocaml.doc("Create a GET request")
let get = (url: string, decoder: Tea_Json.decoder<'a>): request<'a> => {
  method: GET,
  url,
  headers: [],
  body: None,
  timeout: None,
  decoder,
}

@ocaml.doc("Create a POST request with JSON body")
let post = (url: string, body: JSON.t, decoder: Tea_Json.decoder<'a>): request<'a> => {
  method: POST,
  url,
  headers: [("Content-Type", "application/json")],
  body: Some(body),
  timeout: None,
  decoder,
}

@ocaml.doc("Create a PUT request with JSON body")
let put = (url: string, body: JSON.t, decoder: Tea_Json.decoder<'a>): request<'a> => {
  method: PUT,
  url,
  headers: [("Content-Type", "application/json")],
  body: Some(body),
  timeout: None,
  decoder,
}

@ocaml.doc("Create a PATCH request with JSON body")
let patch = (url: string, body: JSON.t, decoder: Tea_Json.decoder<'a>): request<'a> => {
  method: PATCH,
  url,
  headers: [("Content-Type", "application/json")],
  body: Some(body),
  timeout: None,
  decoder,
}

@ocaml.doc("Create a DELETE request")
let delete = (url: string, decoder: Tea_Json.decoder<'a>): request<'a> => {
  method: DELETE,
  url,
  headers: [],
  body: None,
  timeout: None,
  decoder,
}

// ============================================================================
// Request modifiers
// ============================================================================

@ocaml.doc("Add a header to the request")
let withHeader = (request: request<'a>, key: string, value: string): request<'a> => {
  ...request,
  headers: Belt.Array.concat(request.headers, [(key, value)]),
}

@ocaml.doc("Add multiple headers to the request")
let withHeaders = (request: request<'a>, headers: array<header>): request<'a> => {
  ...request,
  headers: Belt.Array.concat(request.headers, headers),
}

@ocaml.doc("Set request timeout in milliseconds")
let withTimeout = (request: request<'a>, timeoutMs: int): request<'a> => {
  ...request,
  timeout: Some(timeoutMs),
}

@ocaml.doc("Set the request body")
let withBody = (request: request<'a>, body: JSON.t): request<'a> => {
  ...request,
  body: Some(body),
  headers: if !Belt.Array.some(request.headers, ((k, _)) => k == "Content-Type") {
    Belt.Array.concat(request.headers, [("Content-Type", "application/json")])
  } else {
    request.headers
  },
}

// ============================================================================
// Error helpers
// ============================================================================

@ocaml.doc("Convert HTTP error to string for display")
let errorToString = (error: httpError): string =>
  switch error {
  | BadUrl(url) => `Invalid URL: ${url}`
  | Timeout => "Request timed out"
  | NetworkError(msg) => `Network error: ${msg}`
  | BadStatus(status, statusText) => `HTTP ${Belt.Int.toString(status)}: ${statusText}`
  | BadBody(decodeError) => `Failed to decode response: ${Tea_Json.errorToString(decodeError)}`
  }

// ============================================================================
// Send commands
// ============================================================================

@ocaml.doc("Send an HTTP request and handle the result")
let send = (request: request<'a>, toMsg: result<'a, httpError> => 'msg): Tea_Cmd.t<'msg> => {
  Tea_Cmd.effect(dispatch => {
    let fetchPromise = Internal.fetch(request.url, Internal.buildFetchOptions(request))

    let promiseWithTimeout = switch request.timeout {
    | Some(ms) => Internal.withTimeout(fetchPromise, ms)
    | None => fetchPromise
    }

    let _ =
      promiseWithTimeout
      ->Promise.then(response => {
        if Internal.responseOk(response) {
          Internal.responseJson(response)
          ->Promise.then(json => {
            switch Tea_Json.decodeValue(request.decoder, json) {
            | Ok(value) => dispatch(toMsg(Ok(value)))
            | Error(decodeError) => dispatch(toMsg(Error(BadBody(decodeError))))
            }
            Promise.resolve()
          })
          ->Promise.catch(_ => {
            dispatch(toMsg(Error(BadBody(Tea_Json.Failure("Invalid JSON", JSON.Encode.null)))))
            Promise.resolve()
          })
        } else {
          dispatch(
            toMsg(
              Error(
                BadStatus(
                  Internal.responseStatus(response),
                  Internal.responseStatusText(response),
                ),
              ),
            ),
          )
          Promise.resolve()
        }
      })
      ->Promise.catch(error => {
        let errorMsg = Obj.magic(error)["message"]
        let httpError = if errorMsg == "TIMEOUT" {
          Timeout
        } else {
          NetworkError(errorMsg)
        }
        dispatch(toMsg(Error(httpError)))
        Promise.resolve()
      })
  })
}

@ocaml.doc("Send a request expecting a full response object")
let sendWithResponse = (
  request: request<'a>,
  toMsg: result<response<'a>, httpError> => 'msg,
): Tea_Cmd.t<'msg> => {
  Tea_Cmd.effect(dispatch => {
    let fetchPromise = Internal.fetch(request.url, Internal.buildFetchOptions(request))

    let promiseWithTimeout = switch request.timeout {
    | Some(ms) => Internal.withTimeout(fetchPromise, ms)
    | None => fetchPromise
    }

    let _ =
      promiseWithTimeout
      ->Promise.then(fetchResponse => {
        if Internal.responseOk(fetchResponse) {
          Internal.responseJson(fetchResponse)
          ->Promise.then(json => {
            switch Tea_Json.decodeValue(request.decoder, json) {
            | Ok(value) => {
                let response: response<'a> = {
                  url: Internal.responseUrl(fetchResponse),
                  status: Internal.responseStatus(fetchResponse),
                  statusText: Internal.responseStatusText(fetchResponse),
                  headers: Internal.getHeaders(fetchResponse),
                  body: value,
                }
                dispatch(toMsg(Ok(response)))
              }
            | Error(decodeError) => dispatch(toMsg(Error(BadBody(decodeError))))
            }
            Promise.resolve()
          })
          ->Promise.catch(_ => {
            dispatch(toMsg(Error(BadBody(Tea_Json.Failure("Invalid JSON", JSON.Encode.null)))))
            Promise.resolve()
          })
        } else {
          dispatch(
            toMsg(
              Error(
                BadStatus(
                  Internal.responseStatus(fetchResponse),
                  Internal.responseStatusText(fetchResponse),
                ),
              ),
            ),
          )
          Promise.resolve()
        }
      })
      ->Promise.catch(error => {
        let errorMsg = Obj.magic(error)["message"]
        let httpError = if errorMsg == "TIMEOUT" {
          Timeout
        } else {
          NetworkError(errorMsg)
        }
        dispatch(toMsg(Error(httpError)))
        Promise.resolve()
      })
  })
}

// ============================================================================
// Convenience functions
// ============================================================================

@ocaml.doc("Simple GET request - just URL and decoder")
let getString = (url: string, toMsg: result<string, httpError> => 'msg): Tea_Cmd.t<'msg> => {
  send(get(url, Tea_Json.string), toMsg)
}

@ocaml.doc("GET request with JSON decoder")
let getJson = (
  url: string,
  decoder: Tea_Json.decoder<'a>,
  toMsg: result<'a, httpError> => 'msg,
): Tea_Cmd.t<'msg> => {
  send(get(url, decoder), toMsg)
}

@ocaml.doc("POST request with JSON body and decoder")
let postJson = (
  url: string,
  body: JSON.t,
  decoder: Tea_Json.decoder<'a>,
  toMsg: result<'a, httpError> => 'msg,
): Tea_Cmd.t<'msg> => {
  send(post(url, body, decoder), toMsg)
}
