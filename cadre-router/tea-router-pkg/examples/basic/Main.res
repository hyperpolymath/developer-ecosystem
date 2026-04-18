// SPDX-License-Identifier: Apache-2.0
// Main.res - Example TEA application with routing

// Message type
type msg =
  | RouteChanged(Route.t)
  | UrlNotFound(CadreRouter.Url.t)
  | ClickedLink(Route.t)
  | NoOp

// Create the router
module Router = TeaRouter.Make({
  type route = Route.t
  type msg = msg

  let parser = Route.parser
  let toString = Route.toString
  let onRouteChange = route => RouteChanged(route)
  let onNotFound = url => UrlNotFound(url)
})

// Model
type model = {
  route: Route.t,
  errorMessage: option<string>,
}

// Init
let init = () => {
  let (route, cmd) = Router.init()
  (
    {
      route: route->Belt.Option.getWithDefault(Route.Home),
      errorMessage: None,
    },
    cmd,
  )
}

// Update
let update = (msg: msg, model: model): (model, Tea.Cmd.t<msg>) =>
  switch msg {
  | RouteChanged(route) => ({...model, route, errorMessage: None}, Tea.Cmd.none)

  | UrlNotFound(url) => (
      {
        ...model,
        route: Route.NotFound,
        errorMessage: Some("Page not found: " ++ CadreRouter.Url.toString(url)),
      },
      Tea.Cmd.none,
    )

  | ClickedLink(route) => (model, Router.push(route))

  | NoOp => (model, Tea.Cmd.none)
  }

// Subscriptions
let subscriptions = (_model: model): Tea.Sub.t<msg> => {
  Router.urlChanges
}

// View helpers
let viewNav = () => {
  open Tea.Html
  nav([], [
    ul([], [
      li([], [Router.link(~route=Route.Home, [text("Home")])]),
      li([], [Router.link(~route=Route.MoodInput, [text("Mood")])]),
      li([], [Router.link(~route=Route.Profile, [text("Profile")])]),
      li([], [
        Router.link(
          ~route=Route.Journey(Route.JourneyId.JourneyId("demo"), Route.Overview),
          [text("Demo Journey")],
        ),
      ]),
    ]),
  ])
}

let viewContent = (model: model) => {
  open Tea.Html
  switch model.route {
  | Route.Home => div([], [h1([], [text("Welcome Home")])])

  | Route.MoodInput => div([], [h1([], [text("How are you feeling?")])])

  | Route.Journey(Route.JourneyId.JourneyId(id), sub) =>
    div([], [
      h1([], [text("Journey: " ++ id)]),
      div([], [
        Router.link(~route=Route.Journey(Route.JourneyId.JourneyId(id), Route.Overview), [
          text("Overview"),
        ]),
        text(" | "),
        Router.link(~route=Route.Journey(Route.JourneyId.JourneyId(id), Route.Map), [text("Map")]),
        text(" | "),
        Router.link(~route=Route.Journey(Route.JourneyId.JourneyId(id), Route.Log), [text("Log")]),
        text(" | "),
        Router.link(~route=Route.Journey(Route.JourneyId.JourneyId(id), Route.Settings), [
          text("Settings"),
        ]),
      ]),
      p([], [
        text(
          switch sub {
          | Route.Overview => "Journey overview content"
          | Route.Map => "Journey map content"
          | Route.Log => "Journey log content"
          | Route.Settings => "Journey settings content"
          },
        ),
      ]),
    ])

  | Route.Profile => div([], [h1([], [text("Your Profile")])])

  | Route.NotFound =>
    div([], [
      h1([], [text("404 - Page Not Found")]),
      switch model.errorMessage {
      | Some(msg) => p([], [text(msg)])
      | None => Tea.Html.noNode
      },
      Router.link(~route=Route.Home, [text("Go Home")]),
    ])
  }
}

// Main view
let view = (model: model): Tea.Html.t<msg> => {
  open Tea.Html
  div([], [viewNav(), hr([]), viewContent(model)])
}

// Main program
let main = Tea.Navigation.navigationProgram(
  _location => NoOp, // Initial location handling done in init
  {
    init: _ => init(),
    update,
    view,
    subscriptions,
    shutdown: _ => Tea.Cmd.none,
  },
)
