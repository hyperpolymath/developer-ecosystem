// SPDX-License-Identifier: Apache-2.0
// ServerRouter.res - Server-side routing for SSR with Deno

// HTTP method type
type method =
  | GET
  | POST
  | PUT
  | PATCH
  | DELETE
  | HEAD
  | OPTIONS

let methodFromString = (s: string): option<method> => {
  switch Js.String2.toUpperCase(s) {
  | "GET" => Some(GET)
  | "POST" => Some(POST)
  | "PUT" => Some(PUT)
  | "PATCH" => Some(PATCH)
  | "DELETE" => Some(DELETE)
  | "HEAD" => Some(HEAD)
  | "OPTIONS" => Some(OPTIONS)
  | _ => None
  }
}

let methodToString = (m: method): string => {
  switch m {
  | GET => "GET"
  | POST => "POST"
  | PUT => "PUT"
  | PATCH => "PATCH"
  | DELETE => "DELETE"
  | HEAD => "HEAD"
  | OPTIONS => "OPTIONS"
  }
}

// Request context for server-side routing
type requestContext = {
  url: Url.t,
  method: method,
  headers: Belt.Map.String.t<string>,
  path: string,
}

// Create context from URL string and method
let makeContext = (
  ~urlString: string,
  ~method: method,
  ~headers: Belt.Map.String.t<string>=Belt.Map.String.empty,
  ()
): requestContext => {
  let url = Url.fromString(urlString)
  {
    url,
    method,
    headers,
    path: "/" ++ Belt.List.toArray(url.path)->Js.Array2.joinWith("/"),
  }
}

// Server route handler result
type handlerResult<'data> =
  | Render('data)
  | Redirect(string)
  | NotFound
  | MethodNotAllowed(array<method>)
  | ServerError(string)

// Server route definition with method constraints
type serverRoute<'route, 'data> = {
  parse: requestContext => option<'route>,
  methods: array<method>,
  handler: ('route, requestContext) => handlerResult<'data>,
}

// Build a server route from a parser
let make = (
  ~parser: Parser.t<'route>,
  ~methods: array<method>=[GET],
  ~handler: ('route, requestContext) => handlerResult<'data>
): serverRoute<'route, 'data> => {
  {
    parse: ctx => Parser.parse(parser, ctx.url),
    methods,
    handler,
  }
}

// Match result including method validation
type matchResult<'route, 'data> =
  | Matched(handlerResult<'data>)
  | WrongMethod(array<method>)
  | NoMatch

// Try to match a route
let matchRoute = (
  route: serverRoute<'route, 'data>,
  ctx: requestContext
): matchResult<'route, 'data> => {
  switch route.parse(ctx) {
  | Some(parsed) =>
    let methodAllowed = Belt.Array.some(route.methods, m => m == ctx.method)
    if methodAllowed {
      Matched(route.handler(parsed, ctx))
    } else {
      WrongMethod(route.methods)
    }
  | None => NoMatch
  }
}

// Router combining multiple server routes
// Note: Uses type erasure to allow heterogeneous route types
type routerRoutes<'data>

@unboxed
external makeRoutes: array<serverRoute<'route, 'data>> => routerRoutes<'data> = "%identity"

type t<'data> = {
  routes: routerRoutes<'data>,
  routeArray: array<serverRoute<unit, 'data>>,
  notFoundHandler: requestContext => 'data,
}

// Create a router
let router = (
  ~routes: array<serverRoute<'route, 'data>>,
  ~notFound: requestContext => 'data
): t<'data> => {
  {
    routes: makeRoutes(routes),
    routeArray: routes->Obj.magic,
    notFoundHandler: notFound,
  }
}

// Route a request through the router
let route = (router: t<'data>, ctx: requestContext): handlerResult<'data> => {
  let result = ref(None)
  let allowedMethods = ref([])
  let i = ref(0)
  let len = Belt.Array.length(router.routeArray)

  while result.contents == None && i.contents < len {
    switch router.routeArray[i.contents] {
    | Some(r) =>
      switch matchRoute(r, ctx) {
      | Matched(handlerResult) => result := Some(handlerResult)
      | WrongMethod(methods) =>
        allowedMethods := Belt.Array.concat(allowedMethods.contents, methods)
        i := i.contents + 1
      | NoMatch => i := i.contents + 1
      }
    | None => i := i.contents + 1
    }
  }

  switch result.contents {
  | Some(r) => r
  | None =>
    if Belt.Array.length(allowedMethods.contents) > 0 {
      MethodNotAllowed(allowedMethods.contents)
    } else {
      NotFound
    }
  }
}

// SSR rendering context - passed to render functions
type ssrContext<'route, 'data> = {
  route: 'route,
  data: 'data,
  url: Url.t,
  headers: Belt.Map.String.t<string>,
}

// Functor for isomorphic routing (same routes on client and server)
module MakeIsomorphic = (Config: {
  type route
  type data
  let parser: Parser.t<route>
  let toString: route => string
  let fetchData: (route, requestContext) => Js.Promise.t<data>
  let render: ssrContext<route, data> => string
  let notFoundRoute: route
}): {
  let handleRequest: requestContext => Js.Promise.t<handlerResult<string>>
  let hydrateUrl: string => option<Config.route>
} => {
  let handleRequest = (ctx: requestContext): Js.Promise.t<handlerResult<string>> => {
    switch Parser.parse(Config.parser, ctx.url) {
    | Some(route) =>
      Config.fetchData(route, ctx)
      ->Js.Promise.then_(
        data => {
          let ssrCtx = {
            route,
            data,
            url: ctx.url,
            headers: ctx.headers,
          }
          Js.Promise.resolve(Render(Config.render(ssrCtx)))
        },
        _,
      )
      ->Js.Promise.catch(
        err => {
          let msg = switch Js.Exn.message(Obj.magic(err)) {
          | Some(m) => m
          | None => "Unknown error"
          }
          Js.Promise.resolve(ServerError(msg))
        },
        _,
      )
    | None =>
      // Handle not found by rendering the notFound route
      Config.fetchData(Config.notFoundRoute, ctx)
      ->Js.Promise.then_(
        data => {
          let ssrCtx = {
            route: Config.notFoundRoute,
            data,
            url: ctx.url,
            headers: ctx.headers,
          }
          Js.Promise.resolve(Render(Config.render(ssrCtx)))
        },
        _,
      )
      ->Js.Promise.catch(_ => Js.Promise.resolve(NotFound), _)
    }
  }

  // Client-side hydration - parse URL to get initial route
  let hydrateUrl = (urlString: string): option<Config.route> => {
    Parser.parse(Config.parser, Url.fromString(urlString))
  }
}

// Utility: Extract path parameters from a matched route for logging/analytics
let extractParams = (url: Url.t): array<string> => {
  Belt.List.toArray(url.path)
}

// Utility: Build redirect URL preserving query params
let redirectWithQuery = (newPath: string, url: Url.t): string => {
  let queryString = Url.toString({...url, path: list{}, fragment: None})
  if Js.String2.length(queryString) > 1 {
    newPath ++ queryString
  } else {
    newPath
  }
}
