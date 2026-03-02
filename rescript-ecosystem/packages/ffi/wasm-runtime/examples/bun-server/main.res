// Bun runtime example
// Run with: bun run examples/bun-server/main.mjs

let handler = async (req: Bun.request): promise<Bun.response> => {
  let url = Bun.Request.url(req)
  let urlObj = Bun.Url.make(url)
  let path = Bun.Url.pathname(urlObj)

  switch path {
  | "/" => Bun.Response.text("Hello from Bun!", ())
  | "/json" => {
      let data = Js.Json.object_(Js.Dict.fromArray([
        ("message", Js.Json.string("Running on Bun runtime")),
        ("fast", Js.Json.boolean(true)),
        ("timestamp", Js.Json.number(Bun.now()))
      ]))
      Bun.Response.json(data, ())
    }
  | _ => Bun.Response.text("Not Found", ~status=404, ())
  }
}

let server = Bun.createServer(
  ~port=8000,
  ~hostname="127.0.0.1",
  ~development=true,
  handler
)

Bun.log("Bun server running on http://127.0.0.1:8000")
