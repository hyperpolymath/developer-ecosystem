// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Drag behavior bindings

type t

type subject<'data> = {
  x: float,
  y: float,
  data: 'data,
}

type dragEvent<'datum> = {
  target: t,
  @as("type") type_: string,  // "start", "drag", "end"
  subject: subject<'datum>,
  x: float,
  y: float,
  dx: float,
  dy: float,
  identifier: string,
  active: int,
  sourceEvent: Dom.event,
}

// Create drag behavior
@module("d3") external drag: unit => t = "drag"

// Configuration
@send external container: (t, Dom.element) => t = "container"
@send external containerFn: (t, @uncurry (Dom.element, 'datum, int) => Dom.element) => t = "container"
@send external filter: (t, @uncurry (Dom.event, 'datum) => bool) => t = "filter"
@send external touchable: (t, @uncurry (Dom.element, 'datum, int) => bool) => t = "touchable"
@send external subject: (t, @uncurry (Dom.event, 'datum) => subject<'datum>) => t = "subject"
@send external clickDistance: (t, int) => t = "clickDistance"

// Event handlers
@send external on: (t, string, @uncurry (dragEvent<'datum>, 'datum) => unit) => t = "on"

// Apply drag to selection
@send external applyTo: (D3_Selection.t, t) => D3_Selection.t = "call"

// Disable drag on certain elements (useful for buttons inside draggable nodes)
@module("d3") external dragDisable: Dom.window => unit = "dragDisable"
@module("d3") external dragEnable: (Dom.window, ~noclick: bool=?) => unit = "dragEnable"
