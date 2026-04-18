// SPDX-License-Identifier: Apache-2.0
// Parser.res - Elm-style URL parser combinators

type state = {
  remaining: list<string>,
  url: Url.t,
}

type t<'a> = state => option<('a, state)>

// === Path Segment Matchers ===

let s = (literal: string): t<unit> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} if head == literal =>
      Some(((), {...state, remaining: tail}))
    | _ => None
    }
  }
}

let str: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} if head != "" =>
    Some((head, {...state, remaining: tail}))
  | _ => None
  }
}

let int: t<int> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    switch Belt.Int.fromString(head) {
    | Some(n) => Some((n, {...state, remaining: tail}))
    | None => None
    }
  | list{} => None
  }
}

let custom = (parse: string => option<'a>): t<'a> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      switch parse(head) {
      | Some(value) => Some((value, {...state, remaining: tail}))
      | None => None
      }
    | list{} => None
    }
  }
}

let top: t<unit> = state => {
  switch state.remaining {
  | list{} => Some(((), state))
  | _ => None
  }
}

// === Combinators ===

let andThen = (parserA: t<'a>, parserB: t<'b>): t<('a, 'b)> => {
  state => {
    switch parserA(state) {
    | Some((a, stateAfterA)) =>
      switch parserB(stateAfterA) {
      | Some((b, stateAfterB)) => Some(((a, b), stateAfterB))
      | None => None
      }
    | None => None
    }
  }
}

let \"</>" = andThen

let map = (parser: t<'a>, fn: 'a => 'b): t<'b> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((fn(a), newState))
    | None => None
    }
  }
}

let \"<$>" = (fn: 'a => 'b, parser: t<'a>): t<'b> => map(parser, fn)

let oneOf = (parsers: array<t<'a>>): t<'a> => {
  state => {
    let result = ref(None)
    let i = ref(0)
    let len = Belt.Array.length(parsers)

    while result.contents == None && i.contents < len {
      switch parsers[i.contents] {
      | Some(parser) =>
        switch parser(state) {
        | Some(_) as success => result := success
        | None => i := i.contents + 1
        }
      | None => i := i.contents + 1
      }
    }

    result.contents
  }
}

let optional = (parser: t<'a>): t<option<'a>> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((Some(a), newState))
    | None => Some((None, state))
    }
  }
}

// === Query Parameters ===

let query = (key: string): t<option<string>> => {
  state => {
    let value = state.url->Url.getQueryParam(key)
    Some((value, state))
  }
}

let queryInt = (key: string): t<option<int>> => {
  state => {
    let value = state.url->Url.getQueryParamInt(key)
    Some((value, state))
  }
}

let queryBool = (key: string): t<option<bool>> => {
  state => {
    let value = state.url->Url.getQueryParamBool(key)
    Some((value, state))
  }
}

let queryRequired = (key: string): t<string> => {
  state => {
    switch state.url->Url.getQueryParam(key) {
    | Some(value) => Some((value, state))
    | None => None
    }
  }
}

// === Advanced Segment Matchers ===

// UUID regex: 8-4-4-4-12 hex chars
let uuidRegex = %re("/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/")

let uuid: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    if Js.Re.test_(uuidRegex, head) {
      Some((head, {...state, remaining: tail}))
    } else {
      None
    }
  | list{} => None
  }
}

// Slug: lowercase alphanumeric + hyphens, no leading/trailing hyphens
let slugRegex = %re("/^[a-z0-9]+(?:-[a-z0-9]+)*$/")

let slug: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    if Js.Re.test_(slugRegex, head) {
      Some((head, {...state, remaining: tail}))
    } else {
      None
    }
  | list{} => None
  }
}

let float: t<float> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    switch Belt.Float.fromString(head) {
    | Some(f) => Some((f, {...state, remaining: tail}))
    | None => None
    }
  | list{} => None
  }
}

let enum = (options: array<string>): t<string> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      if Belt.Array.some(options, opt => opt == head) {
        Some((head, {...state, remaining: tail}))
      } else {
        None
      }
    | list{} => None
    }
  }
}

let regex = (re: Js.Re.t): t<string> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      if Js.Re.test_(re, head) {
        Some((head, {...state, remaining: tail}))
      } else {
        None
      }
    | list{} => None
    }
  }
}

let rest: t<list<string>> = state => {
  Some((state.remaining, {...state, remaining: list{}}))
}

let restAsString: t<string> = state => {
  let joined = state.remaining->Belt.List.toArray->Js.Array2.joinWith("/")
  Some((joined, {...state, remaining: list{}}))
}

// === Fragment ===

let fragment: t<option<string>> = state => {
  Some((state.url.fragment, state))
}

let fragmentRequired: t<string> = state => {
  switch state.url.fragment {
  | Some(f) => Some((f, state))
  | None => None
  }
}

// === Control Flow ===

let succeed = (value: 'a): t<'a> => {
  state => Some((value, state))
}

let fail: t<'a> = _ => None

let lazy_ = (thunk: unit => t<'a>): t<'a> => {
  state => thunk()(state)
}

let filter = (parser: t<'a>, predicate: 'a => bool): t<'a> => {
  state => {
    switch parser(state) {
    | Some((value, newState)) if predicate(value) => Some((value, newState))
    | _ => None
    }
  }
}

let withDefault = (parser: t<'a>, default: 'a): t<'a> => {
  state => {
    switch parser(state) {
    | Some(_) as result => result
    | None => Some((default, state))
    }
  }
}

let attempt = (parser: t<'a>): t<'a> => {
  state => {
    switch parser(state) {
    | Some(_) as result => result
    | None => None  // Same as regular, but semantically for backtracking
    }
  }
}

// === Debugging ===

let debug = (label: string, parser: t<'a>): t<'a> => {
  state => {
    Js.Console.log(`[Parser Debug: ${label}]`)
    Js.Console.log(`  Remaining: ${state.remaining->Belt.List.toArray->Js.Array2.joinWith("/")}`)

    let result = parser(state)

    switch result {
    | Some((_, newState)) =>
      Js.Console.log(`  Result: Success`)
      Js.Console.log(`  Consumed: ${Belt.Int.toString(
        Belt.List.length(state.remaining) - Belt.List.length(newState.remaining)
      )} segments`)
    | None =>
      Js.Console.log(`  Result: Failed`)
    }

    result
  }
}

// === Execution ===

let parse = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, finalState)) =>
    // Only succeed if all path segments were consumed
    switch finalState.remaining {
    | list{} => Some(result)
    | _ => None
    }
  | None => None
  }
}

let parsePartial = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, _)) => Some(result)
  | None => None
  }
}

type parseError = {
  remainingPath: list<string>,
  consumedPath: list<string>,
  url: Url.t,
}

let parseWithError = (parser: t<'a>, url: Url.t): result<'a, parseError> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, finalState)) =>
    switch finalState.remaining {
    | list{} => Ok(result)
    | remaining =>
      let consumedCount = Belt.List.length(url.path) - Belt.List.length(remaining)
      let consumed = url.path->Belt.List.take(consumedCount)->Belt.Option.getWithDefault(list{})
      Error({
        remainingPath: remaining,
        consumedPath: consumed,
        url,
      })
    }
  | None =>
    Error({
      remainingPath: url.path,
      consumedPath: list{},
      url,
    })
  }
}
