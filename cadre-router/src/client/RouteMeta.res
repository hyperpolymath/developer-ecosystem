// SPDX-License-Identifier: Apache-2.0
// RouteMeta.res - Route metadata for breadcrumbs, titles, and auth guards

// Core metadata type - extensible with custom data
type meta<'custom> = {
  title: option<string>,
  breadcrumb: option<string>,
  requiresAuth: bool,
  roles: array<string>,
  custom: option<'custom>,
}

// Default empty metadata
let empty: meta<'custom> = {
  title: None,
  breadcrumb: None,
  requiresAuth: false,
  roles: [],
  custom: None,
}

// Builder functions for fluent API
let withTitle = (meta: meta<'custom>, title: string): meta<'custom> => {
  {...meta, title: Some(title)}
}

let withBreadcrumb = (meta: meta<'custom>, breadcrumb: string): meta<'custom> => {
  {...meta, breadcrumb: Some(breadcrumb)}
}

let withAuth = (meta: meta<'custom>): meta<'custom> => {
  {...meta, requiresAuth: true}
}

let withRoles = (meta: meta<'custom>, roles: array<string>): meta<'custom> => {
  {...meta, requiresAuth: true, roles}
}

let withCustom = (meta: meta<'a>, custom: 'b): meta<'b> => {
  {
    title: meta.title,
    breadcrumb: meta.breadcrumb,
    requiresAuth: meta.requiresAuth,
    roles: meta.roles,
    custom: Some(custom),
  }
}

// Route with metadata attached
type routeWithMeta<'route, 'custom> = {
  route: 'route,
  meta: meta<'custom>,
}

// Route definition with metadata
type definition<'route, 'custom> = {
  parse: Url.t => option<routeWithMeta<'route, 'custom>>,
  toString: 'route => option<string>,
  getMeta: 'route => meta<'custom>,
}

// Breadcrumb item for navigation
type breadcrumbItem<'route> = {
  label: string,
  route: option<'route>,
  url: option<string>,
}

// Build a route definition with metadata
let build = (
  routeBuilder: RouteBuilder.t<'route>,
  ~getMeta: 'route => meta<'custom>
): definition<'route, 'custom> => {
  {
    parse: url => {
      switch routeBuilder.parse(url) {
      | Some(route) => Some({route, meta: getMeta(route)})
      | None => None
      }
    },
    toString: routeBuilder.toString,
    getMeta,
  }
}

// Auth guard result type
type authResult<'route> =
  | Allowed('route)
  | RequiresLogin('route)
  | InsufficientRoles('route, array<string>)

// Check if a route is accessible given user roles
let checkAuth = (
  routeWithMeta: routeWithMeta<'route, 'custom>,
  ~isLoggedIn: bool,
  ~userRoles: array<string>
): authResult<'route> => {
  let {route, meta} = routeWithMeta

  if !meta.requiresAuth {
    Allowed(route)
  } else if !isLoggedIn {
    RequiresLogin(route)
  } else if Belt.Array.length(meta.roles) == 0 {
    // Auth required but no specific roles
    Allowed(route)
  } else {
    // Check if user has any of the required roles
    let hasRole = Belt.Array.some(meta.roles, role =>
      Belt.Array.some(userRoles, userRole => userRole == role)
    )
    if hasRole {
      Allowed(route)
    } else {
      InsufficientRoles(route, meta.roles)
    }
  }
}

// Functor for building breadcrumbs from route hierarchy
module MakeBreadcrumbs = (Config: {
  type route
  type custom
  let definition: definition<route, custom>
  let getParent: route => option<route>
}): {
  let breadcrumbs: Config.route => array<breadcrumbItem<Config.route>>
} => {
  let rec collectBreadcrumbs = (
    route: Config.route,
    acc: list<breadcrumbItem<Config.route>>
  ): list<breadcrumbItem<Config.route>> => {
    let meta = Config.definition.getMeta(route)
    let url = Config.definition.toString(route)
    let label = switch meta.breadcrumb {
    | Some(b) => b
    | None =>
      switch meta.title {
      | Some(t) => t
      | None => "/"
      }
    }

    let item = {label, route: Some(route), url}
    let newAcc = list{item, ...acc}

    switch Config.getParent(route) {
    | Some(parent) => collectBreadcrumbs(parent, newAcc)
    | None => newAcc
    }
  }

  let breadcrumbs = (route: Config.route): array<breadcrumbItem<Config.route>> => {
    collectBreadcrumbs(route, list{})->Belt.List.toArray
  }
}

// Helper to create metadata inline
let make = (
  ~title: option<string>=?,
  ~breadcrumb: option<string>=?,
  ~requiresAuth: bool=false,
  ~roles: array<string>=[],
  ~custom: option<'custom>=?,
  ()
): meta<'custom> => {
  {
    title,
    breadcrumb,
    requiresAuth,
    roles,
    custom,
  }
}

// Convenience function for public routes
let public_ = (~title: option<string>=?, ~breadcrumb: option<string>=?, ()): meta<'custom> => {
  make(~title?, ~breadcrumb?, ~requiresAuth=false, ())
}

// Convenience function for authenticated routes
let authenticated = (
  ~title: option<string>=?,
  ~breadcrumb: option<string>=?,
  ~roles: array<string>=[],
  ()
): meta<'custom> => {
  make(~title?, ~breadcrumb?, ~requiresAuth=true, ~roles, ())
}
