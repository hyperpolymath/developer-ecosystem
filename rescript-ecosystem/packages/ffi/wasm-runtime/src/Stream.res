// Stream support for WASM runtime

let handleStream = async (_request: Deno.request): promise<Deno.response> => {
  let headersDict = Js.Dict.empty()
  Js.Dict.set(headersDict, "content-type", "application/octet-stream")
  
  let init: Deno.responseInit = {
    status: 200,
    statusText: "OK",
    headers: headersDict
  }

  Promise.resolve(Deno.Response.make("", ~init))
}

let handleSSE = async (_request: Deno.request): promise<Deno.response> => {
  let headersDict = Js.Dict.empty()
  Js.Dict.set(headersDict, "content-type", "text/event-stream")
  Js.Dict.set(headersDict, "cache-control", "no-cache")
  Js.Dict.set(headersDict, "connection", "keep-alive")

  let init: Deno.responseInit = {
    status: 200,
    statusText: "OK",
    headers: headersDict
  }

  Promise.resolve(Deno.Response.make("", ~init))
}
