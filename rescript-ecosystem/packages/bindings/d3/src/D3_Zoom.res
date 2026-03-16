// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Zoom behavior bindings

type t
type transform = {
  x: float,
  y: float,
  k: float,  // scale
}

type zoomEvent<'datum> = {
  target: t,
  @as("type") type_: string,
  transform: transform,
  sourceEvent: Nullable.t<Dom.event>,
}

// Create zoom behavior
@module("d3") external zoom: unit => t = "zoom"

// Zoom configuration
@send external scaleExtent: (t, (float, float)) => t = "scaleExtent"
@send external translateExtent: (t, ((float, float), (float, float))) => t = "translateExtent"
@send external extent: (t, ((float, float), (float, float))) => t = "extent"
@send external extentFn: (t, @uncurry (Dom.element, 'datum, int) => ((float, float), (float, float))) => t = "extent"
@send external duration: (t, int) => t = "duration"
@send external interpolate: (t, 'interpolator) => t = "interpolate"
@send external filter: (t, @uncurry (Dom.event, 'datum) => bool) => t = "filter"
@send external touchable: (t, @uncurry (Dom.element, 'datum, int) => bool) => t = "touchable"
@send external wheelDelta: (t, @uncurry Dom.event => float) => t = "wheelDelta"
@send external clickDistance: (t, int) => t = "clickDistance"
@send external constrain: (t, @uncurry (transform, ((float, float), (float, float)), ((float, float), (float, float))) => transform) => t = "constrain"

// Event handlers
@send external on: (t, string, @uncurry (zoomEvent<'datum>, 'datum) => unit) => t = "on"

// Apply zoom to selection
@send external applyTo: (D3_Selection.t, t) => D3_Selection.t = "call"

// Transform utilities
@module("d3") external zoomIdentity: transform = "zoomIdentity"
@module("d3") external zoomTransform: Dom.element => transform = "zoomTransform"

// Transform methods (immutable - returns new transform)
@send external scale: (transform, float) => transform = "scale"
@send external translate: (transform, float, float) => transform = "translate"
@send external apply: (transform, (float, float)) => (float, float) = "apply"
@send external applyX: (transform, float) => float = "applyX"
@send external applyY: (transform, float) => float = "applyY"
@send external invert: (transform, (float, float)) => (float, float) = "invert"
@send external invertX: (transform, float) => float = "invertX"
@send external invertY: (transform, float) => float = "invertY"
@send external rescaleX: (transform, 'scale) => 'scale = "rescaleX"
@send external rescaleY: (transform, 'scale) => 'scale = "rescaleY"
@send external toString: transform => string = "toString"

// Programmatic zoom control
@send external zoomTransformTo: (D3_Selection.t, t, transform) => D3_Selection.t = "call"
@send external zoomScaleBy: (D3_Selection.t, t, float) => D3_Selection.t = "call"
@send external zoomScaleTo: (D3_Selection.t, t, float) => D3_Selection.t = "call"
@send external zoomTranslateBy: (D3_Selection.t, t, float, float) => D3_Selection.t = "call"
@send external zoomTranslateTo: (D3_Selection.t, t, float, float) => D3_Selection.t = "call"
