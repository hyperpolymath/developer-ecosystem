// SPDX-License-Identifier: PMPL-1.0-or-later
// KernelMonitor.res  Coprocessor resource HUD overlay.
//
// Renders a compact, real-time resource dashboard for the hacked device
// currently executing coprocessor operations.  Positioned in the bottom-left
// of the screen (12 px from edges), below the alert indicator and HP bar.
//
// ──────────────────────────────────────────────────────────────────────────
// Displayed metrics (per device):
//   CPU    — compute units consumed as % of session quota  (bar + label)
//   MEM    — peak memory bytes allocated as % of quota     (bar + label)
//   PWR    — cumulative energy Joules as % of quota        (bar + label)
//   ACTIVE — count of concurrently-executing coprocessor ops
//
// ──────────────────────────────────────────────────────────────────────────
// Colour coding (mirrors ColorPalette for colour-blind accessibility):
//   0 – 79 %    → green  #00cc44   normal operation
//   80 – 94 %   → orange #ff8800   heavy load, approaching limits
//   95 – 100 %  → red    #ff2222   near-exhaustion; ops will be rejected soon
//
// ──────────────────────────────────────────────────────────────────────────
// Visibility:
//   Invisible (alpha 0.0) when no device is attached or `setVisible(false)`.
//   Auto-shown at alpha 0.85 when `setDevice` is called with a non-empty ID.
//
// ──────────────────────────────────────────────────────────────────────────
// Per-frame update:
//   Call `update(monitor)` every game frame from the WorldScreen update loop.
//   Resource bars are redrawn only when the displayed percentage changes by
//   ≥ 0.5 percentage points, preventing redundant Graphics redraws.
//
// ──────────────────────────────────────────────────────────────────────────
// Size: 204 × 90 px at 1× canvas scale.  No pointer interaction (eventMode "none").

open Pixi

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

// Width of each filled resource bar, in canvas pixels.
let barWidth  = 120.0

// Height of each filled resource bar, in canvas pixels.
let barHeight = 8.0

// Vertical distance between the top edges of successive bar rows.
let barGap    = 18.0

// Total width of the overlay panel (bar + label gutter).
let panelW    = 204.0

// Total height of the overlay panel.
let panelH    = 90.0

// ---------------------------------------------------------------------------
// Bar colour thresholds
// ---------------------------------------------------------------------------

// 0–79% usage — device is within normal operating load.
let colorOk       = 0x00cc44

// 80–94% usage — device under heavy load; approaching its quota limits.
let colorWarn     = 0xff8800

// ≥95% usage — near exhaustion; new coprocessor ops will be rejected.
let colorCritical = 0xff2222

// Dark grey shown behind the unfilled portion of every bar.
let colorBg       = 0x222222

// Map a usage percentage (0.0 – 100.0) to the appropriate bar fill colour.
let barColor = (pct: float): int => {
  if pct >= 95.0 {colorCritical}
  else if pct >= 80.0 {colorWarn}
  else {colorOk}
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

// One rendered resource bar: a static dark background, a dynamic fill layer,
// and a text label ("CPU 82%!") positioned to the right of the bar.
type resourceBar = {
  bg:    Graphics.t,   // Static dark background, drawn once at construction time
  fill:  Graphics.t,   // Dynamic coloured fill, cleared and redrawn per update
  label: Text.t,       // "PREFIX pct%[!]" — updated whenever the fill changes
}

// Full KernelMonitor overlay state.  All PixiJS display objects are owned here.
type t = {
  container:       Container.t,   // Root container; attach to HUD or WorldScreen
  header:          Text.t,        // "QPU MONITOR" idle / "QPU: <ip>" when active
  computeBar:      resourceBar,   // CPU compute-units utilisation bar
  memoryBar:       resourceBar,   // Peak memory-bytes utilisation bar
  energyBar:       resourceBar,   // Cumulative energy-Joules utilisation bar
  activeText:      Text.t,        // "ACTIVE: N" concurrent-operations counter
  mutable deviceId:    string,    // Currently monitored device ("" = none / hidden)
  mutable lastCompute: float,     // Cached compute% for change detection
  mutable lastMemory:  float,     // Cached memory% for change detection
  mutable lastEnergy:  float,     // Cached energy% for change detection
}

// ---------------------------------------------------------------------------
// Style helper
// ---------------------------------------------------------------------------

// Produce a monospace text style object for Text.make / Text.setStyle.
let monoStyle = (~fontSize: float, ~fill: string, ()): {..} => {
  {"fontFamily": "monospace", "fontSize": fontSize, "fill": fill}
}

// ---------------------------------------------------------------------------
// Bar construction helper
// ---------------------------------------------------------------------------

// Build one resource bar row inside `parent`, with its top edge at `yOffset`
// pixels below the panel top.  The background is painted once and never
// repainted; the fill and label are updated by `redrawBar` each frame.
let makeResourceBar = (parent: Container.t, yOffset: float, prefix: string): resourceBar => {
  // Static background — drawn once, alpha unchanged for the lifetime of the overlay.
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, yOffset, barWidth, barHeight)->Graphics.fill({"color": colorBg})
  let _ = Container.addChildGraphics(parent, bg)

  // Dynamic fill layer — cleared and redrawn whenever the percentage changes.
  let fill = Graphics.make()
  let _ = Container.addChildGraphics(parent, fill)

  // Label: positioned 4 px to the right of the bar, vertically centred on it.
  let label = Text.make({
    "text": `${prefix} ---%`,
    "style": monoStyle(~fontSize=9.0, ~fill="#888888", ()),
  })
  Text.setX(label, barWidth +. 4.0)
  Text.setY(label, yOffset -. 1.0)
  let _ = Container.addChildText(parent, label)

  {bg, fill, label}
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

// Create a new KernelMonitor overlay and return its state record.
//
// The overlay starts fully transparent (alpha 0.0) and is shown automatically
// when `setDevice` is called with a valid device ID.
//
// Caller must attach `monitor.container` to a parent PixiJS container
// (typically the WorldScreen or HUD root container) after calling `make`.
let make = (): t => {
  let container = Container.make()
  Container.setEventMode(container, "none")    // Overlay never captures pointer events
  Container.setAlpha(container, 0.0)           // Hidden until a device is enrolled

  // Translucent dark panel background.
  let panel = Graphics.make()
  let _ = panel->Graphics.rect(0.0, 0.0, panelW, panelH)->Graphics.fill({"color": 0x111111})
  let _ = Container.addChildGraphics(container, panel)

  // Header label — updated by setDevice with the active device's IP.
  let header = Text.make({
    "text": "QPU MONITOR",
    "style": monoStyle(~fontSize=9.0, ~fill="#555555", ()),
  })
  Text.setX(header, 4.0)
  Text.setY(header, 4.0)
  let _ = Container.addChildText(container, header)

  // Three resource bars stacked vertically, separated by barGap pixels.
  let computeBar = makeResourceBar(container, 18.0,                  "CPU")
  let memoryBar  = makeResourceBar(container, 18.0 +. barGap,        "MEM")
  let energyBar  = makeResourceBar(container, 18.0 +. barGap *. 2.0, "PWR")

  // Active-ops counter at the bottom of the panel.
  let activeText = Text.make({
    "text": "ACTIVE: 0",
    "style": monoStyle(~fontSize=9.0, ~fill="#aaaaaa", ()),
  })
  Text.setX(activeText, 4.0)
  Text.setY(activeText, 18.0 +. barGap *. 3.0)
  let _ = Container.addChildText(container, activeText)

  {
    container,
    header,
    computeBar,
    memoryBar,
    energyBar,
    activeText,
    deviceId:    "",
    lastCompute: -1.0,    // Initialised to -1.0 so the first update always redraws
    lastMemory:  -1.0,
    lastEnergy:  -1.0,
  }
}

// ---------------------------------------------------------------------------
// Device attachment
// ---------------------------------------------------------------------------

// Attach the monitor to `deviceId` — the IP address of the hacked device to track.
//
// Resets cached percentages to -1.0 to force a full bar redraw on the next
// `update` call.  Passing an empty string hides the overlay.
let setDevice = (monitor: t, deviceId: string): unit => {
  monitor.deviceId    = deviceId
  monitor.lastCompute = -1.0
  monitor.lastMemory  = -1.0
  monitor.lastEnergy  = -1.0
  if String.length(deviceId) > 0 {
    Text.setText(monitor.header, `QPU: ${deviceId}`)
    Container.setAlpha(monitor.container, 0.85)
  } else {
    Text.setText(monitor.header, "QPU MONITOR")
    Container.setAlpha(monitor.container, 0.0)
  }
}

// ---------------------------------------------------------------------------
// Bar redraw
// ---------------------------------------------------------------------------

// Redraw the fill portion of one resource bar to reflect `pct` (0.0 – 100.0).
//
// Clears the previous fill Graphics, draws a new coloured rect proportional
// to the percentage, and updates the text label.  A "!" suffix is appended
// when load exceeds 80% to provide a non-colour alert cue (WCAG 1.4.1).
//
// Parameters:
//   bar     — the resourceBar to update
//   pct     — current utilisation percentage (clamped to 0–100)
//   prefix  — short label prefix ("CPU", "MEM", "PWR")
//   yOffset — vertical offset from panel top for this bar's fill rect
let redrawBar = (bar: resourceBar, pct: float, prefix: string, yOffset: float): unit => {
  let clamp  = if pct < 0.0 {0.0} else if pct > 100.0 {100.0} else {pct}
  let fillW  = barWidth *. clamp /. 100.0
  let color  = barColor(clamp)

  // Clear previous fill and redraw proportionally.
  let _ = Graphics.clear(bar.fill)
  if fillW > 0.0 {
    let _ = bar.fill->Graphics.rect(0.0, yOffset, fillW, barHeight)->Graphics.fill({"color": color})
  }

  // Update the label text and its colour to match the fill.
  let pctStr   = Int.toString(Float.toInt(Math.floor(clamp)))
  let warning  = if clamp >= 80.0 {"!"} else {""}
  Text.setText(bar.label, `${prefix} ${pctStr}%${warning}`)
  let hexColor = if color == colorOk {"#00cc44"}
                 else if color == colorWarn {"#ff8800"}
                 else {"#ff2222"}
  Text.setStyle(bar.label, TextStyle.make(monoStyle(~fontSize=9.0, ~fill=hexColor, ())))
}

// ---------------------------------------------------------------------------
// Per-frame update
// ---------------------------------------------------------------------------

// Update all resource bars and the active-ops counter from ResourceAccounting.
//
// Bars are only redrawn when their percentage has changed by ≥ 0.5 points,
// avoiding redundant Graphics.clear / Graphics.rect calls on idle frames.
//
// The active-ops text is always refreshed (cheap Text.setText, not a redraw).
//
// Call this every game frame from the WorldScreen or HUD update loop when
// the coprocessor overlay is visible.
let update = (monitor: t): unit => {
  if String.length(monitor.deviceId) > 0 {
    let pct   = ResourceAccounting.getUsagePercentage(monitor.deviceId)
    let state = ResourceAccounting.getDeviceState(monitor.deviceId)

    // Compute bar — refresh when the displayed percentage drifts by ≥ 0.5 points.
    if Math.abs(pct.compute -. monitor.lastCompute) >= 0.5 {
      monitor.lastCompute = pct.compute
      redrawBar(monitor.computeBar, pct.compute, "CPU", 18.0)
    }

    // Memory bar.
    if Math.abs(pct.memory -. monitor.lastMemory) >= 0.5 {
      monitor.lastMemory = pct.memory
      redrawBar(monitor.memoryBar, pct.memory, "MEM", 18.0 +. barGap)
    }

    // Energy bar.
    if Math.abs(pct.energy -. monitor.lastEnergy) >= 0.5 {
      monitor.lastEnergy = pct.energy
      redrawBar(monitor.energyBar, pct.energy, "PWR", 18.0 +. barGap *. 2.0)
    }

    // Active-ops counter: always refreshed (no Graphics involved, negligible cost).
    Text.setText(monitor.activeText, `ACTIVE: ${Int.toString(state.activeCalls)}`)
  }
}

// ---------------------------------------------------------------------------
// Positioning and visibility
// ---------------------------------------------------------------------------

// Reposition the overlay container after a canvas resize.
//
// The monitor is anchored to the bottom-left corner with a 12 px margin.
// Call from the parent screen's `resize` handler whenever the canvas dimensions
// change.
let resize = (monitor: t, ~screenWidth: float, ~screenHeight: float): unit => {
  let _ = screenWidth   // Layout is left-anchored; width is unused
  Container.setX(monitor.container, 12.0)
  Container.setY(monitor.container, screenHeight -. 104.0)
}

// Force-show or force-hide the overlay, overriding automatic visibility.
//
// Useful for temporarily hiding during menus, cutscenes, or the pause screen.
// Note: calling `setDevice("")` is the clean way to hide and detach from a device.
let setVisible = (monitor: t, visible: bool): unit => {
  if visible && String.length(monitor.deviceId) > 0 {
    Container.setAlpha(monitor.container, 0.85)
  } else {
    Container.setAlpha(monitor.container, 0.0)
  }
}
