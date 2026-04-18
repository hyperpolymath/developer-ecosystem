// SPDX-License-Identifier: Apache-2.0
// NestedRoute.res - React Router-style nested layouts with outlets

// A nested route tree structure
type rec tree<'route> =
  | Leaf('route)
  | Branch({
      route: 'route,
      children: array<tree<'route>>,
    })

// Flattened match result with full path
type matchPath<'route> = {
  segments: array<'route>,
  leaf: 'route,
}

// Find a route in the tree and return the full path
let rec findInTree = (
  tree: tree<'route>,
  target: 'route,
  ~eq: ('route, 'route) => bool,
  ~currentPath: list<'route>
): option<matchPath<'route>> => {
  switch tree {
  | Leaf(route) =>
    if eq(route, target) {
      Some({
        segments: Belt.List.toArray(Belt.List.reverse(currentPath)),
        leaf: route,
      })
    } else {
      None
    }
  | Branch({route, children}) =>
    if eq(route, target) {
      Some({
        segments: Belt.List.toArray(Belt.List.reverse(currentPath)),
        leaf: route,
      })
    } else {
      let newPath = list{route, ...currentPath}
      let result = ref(None)
      let i = ref(0)
      let len = Belt.Array.length(children)

      while result.contents == None && i.contents < len {
        switch children[i.contents] {
        | Some(child) =>
          switch findInTree(child, target, ~eq, ~currentPath=newPath) {
          | Some(_) as found => result := found
          | None => i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }

      result.contents
    }
  }
}

// Layout context for passing outlet content
type layoutContext<'route> = {
  route: 'route,
  depth: int,
  isLeaf: bool,
}

// Nested route definition with layout support
type t<'route> = {
  tree: tree<'route>,
  parse: Url.t => option<'route>,
  toString: 'route => option<string>,
  eq: ('route, 'route) => bool,
}

// Create a nested route definition
let make = (
  ~tree: tree<'route>,
  ~parse: Url.t => option<'route>,
  ~toString: 'route => option<string>,
  ~eq: ('route, 'route) => bool
): t<'route> => {
  {tree, parse, toString, eq}
}

// Get the layout path for a route (all parent routes + the route itself)
let getLayoutPath = (def: t<'route>, route: 'route): option<matchPath<'route>> => {
  findInTree(def.tree, route, ~eq=def.eq, ~currentPath=list{})
}

// Get layout contexts for rendering nested layouts
let getLayoutContexts = (def: t<'route>, route: 'route): array<layoutContext<'route>> => {
  switch getLayoutPath(def, route) {
  | Some({segments, leaf}) =>
    let parentContexts =
      segments->Belt.Array.mapWithIndex((i, r) => {
        {
          route: r,
          depth: i,
          isLeaf: false,
        }
      })
    let leafContext = {
      route: leaf,
      depth: Belt.Array.length(segments),
      isLeaf: true,
    }
    Belt.Array.concat(parentContexts, [leafContext])
  | None => []
  }
}

// Helpers for building route trees
let leaf = (route: 'route): tree<'route> => Leaf(route)

let branch = (route: 'route, children: array<tree<'route>>): tree<'route> => {
  Branch({route, children})
}

// Alternative: index route (first child is the default)
let index = (parent: 'route, indexRoute: 'route, children: array<tree<'route>>): tree<'route> => {
  Branch({
    route: parent,
    children: Belt.Array.concat([Leaf(indexRoute)], children),
  })
}

// React integration for nested layouts
module React = {
  // Context for passing outlet content down the tree
  type outletContext<'route> = {
    remainingLayouts: array<layoutContext<'route>>,
    renderLayout: layoutContext<'route> => React.element,
  }

  // Outlet component placeholder
  @react.component
  let outlet = (~context: outletContext<'route>, ~fallback: React.element=React.null) => {
    switch context.remainingLayouts[0] {
    | Some(nextLayout) => context.renderLayout(nextLayout)
    | None => fallback
    }
  }

  // Build outlet context for the next level
  let nextOutletContext = (
    context: outletContext<'route>
  ): outletContext<'route> => {
    {
      ...context,
      remainingLayouts: Belt.Array.sliceToEnd(context.remainingLayouts, 1),
    }
  }

  // Functor for creating a complete nested router
  module Make = (Config: {
    type route
    let definition: t<route>
    let renderLayout: (layoutContext<route>, outletContext<route>) => React.element
    let renderNotFound: unit => React.element
  }): {
    @react.component
    let make: (~route: Config.route) => React.element
  } => {
    @react.component
    let make = (~route: Config.route) => {
      let layouts = getLayoutContexts(Config.definition, route)

      if Belt.Array.length(layouts) == 0 {
        Config.renderNotFound()
      } else {
        let rec renderAtDepth = (idx: int): React.element => {
          switch layouts[idx] {
          | Some(layout) =>
            let outletCtx: outletContext<Config.route> = {
              remainingLayouts: Belt.Array.sliceToEnd(layouts, idx + 1),
              renderLayout: ctx => {
                let nextIdx =
                  layouts->Belt.Array.getIndexBy(l => Config.definition.eq(l.route, ctx.route))
                switch nextIdx {
                | Some(i) => renderAtDepth(i)
                | None => React.null
                }
              },
            }
            Config.renderLayout(layout, outletCtx)
          | None => React.null
          }
        }
        renderAtDepth(0)
      }
    }
  }
}

// Parser combinator for nested routes
let nestedParser = (
  parentParser: Parser.t<'parent>,
  childParser: Parser.t<'child>,
  ~combine: ('parent, 'child) => 'route
): Parser.t<'route> => {
  Parser.andThen(parentParser, childParser)->Parser.map(((p, c)) => combine(p, c))
}

// Optional child parser (matches parent alone or parent + child)
let optionalChild = (
  parentParser: Parser.t<'parent>,
  childParser: Parser.t<'child>,
  ~parentOnly: 'parent => 'route,
  ~withChild: ('parent, 'child) => 'route
): Parser.t<'route> => {
  Parser.oneOf([
    Parser.andThen(parentParser, childParser)->Parser.map(((p, c)) => withChild(p, c)),
    Parser.andThen(parentParser, Parser.top)->Parser.map(((p, _)) => parentOnly(p)),
  ])
}
