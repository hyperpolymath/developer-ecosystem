// SPDX-License-Identifier: PMPL-1.0-or-later
// RouteBuilder.res - Bidirectional route definitions

type t<'route> = {
  parse: Url.t => option<'route>,
  toString: 'route => option<string>,
}

// Internal representation of a segment builder
type segment<'a> = {
  parser: Parser.t<'a>,
  serializer: 'a => list<string>,
}

let lit = (literal: string): segment<unit> => {
  {
    parser: Parser.s(literal),
    serializer: _ => list{literal},
  }
}

let str = (): segment<string> => {
  {
    parser: Parser.str,
    serializer: s => list{s},
  }
}

let int = (): segment<int> => {
  {
    parser: Parser.int,
    serializer: n => list{Belt.Int.toString(n)},
  }
}

let custom = (
  ~parse: string => option<'a>,
  ~serialize: 'a => string
): segment<'a> => {
  {
    parser: Parser.custom(parse),
    serializer: a => list{serialize(a)},
  }
}

let andThen = (segA: segment<'a>, segB: segment<'b>): segment<('a, 'b)> => {
  {
    parser: Parser.andThen(segA.parser, segB.parser),
    serializer: ((a, b)) => {
      Belt.List.concat(segA.serializer(a), segB.serializer(b))
    },
  }
}

let \"/>" = andThen

let end_: segment<unit> = {
  parser: Parser.top,
  serializer: _ => list{},
}

let build = (
  seg: segment<'a>,
  ~toRoute: 'a => 'route,
  ~fromRoute: 'route => option<'a>
): t<'route> => {
  {
    parse: url => {
      // Combine segment parser with top to ensure full match
      let fullParser = seg.parser->Parser.andThen(Parser.top)->Parser.map(((a, _)) => a)
      switch Parser.parse(fullParser, url) {
      | Some(a) => Some(toRoute(a))
      | None => None
      }
    },
    toString: route => {
      switch fromRoute(route) {
      | Some(a) => {
          let segments = seg.serializer(a)
          Some("/" ++ Belt.List.toArray(segments)->Js.Array2.joinWith("/"))
        }
      | None => None
      }
    },
  }
}

let oneOf = (routes: array<t<'route>>): t<'route> => {
  {
    parse: url => {
      let result = ref(None)
      let i = ref(0)
      let len = Belt.Array.length(routes)

      while result.contents == None && i.contents < len {
        switch routes[i.contents] {
        | Some(r) =>
          switch r.parse(url) {
          | Some(_) as success => result := success
          | None => i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }

      result.contents
    },
    toString: route => {
      let result = ref(None)
      let i = ref(0)
      let len = Belt.Array.length(routes)

      while result.contents == None && i.contents < len {
        switch routes[i.contents] {
        | Some(r) =>
          switch r.toString(route) {
          | Some(_) as success => result := success
          | None => i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }

      result.contents
    },
  }
}

// === Optimised Dispatch ===

// oneOfGrouped pre-groups route builders by a user-supplied key
// (typically the first path segment). When a URL arrives, the key is
// extracted and used for O(1) dispatch into the correct group, then
// only builders within that group are tried linearly.
//
// This mirrors Parser.oneOfGrouped but operates at the RouteBuilder
// level (bidirectional: parse + toString). The key function allows
// flexible grouping strategies:
//
//   // Group by first path segment
//   let router = RouteBuilder.oneOfGrouped(
//     routes,
//     ~keyFromUrl=url => switch url.path {
//     | list{first, ..._} => first
//     | list{} => ""
//     },
//   )
//
// For N routes with K unique keys, parse dispatch drops from O(N)
// to O(N/K). toString remains O(N) since we cannot know the key
// from a route value without trying each builder.
//
// Inspired by http-capability-gateway's ETS-based O(1) route lookups
// and cadre-router's Parser.oneOfGrouped (2026-02-28).
let oneOfGrouped = (
  entries: array<(string, t<'route>)>,
  ~keyFromUrl: Url.t => string
): t<'route> => {
  // Build a map from key to array of route builders
  let groups: Dict.t<array<t<'route>>> = Dict.make()

  entries->Array.forEach(((key, builder)) => {
    let existing = groups->Dict.get(key)->Option.getOr([])
    groups->Dict.set(key, Array.concat(existing, [builder]))
  })

  // Collect all builders for toString (must try all since we
  // cannot derive the key from a route value)
  let allBuilders = entries->Array.map(((_, builder)) => builder)

  {
    parse: url => {
      let key = keyFromUrl(url)

      // O(1) lookup into the correct group
      let tryGroup = (parsers: array<t<'route>>): option<'route> => {
        let result = ref(None)
        let i = ref(0)
        let len = parsers->Array.length
        while result.contents == None && i.contents < len {
          switch parsers[i.contents] {
          | Some(r) =>
            switch r.parse(url) {
            | Some(_) as success => result := success
            | None => i := i.contents + 1
            }
          | None => i := i.contents + 1
          }
        }
        result.contents
      }

      switch groups->Dict.get(key) {
      | Some(parsers) =>
        switch tryGroup(parsers) {
        | Some(_) as result => result
        | None =>
          // Fall back to empty-key group (catch-all routes)
          switch groups->Dict.get("") {
          | Some(fallback) => tryGroup(fallback)
          | None => None
          }
        }
      | None =>
        // No group matched — try empty-key group as fallback
        switch groups->Dict.get("") {
        | Some(fallback) => tryGroup(fallback)
        | None => None
        }
      }
    },
    toString: route => {
      // toString must try all builders (cannot derive key from route)
      let result = ref(None)
      let i = ref(0)
      let len = allBuilders->Array.length
      while result.contents == None && i.contents < len {
        switch allBuilders[i.contents] {
        | Some(r) =>
          switch r.toString(route) {
          | Some(_) as success => result := success
          | None => i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }
      result.contents
    },
  }
}

module Make = (Config: {
  type route
  let definition: t<route>
  let notFound: route
}) => {
  let parseOption = (url: Url.t): option<Config.route> => {
    Config.definition.parse(url)
  }

  let parse = (url: Url.t): Config.route => {
    switch parseOption(url) {
    | Some(route) => route
    | None => Config.notFound
    }
  }

  let toString = (route: Config.route): string => {
    switch Config.definition.toString(route) {
    | Some(s) => s
    | None => "/"
    }
  }
}
