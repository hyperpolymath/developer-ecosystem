// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Selection bindings

type t

// Selection creation
@module("d3") external select: string => t = "select"
@module("d3") external selectElement: Dom.element => t = "select"
@module("d3") external selectAll: string => t = "selectAll"

// Sub-selection
@send external selectChild: (t, string) => t = "select"
@send external selectChildren: (t, string) => t = "selectAll"

// Modification
@send external attr: (t, string, 'a) => t = "attr"
@send external attrFn: (t, string, @uncurry ('datum, int) => 'a) => t = "attr"
@send external style: (t, string, string) => t = "style"
@send external styleFn: (t, string, @uncurry ('datum, int) => string) => t = "style"
@send external classed: (t, string, bool) => t = "classed"
@send external text: (t, string) => t = "text"
@send external textFn: (t, @uncurry ('datum, int) => string) => t = "text"
@send external html: (t, string) => t = "html"
@send external property: (t, string, 'a) => t = "property"

// Data binding
@send external data: (t, array<'datum>) => t = "data"
@send external dataWithKey: (t, array<'datum>, @uncurry ('datum, int) => string) => t = "data"
@send external datum: (t, 'datum) => t = "datum"
@send external enter: t => t = "enter"
@send external exit: t => t = "exit"
@send external merge: (t, t) => t = "merge"
@send external join: (t, string) => t = "join"

// DOM manipulation
@send external append: (t, string) => t = "append"
@send external insert: (t, string, string) => t = "insert"
@send external remove: t => t = "remove"
@send external raise_: t => t = "raise"
@send external lower: t => t = "lower"
@send external clone: t => t = "clone"

// Events
@send external on: (t, string, @uncurry ('event, 'datum) => unit) => t = "on"
@send external onWithCapture: (t, string, @uncurry ('event, 'datum) => unit, bool) => t = "on"

// Iteration
@send external each: (t, @uncurry ('datum, int, array<Dom.element>) => unit) => t = "each"
@send external call: (t, @uncurry t => unit) => t = "call"
@send external callWithArg: (t, @uncurry (t, 'arg) => unit, 'arg) => t = "call"

// Control flow
@send external empty: t => bool = "empty"
@send external nodes: t => array<Dom.element> = "nodes"
@send external node: t => Nullable.t<Dom.element> = "node"
@send external size: t => int = "size"

// Transitions (basic)
@send external transition: t => t = "transition"
@send external transitionNamed: (t, string) => t = "transition"
@send external duration: (t, int) => t = "duration"
@send external delay: (t, int) => t = "delay"
@send external ease: (t, 'easeFn) => t = "ease"
