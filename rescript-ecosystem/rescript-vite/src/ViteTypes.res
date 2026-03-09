// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// ViteTypes.res — Vite plugin API type bindings.
//
// Minimal, correct bindings for the Vite plugin hooks we use.
// Not a full Vite binding — just what rescript-vite needs.

/// Vite resolved config (subset we care about)
type resolvedConfig = {
  root: string,
  command: string,  // "serve" | "build"
  mode: string,     // "development" | "production"
}

/// Vite HMR context for handleHotUpdate
type rec hmrContext = {
  file: string,
  modules: array<moduleNode>,
  server: viteDevServer,
}
and moduleNode = {
  id: option<string>,
  @as("file") moduleFile: option<string>,
  url: string,
}
and viteDevServer = {
  moduleGraph: moduleGraph,
  ws: webSocketServer,
}
and moduleGraph = {
  getModulesByFile: string => option<array<moduleNode>>,
}
and webSocketServer = {
  send: JSON.t => unit,
}

/// Vite plugin definition (the object we return)
type plugin = {
  name: string,
  enforce: option<string>,  // "pre" | "post"
  configResolved: option<resolvedConfig => unit>,
  buildStart: option<unit => promise<unit>>,
  handleHotUpdate: option<hmrContext => option<array<moduleNode>>>,
  buildEnd: option<unit => unit>,
  closeBundle: option<unit => unit>,
}
