// SPDX-License-Identifier: Apache-2.0
// Route.res - Example route definitions for TEA app

// Typed ID for journeys
module JourneyId = {
  type t = JourneyId(string)

  let fromString = (s: string): option<t> =>
    if Js.String2.length(s) > 0 { Some(JourneyId(s)) } else { None }

  let toString = (JourneyId(s): t): string => s

  let parser = CadreRouter.Parser.custom(fromString)
}

// Sub-routes for journeys
type journeySub = Overview | Map | Log | Settings

let journeySubParser = {
  open CadreRouter.Parser
  oneOf([
    s("map")->map(_ => Map),
    s("log")->map(_ => Log),
    s("settings")->map(_ => Settings),
    top->map(_ => Overview),
  ])
}

let journeySubToString = sub =>
  switch sub {
  | Overview => ""
  | Map => "/map"
  | Log => "/log"
  | Settings => "/settings"
  }

// Main route type
type t =
  | Home
  | MoodInput
  | Journey(JourneyId.t, journeySub)
  | Profile
  | NotFound

// Parser
let parser = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => Home),
    s("mood")->map(_ => MoodInput),
    s("journey")
      ->andThen(JourneyId.parser)
      ->andThen(journeySubParser)
      ->map((((_, id), sub)) => Journey(id, sub)),
    s("profile")->map(_ => Profile),
  ])
}

// Serializer
let toString = route =>
  switch route {
  | Home => "/"
  | MoodInput => "/mood"
  | Journey(id, sub) => "/journey/" ++ JourneyId.toString(id) ++ journeySubToString(sub)
  | Profile => "/profile"
  | NotFound => "/404"
  }
