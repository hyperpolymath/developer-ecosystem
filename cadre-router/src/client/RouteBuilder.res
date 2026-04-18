// SPDX-License-Identifier: Apache-2.0
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
