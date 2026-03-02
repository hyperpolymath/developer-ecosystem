// Minimal hello world HTTP server
// Target bundle size: ~1KB

let handler = async (_req: Deno.request): promise<Deno.response> => {
  Deno.Response.text("Hello, World!", ())
}

Server.simple(~port=8000, handler)
