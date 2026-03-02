// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Force simulation bindings for force-directed graphs

// Node type for force simulation
type node<'data> = {
  mutable index: int,
  mutable x: float,
  mutable y: float,
  mutable vx: float,
  mutable vy: float,
  mutable fx: Nullable.t<float>,
  mutable fy: Nullable.t<float>,
  data: 'data,
}

// Link type for force simulation
type link<'nodeData> = {
  source: node<'nodeData>,
  target: node<'nodeData>,
  mutable index: int,
}

// Link input (before simulation processes it)
type linkInput<'nodeData> = {
  source: string,  // Node ID
  target: string,  // Node ID
}

// Simulation type
type simulation<'nodeData>

// Force types
type force<'nodeData>

// Create simulation
@module("d3") external forceSimulation: array<node<'data>> => simulation<'data> = "forceSimulation"
@module("d3") external forceSimulationEmpty: unit => simulation<'data> = "forceSimulation"

// Simulation methods
@send external nodes: (simulation<'data>, array<node<'data>>) => simulation<'data> = "nodes"
@send external getNodes: simulation<'data> => array<node<'data>> = "nodes"
@send external alpha: (simulation<'data>, float) => simulation<'data> = "alpha"
@send external getAlpha: simulation<'data> => float = "alpha"
@send external alphaMin: (simulation<'data>, float) => simulation<'data> = "alphaMin"
@send external alphaDecay: (simulation<'data>, float) => simulation<'data> = "alphaDecay"
@send external alphaTarget: (simulation<'data>, float) => simulation<'data> = "alphaTarget"
@send external velocityDecay: (simulation<'data>, float) => simulation<'data> = "velocityDecay"
@send external force: (simulation<'data>, string, force<'data>) => simulation<'data> = "force"
@send external getForce: (simulation<'data>, string) => Nullable.t<force<'data>> = "force"
@send external removeForce: (simulation<'data>, string, @as(json`null`) _) => simulation<'data> = "force"
@send external restart: simulation<'data> => simulation<'data> = "restart"
@send external stop: simulation<'data> => simulation<'data> = "stop"
@send external tick: (simulation<'data>, ~iterations: int=?) => simulation<'data> = "tick"
@send external on: (simulation<'data>, string, @uncurry unit => unit) => simulation<'data> = "on"

// Force: Link
@module("d3") external forceLink: array<linkInput<'data>> => force<'data> = "forceLink"
@module("d3") external forceLinkEmpty: unit => force<'data> = "forceLink"

// Link force methods (need to cast)
type linkForce<'data>
external asLinkForce: force<'data> => linkForce<'data> = "%identity"
@send external links: (linkForce<'data>, array<linkInput<'data>>) => linkForce<'data> = "links"
@send external getLinks: linkForce<'data> => array<link<'data>> = "links"
@send external linkId: (linkForce<'data>, @uncurry (linkInput<'data>, int, array<linkInput<'data>>) => string) => linkForce<'data> = "id"
@send external linkDistance: (linkForce<'data>, float) => linkForce<'data> = "distance"
@send external linkDistanceFn: (linkForce<'data>, @uncurry (link<'data>, int, array<link<'data>>) => float) => linkForce<'data> = "distance"
@send external linkStrength: (linkForce<'data>, float) => linkForce<'data> = "strength"
@send external linkStrengthFn: (linkForce<'data>, @uncurry (link<'data>, int, array<link<'data>>) => float) => linkForce<'data> = "strength"
@send external linkIterations: (linkForce<'data>, int) => linkForce<'data> = "iterations"
external linkForceAsForce: linkForce<'data> => force<'data> = "%identity"

// Force: Many-body (gravity/repulsion)
@module("d3") external forceManyBody: unit => force<'data> = "forceManyBody"

type manyBodyForce<'data>
external asManyBodyForce: force<'data> => manyBodyForce<'data> = "%identity"
@send external strength: (manyBodyForce<'data>, float) => manyBodyForce<'data> = "strength"
@send external strengthFn: (manyBodyForce<'data>, @uncurry (node<'data>, int, array<node<'data>>) => float) => manyBodyForce<'data> = "strength"
@send external theta: (manyBodyForce<'data>, float) => manyBodyForce<'data> = "theta"
@send external distanceMin: (manyBodyForce<'data>, float) => manyBodyForce<'data> = "distanceMin"
@send external distanceMax: (manyBodyForce<'data>, float) => manyBodyForce<'data> = "distanceMax"
external manyBodyForceAsForce: manyBodyForce<'data> => force<'data> = "%identity"

// Force: Center
@module("d3") external forceCenter: (float, float) => force<'data> = "forceCenter"

type centerForce<'data>
external asCenterForce: force<'data> => centerForce<'data> = "%identity"
@send external x: (centerForce<'data>, float) => centerForce<'data> = "x"
@send external y: (centerForce<'data>, float) => centerForce<'data> = "y"
@send external centerStrength: (centerForce<'data>, float) => centerForce<'data> = "strength"
external centerForceAsForce: centerForce<'data> => force<'data> = "%identity"

// Force: Collision
@module("d3") external forceCollide: float => force<'data> = "forceCollide"
@module("d3") external forceCollideEmpty: unit => force<'data> = "forceCollide"

type collideForce<'data>
external asCollideForce: force<'data> => collideForce<'data> = "%identity"
@send external radius: (collideForce<'data>, float) => collideForce<'data> = "radius"
@send external radiusFn: (collideForce<'data>, @uncurry (node<'data>, int, array<node<'data>>) => float) => collideForce<'data> = "radius"
@send external collideStrength: (collideForce<'data>, float) => collideForce<'data> = "strength"
@send external collideIterations: (collideForce<'data>, int) => collideForce<'data> = "iterations"
external collideForceAsForce: collideForce<'data> => force<'data> = "%identity"

// Force: X positioning
@module("d3") external forceX: float => force<'data> = "forceX"
@module("d3") external forceXEmpty: unit => force<'data> = "forceX"

type xForce<'data>
external asXForce: force<'data> => xForce<'data> = "%identity"
@send external xTarget: (xForce<'data>, float) => xForce<'data> = "x"
@send external xTargetFn: (xForce<'data>, @uncurry (node<'data>, int, array<node<'data>>) => float) => xForce<'data> = "x"
@send external xStrength: (xForce<'data>, float) => xForce<'data> = "strength"
external xForceAsForce: xForce<'data> => force<'data> = "%identity"

// Force: Y positioning
@module("d3") external forceY: float => force<'data> = "forceY"
@module("d3") external forceYEmpty: unit => force<'data> = "forceY"

type yForce<'data>
external asYForce: force<'data> => yForce<'data> = "%identity"
@send external yTarget: (yForce<'data>, float) => yForce<'data> = "y"
@send external yTargetFn: (yForce<'data>, @uncurry (node<'data>, int, array<node<'data>>) => float) => yForce<'data> = "y"
@send external yStrength: (yForce<'data>, float) => yForce<'data> = "strength"
external yForceAsForce: yForce<'data> => force<'data> = "%identity"

// Force: Radial
@module("d3") external forceRadial: (float, float, float) => force<'data> = "forceRadial"

type radialForce<'data>
external asRadialForce: force<'data> => radialForce<'data> = "%identity"
@send external radialRadius: (radialForce<'data>, float) => radialForce<'data> = "radius"
@send external radialX: (radialForce<'data>, float) => radialForce<'data> = "x"
@send external radialY: (radialForce<'data>, float) => radialForce<'data> = "y"
@send external radialStrength: (radialForce<'data>, float) => radialForce<'data> = "strength"
external radialForceAsForce: radialForce<'data> => force<'data> = "%identity"
