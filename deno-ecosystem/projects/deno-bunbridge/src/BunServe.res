// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// BunServe - Bun.serve() compatible interface

type serverOptions = {
  port?: int,
  hostname?: string,
  fetch: Request.t => promise<Response.t>,
  error?: Exn.t => promise<Response.t>,
}

type server = {
  port: int,
  hostname: string,
  stop: unit => unit,
}

let serve = (options: serverOptions): server => {
  let port = Option.getOr(options.port, 3000)
  let hostname = Option.getOr(options.hostname, "localhost")

  let handler = async (request: Request.t): Response.t => {
    try {
      await options.fetch(request)
    } catch {
    | exn =>
      switch options.error {
      | Some(errorHandler) => await errorHandler(Obj.magic(exn))
      | None => Response.make("Internal Server Error", ~options={status: 500})
      }
    }
  }

  let denoServer = Deno.Serve.serve({port: port, hostname: hostname}, handler)

  {
    port: port,
    hostname: hostname,
    stop: () => denoServer.shutdown(),
  }
}
