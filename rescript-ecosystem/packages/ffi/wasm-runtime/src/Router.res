// HTTP Router for WASM runtime

type method = GET | POST | PUT | DELETE | PATCH

type route = {
  method: method,
  pattern: string,
  handler: (Deno.request, Js.Dict.t<string>) => promise<Deno.response>,
}

type middleware = (Deno.request, Deno.request => promise<Deno.response>) => promise<Deno.response>

type t = {
  routes: array<route>,
  notFoundHandler: Deno.request => promise<Deno.response>,
}

let make = (~notFoundHandler=?, ()): t => {
  routes: [],
  notFoundHandler: switch notFoundHandler {
  | Some(h) => h
  | None => (req => Promise.resolve(Deno.Response.text("Not Found", ~status=404, ())))
  }
}

let addRoute = (router: t, method: method, pattern: string, handler: (Deno.request, Js.Dict.t<string>) => promise<Deno.response>): unit => {
  let _ = Js.Array.push({method, pattern, handler}, router.routes)
}

// Path matching with named parameters
let matchPath = (pattern: string, path: string): option<Js.Dict.t<string>> => {
  let patternParts = pattern->Js.String2.split("/")->Belt.Array.keep(p => p !== "")
  let pathParts = path->Js.String2.split("/")->Belt.Array.keep(p => p !== "")

  if Array.length(patternParts) !== Array.length(pathParts) {
    None
  } else {
    let params = Js.Dict.empty()
    let matches = ref(true)

    for i in 0 to Array.length(patternParts) - 1 {
      let patternPart = Belt.Array.getExn(patternParts, i)
      let pathPart = Belt.Array.getExn(pathParts, i)

      if Js.String2.startsWith(patternPart, ":") {
        let key = Js.String2.sliceToEnd(patternPart, ~from=1)
        Js.Dict.set(params, key, pathPart)
      } else if patternPart !== pathPart {
        matches := false
      }
    }

    if matches.contents { Some(params) } else { None }
  }
}

let handleRequest = async (router: t, request: Deno.request): promise<Deno.response> => {
  let url = Deno.Url.make(Deno.Request.url(request))
  let path = Deno.Url.pathname(url)
  let methodStr = Deno.Request.method(request)

  let methodEnum = switch methodStr {
  | "GET" => Some(GET)
  | "POST" => Some(POST)
  | "PUT" => Some(PUT)
  | "DELETE" => Some(DELETE)
  | "PATCH" => Some(PATCH)
  | _ => None
  }

  switch methodEnum {
  | None => Promise.resolve(Deno.Response.text("Method not allowed", ~status=405, ()))
  | Some(m) => {
      let rec findMatch = (idx: int): promise<Deno.response> => {
        if idx >= Array.length(router.routes) {
          router.notFoundHandler(request)
        } else {
          let route = Belt.Array.getExn(router.routes, idx)
          if route.method == m {
            switch matchPath(route.pattern, path) {
            | Some(params) => route.handler(request, params)
            | None => findMatch(idx + 1)
            }
          } else {
            findMatch(idx + 1)
          }
        }
      }
      findMatch(0)
    }
  }
}
