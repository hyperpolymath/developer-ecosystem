// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@ocaml.doc("
Type-safe query parameter handling for multi-parameter state synchronization.
Enables deep-linking to specific comparison states (e.g., Repo A vs Repo B).
")

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("Query parameters as a typed dictionary")
type t = Js.Dict.t<string>

@ocaml.doc("Multi-value query parameters (for arrays like ?tag=a&tag=b)")
type multi = Js.Dict.t<array<string>>

// ============================================================================
// Parsing
// ============================================================================

@ocaml.doc("Parse a query string into key-value pairs")
let parse = (queryString: string): t => {
  let dict = Js.Dict.empty()

  let str = if queryString->String.startsWith("?") {
    queryString->String.sliceToEnd(~start=1)
  } else {
    queryString
  }

  if str->String.length == 0 {
    dict
  } else {
    str
    ->String.split("&")
    ->Array.forEach(pair => {
      switch pair->String.split("=") {
      | [key, value] =>
        let decodedKey = decodeURIComponent(key)
        let decodedValue = decodeURIComponent(value)
        Js.Dict.set(dict, decodedKey, decodedValue)
      | [key] =>
        let decodedKey = decodeURIComponent(key)
        Js.Dict.set(dict, decodedKey, "")
      | _ => ()
      }
    })
    dict
  }
}

@ocaml.doc("Parse query string preserving multiple values for same key")
let parseMulti = (queryString: string): multi => {
  let dict: Js.Dict.t<array<string>> = Js.Dict.empty()

  let str = if queryString->String.startsWith("?") {
    queryString->String.sliceToEnd(~start=1)
  } else {
    queryString
  }

  if str->String.length > 0 {
    str
    ->String.split("&")
    ->Array.forEach(pair => {
      switch pair->String.split("=") {
      | [key, value] =>
        let decodedKey = decodeURIComponent(key)
        let decodedValue = decodeURIComponent(value)
        let existing = Js.Dict.get(dict, decodedKey)->Option.getOr([])
        Js.Dict.set(dict, decodedKey, Array.concat(existing, [decodedValue]))
      | [key] =>
        let decodedKey = decodeURIComponent(key)
        let existing = Js.Dict.get(dict, decodedKey)->Option.getOr([])
        Js.Dict.set(dict, decodedKey, Array.concat(existing, [""]))
      | _ => ()
      }
    })
  }
  dict
}

// ============================================================================
// Building
// ============================================================================

@ocaml.doc("Build a query string from key-value pairs")
let build = (params: t): string => {
  let pairs = Js.Dict.entries(params)
  if Array.length(pairs) == 0 {
    ""
  } else {
    "?" ++ pairs
      ->Array.map(((key, value)) => {
        encodeURIComponent(key) ++ "=" ++ encodeURIComponent(value)
      })
      ->Array.join("&")
  }
}

@ocaml.doc("Build query string from multi-value params")
let buildMulti = (params: multi): string => {
  let pairs = Js.Dict.entries(params)
  if Array.length(pairs) == 0 {
    ""
  } else {
    let allPairs = pairs->Array.flatMap(((key, values)) => {
      values->Array.map(value => {
        encodeURIComponent(key) ++ "=" ++ encodeURIComponent(value)
      })
    })
    "?" ++ allPairs->Array.join("&")
  }
}

// ============================================================================
// Accessors
// ============================================================================

@ocaml.doc("Get a single query parameter")
let get = (params: t, key: string): option<string> => {
  Js.Dict.get(params, key)
}

@ocaml.doc("Get a query parameter with default")
let getOr = (params: t, key: string, default: string): string => {
  Js.Dict.get(params, key)->Option.getOr(default)
}

@ocaml.doc("Get a query parameter as int")
let getInt = (params: t, key: string): option<int> => {
  Js.Dict.get(params, key)->Option.flatMap(Int.fromString)
}

@ocaml.doc("Get a query parameter as float")
let getFloat = (params: t, key: string): option<float> => {
  Js.Dict.get(params, key)->Option.flatMap(Float.fromString)
}

@ocaml.doc("Get a query parameter as bool (accepts 'true', '1', 'yes')")
let getBool = (params: t, key: string): option<bool> => {
  Js.Dict.get(params, key)->Option.map(v => {
    switch v->String.toLowerCase {
    | "true" | "1" | "yes" => true
    | _ => false
    }
  })
}

@ocaml.doc("Check if a parameter exists")
let has = (params: t, key: string): bool => {
  Js.Dict.get(params, key)->Option.isSome
}

// ============================================================================
// Mutation (returns new dict)
// ============================================================================

@ocaml.doc("Set a query parameter (returns new dict)")
let set = (params: t, key: string, value: string): t => {
  let newDict = Js.Dict.fromArray(Js.Dict.entries(params))
  Js.Dict.set(newDict, key, value)
  newDict
}

@ocaml.doc("Set multiple parameters at once")
let setMany = (params: t, updates: array<(string, string)>): t => {
  let newDict = Js.Dict.fromArray(Js.Dict.entries(params))
  updates->Array.forEach(((key, value)) => {
    Js.Dict.set(newDict, key, value)
  })
  newDict
}

@ocaml.doc("Remove a query parameter (returns new dict)")
let remove = (params: t, key: string): t => {
  Js.Dict.fromArray(
    Js.Dict.entries(params)->Array.filter(((k, _)) => k != key)
  )
}

@ocaml.doc("Remove multiple parameters")
let removeMany = (params: t, keys: array<string>): t => {
  Js.Dict.fromArray(
    Js.Dict.entries(params)->Array.filter(((k, _)) => !Array.includes(keys, k))
  )
}

@ocaml.doc("Merge two query param dicts (second overwrites first)")
let merge = (base: t, overrides: t): t => {
  let newDict = Js.Dict.fromArray(Js.Dict.entries(base))
  Js.Dict.entries(overrides)->Array.forEach(((key, value)) => {
    Js.Dict.set(newDict, key, value)
  })
  newDict
}

// ============================================================================
// Multi-Parameter State Sync
// ============================================================================

@ocaml.doc("
State sync configuration for comparison views.
Enables deep-linking like ?repoA=foo&repoB=bar&view=diff
")
type comparisonState = {
  itemA: option<string>,
  itemB: option<string>,
  view: option<string>,
  extra: t,
}

@ocaml.doc("Parse comparison state from query params")
let parseComparison = (params: t, ~keyA: string="a", ~keyB: string="b", ~keyView: string="view", ()): comparisonState => {
  let itemA = get(params, keyA)
  let itemB = get(params, keyB)
  let view = get(params, keyView)
  let extra = removeMany(params, [keyA, keyB, keyView])
  {itemA, itemB, view, extra}
}

@ocaml.doc("Build query params from comparison state")
let buildComparison = (state: comparisonState, ~keyA: string="a", ~keyB: string="b", ~keyView: string="view", ()): t => {
  let params = state.extra
  let params = switch state.itemA {
  | Some(a) => set(params, keyA, a)
  | None => params
  }
  let params = switch state.itemB {
  | Some(b) => set(params, keyB, b)
  | None => params
  }
  let params = switch state.view {
  | Some(v) => set(params, keyView, v)
  | None => params
  }
  params
}

// ============================================================================
// SWOT Flip State Persistence
// ============================================================================

@ocaml.doc("SWOT quadrant flip states for URL persistence")
type swotState = {
  mode: option<string>,      // "match" | "convert" | "eliminate"
  quadrant: option<string>,  // "tl" | "tr" | "bl" | "br"
  expanded: option<bool>,
}

@ocaml.doc("Parse SWOT state from query params")
let parseSwotState = (params: t): swotState => {
  {
    mode: get(params, "mode"),
    quadrant: get(params, "q"),
    expanded: getBool(params, "expanded"),
  }
}

@ocaml.doc("Build query params from SWOT state")
let buildSwotState = (state: swotState): t => {
  let params = Js.Dict.empty()
  let params = switch state.mode {
  | Some(m) => set(params, "mode", m)
  | None => params
  }
  let params = switch state.quadrant {
  | Some(q) => set(params, "q", q)
  | None => params
  }
  let params = switch state.expanded {
  | Some(true) => set(params, "expanded", "1")
  | Some(false) => set(params, "expanded", "0")
  | None => params
  }
  params
}

// ============================================================================
// URL Integration
// ============================================================================

@ocaml.doc("Get current query params from browser")
let current = (): t => {
  switch %external(__unsafe_window) {
  | None => Js.Dict.empty()
  | Some(_) => parse(%raw(`window.location.search`))
  }
}

@ocaml.doc("Update browser URL with new query params (push)")
let pushToUrl = (params: t): unit => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    let query = build(params)
    let path = %raw(`window.location.pathname`)
    let newUrl = path ++ query
    %raw(`window.history.pushState({}, '', newUrl)`)(newUrl)
  }
}

@ocaml.doc("Update browser URL with new query params (replace)")
let replaceInUrl = (params: t): unit => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    let query = build(params)
    let path = %raw(`window.location.pathname`)
    let newUrl = path ++ query
    %raw(`window.history.replaceState({}, '', newUrl)`)(newUrl)
  }
}

// ============================================================================
// External bindings
// ============================================================================

@val external decodeURIComponent: string => string = "decodeURIComponent"
@val external encodeURIComponent: string => string = "encodeURIComponent"
