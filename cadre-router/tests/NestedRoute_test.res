// SPDX-License-Identifier: Apache-2.0
// NestedRoute_test.res - Tests for nested route layouts

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

let assertSome = (name: string, actual: option<'a>): unit => {
  switch actual {
  | Some(_) => Js.Console.log(`[PASS] ${name}`)
  | None => Js.Console.error(`[FAIL] ${name} - expected Some, got None`)
  }
}

let assertNone = (name: string, actual: option<'a>): unit => {
  switch actual {
  | None => Js.Console.log(`[PASS] ${name}`)
  | Some(_) => Js.Console.error(`[FAIL] ${name} - expected None, got Some`)
  }
}

// ============================================================
// Test Route Types
// ============================================================

type route =
  | Root
  | Dashboard
  | DashboardOverview
  | DashboardAnalytics
  | Settings
  | SettingsProfile
  | SettingsSecurity
  | NotFound

let routeEq = (a: route, b: route): bool => a == b

// ============================================================
// Tree Building Tests
// ============================================================

let testLeaf = () => {
  let tree = NestedRoute.leaf(Dashboard)
  switch tree {
  | NestedRoute.Leaf(r) => assertEq("leaf: creates leaf node", r, Dashboard)
  | _ => Js.Console.error("[FAIL] leaf: should create Leaf variant")
  }
}

let testBranch = () => {
  let tree = NestedRoute.branch(
    Dashboard,
    [NestedRoute.leaf(DashboardOverview), NestedRoute.leaf(DashboardAnalytics)],
  )
  switch tree {
  | NestedRoute.Branch({route, children}) =>
    assertEq("branch: parent route", route, Dashboard)
    assertEq("branch: child count", Belt.Array.length(children), 2)
  | _ => Js.Console.error("[FAIL] branch: should create Branch variant")
  }
}

let testIndex = () => {
  let tree = NestedRoute.index(
    Settings,
    SettingsProfile,
    [NestedRoute.leaf(SettingsSecurity)],
  )
  switch tree {
  | NestedRoute.Branch({route, children}) =>
    assertEq("index: parent route", route, Settings)
    // Index route is prepended as first child
    assertEq("index: child count", Belt.Array.length(children), 2)
  | _ => Js.Console.error("[FAIL] index: should create Branch variant")
  }
}

// ============================================================
// Tree Search Tests
// ============================================================

let testFindLeafInTree = () => {
  let tree = NestedRoute.branch(
    Root,
    [
      NestedRoute.branch(Dashboard, [NestedRoute.leaf(DashboardOverview)]),
      NestedRoute.leaf(Settings),
    ],
  )

  let result = NestedRoute.findInTree(tree, DashboardOverview, ~eq=routeEq, ~currentPath=list{})
  assertSome("findInTree: finds nested leaf", result)

  switch result {
  | Some({segments, leaf}) =>
    assertEq("findInTree: correct leaf", leaf, DashboardOverview)
    assertEq("findInTree: path depth", Belt.Array.length(segments), 2)
  | None => ()
  }
}

let testFindBranchInTree = () => {
  let tree = NestedRoute.branch(
    Root,
    [NestedRoute.branch(Dashboard, [NestedRoute.leaf(DashboardOverview)])],
  )

  let result = NestedRoute.findInTree(tree, Dashboard, ~eq=routeEq, ~currentPath=list{})
  assertSome("findInTree: finds branch route", result)
}

let testFindNotInTree = () => {
  let tree = NestedRoute.branch(Root, [NestedRoute.leaf(Dashboard)])

  let result = NestedRoute.findInTree(tree, Settings, ~eq=routeEq, ~currentPath=list{})
  assertNone("findInTree: returns None for missing route", result)
}

// ============================================================
// Layout Context Tests
// ============================================================

let testGetLayoutContexts = () => {
  let tree = NestedRoute.branch(
    Root,
    [
      NestedRoute.branch(
        Dashboard,
        [
          NestedRoute.leaf(DashboardOverview),
          NestedRoute.leaf(DashboardAnalytics),
        ],
      ),
    ],
  )

  let def = NestedRoute.make(
    ~tree,
    ~parse=_ => Some(DashboardOverview),
    ~toString=_ => Some("/dashboard/overview"),
    ~eq=routeEq,
  )

  let contexts = NestedRoute.getLayoutContexts(def, DashboardOverview)

  // Should have: Root -> Dashboard -> DashboardOverview
  assertEq("getLayoutContexts: context count", Belt.Array.length(contexts), 3)

  // Check first context (Root)
  switch contexts[0] {
  | Some(ctx) =>
    assertEq("getLayoutContexts: first route", ctx.route, Root)
    assertEq("getLayoutContexts: first depth", ctx.depth, 0)
    assertEq("getLayoutContexts: first isLeaf", ctx.isLeaf, false)
  | None => Js.Console.error("[FAIL] getLayoutContexts: missing first context")
  }

  // Check last context (leaf)
  switch contexts[2] {
  | Some(ctx) =>
    assertEq("getLayoutContexts: last route", ctx.route, DashboardOverview)
    assertEq("getLayoutContexts: last isLeaf", ctx.isLeaf, true)
  | None => Js.Console.error("[FAIL] getLayoutContexts: missing last context")
  }
}

let testGetLayoutContextsNotFound = () => {
  let tree = NestedRoute.leaf(Root)

  let def = NestedRoute.make(
    ~tree,
    ~parse=_ => None,
    ~toString=_ => None,
    ~eq=routeEq,
  )

  let contexts = NestedRoute.getLayoutContexts(def, NotFound)
  assertEq("getLayoutContexts not found: empty array", Belt.Array.length(contexts), 0)
}

// ============================================================
// Parser Combinator Tests
// ============================================================

let testNestedParser = () => {
  let parentParser = Parser.s("dashboard")
  let childParser = Parser.s("overview")

  let combined = NestedRoute.nestedParser(
    parentParser,
    childParser,
    ~combine=(_, _) => DashboardOverview,
  )

  let url = Url.fromString("/dashboard/overview")
  let result = Parser.parse(combined, url)
  assertEq("nestedParser: parses nested route", result, Some(DashboardOverview))
}

let testOptionalChildWithChild = () => {
  let parentParser = Parser.s("settings")
  let childParser = Parser.s("security")

  let combined = NestedRoute.optionalChild(
    parentParser,
    childParser,
    ~parentOnly=_ => Settings,
    ~withChild=(_, _) => SettingsSecurity,
  )

  let url = Url.fromString("/settings/security")
  let result = Parser.parse(combined, url)
  assertEq("optionalChild with child: parses full path", result, Some(SettingsSecurity))
}

let testOptionalChildWithoutChild = () => {
  let parentParser = Parser.s("settings")
  let childParser = Parser.s("security")

  let combined = NestedRoute.optionalChild(
    parentParser,
    childParser,
    ~parentOnly=_ => Settings,
    ~withChild=(_, _) => SettingsSecurity,
  )

  let url = Url.fromString("/settings")
  let result = Parser.parse(combined, url)
  assertEq("optionalChild without child: parses parent only", result, Some(Settings))
}

// ============================================================
// Run All Tests
// ============================================================

let runTests = () => {
  Js.Console.log("=== NestedRoute Tests ===")

  // Tree building
  testLeaf()
  testBranch()
  testIndex()

  // Tree search
  testFindLeafInTree()
  testFindBranchInTree()
  testFindNotInTree()

  // Layout contexts
  testGetLayoutContexts()
  testGetLayoutContextsNotFound()

  // Parser combinators
  testNestedParser()
  testOptionalChildWithChild()
  testOptionalChildWithoutChild()

  Js.Console.log("=== NestedRoute Tests Complete ===")
}

// Auto-run tests
let _ = runTests()
