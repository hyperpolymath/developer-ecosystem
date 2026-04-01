// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Coq-Jr Contributors
//
// Deno HTTP server for Coq-Jr
// Migrated from server.ts to ReScript

/** Port the server listens on */
let port = 8000

// --- Deno FFI bindings ---

/** Deno.readFile returns a promise of Uint8Array */
@scope("Deno") @val
external readFile: string => Js.Promise2.t<Js.TypedArray2.Uint8Array.t> = "readFile"

/** Response constructor options */
type responseInit = {
  headers?: Js.Dict.t<string>,
  status?: int,
}

/** Deno-compatible Response binding */
@new
external makeResponseFromText: (string, responseInit) => Webapi.Fetch.Response.t = "Response"

@new
external makeResponseFromBuffer: (Js.TypedArray2.Uint8Array.t, responseInit) => Webapi.Fetch.Response.t =
  "Response"

/** Deno.serve options */
type serveOptions = {port: int}

/** Deno.serve binding */
@scope("Deno") @val
external serve: (serveOptions, Webapi.Fetch.Request.t => Js.Promise2.t<Webapi.Fetch.Response.t>) => unit =
  "serve"

/** URL constructor for parsing request URLs */
type url = {pathname: string}

@new external makeURL: string => url = "URL"

/** Request helpers */
@get external requestUrl: Webapi.Fetch.Request.t => string = "url"
@get external requestMethod: Webapi.Fetch.Request.t => string = "method"

// --- Dynamic import for compiled ReScript page renderer ---

/** Module shape returned by dynamic import of Main.res.js */
type mainModule = {getPageHtml: unit => string}

@val external importModule: string => Js.Promise2.t<mainModule> = "import"

// --- MIME type lookup ---

/** Map of file extensions to MIME types */
let mimeTypes: Js.Dict.t<string> = Js.Dict.fromArray([
  (".html", "text/html"),
  (".css", "text/css"),
  (".js", "application/javascript"),
  (".json", "application/json"),
  (".png", "image/png"),
  (".jpg", "image/jpeg"),
  (".jpeg", "image/jpeg"),
  (".gif", "image/gif"),
  (".svg", "image/svg+xml"),
  (".ico", "image/x-icon"),
  (".woff", "font/woff"),
  (".woff2", "font/woff2"),
])

/** Extract MIME type from a file path based on its extension */
let getMimeType = (path: string): string => {
  let lastDotIndex = Js.String2.lastIndexOf(path, ".")
  let ext = Js.String2.substr(path, ~from=lastDotIndex)
  switch Js.Dict.get(mimeTypes, ext) {
  | Some(mime) => mime
  | None => "application/octet-stream"
  }
}

// --- Fallback HTML when ReScript sources are not yet compiled ---

/** Fallback page displayed when Main.res.js has not been built */
let fallbackHtml = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Coq-Jr - Build Required</title>
    <style>
      body { font-family: system-ui, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
      code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
      pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
  </head>
  <body>
    <h1>Coq-Jr</h1>
    <p>The ReScript sources need to be compiled first.</p>
    <h2>Quick Start</h2>
    <pre><code>npm install
npm run res:build
deno task serve</code></pre>
  </body>
</html>`

// --- Page renderer (loaded dynamically, with fallback) ---

/** Mutable reference holding the page HTML generator function.
    Initially set to fallback; replaced once Main.res.js loads. */
let getPageHtml: ref<unit => string> = ref(() => fallbackHtml)

/** Attempt to load the compiled ReScript page renderer module */
let _loadMainModule =
  importModule("./src/Main.res.js")
  ->Js.Promise2.then(mod => {
    getPageHtml := mod.getPageHtml
    Js.Promise2.resolve()
  })
  ->Js.Promise2.catch(_err => {
    // Main.res.js not compiled yet; fallback HTML remains active
    Js.Promise2.resolve()
  })

// --- Static file serving ---

/** Attempt to serve a static file from disk. Returns None on failure. */
let serveStaticFile = (path: string): Js.Promise2.t<option<Webapi.Fetch.Response.t>> => {
  readFile(path)
  ->Js.Promise2.then(file => {
    let headers = Js.Dict.fromArray([("content-type", getMimeType(path))])
    let response = makeResponseFromBuffer(file, {headers: headers})
    Js.Promise2.resolve(Some(response))
  })
  ->Js.Promise2.catch(_err => {
    Js.Promise2.resolve(None)
  })
}

// --- Request handler ---

/** Main request handler dispatching to index page, static files, or 404 */
let handler = (request: Webapi.Fetch.Request.t): Js.Promise2.t<Webapi.Fetch.Response.t> => {
  let urlObj = makeURL(requestUrl(request))
  let pathname = urlObj.pathname

  Js.log(`${requestMethod(request)} ${pathname}`)

  // Serve index page
  if pathname == "/" || pathname == "/index.html" {
    let html = getPageHtml.contents()
    let headers = Js.Dict.fromArray([("content-type", "text/html; charset=utf-8")])
    Js.Promise2.resolve(makeResponseFromText(html, {headers: headers}))
  } else {
    // Try to serve static files
    let staticPath = "." ++ pathname
    serveStaticFile(staticPath)->Js.Promise2.then(maybeResponse => {
      switch maybeResponse {
      | Some(response) => Js.Promise2.resolve(response)
      | None =>
        // 404 for everything else
        Js.Promise2.resolve(makeResponseFromText("Not Found", {status: 404}))
      }
    })
  }
}

// --- Server startup ---

Js.log(`Coq-Jr server running at http://localhost:${Belt.Int.toString(port)}/`)
serve({port: port}, handler)
