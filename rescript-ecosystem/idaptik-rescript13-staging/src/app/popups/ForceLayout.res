// SPDX-License-Identifier: PMPL-1.0-or-later
// Force-directed graph layout with zone constraints
// Provides automatic device positioning while respecting zone boundaries

// Node in the force graph
type node = {
  id: string,
  mutable x: float,
  mutable y: float,
  mutable vx: float,
  mutable vy: float,
  isFixed: bool, // Anchored nodes (firewalls, routers) don't move
  zoneId: option<string>, // Which zone this node belongs to
}

// Edge connecting two nodes
type edge = {
  source: string,
  target: string,
  strength: float, // Connection strength
}

// Zone boundary definition
type zone = {
  id: string,
  x: float,
  y: float,
  width: float,
  height: float,
  padding: float, // Keep nodes this far from edges
}

// Force layout simulation
type simulation = {
  nodes: dict<node>,
  mutable edges: array<edge>,
  zones: dict<zone>,
  mutable alpha: float, // Simulation "heat" - decreases over time
  mutable alphaDecay: float,
  mutable velocityDecay: float,
}

// Create a new node
let makeNode = (
  ~id: string,
  ~x: float,
  ~y: float,
  ~isFixed: bool=false,
  ~zoneId: option<string>=None,
  (),
): node => {
  {
    id,
    x,
    y,
    vx: 0.0,
    vy: 0.0,
    isFixed,
    zoneId,
  }
}

// Create a new simulation
let makeSimulation = (): simulation => {
  {
    nodes: Dict.make(),
    edges: [],
    zones: Dict.make(),
    alpha: 1.0,
    alphaDecay: 0.0000001, // Extremely slow decay for millions of iterations
    velocityDecay: 0.4, // Moderate damping for stability
  }
}

// Add node to simulation
let addNode = (sim: simulation, node: node): unit => {
  Dict.set(sim.nodes, node.id, node)
}

// Add edge to simulation
let addEdge = (sim: simulation, source: string, target: string, ~strength: float=1.0, ()): unit => {
  sim.edges = Array.concat(sim.edges, [{source, target, strength}])
}

// Add zone boundary
let addZone = (sim: simulation, zone: zone): unit => {
  Dict.set(sim.zones, zone.id, zone)
}

// Math bindings
@val external sqrt: float => float = "Math.sqrt"

// Distance between two points
let distance = (x1: float, y1: float, x2: float, y2: float): float => {
  let dx = x2 -. x1
  let dy = y2 -. y1
  sqrt(dx *. dx +. dy *. dy)
}

// Apply repulsion force between nodes (prevents overlap)
let applyRepulsion = (sim: simulation, strength: float, ~minDist: float=120.0): unit => {
  let nodeArray = Dict.toArray(sim.nodes)->Array.map(((_, node)) => node)

  Array.forEach(nodeArray, nodeA => {
    if !nodeA.isFixed {
      Array.forEach(nodeArray, nodeB => {
        if nodeA.id != nodeB.id {
          let dx = nodeB.x -. nodeA.x
          let dy = nodeB.y -. nodeA.y
          let dist = distance(nodeA.x, nodeA.y, nodeB.x, nodeB.y)

          if dist > 0.0 && dist < 400.0 {
            // Wide range for repulsion
            let force = if dist < minDist {
              strength *. 2.0 /. (dist +. 1.0)
            } else {
              // Very strong if too close

              strength /. (dist *. dist +. 1.0)
            }
            nodeA.vx = nodeA.vx -. dx /. dist *. force
            nodeA.vy = nodeA.vy -. dy /. dist *. force
          }
        }
      })
    }
  })
}

// Apply attraction force along edges (keeps connected nodes together)
let applyAttraction = (sim: simulation, strength: float): unit => {
  Array.forEach(sim.edges, edge => {
    switch (Dict.get(sim.nodes, edge.source), Dict.get(sim.nodes, edge.target)) {
    | (Some(source), Some(target)) =>
      let dx = target.x -. source.x
      let dy = target.y -. source.y
      let dist = distance(source.x, source.y, target.x, target.y)

      if dist > 0.0 {
        let force = dist *. strength *. edge.strength

        if !source.isFixed {
          source.vx = source.vx +. dx /. dist *. force
          source.vy = source.vy +. dy /. dist *. force
        }

        if !target.isFixed {
          target.vx = target.vx -. dx /. dist *. force
          target.vy = target.vy -. dy /. dist *. force
        }
      }
    | _ => ()
    }
  })
}

// Apply zone containment force (keeps nodes within zone boundaries)
let applyZoneConstraints = (sim: simulation, strength: float): unit => {
  Dict.toArray(sim.nodes)->Array.forEach(((_, node)) => {
    if !node.isFixed {
      switch node.zoneId {
      | Some(zoneId) =>
        switch Dict.get(sim.zones, zoneId) {
        | Some(zone) =>
          let minX = zone.x +. zone.padding
          let maxX = zone.x +. zone.width -. zone.padding
          let minY = zone.y +. zone.padding
          let maxY = zone.y +. zone.height -. zone.padding

          // Push back if outside bounds
          if node.x < minX {
            node.vx = node.vx +. (minX -. node.x) *. strength
          } else if node.x > maxX {
            node.vx = node.vx +. (maxX -. node.x) *. strength
          }

          if node.y < minY {
            node.vy = node.vy +. (minY -. node.y) *. strength
          } else if node.y > maxY {
            node.vy = node.vy +. (maxY -. node.y) *. strength
          }
        | None => ()
        }
      | None => ()
      }
    }
  })
}

// Update node positions based on velocities
let updatePositions = (sim: simulation): unit => {
  Dict.toArray(sim.nodes)->Array.forEach(((_, node)) => {
    if !node.isFixed {
      node.vx = node.vx *. sim.velocityDecay
      node.vy = node.vy *. sim.velocityDecay
      node.x = node.x +. node.vx *. sim.alpha
      node.y = node.y +. node.vy *. sim.alpha
    }
  })
}

// Run one tick of the simulation
let tick = (
  sim: simulation,
  ~repulsionStrength: float,
  ~attractionStrength: float,
  ~minDist: float,
): unit => {
  applyRepulsion(sim, repulsionStrength, ~minDist)
  applyAttraction(sim, attractionStrength)
  // No zone constraints - pure force-directed layout
  updatePositions(sim)

  // Decay alpha (simulation "cools down")
  sim.alpha = sim.alpha *. (1.0 -. sim.alphaDecay)
}

// Run simulation for exactly N iterations (no early stopping)
let runSimulation = (
  sim: simulation,
  maxIterations: int,
  ~repulsionStrength: float,
  ~attractionStrength: float,
  ~minDist: float,
): unit => {
  let i = ref(0)
  while i.contents < maxIterations {
    tick(sim, ~repulsionStrength, ~attractionStrength, ~minDist)
    i := i.contents + 1
  }
}

// Reset simulation (for re-running with new parameters)
let resetSimulation = (sim: simulation): unit => {
  sim.alpha = 1.0
  Dict.toArray(sim.nodes)->Array.forEach(((_, node)) => {
    node.vx = 0.0
    node.vy = 0.0
  })
}
