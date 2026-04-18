@@ocaml.doc("URL representation and utilities")

@ocaml.doc("Represents a parsed URL")
type t = {
  path: string,
  query: option<string>,
  fragment: option<string>,
}

@ocaml.doc("Parse a URL string into components")
let parse: string => t = url => {
  // Split URL into path, query, and fragment
  let (pathAndQuery, fragment) = switch url->String.split("#") {
  | [pq, f] => (pq, Some(f))
  | [pq] => (pq, None)
  | _ => (url, None)
  }

  let (path, query) = switch pathAndQuery->String.split("?") {
  | [p, q] => (p, Some(q))
  | [p] => (p, None)
  | _ => (pathAndQuery, None)
  }

  // Normalize path - ensure leading slash, remove trailing slash
  let normalizedPath = switch path {
  | "" => "/"
  | p if !p->String.startsWith("/") => "/" ++ p
  | p if p->String.length > 1 && p->String.endsWith("/") =>
    p->String.slice(~start=0, ~end=p->String.length - 1)
  | p => p
  }

  {
    path: normalizedPath,
    query,
    fragment,
  }
}

@ocaml.doc("Convert URL components back to a string")
let toString: t => string = ({path, query, fragment}) => {
  let queryPart = query->Option.mapOr("", q => "?" ++ q)
  let fragmentPart = fragment->Option.mapOr("", f => "#" ++ f)
  path ++ queryPart ++ fragmentPart
}

@ocaml.doc("Get the current browser URL")
let current: unit => t = () => {
  // Browser-specific implementation
  switch %external(__unsafe_window) {
  | None => {path: "/", query: None, fragment: None}
  | Some(_) => parse(%raw(`window.location.pathname + window.location.search + window.location.hash`))
  }
}
