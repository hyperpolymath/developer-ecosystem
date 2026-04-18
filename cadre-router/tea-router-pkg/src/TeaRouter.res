// SPDX-License-Identifier: Apache-2.0
// TeaRouter.res - Type-safe routing for rescript-tea applications

module type Config = {
  type route
  type msg

  let parser: CadreRouter.Parser.t<route>
  let toString: route => string
  let onRouteChange: route => msg
  let onNotFound: CadreRouter.Url.t => msg
}

// Helper to create navigation commands
module NavCmd = {
  // Using Tea.Navigation for actual navigation
  let push = (url: string): Tea.Cmd.t<'msg> => {
    Tea.Navigation.pushUrl(url)
  }

  let replace = (url: string): Tea.Cmd.t<'msg> => {
    Tea.Navigation.replaceUrl(url)
  }

  let back = (): Tea.Cmd.t<'msg> => {
    Tea.Navigation.back(1)
  }

  let forward = (): Tea.Cmd.t<'msg> => {
    Tea.Navigation.forward(1)
  }

  let go = (n: int): Tea.Cmd.t<'msg> => {
    if n < 0 {
      Tea.Navigation.back(-n)
    } else {
      Tea.Navigation.forward(n)
    }
  }
}

module Make = (C: Config) => {
  let parseUrl = (url: CadreRouter.Url.t): option<C.route> => {
    CadreRouter.Parser.parse(C.parser, url)
  }

  let currentRoute = (): option<C.route> => {
    parseUrl(CadreRouter.Navigation.currentUrl())
  }

  let init = (): (option<C.route>, Tea.Cmd.t<C.msg>) => {
    let url = CadreRouter.Navigation.currentUrl()
    let route = parseUrl(url)

    // Create a command to dispatch the appropriate message
    let cmd = Tea.Cmd.msg(
      switch route {
      | Some(r) => C.onRouteChange(r)
      | None => C.onNotFound(url)
      }
    )

    (route, cmd)
  }

  let push = (route: C.route): Tea.Cmd.t<C.msg> => {
    let url = C.toString(route)
    // Chain: push URL, then dispatch route change
    Tea.Cmd.batch([
      NavCmd.push(url),
      Tea.Cmd.msg(C.onRouteChange(route)),
    ])
  }

  let replace = (route: C.route): Tea.Cmd.t<C.msg> => {
    let url = C.toString(route)
    Tea.Cmd.batch([
      NavCmd.replace(url),
      Tea.Cmd.msg(C.onRouteChange(route)),
    ])
  }

  let back: Tea.Cmd.t<C.msg> = NavCmd.back()

  let forward: Tea.Cmd.t<C.msg> = NavCmd.forward()

  let go = (n: int): Tea.Cmd.t<C.msg> => NavCmd.go(n)

  // Subscription for URL changes (popstate)
  let urlChanges: Tea.Sub.t<C.msg> = {
    Tea.Navigation.urlChange(location => {
      // Convert Tea.Navigation.Location to CadreRouter.Url
      let url: CadreRouter.Url.t = {
        path: location.pathname
          ->Js.String2.split("/")
          ->Belt.Array.keep(s => s != "")
          ->Belt.List.fromArray,
        query: {
          let search = location.search
          if Js.String2.startsWith(search, "?") {
            Js.String2.sliceToEnd(search, ~from=1)
            ->Js.String2.split("&")
            ->Belt.Array.reduce(Belt.Map.String.empty, (acc, pair) => {
              switch Js.String2.split(pair, "=") {
              | [key, value] => acc->Belt.Map.String.set(key, Js.Global.decodeURIComponent(value))
              | [key] => acc->Belt.Map.String.set(key, "")
              | _ => acc
              }
            })
          } else {
            Belt.Map.String.empty
          }
        },
        fragment: {
          let hash = location.hash
          if Js.String2.startsWith(hash, "#") && Js.String2.length(hash) > 1 {
            Some(Js.String2.sliceToEnd(hash, ~from=1))
          } else {
            None
          }
        },
      }

      switch parseUrl(url) {
      | Some(route) => C.onRouteChange(route)
      | None => C.onNotFound(url)
      }
    })
  }

  // Type-safe link element
  let link = (
    ~route: C.route,
    ~attrs: option<list<Tea.Html.attribute<C.msg>>>=?,
    children: list<Tea.Html.t<C.msg>>
  ): Tea.Html.t<C.msg> => {
    let url = C.toString(route)
    let baseAttrs = [
      Tea.Html.Attributes.href(url),
      Tea.Html.Events.onClickPreventDefault(_ => C.onRouteChange(route)),
    ]
    let allAttrs = switch attrs {
    | Some(extra) => Belt.List.concat(baseAttrs, extra)
    | None => baseAttrs
    }
    Tea.Html.a(allAttrs, children)
  }

  let href = (route: C.route): Tea.Html.attribute<C.msg> => {
    Tea.Html.Attributes.href(C.toString(route))
  }
}

// Hash-based router for static hosting
module HashRouter = {
  module Make = (C: Config) => {
    let parseUrl = (url: CadreRouter.Url.t): option<C.route> => {
      CadreRouter.Parser.parse(C.parser, url)
    }

    let currentRoute = (): option<C.route> => {
      parseUrl(CadreRouter.HashNavigation.currentUrl())
    }

    let init = (): (option<C.route>, Tea.Cmd.t<C.msg>) => {
      let url = CadreRouter.HashNavigation.currentUrl()
      let route = parseUrl(url)

      let cmd = Tea.Cmd.msg(
        switch route {
        | Some(r) => C.onRouteChange(r)
        | None => C.onNotFound(url)
        }
      )

      (route, cmd)
    }

    let push = (route: C.route): Tea.Cmd.t<C.msg> => {
      let url = C.toString(route)
      // For hash routing, we use a custom command
      Tea.Cmd.call(_ => {
        CadreRouter.HashNavigation.pushUrl(url)
      })->Tea.Cmd.map(_ => C.onRouteChange(route))
    }

    let replace = (route: C.route): Tea.Cmd.t<C.msg> => {
      let url = C.toString(route)
      Tea.Cmd.call(_ => {
        CadreRouter.HashNavigation.replaceUrl(url)
      })->Tea.Cmd.map(_ => C.onRouteChange(route))
    }

    let back: Tea.Cmd.t<C.msg> = Tea.Cmd.call(_ => {
      CadreRouter.HashNavigation.back()
    })

    let forward: Tea.Cmd.t<C.msg> = Tea.Cmd.call(_ => {
      CadreRouter.HashNavigation.forward()
    })

    let go = (n: int): Tea.Cmd.t<C.msg> => {
      if n < 0 {
        Tea.Navigation.back(-n)
      } else {
        Tea.Navigation.forward(n)
      }
    }

    // For hash routing, we listen to hashchange
    let urlChanges: Tea.Sub.t<C.msg> = {
      // Use the standard URL change and parse from hash
      Tea.Navigation.urlChange(location => {
        let hash = location.hash
        let url = if Js.String2.startsWith(hash, "#/") {
          CadreRouter.Url.fromString(Js.String2.sliceToEnd(hash, ~from=1))
        } else if Js.String2.startsWith(hash, "#") {
          CadreRouter.Url.fromString("/" ++ Js.String2.sliceToEnd(hash, ~from=1))
        } else {
          CadreRouter.Url.fromString("/")
        }

        switch parseUrl(url) {
        | Some(route) => C.onRouteChange(route)
        | None => C.onNotFound(url)
        }
      })
    }

    let link = (
      ~route: C.route,
      ~attrs: option<list<Tea.Html.attribute<C.msg>>>=?,
      children: list<Tea.Html.t<C.msg>>
    ): Tea.Html.t<C.msg> => {
      let url = "#" ++ C.toString(route)
      let baseAttrs = [
        Tea.Html.Attributes.href(url),
        Tea.Html.Events.onClickPreventDefault(_ => C.onRouteChange(route)),
      ]
      let allAttrs = switch attrs {
      | Some(extra) => Belt.List.concat(baseAttrs, extra)
      | None => baseAttrs
      }
      Tea.Html.a(allAttrs, children)
    }

    let href = (route: C.route): Tea.Html.attribute<C.msg> => {
      Tea.Html.Attributes.href("#" ++ C.toString(route))
    }
  }
}
