# Cadre Router API Guide

**Version:** 0.2.0
**Status:** Production Ready
**License:** PMPL-1.0-or-later
**Author:** Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

## Table of Contents

- [Introduction](#introduction)
- [Core Concepts](#core-concepts)
- [Module Reference](#module-reference)
- [Parser Combinators](#parser-combinators)
- [Navigation](#navigation)
- [TEA Integration](#tea-integration)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Migration Guide](#migration-guide)

---

## Introduction

Cadre Router is a **type-safe routing library** for ReScript applications that provides:

- ✅ **Type-safe route definitions** (routes as variants, not strings)
- ✅ **Bidirectional serialization** (route ↔ URL)
- ✅ **Typed route parameters** (no string parsing errors)
- ✅ **Parser combinators** (composable URL parsing DSL)
- ✅ **Framework-agnostic** (works with React, TEA, or vanilla JS)
- ✅ **TEA integration** (optional, via `src/tea/` modules)

### Why Cadre Router?

Traditional routers are stringly-typed:
```javascript
// ❌ UNSAFE - strings everywhere
if (path === "/user/123") {
  const userId = path.split("/")[2]  // String manipulation
  loadUser(userId)  // userId might be invalid
}
```

Cadre Router is type-safe:
```rescript
// ✅ SAFE - types everywhere
switch route {
| User(userId) => loadUser(userId)  // userId is UserId.t (typed!)
| _ => ()
}
```

---

## Core Concepts

### 1. Routes as Variants

Define your application's routes as a ReScript variant:

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route =
  | Home
  | About
  | User(UserId.t)
  | Post(PostId.t, option<string>)  // postId + optional section
  | NotFound
```

### 2. Bidirectional Serialization

Every route can be:
- **Parsed from URL**: `string → route`
- **Serialized to URL**: `route → string`

```rescript
// Parse: "/user/abc123" → User(UserId("abc123"))
let route = parseUrl("/user/abc123")

// Serialize: User(UserId("abc123")) → "/user/abc123"
let url = serializeRoute(User(UserId("abc123")))
```

### 3. Parser Combinators

Build URL parsers compositionally:

```rescript
open CadreRouter.Parser

let userParser =
  s("user")                    // Match "/user"
  ->andThen(UserId.parser)     // Then parse UserId
  ->map(((_, id)) => User(id)) // Construct route

let parser = oneOf([
  top->map(_ => Home),
  userParser,
  // ... more routes
])
```

---

## Module Reference

### CadreRouter.Url

Parsed URL representation.

#### Types

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type t = {
  path: list<string>,
  query: Belt.Map.String.t<string>,
  fragment: option<string>
}
```

#### Functions

```rescript
let fromString: string => t
```
Parse a URL string into a structured URL.

**Example:**
```rescript
let url = CadreRouter.Url.fromString("/user/123?tab=profile#bio")
// url.path = ["user", "123"]
// url.query = Map { "tab": "profile" }
// url.fragment = Some("bio")
```

---

```rescript
let fromLocation: unit => t
```
Read current browser URL from `window.location`.

**Example:**
```rescript
// If browser is at: https://example.com/about?ref=home
let currentUrl = CadreRouter.Url.fromLocation()
// currentUrl.path = ["about"]
// currentUrl.query = Map { "ref": "home" }
```

---

```rescript
let toString: t => string
```
Serialize a URL back to a string.

**Example:**
```rescript
let url = {
  path: list{"user", "123"},
  query: Belt.Map.String.fromArray([("tab", "profile")]),
  fragment: Some("bio")
}
CadreRouter.Url.toString(url)
// => "/user/123?tab=profile#bio"
```

---

### CadreRouter.Parser

Parser combinators for building type-safe URL parsers.

#### Core Combinators

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

let top: parser<unit>
```
Matches the root path `/`.

**Example:**
```rescript
let homeParser = top->map(_ => Home)
// Matches: "/"
// Returns: Home
```

---

```rescript
let s: string => parser<unit>
```
Matches a literal path segment.

**Example:**
```rescript
let aboutParser = s("about")->map(_ => About)
// Matches: "/about"
// Returns: About
```

---

```rescript
let string: parser<string>
```
Captures a path segment as a string.

**Example:**
```rescript
let userParser =
  s("user")
  ->andThen(string)
  ->map(((_, name)) => User(name))
// Matches: "/user/alice"
// Returns: User("alice")
```

---

```rescript
let int: parser<int>
```
Captures a path segment as an integer.

**Example:**
```rescript
let postParser =
  s("post")
  ->andThen(int)
  ->map(((_, id)) => Post(id))
// Matches: "/post/42"
// Returns: Post(42)
```

---

```rescript
let custom: (string => option<'a>) => parser<'a>
```
Custom parser with validation.

**Example:**
```rescript
module UserId = {
  type t = UserId(string)

  let fromString = (str): option<t> => {
    if String.length(str) >= 3 {
      Some(UserId(str))
    } else {
      None
    }
  }

  let parser = CadreRouter.Parser.custom(fromString)
}

let userParser =
  s("user")
  ->andThen(UserId.parser)
  ->map(((_, id)) => User(id))
// Matches: "/user/abc123"
// Returns: User(UserId("abc123"))
// Rejects: "/user/ab" (too short)
```

---

#### Combinators

```rescript
let map: (parser<'a>, 'a => 'b) => parser<'b>
```
Transform parser result.

---

```rescript
let andThen: (parser<'a>, parser<'b>) => parser<('a, 'b)>
```
Sequence two parsers (both must match).

---

```rescript
let oneOf: list<parser<'a>> => parser<'a>
```
Try parsers in order until one succeeds.

**Example:**
```rescript
let parser = oneOf([
  top->map(_ => Home),
  s("about")->map(_ => About),
  s("contact")->map(_ => Contact),
])
```

---

```rescript
let query: (string, string => option<'a>) => parser<option<'a>>
```
Parse query parameter.

**Example:**
```rescript
let searchParser =
  s("search")
  ->andThen(query("q", str => Some(str)))
  ->map(((_, q)) => Search(q))
// Matches: "/search?q=hello"
// Returns: Search(Some("hello"))
```

---

```rescript
let fragment: parser<option<string>>
```
Capture URL fragment (hash).

**Example:**
```rescript
let docParser =
  s("docs")
  ->andThen(fragment)
  ->map(((_, frag)) => Docs(frag))
// Matches: "/docs#section-2"
// Returns: Docs(Some("section-2"))
```

---

#### Parsing

```rescript
let parse: (parser<'a>, Url.t) => option<'a>
```
Run a parser against a URL.

**Example:**
```rescript
let url = CadreRouter.Url.fromString("/user/123")
let result = CadreRouter.Parser.parse(parser, url)
// result = Some(User(UserId("123")))
```

---

### CadreRouter.Navigation

Browser History API integration.

#### Module Functor

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

module Make = (Route: {
  type t
  let toString: t => string
}) => {
  let pushUrl: string => unit
  let replaceUrl: string => unit
  let back: unit => unit
  let forward: unit => unit

  let pushRoute: Route.t => unit
  let replaceRoute: Route.t => unit
}
```

**Usage:**
```rescript
module Nav = CadreRouter.Navigation.Make({
  type t = route
  let toString = routeToString
})

// Navigate to a route
Nav.pushRoute(User(UserId("123")))

// Replace current history entry
Nav.replaceRoute(Home)

// Browser back/forward
Nav.back()
Nav.forward()
```

---

## Parser Combinators

### Building Complex Parsers

#### Example 1: Nested Routes

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route =
  | Home
  | User(userId, userView)

and userId = UserId(string)

and userView =
  | Profile
  | Posts
  | Settings

let userViewParser =
  oneOf([
    s("profile")->map(_ => Profile),
    s("posts")->map(_ => Posts),
    s("settings")->map(_ => Settings),
  ])

let userParser =
  s("user")
  ->andThen(UserId.parser)
  ->andThen(userViewParser)
  ->map((((_, id), view)) => User(id, view))

// Matches: "/user/alice/profile" → User(UserId("alice"), Profile)
// Matches: "/user/bob/posts" → User(UserId("bob"), Posts)
```

#### Example 2: Optional Segments

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route =
  | Search(option<string>)

let searchParser =
  s("search")
  ->andThen(oneOf([
    string->map(q => Some(q)),
    top->map(_ => None)
  ]))
  ->map(((_, query)) => Search(query))

// Matches: "/search" → Search(None)
// Matches: "/search/hello" → Search(Some("hello"))
```

#### Example 3: Query Parameters

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route = Posts(option<int>)  // page number

let postsParser =
  s("posts")
  ->andThen(query("page", str => Belt.Int.fromString(str)))
  ->map(((_, page)) => Posts(page))

// Matches: "/posts" → Posts(None)
// Matches: "/posts?page=2" → Posts(Some(2))
// Rejects: "/posts?page=abc" (invalid int)
```

---

## Navigation

### Programmatic Navigation

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

module Nav = CadreRouter.Navigation.Make({
  type t = route
  let toString = routeToString
})

// Push new route (adds history entry)
Nav.pushRoute(User(UserId("123")))

// Replace current route (no new history entry)
Nav.replaceRoute(Home)

// Go back/forward in history
Nav.back()
Nav.forward()

// Push raw URL
Nav.pushUrl("/about")
```

### Link Components (React)

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

@react.component
let make = (~route: route, ~children) => {
  let href = routeToString(route)

  let onClick = event => {
    ReactEvent.Mouse.preventDefault(event)
    Nav.pushRoute(route)
  }

  <a href onClick>{children}</a>
}

// Usage
<Link route={User(UserId("alice"))}>
  {React.string("View Alice's Profile")}
</Link>
```

---

## TEA Integration

### Optional TEA Module

Cadre Router includes optional TEA integration in `src/tea/`.

#### Tea_Router Module

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

module Router = {
  type t<'route> = {
    parser: CadreRouter.Parser.parser<'route>,
    toString: 'route => string,
    fallback: 'route
  }

  let make: (
    ~parser: CadreRouter.Parser.parser<'route>,
    ~toString: 'route => string,
    ~fallback: 'route
  ) => t<'route>
}

module Subscription = {
  let onChange: (
    Router.t<'route>,
    'route => 'msg
  ) => Tea_Sub.t<'msg>
}

module Command = {
  let pushRoute: (Router.t<'route>, 'route) => Tea_Cmd.t<'msg>
  let replaceRoute: (Router.t<'route>, 'route) => Tea_Cmd.t<'msg>
  let back: Tea_Cmd.t<'msg>
  let forward: Tea_Cmd.t<'msg>
}
```

#### Complete TEA Example

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

// Define routes
type route =
  | Home
  | About
  | User(UserId.t)
  | NotFound

// Create router
let router = Tea_Router.Router.make(
  ~parser=routeParser,
  ~toString=routeToString,
  ~fallback=NotFound
)

// Model includes current route
type model = {
  route: route,
  // ... other fields
}

type msg =
  | RouteChanged(route)
  | NavigateTo(route)
  // ... other messages

let init = () => {
  let initialRoute = Tea_Router.getCurrentRoute(router)
  ({route: initialRoute}, Tea_Cmd.none)
}

let update = (model, msg) => {
  switch msg {
  | RouteChanged(newRoute) => (
      {...model, route: newRoute},
      Tea_Cmd.none
    )
  | NavigateTo(route) => (
      model,
      Tea_Router.Command.pushRoute(router, route)
    )
  }
}

let subscriptions = model => {
  Tea_Router.Subscription.onChange(router, route => RouteChanged(route))
}
```

---

## Examples

### Example 1: Blog Router

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route =
  | Home
  | BlogIndex
  | BlogPost(PostId.t)
  | BlogTag(string)
  | About

module PostId = {
  type t = PostId(string)

  let fromString = (str): option<t> => {
    if String.length(str) > 0 {
      Some(PostId(str))
    } else {
      None
    }
  }

  let toString = (PostId(id)) => id
  let parser = CadreRouter.Parser.custom(fromString)
}

let routeParser = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => Home),
    s("blog")->map(_ => BlogIndex),
    s("blog")->andThen(PostId.parser)->map(((_, id)) => BlogPost(id)),
    s("tag")->andThen(string)->map(((_, tag)) => BlogTag(tag)),
    s("about")->map(_ => About),
  ])
}

let routeToString = route => switch route {
| Home => "/"
| BlogIndex => "/blog"
| BlogPost(id) => "/blog/" ++ PostId.toString(id)
| BlogTag(tag) => "/tag/" ++ tag
| About => "/about"
}
```

### Example 2: Admin Panel

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later

type route =
  | Dashboard
  | Users(usersView)
  | Settings(settingsView)

and usersView =
  | UsersList
  | UserDetail(UserId.t)
  | UserEdit(UserId.t)

and settingsView =
  | General
  | Security
  | Billing

let usersViewParser = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => UsersList),
    UserId.parser->andThen(s("edit"))->map(((id, _)) => UserEdit(id)),
    UserId.parser->map(id => UserDetail(id)),
  ])
}

let settingsViewParser = {
  open CadreRouter.Parser
  oneOf([
    s("general")->map(_ => General),
    s("security")->map(_ => Security),
    s("billing")->map(_ => Billing),
  ])
}

let routeParser = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => Dashboard),
    s("users")->andThen(usersViewParser)->map(((_, view)) => Users(view)),
    s("settings")->andThen(settingsViewParser)->map(((_, view)) => Settings(view)),
  ])
}
```

---

## Best Practices

### 1. Use Typed IDs

```rescript
// ✓ GOOD - Typed IDs
module UserId = {
  type t = UserId(string)
  let parser = CadreRouter.Parser.custom(str => Some(UserId(str)))
  let toString = (UserId(id)) => id
}

type route = User(UserId.t)

// ✗ BAD - String IDs
type route = User(string)
```

### 2. Centralize Route Definition

```rescript
// ✓ GOOD - Single source of truth
// Routes.res
type t = Home | About | User(UserId.t)
let parser = /* ... */
let toString = /* ... */

// ✗ BAD - Routes scattered across files
```

### 3. Handle NotFound

```rescript
// ✓ GOOD - Explicit NotFound variant
type route = Home | About | NotFound

let parseUrl = url => {
  switch CadreRouter.Parser.parse(parser, url) {
  | Some(route) => route
  | None => NotFound
  }
}

// ✗ BAD - Using option everywhere
let parseUrl = url => CadreRouter.Parser.parse(parser, url)  // option<route>
```

### 4. Extract Parsers

```rescript
// ✓ GOOD - Reusable parsers
let userIdParser = UserId.parser
let userParser = s("user")->andThen(userIdParser)->map(/* ... */)

// ✗ BAD - Inline everything
let parser = s("user")->andThen(custom(str => Some(UserId(str))))->map(/* ... */)
```

---

## Migration Guide

### From React Router

**Before (React Router):**
```jsx
<Route path="/user/:id" component={UserPage} />

// In component:
const { id } = useParams();  // id is string
```

**After (Cadre Router):**
```rescript
// Route definition
type route = User(UserId.t)

// In view:
switch model.route {
| User(userId) => <UserPage userId />  // userId is UserId.t
}
```

### From String-Based Routing

**Before:**
```javascript
if (window.location.pathname === "/about") {
  showAboutPage();
}
```

**After:**
```rescript
switch currentRoute {
| About => showAboutPage()
| _ => ()
}
```

---

## Testing

### Testing Parsers

```rescript
// SPDX-License-Identifier: PMPL-1.0-or-later
open Test

test("parses user route", () => {
  let url = CadreRouter.Url.fromString("/user/123")
  let result = CadreRouter.Parser.parse(routeParser, url)

  Assert.equal(result, Some(User(UserId("123"))))
})

test("rejects invalid routes", () => {
  let url = CadreRouter.Url.fromString("/invalid")
  let result = CadreRouter.Parser.parse(routeParser, url)

  Assert.equal(result, None)
})
```

### Testing Serialization

```rescript
test("route roundtrip", () => {
  let route = User(UserId("abc"))
  let url = routeToString(route)
  let parsed = parseUrl(CadreRouter.Url.fromString(url))

  Assert.equal(parsed, route)
})
```

---

## License

PMPL-1.0-or-later

Copyright (c) 2025 Jonathan D.A. Jewell

---

## References

- **Elm URL Parsing**: https://package.elm-lang.org/packages/elm/url/latest/
- **ReScript**: https://rescript-lang.org/
- **TEA Integration**: See `src/tea/` modules
- **Examples**: See `examples/` directory
