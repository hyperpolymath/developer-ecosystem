// Static file server with MIME type detection

module MimeTypes = {
  let getMimeType = (filePath: string): string => {
    if Js.String2.endsWith(filePath, ".html") {
      "text/html; charset=utf-8"
    } else if Js.String2.endsWith(filePath, ".css") {
      "text/css; charset=utf-8"
    } else if Js.String2.endsWith(filePath, ".js") || Js.String2.endsWith(filePath, ".mjs") {
      "application/javascript; charset=utf-8"
    } else if Js.String2.endsWith(filePath, ".json") {
      "application/json; charset=utf-8"
    } else if Js.String2.endsWith(filePath, ".png") {
      "image/png"
    } else if Js.String2.endsWith(filePath, ".jpg") || Js.String2.endsWith(filePath, ".jpeg") {
      "image/jpeg"
    } else if Js.String2.endsWith(filePath, ".gif") {
      "image/gif"
    } else if Js.String2.endsWith(filePath, ".svg") {
      "image/svg+xml"
    } else if Js.String2.endsWith(filePath, ".wasm") {
      "application/wasm"
    } else {
      "application/octet-stream"
    }
  }
}

let serveStatic = async (req: Deno.request, ~root="./public"): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)

  // Prevent directory traversal
  let safePath = path->Js.String2.replaceByRe(%re("/\.\./g"), "")

  // Default to index.html for directories
  let filePath = if safePath === "/" {
    `${root}/index.html`
  } else {
    `${root}${safePath}`
  }

  try {
    let content = await Deno.Fs.readFile(filePath)
    let mimeType = MimeTypes.getMimeType(filePath)

    let headers = Js.Dict.fromArray([
      ("content-type", mimeType),
      ("cache-control", "public, max-age=3600")
    ])

    // Note: In a real implementation, we'd create a Response from Uint8Array
    Promise.resolve(Deno.Response.text("File content", ~headers, ()))
  } catch {
  | _ => {
      Promise.resolve(Deno.Response.text("File not found", ~status=404, ()))
    }
  }
}

let router = Router.make()
  ->Router.get("/*", req => serveStatic(req, ~root="./public"))

Server.withRouter(~port=8000, router)
