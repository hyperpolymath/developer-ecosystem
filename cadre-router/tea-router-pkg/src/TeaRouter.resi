// SPDX-License-Identifier: Apache-2.0
// TeaRouter.resi — Type-safe routing for rescript-tea applications

/**
 * Configuration for creating a router.
 */
module type Config = {
  /** Your route variant type */
  type route

  /** Your message type */
  type msg

  /** Parser from cadre-router */
  let parser: CadreRouter.Parser.t<route>

  /** Serialize route to URL string */
  let toString: route => string

  /** Message to dispatch when route changes */
  let onRouteChange: route => msg

  /** Message to dispatch when URL doesn't match any route */
  let onNotFound: CadreRouter.Url.t => msg
}

/**
 * Create a TEA-integrated router from configuration.
 *
 * Example:
 * ```rescript
 * module Router = TeaRouter.Make({
 *   type route = Route.t
 *   type msg = Msg.t
 *   let parser = Route.parser
 *   let toString = Route.toString
 *   let onRouteChange = route => Msg.RouteChanged(route)
 *   let onNotFound = url => Msg.RouteNotFound(url)
 * })
 * ```
 */
module Make: (C: Config) => {
  /**
   * Initialize the router by parsing the current URL.
   * Call this in your app's init function.
   *
   * Returns the parsed route (if any) and a command that will
   * trigger onRouteChange or onNotFound.
   */
  let init: unit => (option<C.route>, Tea.Cmd.t<C.msg>)

  /**
   * Navigate to a route, adding to browser history.
   * This is the primary navigation method.
   */
  let push: C.route => Tea.Cmd.t<C.msg>

  /**
   * Navigate to a route, replacing current history entry.
   * Use for redirects or temporary routes.
   */
  let replace: C.route => Tea.Cmd.t<C.msg>

  /**
   * Go back in browser history.
   */
  let back: Tea.Cmd.t<C.msg>

  /**
   * Go forward in browser history.
   */
  let forward: Tea.Cmd.t<C.msg>

  /**
   * Go to a specific point in history.
   * Negative values go back, positive go forward.
   */
  let go: int => Tea.Cmd.t<C.msg>

  /**
   * Subscription for URL changes.
   * Add this to your subscriptions function.
   *
   * Fires when:
   * - User clicks browser back/forward
   * - User edits URL manually
   *
   * Does NOT fire when:
   * - You call push/replace (those trigger the change directly)
   */
  let urlChanges: Tea.Sub.t<C.msg>

  /**
   * Create a type-safe link element.
   *
   * Example:
   * ```rescript
   * Router.link(~route=Route.Profile, [text("My Profile")])
   * Router.link(~route=Route.User(42), ~attrs=[class'("nav-link")], [text("User")])
   * ```
   */
  let link: (
    ~route: C.route,
    ~attrs: list<Tea.Html.attribute<C.msg>>=?,
    list<Tea.Html.t<C.msg>>
  ) => Tea.Html.t<C.msg>

  /**
   * Create an href attribute for a route.
   * Use when you need more control over link construction.
   */
  let href: C.route => Tea.Html.attribute<C.msg>

  /**
   * Parse a URL to a route.
   * Useful for external URL handling.
   */
  let parseUrl: CadreRouter.Url.t => option<C.route>

  /**
   * Get the current route.
   */
  let currentRoute: unit => option<C.route>
}

/**
 * Hash-based router for static hosting.
 * Uses URLs like /#/profile instead of /profile.
 */
module HashRouter: {
  module Make: (C: Config) => {
    let init: unit => (option<C.route>, Tea.Cmd.t<C.msg>)
    let push: C.route => Tea.Cmd.t<C.msg>
    let replace: C.route => Tea.Cmd.t<C.msg>
    let back: Tea.Cmd.t<C.msg>
    let forward: Tea.Cmd.t<C.msg>
    let go: int => Tea.Cmd.t<C.msg>
    let urlChanges: Tea.Sub.t<C.msg>
    let link: (
      ~route: C.route,
      ~attrs: list<Tea.Html.attribute<C.msg>>=?,
      list<Tea.Html.t<C.msg>>
    ) => Tea.Html.t<C.msg>
    let href: C.route => Tea.Html.attribute<C.msg>
    let parseUrl: CadreRouter.Url.t => option<C.route>
    let currentRoute: unit => option<C.route>
  }
}
