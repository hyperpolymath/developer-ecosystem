// SPDX-License-Identifier: Apache-2.0
// Demo.res - Runnable demo of cadre-router

// Define a typed ID module
module UserId = {
  type t = UserId(string)

  let fromString = (str: string): option<t> => {
    if String.length(str) > 0 {
      Some(UserId(str))
    } else {
      None
    }
  }

  let toString = (UserId(str): t): string => str
  let parser: CadreRouter.Parser.t<t> = CadreRouter.Parser.custom(fromString)
}

// Define route types
type route =
  | Home
  | Profile
  | User(int)
  | Article(UserId.t)
  | Search(string)
  | NotFound

// Build the parser
let parser: CadreRouter.Parser.t<route> = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => Home),
    s("profile")->map(_ => Profile),
    s("user")->andThen(int)->map(((_, id)) => User(id)),
    s("article")->andThen(UserId.parser)->map(((_, id)) => Article(id)),
    s("search")->andThen(queryRequired("q"))->map(((_, q)) => Search(q)),
  ])
}

// Route to string serializer
let routeToString = (route: route): string =>
  switch route {
  | Home => "/"
  | Profile => "/profile"
  | User(id) => "/user/" ++ Int.toString(id)
  | Article(id) => "/article/" ++ UserId.toString(id)
  | Search(q) => "/search?q=" ++ q
  | NotFound => "/not-found"
  }

// Demo function - parse URLs and show results
let runDemo = () => {
  Js.Console.log("=== cadre-router Demo ===")
  Js.Console.log("")

  let testUrls = [
    "/",
    "/profile",
    "/user/42",
    "/user/123",
    "/article/my-first-post",
    "/search?q=hello",
    "/unknown",
  ]

  testUrls->Array.forEach(urlStr => {
    let url = CadreRouter.Url.fromString(urlStr)
    let parsed = CadreRouter.Parser.parse(parser, url)

    Js.Console.log("URL: " ++ urlStr)
    switch parsed {
    | Some(route) => {
        let routeName = switch route {
        | Home => "Home"
        | Profile => "Profile"
        | User(id) => "User(" ++ Int.toString(id) ++ ")"
        | Article(UserId.UserId(id)) => "Article(" ++ id ++ ")"
        | Search(q) => "Search(" ++ q ++ ")"
        | NotFound => "NotFound"
        }
        Js.Console.log("  -> Parsed: " ++ routeName)

        // Roundtrip test
        let serialized = routeToString(route)
        Js.Console.log("  -> Serialized: " ++ serialized)
      }
    | None => Js.Console.log("  -> No match (would be NotFound)")
    }
    Js.Console.log("")
  })

  Js.Console.log("=== Demo Complete ===")
}

// Auto-run
let _ = runDemo()
