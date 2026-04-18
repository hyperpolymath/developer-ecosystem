// SPDX-License-Identifier: Apache-2.0
// Url.res - Parsed URL representation for client-side routing

type t = {
  path: list<string>,
  query: Belt.Map.String.t<string>,
  fragment: option<string>,
}

// Helper: split path string into segments, filtering empty strings
let pathToSegments = (pathStr: string): list<string> => {
  pathStr
  ->Js.String2.split("/")
  ->Belt.Array.keep(s => s != "")
  ->Belt.List.fromArray
}

// Helper: parse query string into map
let parseQuery = (queryStr: string): Belt.Map.String.t<string> => {
  if queryStr == "" {
    Belt.Map.String.empty
  } else {
    queryStr
    ->Js.String2.split("&")
    ->Belt.Array.reduce(Belt.Map.String.empty, (acc, pair) => {
      switch Js.String2.split(pair, "=") {
      | [key, value] => acc->Belt.Map.String.set(key, Js.Global.decodeURIComponent(value))
      | [key] => acc->Belt.Map.String.set(key, "")
      | _ => acc
      }
    })
  }
}

let fromString = (urlStr: string): t => {
  // Handle fragment
  let (withoutFragment, fragment) = switch Js.String2.split(urlStr, "#") {
  | [main, frag] => (main, Some(frag))
  | [main] => (main, None)
  | _ => (urlStr, None)
  }

  // Handle query string
  let (pathPart, query) = switch Js.String2.split(withoutFragment, "?") {
  | [path, queryStr] => (path, parseQuery(queryStr))
  | [path] => (path, Belt.Map.String.empty)
  | _ => (withoutFragment, Belt.Map.String.empty)
  }

  {
    path: pathToSegments(pathPart),
    query,
    fragment,
  }
}

@val external locationPathname: string = "window.location.pathname"
@val external locationSearch: string = "window.location.search"
@val external locationHash: string = "window.location.hash"

let fromLocation = (): t => {
  let pathname = locationPathname
  let search = locationSearch
  let hash = locationHash

  let query = if Js.String2.startsWith(search, "?") {
    parseQuery(Js.String2.sliceToEnd(search, ~from=1))
  } else {
    Belt.Map.String.empty
  }

  let fragment = if Js.String2.startsWith(hash, "#") && Js.String2.length(hash) > 1 {
    Some(Js.String2.sliceToEnd(hash, ~from=1))
  } else {
    None
  }

  {
    path: pathToSegments(pathname),
    query,
    fragment,
  }
}

let pathToString = (url: t): string => {
  "/" ++ (url.path->Belt.List.toArray->Js.Array2.joinWith("/"))
}

let toString = (url: t): string => {
  let path = pathToString(url)

  let queryStr = if Belt.Map.String.isEmpty(url.query) {
    ""
  } else {
    let pairs = url.query
      ->Belt.Map.String.toArray
      ->Belt.Array.map(((k, v)) => k ++ "=" ++ Js.Global.encodeURIComponent(v))
      ->Js.Array2.joinWith("&")
    "?" ++ pairs
  }

  let fragmentStr = switch url.fragment {
  | Some(f) => "#" ++ f
  | None => ""
  }

  path ++ queryStr ++ fragmentStr
}

let getQueryParam = (url: t, key: string): option<string> => {
  url.query->Belt.Map.String.get(key)
}

let getQueryParamInt = (url: t, key: string): option<int> => {
  url
  ->getQueryParam(key)
  ->Belt.Option.flatMap(v => Belt.Int.fromString(v))
}

let getQueryParamBool = (url: t, key: string): option<bool> => {
  url
  ->getQueryParam(key)
  ->Belt.Option.map(v => {
    switch v {
    | "true" | "1" => true
    | _ => false
    }
  })
}

let isRoot = (url: t): bool => {
  url.path == list{}
}
