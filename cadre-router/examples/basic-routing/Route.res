// SPDX-License-Identifier: Apache-2.0
// Route.res - Example route definition for a typical SPA
//
// This example demonstrates patterns for nafa-app-ambient style routing:
// - Typed ID parameters (JourneyId.t)
// - Nested routes (Journey sub-routes)
// - Query parameters

// === Typed ID Module ===
module JourneyId = {
  type t = JourneyId(string)

  let fromString = (str: string): option<t> => {
    // Add validation as needed (UUID format, non-empty, etc.)
    if Js.String2.length(str) > 0 {
      Some(JourneyId(str))
    } else {
      None
    }
  }

  let toString = (JourneyId(str): t): string => str

  // Parser for use with cadre-router
  let parser: CadreRouter.Parser.t<t> =
    CadreRouter.Parser.custom(fromString)
}

// === Journey Sub-Routes ===
type journeySubRoute =
  | JourneyOverview
  | JourneyMap
  | JourneyLog
  | JourneySettings

let journeySubToString = (sub: journeySubRoute): string =>
  switch sub {
  | JourneyOverview => ""
  | JourneyMap => "/map"
  | JourneyLog => "/log"
  | JourneySettings => "/settings"
  }

let journeySubParser: CadreRouter.Parser.t<journeySubRoute> = {
  open CadreRouter.Parser
  oneOf([
    s("map")->map(_ => JourneyMap),
    s("log")->map(_ => JourneyLog),
    s("settings")->map(_ => JourneySettings),
    top->map(_ => JourneyOverview),
  ])
}

// === Main Route Type ===
type t =
  | Home
  | MoodInput
  | Journey(JourneyId.t, journeySubRoute)
  | Profile
  | Search({query: string, page: option<int>})
  | NotFound

// === Parser ===
let parser: CadreRouter.Parser.t<t> = {
  open CadreRouter.Parser
  oneOf([
    // Home: /
    top->map(_ => Home),

    // MoodInput: /mood
    s("mood")->map(_ => MoodInput),

    // Journey: /journey/:id or /journey/:id/map etc.
    s("journey")
      ->andThen(JourneyId.parser)
      ->andThen(journeySubParser)
      ->map((((_, id), sub)) => Journey(id, sub)),

    // Profile: /profile
    s("profile")->map(_ => Profile),

    // Search: /search?q=...&page=...
    s("search")
      ->andThen(queryRequired("q"))
      ->andThen(queryInt("page"))
      ->map((((_, q), page)) => Search({query: q, page})),
  ])
}

// === Serializer ===
let toString = (route: t): string =>
  switch route {
  | Home => "/"
  | MoodInput => "/mood"
  | Journey(id, sub) =>
    "/journey/" ++ JourneyId.toString(id) ++ journeySubToString(sub)
  | Profile => "/profile"
  | Search({query, page}) => {
      let pageParam = switch page {
      | Some(p) => "&page=" ++ Belt.Int.toString(p)
      | None => ""
      }
      "/search?q=" ++ Js.Global.encodeURIComponent(query) ++ pageParam
    }
  | NotFound => "/not-found"
  }

// === Parse URL to Route ===
let fromUrl = (url: CadreRouter.Url.t): t => {
  switch CadreRouter.Parser.parse(parser, url) {
  | Some(route) => route
  | None => NotFound
  }
}

// === Typed Navigation ===
module Nav = CadreRouter.Navigation.Make({
  type t = t
  let toString = toString
})

// === Typed Link (for React apps) ===
module Link = CadreRouter.Link.Make({
  type t = t
  let toString = toString
})
