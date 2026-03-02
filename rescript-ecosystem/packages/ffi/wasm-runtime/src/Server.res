// HTTP Server for WASM runtime

type config = {
  port: int,
  host: string,
  onListen: Deno.addr => unit,
}

let start = (handler: Deno.request => promise<Deno.response>, ~config: config): unit => {
  let options: Deno.serveOptions = {
    hostname: config.host,
    port: config.port,
    onListen: (addr) => config.onListen({hostname: addr["hostname"], port: addr["port"]}),
  }

  let _ = Deno.serveWithOptions(handler, options)
}
