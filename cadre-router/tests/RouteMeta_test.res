// SPDX-License-Identifier: Apache-2.0
// RouteMeta_test.res - Tests for route metadata

// Test harness
let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, actual: bool): unit => {
  if actual {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name} - expected true`)
  }
}

let assertFalse = (name: string, actual: bool): unit => {
  if !actual {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name} - expected false`)
  }
}

// ============================================================
// Test Route Types
// ============================================================

type route =
  | Home
  | Dashboard
  | Profile
  | Settings
  | AdminPanel
  | NotFound

// ============================================================
// Basic Metadata Tests
// ============================================================

let testEmptyMeta = () => {
  let meta: RouteMeta.meta<unit> = RouteMeta.empty
  assertEq("empty: title is None", meta.title, None)
  assertEq("empty: breadcrumb is None", meta.breadcrumb, None)
  assertFalse("empty: requiresAuth is false", meta.requiresAuth)
  assertEq("empty: roles is empty", meta.roles, [])
}

let testWithTitle = () => {
  let meta = RouteMeta.empty->RouteMeta.withTitle("My Page")
  assertEq("withTitle: sets title", meta.title, Some("My Page"))
}

let testWithBreadcrumb = () => {
  let meta = RouteMeta.empty->RouteMeta.withBreadcrumb("Home")
  assertEq("withBreadcrumb: sets breadcrumb", meta.breadcrumb, Some("Home"))
}

let testWithAuth = () => {
  let meta = RouteMeta.empty->RouteMeta.withAuth
  assertTrue("withAuth: sets requiresAuth", meta.requiresAuth)
}

let testWithRoles = () => {
  let meta = RouteMeta.empty->RouteMeta.withRoles(["admin", "editor"])
  assertTrue("withRoles: sets requiresAuth", meta.requiresAuth)
  assertEq("withRoles: sets roles", meta.roles, ["admin", "editor"])
}

let testFluentBuilder = () => {
  let meta =
    RouteMeta.empty
    ->RouteMeta.withTitle("Admin Panel")
    ->RouteMeta.withBreadcrumb("Admin")
    ->RouteMeta.withRoles(["admin"])

  assertEq("fluent: title", meta.title, Some("Admin Panel"))
  assertEq("fluent: breadcrumb", meta.breadcrumb, Some("Admin"))
  assertTrue("fluent: requiresAuth", meta.requiresAuth)
  assertEq("fluent: roles", meta.roles, ["admin"])
}

let testMakeHelper = () => {
  let meta = RouteMeta.make(
    ~title="Test",
    ~breadcrumb="Test Crumb",
    ~requiresAuth=true,
    ~roles=["user"],
    (),
  )
  assertEq("make: title", meta.title, Some("Test"))
  assertEq("make: breadcrumb", meta.breadcrumb, Some("Test Crumb"))
  assertTrue("make: requiresAuth", meta.requiresAuth)
  assertEq("make: roles", meta.roles, ["user"])
}

let testPublicHelper = () => {
  let meta = RouteMeta.public_(~title="Public Page", ())
  assertEq("public_: title", meta.title, Some("Public Page"))
  assertFalse("public_: requiresAuth", meta.requiresAuth)
}

let testAuthenticatedHelper = () => {
  let meta = RouteMeta.authenticated(~title="Private", ~roles=["admin"], ())
  assertEq("authenticated: title", meta.title, Some("Private"))
  assertTrue("authenticated: requiresAuth", meta.requiresAuth)
  assertEq("authenticated: roles", meta.roles, ["admin"])
}

// ============================================================
// Auth Guard Tests
// ============================================================

let testCheckAuthPublicRoute = () => {
  let routeWithMeta: RouteMeta.routeWithMeta<route, unit> = {
    route: Home,
    meta: RouteMeta.public_(~title="Home", ()),
  }
  let result = RouteMeta.checkAuth(routeWithMeta, ~isLoggedIn=false, ~userRoles=[])

  switch result {
  | RouteMeta.Allowed(r) => assertEq("checkAuth public: allowed", r, Home)
  | _ => Js.Console.error("[FAIL] checkAuth public: should be Allowed")
  }
}

let testCheckAuthRequiresLoginNotLoggedIn = () => {
  let routeWithMeta: RouteMeta.routeWithMeta<route, unit> = {
    route: Dashboard,
    meta: RouteMeta.authenticated(~title="Dashboard", ()),
  }
  let result = RouteMeta.checkAuth(routeWithMeta, ~isLoggedIn=false, ~userRoles=[])

  switch result {
  | RouteMeta.RequiresLogin(r) => assertEq("checkAuth not logged in: requires login", r, Dashboard)
  | _ => Js.Console.error("[FAIL] checkAuth not logged in: should be RequiresLogin")
  }
}

let testCheckAuthRequiresLoginLoggedIn = () => {
  let routeWithMeta: RouteMeta.routeWithMeta<route, unit> = {
    route: Profile,
    meta: RouteMeta.authenticated(~title="Profile", ()),
  }
  let result = RouteMeta.checkAuth(routeWithMeta, ~isLoggedIn=true, ~userRoles=[])

  switch result {
  | RouteMeta.Allowed(r) => assertEq("checkAuth logged in: allowed", r, Profile)
  | _ => Js.Console.error("[FAIL] checkAuth logged in: should be Allowed")
  }
}

let testCheckAuthInsufficientRoles = () => {
  let routeWithMeta: RouteMeta.routeWithMeta<route, unit> = {
    route: AdminPanel,
    meta: RouteMeta.authenticated(~title="Admin", ~roles=["admin"], ()),
  }
  let result = RouteMeta.checkAuth(routeWithMeta, ~isLoggedIn=true, ~userRoles=["user"])

  switch result {
  | RouteMeta.InsufficientRoles(r, roles) =>
    assertEq("checkAuth insufficient roles: route", r, AdminPanel)
    assertEq("checkAuth insufficient roles: required", roles, ["admin"])
  | _ => Js.Console.error("[FAIL] checkAuth insufficient roles: should be InsufficientRoles")
  }
}

let testCheckAuthSufficientRoles = () => {
  let routeWithMeta: RouteMeta.routeWithMeta<route, unit> = {
    route: AdminPanel,
    meta: RouteMeta.authenticated(~title="Admin", ~roles=["admin", "superuser"], ()),
  }
  let result = RouteMeta.checkAuth(routeWithMeta, ~isLoggedIn=true, ~userRoles=["admin"])

  switch result {
  | RouteMeta.Allowed(r) => assertEq("checkAuth sufficient roles: allowed", r, AdminPanel)
  | _ => Js.Console.error("[FAIL] checkAuth sufficient roles: should be Allowed")
  }
}

// ============================================================
// Run All Tests
// ============================================================

let runTests = () => {
  Js.Console.log("=== RouteMeta Tests ===")

  // Basic metadata
  testEmptyMeta()
  testWithTitle()
  testWithBreadcrumb()
  testWithAuth()
  testWithRoles()
  testFluentBuilder()
  testMakeHelper()
  testPublicHelper()
  testAuthenticatedHelper()

  // Auth guards
  testCheckAuthPublicRoute()
  testCheckAuthRequiresLoginNotLoggedIn()
  testCheckAuthRequiresLoginLoggedIn()
  testCheckAuthInsufficientRoles()
  testCheckAuthSufficientRoles()

  Js.Console.log("=== RouteMeta Tests Complete ===")
}

// Auto-run tests
let _ = runTests()
