// Bun Runtime Bindings for ReScript
// Alternative to Deno runtime

// Core types (compatible with Deno types)
type request = Deno.request
type response = Deno.response
type responseInit = Deno.responseInit
type server
type serveOptions = {
  "port": int,
  "hostname": string,
  "development": bool,
}

// Server bindings for Bun
@scope("Bun") @val
external serve: {
  "port": int,
  "hostname": string,
  "fetch": request => promise<response>,
  "development": bool,
} => server = "serve"

// Re-export Request and Response (same as Deno)
module Request = Deno.Request
module Response = Deno.Response

// Console bindings (same as Deno)
let log = Deno.log
let error = Deno.error
let warn = Deno.warn
let info = Deno.info

// Environment bindings
module Env = {
  @scope("Bun") @val external get: string => option<string> = "env.get"
  @scope("Bun") @val external set: (string, string) => unit = "env.set"
}

// File system bindings
module Fs = {
  @scope("Bun") @val external readFile: string => promise<string> = "file"
  @scope("Bun") @val external writeFile: (string, string) => promise<unit> = "write"
}

// Date/Time (same as Deno)
let now = Deno.now

// URL utilities (same as Deno)
module Url = Deno.Url

// Helper to create Bun server
let createServer = (
  ~port=8000,
  ~hostname="127.0.0.1",
  ~development=false,
  handler: request => promise<response>
): server => {
  serve({
    "port": port,
    "hostname": hostname,
    "fetch": handler,
    "development": development,
  })
}
