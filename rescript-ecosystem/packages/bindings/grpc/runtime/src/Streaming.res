// SPDX-License-Identifier: MPL-2.0
// Streaming support for gRPC-web server streaming RPCs
// Uses NDJSON (Newline Delimited JSON) format for streaming responses

// Callback types for stream events
type streamCallbacks = {
  onMessage: Js.Json.t => unit,
  onError: string => unit,
  onComplete: unit => unit,
}

// HTTP method type
type httpMethod = [#GET | #POST | #PUT | #DELETE | #PATCH]

// TextDecoder binding
@new external makeTextDecoder: unit => Fetch.textDecoder = "TextDecoder"
@send external decode: (Fetch.textDecoder, Js.Typed_array.Uint8Array.t) => string = "decode"

// ReadableStream bindings
@get external getBody: Fetch.Response.t => Js.Nullable.t<Fetch.readableStream> = "body"
@send external getReader: Fetch.readableStream => Fetch.streamReader = "getReader"

// StreamReader read result
type readResult = {
  done: bool,
  value: Js.Nullable.t<Js.Typed_array.Uint8Array.t>,
}

@send external read: Fetch.streamReader => promise<readResult> = "read"
@send external cancel: Fetch.streamReader => promise<unit> = "cancel"

// Fetch NDJSON stream
// NDJSON format: each line is a complete JSON object
let fetchNdjson = (
  ~url: string,
  ~method: httpMethod,
  ~headers: Js.Dict.t<string>,
  ~body: string,
  ~onMessage: Js.Json.t => unit,
  ~onError: string => unit,
  ~onComplete: unit => unit,
): promise<unit> => {
  let processStream = async () => {
    try {
      let response = await Fetch.fetch(
        url,
        {
          method: method,
          headers: Fetch.Headers.fromDict(headers),
          body: Fetch.Body.string(body),
        },
      )

      if !Fetch.Response.ok(response) {
        let status = Fetch.Response.status(response)
        let text = await Fetch.Response.text(response)
        onError(`HTTP ${Int.toString(status)}: ${text}`)
      } else {
        // Get the response body as a readable stream
        switch Js.Nullable.toOption(getBody(response)) {
        | None =>
          onError("No response body")
        | Some(bodyStream) =>
          let reader = getReader(bodyStream)
          let decoder = makeTextDecoder()
          let buffer = ref("")

          // Read stream chunks
          let rec readLoop = async () => {
            let result = await read(reader)
            if result.done {
              // Process any remaining data in buffer
              if String.length(buffer.contents) > 0 {
                let trimmed = String.trim(buffer.contents)
                if String.length(trimmed) > 0 {
                  try {
                    let json = Js.Json.parseExn(trimmed)
                    onMessage(json)
                  } catch {
                  | _ => onError(`Failed to parse JSON: ${trimmed}`)
                  }
                }
              }
              onComplete()
            } else {
              // Decode the chunk and add to buffer
              switch Js.Nullable.toOption(result.value) {
              | None => await readLoop()
              | Some(chunk) =>
                let text = decode(decoder, chunk)
                buffer := buffer.contents ++ text

                // Process complete lines
                let lines = String.split(buffer.contents, "\n")
                let numLines = Array.length(lines)

                // Process all complete lines (all but the last)
                for i in 0 to numLines - 2 {
                  let line = String.trim(lines->Array.getUnsafe(i))
                  if String.length(line) > 0 {
                    try {
                      let json = Js.Json.parseExn(line)
                      onMessage(json)
                    } catch {
                    | _ => onError(`Failed to parse JSON: ${line}`)
                    }
                  }
                }

                // Keep the last (potentially incomplete) line in buffer
                buffer := lines->Array.getUnsafe(numLines - 1)

                await readLoop()
              }
            }
          }

          await readLoop()
        }
      }
    } catch {
    | Exn.Error(exn) => onError(Exn.message(exn)->Option.getOr("Unknown error"))
    | _ => onError("Unknown error")
    }
  }

  processStream()
}

// Create an async iterator from a stream
// This is an alternative API using async generators
type iteratorResult<'a> = {
  done: bool,
  value: option<'a>,
}

type asyncIterator<'a> = {
  next: unit => promise<iteratorResult<'a>>,
}

let createAsyncIterator = (
  ~url: string,
  ~method: httpMethod,
  ~headers: Js.Dict.t<string>,
  ~body: string,
  ~decode: Js.Json.t => option<'a>,
): asyncIterator<result<'a, string>> => {
  let queue: array<result<'a, string>> = []
  let resolvers: array<result<'a, string> => unit> = []
  let completed = ref(false)
  let error = ref(None)

  // Start the stream
  let _ = fetchNdjson(
    ~url,
    ~method,
    ~headers,
    ~body,
    ~onMessage=json => {
      let item = switch decode(json) {
      | Some(v) => Ok(v)
      | None => Error("Failed to decode message")
      }
      switch Array.shift(resolvers) {
      | Some(resolve) => resolve(item)
      | None => Array.push(queue, item)->ignore
      }
    },
    ~onError=msg => {
      error := Some(msg)
      switch Array.shift(resolvers) {
      | Some(resolve) => resolve(Error(msg))
      | None => ()
      }
    },
    ~onComplete=() => {
      completed := true
      // Resolve any waiting consumers
      Array.forEach(resolvers, resolve => {
        resolve(Error("Stream completed"))
      })
    },
  )

  {
    next: () => {
      Promise.make((resolve, _) => {
        if completed.contents && Array.length(queue) == 0 {
          resolve({done: true, value: None})
        } else {
          switch Array.shift(queue) {
          | Some(item) => resolve({done: false, value: Some(item)})
          | None =>
            // Wait for next item
            Array.push(resolvers, item => {
              resolve({done: false, value: Some(item)})
            })->ignore
          }
        }
      })
    },
  }
}
