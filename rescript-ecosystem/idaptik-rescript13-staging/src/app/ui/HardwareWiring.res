// SPDX-License-Identifier: PMPL-1.0-or-later
// HardwareWiring  Interactive hardware wiring mini-game UI (ADR-0008)
//
// Renders a patch panel with RJ45/fibre/serial ports, lets the player drag
// cables between ports, and computes cable sag using the catenary formula
// (via Coprocessor_Physics `cablesag`).
//
// Architecture (ADR-0008 §Rendering):
//   HardwareWiring.t
//     ├─ portLayer     Container — port circles + labels (topmost hit-targets)
//     ├─ cableLayer    Container — rendered cable curves (below ports)
//     └─ dragLayer     Container — temporary drag-line (topmost, above everything)
//
// Cable sag formula (catenary approximation used by physics coprocessor):
//   sag = (weight_g × length_cm²) / (8 × tension_N)
// The sag value is the vertical pixel drop at the cable midpoint.
// It becomes the Y-offset of the quadratic Bézier control point.
//
// Physical to pixel mapping: 1 cm ≈ 3 pixels at standard zoom.
// Default cable weight: 50 g (thin Cat6 patch cable).
// Default tension: 1000 N (hand-held, slack cable).
//
// Interaction model:
//   1. Pointer-down on a free port  → begin drag (creates drag line from port)
//   2. Pointer-move on cableLayer   → update drag line endpoint
//   3. Pointer-up on a target port  → complete connection
//   4. Pointer-up on background     → cancel drag
//   5. Pointer-down on connected port → pull cable (breaks connection)
//
// Security events emitted:
//   onConnectionMade(fromIp, toIp)   — NetworkManager wires the two devices
//   onConnectionBroken(portId)       — NetworkManager removes the link

open Pixi

//  Port Types

// The physical connector type of a port.
type portKind =
  | Ethernet // RJ45 copper port (yellow jacket cables)
  | FibreLC // LC fibre port (orange single-mode / aqua multimode)
  | FibreSC // SC fibre port (similar to LC but square push-pull connector)
  | Serial // DB-9 / RJ45 console port (light blue cables)
  | Power // IEC/kettle-lead power port (black cables)

// Current state of a single port.
type portState =
  | Free // Nothing plugged in; port is available
  | Connected(string) // Connected to another portId; cable rendered between them
  | Alarmed // Port is generating a security event (red glow animation)

// A physical port on the panel.
type port = {
  id: string, // Unique identifier, e.g. "A01" or "pp_eth_03"
  label: string, // Short label rendered below the port circle
  kind: portKind,
  mutable state: portState,
  x: float, // Centre X in panel-local coordinates
  y: float, // Centre Y in panel-local coordinates
  vlanColour: int, // VLAN membership colour for the port ring (0xRRGGBB)
}

// A completed cable between two ports.
type cableConnection = {
  id: string, // Unique cable ID, e.g. "cable_A01_B03"
  fromPortId: string,
  toPortId: string,
  kind: portKind,
  colour: int, // Cable jacket colour (kind-specific default or VLAN override)
  mutable sagPixels: float, // Vertical sag at midpoint from physics coprocessor
}

// A cable drag-in-progress (player dragging a cable endpoint).
type cableDragState = {
  fromPortId: string,
  startX: float, // Panel-local X of the source port
  startY: float,
  mutable currentX: float, // Current mouse/pointer position
  mutable currentY: float,
}

// The hardware wiring panel.
type t = {
  container: Container.t, // Root container; caller adds this to the screen
  portLayer: Container.t, // Port circles rendered here
  cableLayer: Container.t, // Completed cables rendered here
  dragLayer: Container.t, // Active drag line rendered here
  ports: dict<port>, // portId -> port
  mutable connections: array<cableConnection>, // All active cable connections
  mutable activeDrag: option<cableDragState>,
  // Callbacks wired by the caller (NetworkManager / GameLoop)
  mutable onConnectionMade: option<(string, string) => unit>, // (fromPortId, toPortId)
  mutable onConnectionBroken: option<string => unit>, // portId of pulled port
  mutable onAlarmTriggered: option<string => unit>, // portId that triggered alert
}

//  Colour Map

// Cable jacket colours per connector kind.
// These match real-world cabling conventions for easy recognition.
let cableColour = (kind: portKind): int =>
  switch kind {
  | Ethernet => 0xFFD700 // Yellow (standard Cat5e/Cat6)
  | FibreLC => 0xFF6B00 // Orange (single-mode) / aqua is 0x00CED1
  | FibreSC => 0x00CED1 // Aqua/teal (multimode SC)
  | Serial => 0x87CEEB // Light blue (console cables)
  | Power => 0x222222 // Black (power leads)
  }

// Port circle fill colours — dim when free, bright when connected.
let portFreeColour = (_kind: portKind): int => 0x444444 // Dark grey
let portConnectedColour = (kind: portKind): int => cableColour(kind)
let portAlarmedColour = (_kind: portKind): int => 0xFF2222 // Alert red

let portRadius = 8.0 // Pixels, hit-target and visual radius

//  Sag Calculation

// Compute cable sag in pixels using the catenary approximation formula.
// dx/dy are the pixel-space distance between the two port centres.
// Uses fixed cable weight (50 g) and tension (1000 N) defaults; callers
// that want physics-engine accuracy should call Coprocessor_Physics.cablesag
// asynchronously and update connection.sagPixels afterwards.
let computeSagLocal = (~dx: float, ~dy: float): float => {
  let dist = Math.sqrt(dx *. dx +. dy *. dy)
  // Map pixel distance to approximate centimetres (3 px/cm at 1:1 zoom)
  let lengthCm = dist /. 3.0
  let weightG = 50.0
  let tensionN = 1000.0
  // sag = (weight × length²) / (8 × tension)
  let sag = weightG *. (lengthCm *. lengthCm) /. (8.0 *. tensionN)
  // Convert back to pixels and clamp to a reasonable maximum
  let sagPx = sag *. 3.0
  Math.min(sagPx, dist *. 0.4) // Sag at most 40% of span for visual clarity
}

//  Port Graphics Helpers

// Draw a single port circle on the given Graphics object.
// The circle fill reflects the current port state and kind.
let drawPortCircle: (Graphics.t, port) => unit = %raw(`
  function(g, port) {
    g.clear();
    // Outer ring: VLAN colour
    g.circle(port.x, port.y, port.radius + 3.0);
    g.fill({ color: port.vlanColour, alpha: 0.6 });
    // Inner fill: state-dependent colour
    g.circle(port.x, port.y, port.radius);
    g.fill({ color: port.fillColour });
  }
`)

// Compute the fill colour for a port given its state and kind.
// Exported so that callers can update a port's visual without full redraw.
let portFill = (port: port): int =>
  switch port.state {
  | Free => portFreeColour(port.kind)
  | Connected(_) => portConnectedColour(port.kind)
  | Alarmed => portAlarmedColour(port.kind)
  }

//  Cable Rendering

// Draw a quadratic Bézier cable between two points.
// The control point is at the midpoint, offset downward by sagPixels.
// This gives an upside-down arch that mimics a hanging cable.
let drawCable: (Graphics.t, ~x1: float, ~y1: float, ~x2: float, ~y2: float, ~sagPixels: float, ~colour: int) => unit = %raw(`
  function(g, x1, y1, x2, y2, sagPixels, colour) {
    g.clear();
    var mx = (x1 + x2) / 2.0;
    var my = (y1 + y2) / 2.0 + sagPixels;
    g.moveTo(x1, y1);
    g.quadraticCurveTo(mx, my, x2, y2);
    g.stroke({ color: colour, width: 3, alpha: 0.9 });
  }
`)

// Draw the active drag line (dashed style, from source port to mouse cursor).
let drawDragLine: (Graphics.t, ~x1: float, ~y1: float, ~x2: float, ~y2: float, ~colour: int) => unit = %raw(`
  function(g, x1, y1, x2, y2, colour) {
    g.clear();
    g.moveTo(x1, y1);
    g.lineTo(x2, y2);
    g.stroke({ color: colour, width: 2, alpha: 0.6, dash: [6, 4] });
  }
`)

//  Panel Creation

// Create a patch panel with the given ports.
// The caller provides the port array; this function lays out the graphics
// and wires interaction handlers.
let make = (~width: float, ~height: float, ~ports: array<port>, ()): t => {
  let container = Container.make()
  let cableLayer = Container.make()
  let portLayer = Container.make()
  let dragLayer = Container.make()

  // Z-order: cables behind ports, drag line on top
  let _ = Container.addChild(container, cableLayer)
  let _ = Container.addChild(container, portLayer)
  let _ = Container.addChild(container, dragLayer)

  // Background panel
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, 0.0, width, height)->Graphics.fillColor(0x1a1a2e)
  let _ = Container.addChildGraphics(container, bg)

  // Panel title bar
  let titleBg = Graphics.make()
  let _ = titleBg->Graphics.rect(0.0, 0.0, width, 24.0)->Graphics.fillColor(0x16213e)
  let _ = Container.addChildGraphics(container, titleBg)
  let titleText = Text.make({"text": "PATCH PANEL", "style": {"fontFamily": "monospace", "fontSize": 11, "fill": 0x00ff88, "fontWeight": "bold"}})
  Text.setX(titleText, 8.0)
  Text.setY(titleText, 5.0)
  let _ = Container.addChildText(container, titleText)

  // Build port dict and render port graphics
  let portDict: dict<port> = Dict.make()
  let portGraphics: dict<Graphics.t> = Dict.make()

  let dragLineGraphic = Graphics.make()
  let _ = Container.addChildGraphics(dragLayer, dragLineGraphic)

  // Store drag state in a mutable ref for closure access
  let panel: t = {
    container,
    portLayer,
    cableLayer,
    dragLayer,
    ports: portDict,
    connections: [],
    activeDrag: None,
    onConnectionMade: None,
    onConnectionBroken: None,
    onAlarmTriggered: None,
  }

  // Render each port
  Array.forEach(ports, port => {
    Dict.set(portDict, port.id, port)

    // Port graphics (circle + label)
    let g = Graphics.make()
    Graphics.setEventMode(g, "static")
    Graphics.setCursor(g, "pointer")

    // Draw the circle using %raw (PixiJS 8 Graphics API)
    let fillColor = portFill(port)
    let vlanCol = port.vlanColour
    let px = port.x
    let py = port.y
    let pr = portRadius

    // Draw ring + fill using raw PixiJS 8 call
    ignore(fillColor)
    ignore(vlanCol)
    ignore(px)
    ignore(py)
    ignore(pr)
    let _ = %raw(`(function(g, px, py, pr, vlan, fill) {
      g.circle(px, py, pr + 3);
      g.fill({ color: vlan, alpha: 0.5 });
      g.circle(px, py, pr);
      g.fill({ color: fill });
    })(g, px, py, pr, vlanCol, fillColor)`)

    Dict.set(portGraphics, port.id, g)
    let _ = Container.addChildGraphics(portLayer, g)

    // Port label below circle
    let lbl = Text.make({"text": port.label, "style": {"fontFamily": "monospace", "fontSize": 8, "fill": 0xaaaaaa}})
    Text.setX(lbl, port.x -. 8.0)
    Text.setY(lbl, port.y +. portRadius +. 2.0)
    let _ = Container.addChildText(portLayer, lbl)

    // Pointer-down: start drag or pull existing cable
    Graphics.on(g, "pointerdown", (_event: 'a) => {
      switch port.state {
      | Free => {
          // Begin dragging a new cable from this port
          panel.activeDrag =Some({
            fromPortId: port.id,
            startX: port.x,
            startY: port.y,
            currentX: port.x,
            currentY: port.y,
          })
        }
      | Connected(otherPortId) => {
          // Pull the cable — break the connection and re-enter drag mode
          let cableId = `cable_${port.id}_${otherPortId}`
          let altCableId = `cable_${otherPortId}_${port.id}`
          // Remove connection from panel
          panel.connections =
            panel.connections->Array.filter(c => c.id != cableId && c.id != altCableId)
          // Update both ports to Free
          port.state =Free
          switch Dict.get(portDict, otherPortId) {
          | Some(otherPort) => otherPort.state =Free
          | None => ()
          }
          // Notify caller
          switch panel.onConnectionBroken {
          | Some(cb) => cb(port.id)
          | None => ()
          }
          // Begin dragging from this port (re-plug elsewhere)
          panel.activeDrag =Some({
            fromPortId: port.id,
            startX: port.x,
            startY: port.y,
            currentX: port.x,
            currentY: port.y,
          })
        }
      | Alarmed => {
          // Touching an alarmed port triggers additional alert escalation
          switch panel.onAlarmTriggered {
          | Some(cb) => cb(port.id)
          | None => ()
          }
        }
      }
    })

    // Pointer-up on a port: complete connection if drag is in progress
    Graphics.on(g, "pointerup", (_event: 'a) => {
      switch panel.activeDrag {
      | Some(drag) when drag.fromPortId != port.id => {
          // Check type compatibility (must be same kind)
          let sourcePort = Dict.get(portDict, drag.fromPortId)
          let compatible = switch sourcePort {
          | Some(src) => src.kind == port.kind
          | None => false
          }

          if compatible {
            switch port.state {
            | Free => {
                // Complete the connection
                let cableId = `cable_${drag.fromPortId}_${port.id}`
                let sag = computeSagLocal(
                  ~dx=port.x -. drag.startX,
                  ~dy=port.y -. drag.startY,
                )
                let conn: cableConnection = {
                  id: cableId,
                  fromPortId: drag.fromPortId,
                  toPortId: port.id,
                  kind: port.kind,
                  colour: cableColour(port.kind),
                  sagPixels: sag,
                }
                panel.connections = Array.concat(panel.connections, [conn])

                // Update port states
                port.state =Connected(drag.fromPortId)
                switch sourcePort {
                | Some(src) => src.state =Connected(port.id)
                | None => ()
                }

                // Notify caller
                switch panel.onConnectionMade {
                | Some(cb) => cb(drag.fromPortId, port.id)
                | None => ()
                }
              }
            | Connected(_) | Alarmed => () // Cannot connect to occupied/alarmed port
            }
          }
          // Cancel drag regardless
          panel.activeDrag =None
          drawDragLine(dragLineGraphic, ~x1=0.0, ~y1=0.0, ~x2=0.0, ~y2=0.0, ~colour=0x000000)
        }
      | _ => ()
      }
    })
  })

  // Pointer-move on the container: update drag line
  Container.setEventMode(container, "static")
  Container.on(container, "pointermove", (event: FederatedPointerEvent.t) => {
    switch panel.activeDrag {
    | Some(drag) => {
        let pos = FederatedPointerEvent.getLocalPosition(event, container)
        drag.currentX = pos.x
        drag.currentY = pos.y

        let srcPort = Dict.get(portDict, drag.fromPortId)
        let colour = switch srcPort {
        | Some(p) => cableColour(p.kind)
        | None => 0xffffff
        }
        drawDragLine(
          dragLineGraphic,
          ~x1=drag.startX,
          ~y1=drag.startY,
          ~x2=drag.currentX,
          ~y2=drag.currentY,
          ~colour,
        )
      }
    | None => ()
    }
  })

  // Pointer-up on background: cancel drag
  Container.on(container, "pointerup", (_event: 'a) => {
    panel.activeDrag =None
    drawDragLine(dragLineGraphic, ~x1=0.0, ~y1=0.0, ~x2=0.0, ~y2=0.0, ~colour=0x000000)
  })

  panel

}

//  Render Cables

// Re-render all cable connections.  Call after connections change or on resize.
// Each connection is represented by a Graphics object in cableLayer.
let renderCables = (panel: t): unit => {
  // Remove old cable graphics
  let _ = %raw(`(function(layer) { layer.removeChildren(); })(panel.cableLayer)`)

  Array.forEach(panel.connections, conn => {
    let fromPort = Dict.get(panel.ports, conn.fromPortId)
    let toPort = Dict.get(panel.ports, conn.toPortId)
    switch (fromPort, toPort) {
    | (Some(fp), Some(tp)) => {
        let g = Graphics.make()
        drawCable(
          g,
          ~x1=fp.x,
          ~y1=fp.y,
          ~x2=tp.x,
          ~y2=tp.y,
          ~sagPixels=conn.sagPixels,
          ~colour=conn.colour,
        )
        let _ = Container.addChildGraphics(panel.cableLayer, g)
      }
    | _ => ()
    }
  })
}

//  Physics Engine Integration

// Asynchronously update the cable sag for a connection using the
// coprocessor physics engine (more accurate than the local approximation).
// The caller should call renderCables after all sag values are updated.
let updateSagAsync = (
  ~deviceId: string,
  ~panel: t,
  ~connectionId: string,
): promise<unit> => {
  let conn = panel.connections-> Array.find(c => c.id == connectionId)
  switch conn {
  | None => Promise.resolve()
  | Some(c) => {
      let fp = Dict.get(panel.ports, c.fromPortId)
      let tp = Dict.get(panel.ports, c.toPortId)
      switch (fp, tp) {
      | (Some(fromPort), Some(toPort)) => {
          let dx = toPort.x -. fromPort.x
          let dy = toPort.y -. fromPort.y
          let distPx = Math.sqrt(dx *. dx +. dy *. dy)
          // Convert pixels to centimetres (3 px/cm at 1:1 zoom)
          let lengthCm = Float.toInt(distPx /. 3.0) // truncates to int
          let weightG = 50 // grams, standard Cat6 patch cable
          let tensionN = 1000 // Newtons, hand-held slack cable
          // Call Coprocessor_Physics cablesag: input [length, weight, tension]
          CoprocessorManager.call(
            deviceId,
            Coprocessor.Domain.Physics,
            "cablesag",
            [lengthCm, weightG, tensionN],
          )->Promise.then(result => {
            if result.status == 0 {
              switch Array.get(result.data, 0) {
              | Some(sagCm) => {
                  // Convert cm back to pixels
                  c.sagPixels = Int.toFloat(sagCm) *. 3.0
                }
              | None => ()
              }
            }
            Promise.resolve()
          })
        }
      | _ => Promise.resolve()
      }
    }
  }
}

//  Patch Panel Layout Helpers

// Generate a standard rack-mount patch panel port array.
// Rows × columns grid, optionally divided into VLAN groups.
// All ports are Ethernet by default; caller can override individual ports.
type patchPanelConfig = {
  rows: int, // Typically 2
  cols: int, // Typically 12 or 24
  startX: float, // Left edge of the first port
  startY: float, // Top edge of the first row
  xSpacing: float, // Horizontal distance between port centres
  ySpacing: float, // Vertical distance between rows
  vlanGroups: array<int>, // VLAN colour for each column group (length must match cols)
}

let defaultVlanColours = [
  0x2196F3, // Blue — VLAN 10 (Management)
  0x4CAF50, // Green — VLAN 20 (Users)
  0xFF9800, // Orange — VLAN 30 (Servers)
  0xF44336, // Red — VLAN 40 (DMZ)
  0x9C27B0, // Purple — VLAN 50 (Voice)
]

// Create a standard patch panel port grid.
// portId format: "<row_letter><col_two_digit>" e.g. "A01", "B12"
let makeStandardPorts = (~config: patchPanelConfig): array<port> => {
  let ports = []
  let rowLetters = ["A", "B", "C", "D", "E", "F"]
  for row in 0 to config.rows - 1 {
    let rowLetter = Array.get(rowLetters, row)->Option.getOr(`R${Int.toString(row)}`)
    for col in 0 to config.cols - 1 {
      let colStr = if col < 9 { `0${Int.toString(col + 1)}` } else { Int.toString(col + 1) }
      let portId = `${rowLetter}${colStr}`
      let vlanColour =
        Array.get(
          config.vlanGroups,
          col / (config.cols / Array.length(config.vlanGroups)),
        )->Option.getOr(0x444444)
      let p: port = {
        id: portId,
        label: portId,
        kind: Ethernet,
        state: Free,
        x: config.startX +. Int.toFloat(col) *. config.xSpacing,
        y: config.startY +. Int.toFloat(row) *. config.ySpacing,
        vlanColour,
      }
      let _ = Array.push(ports, p)
    }
  }
  ports
}

//  Connection Queries

// Return all connections involving a given port.
let connectionsForPort = (panel: t, portId: string): array<cableConnection> => {
  panel.connections->Array.filter(c => c.fromPortId == portId || c.toPortId == portId)
}

// Return true if the two given ports are directly connected.
let areConnected = (panel: t, portIdA: string, portIdB: string): bool => {
  panel.connections->Array.some(c =>
    (c.fromPortId == portIdA && c.toPortId == portIdB) ||
    (c.fromPortId == portIdB && c.toPortId == portIdA)
  )
}

// Return all port IDs that are currently free (no cable plugged in).
let freePorts = (panel: t): array<string> => {
  Dict.keysToArray(panel.ports)->Array.filter(id => {
    switch Dict.get(panel.ports, id) {
    | Some(p) => p.state == Free
    | None => false
    }
  })
}
