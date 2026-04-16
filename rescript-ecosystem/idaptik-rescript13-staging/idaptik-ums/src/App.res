// SPDX-License-Identifier: AGPL-3.0-or-later
//
// App.res — Main application entry point for the IDApTIK Universal Modding Studio.
//
// This is the top-level ReScript module that bootstraps the level editor UI.
// It creates a dark-themed application shell with:
//   - A toolbar (top bar with mode selectors and save/undo controls)
//   - An HTML5 Canvas (centre) for the tile-based level editor
//   - A property panel (right sidebar) for selected tile/object details
//   - A validation panel (bottom bar) showing ABI proof status
//
// The app talks to the Gossamer backend via `invoke` for level I/O
// (`load_level`, `save_level`, `list_levels`, `validate_level_abi`,
// `get_system_info`, `export_level_config`). See `src-gossamer/main.rs`.
//
// This is a standalone Gossamer app — NOT PanLL. It uses vanilla ReScript with
// direct DOM bindings rather than React or rescript-tea.
//
// Author: Jonathan D.A. Jewell

// ---------------------------------------------------------------------------
// DOM bindings — vanilla external declarations for direct DOM access
// ---------------------------------------------------------------------------

/// The global `document` object.
@val external document: Dom.document = "document"

/// The global `window` object (typed loosely for event listener use).
@val external window: {..} = "window"

/// Look up a DOM element by its `id` attribute.
@send
external getElementById: (Dom.document, string) => Js.Nullable.t<Dom.element> = "getElementById"

/// Set the inner HTML of a DOM element.
@set external setInnerHTML: (Dom.element, string) => unit = "innerHTML"

/// Set the inline style text of a DOM element.
@set external setStyleCssText: (Dom.element, string) => unit = "style.cssText"

/// Append a child element to a parent element.
@send external appendChild: (Dom.element, Dom.element) => unit = "appendChild"

/// Create a new DOM element by tag name.
@send external createElement: (Dom.document, string) => Dom.element = "createElement"

/// Set the `className` property on an element.
@set external setClassName: (Dom.element, string) => unit = "className"

/// Set the `id` property on an element.
@set external setId: (Dom.element, string) => unit = "id"

/// Set the `textContent` property on an element.
@set external setTextContent: (Dom.element, string) => unit = "textContent"

/// Set a generic attribute on an element.
@send external setAttribute: (Dom.element, string, string) => unit = "setAttribute"

/// Add an event listener to an element.
@send
external addEventListener: (Dom.element, string, Dom.event => unit) => unit = "addEventListener"

/// Add an event listener to the window object.
@send
external windowAddEventListener: ({..}, string, Dom.event => unit) => unit = "addEventListener"

// ---------------------------------------------------------------------------
// Canvas bindings — typed wrappers for the Canvas 2D rendering context
// ---------------------------------------------------------------------------

/// Opaque type representing a CanvasRenderingContext2D.
type canvasContext2d

/// Obtain the 2D rendering context from a canvas element.
/// Uses `%raw` because ReScript's DOM types do not include canvas natively.
let getContext2d: Dom.element => canvasContext2d = %raw(`
  function(canvas) { return canvas.getContext("2d"); }
`)

/// Set the canvas element's width attribute (not CSS width).
let setCanvasWidth: (Dom.element, int) => unit = %raw(`
  function(canvas, w) { canvas.width = w; }
`)

/// Set the canvas element's height attribute (not CSS height).
let setCanvasHeight: (Dom.element, int) => unit = %raw(`
  function(canvas, h) { canvas.height = h; }
`)

/// Set the fill style (colour) on the 2D context.
let setFillStyle: (canvasContext2d, string) => unit = %raw(`
  function(ctx, color) { ctx.fillStyle = color; }
`)

/// Set the stroke style (colour) on the 2D context.
let setStrokeStyle: (canvasContext2d, string) => unit = %raw(`
  function(ctx, color) { ctx.strokeStyle = color; }
`)

/// Set the line width on the 2D context.
let setLineWidth: (canvasContext2d, float) => unit = %raw(`
  function(ctx, w) { ctx.lineWidth = w; }
`)

/// Fill a rectangle on the 2D context.
@send
external fillRect: (canvasContext2d, float, float, float, float) => unit = "fillRect"

/// Stroke a rectangle outline on the 2D context.
@send
external strokeRect: (canvasContext2d, float, float, float, float) => unit = "strokeRect"

/// Clear a rectangle region on the 2D context.
@send
external clearRect: (canvasContext2d, float, float, float, float) => unit = "clearRect"

/// Set the font on the 2D context.
let setFont: (canvasContext2d, string) => unit = %raw(`
  function(ctx, font) { ctx.font = font; }
`)

/// Set the text alignment on the 2D context.
let setTextAlign: (canvasContext2d, string) => unit = %raw(`
  function(ctx, align) { ctx.textAlign = align; }
`)

/// Draw text at a position on the 2D context.
@send
external fillText: (canvasContext2d, string, float, float) => unit = "fillText"

// ---------------------------------------------------------------------------
// Gossamer IPC binding — calls into the Rust backend
// ---------------------------------------------------------------------------

/// Invoke a Gossamer command by name, passing an argument object.
/// Returns a Promise that resolves with the command's JSON result.
/// Falls back to Tauri for legacy compatibility, then to a no-op stub.
let tauriInvoke: (string, {..}) => Js.Promise.t<Js.Json.t> = %raw(`
  function(cmd, args) {
    if (typeof window !== "undefined" && typeof window.__gossamer_invoke === "function") {
      return window.__gossamer_invoke(cmd, args);
    }
    if (window.__TAURI__ && window.__TAURI__.core && window.__TAURI__.core.invoke) {
      return window.__TAURI__.core.invoke(cmd, args);
    }
    console.warn("Desktop runtime invoke not available for command:", cmd);
    return Promise.resolve(null);
  }
`)

// ---------------------------------------------------------------------------
// Keyboard event helpers
// ---------------------------------------------------------------------------

/// Extract the `key` property from a DOM keyboard event.
let eventKey: Dom.event => string = %raw(`
  function(e) { return e.key || ""; }
`)

/// Check whether the Ctrl (or Meta on macOS) modifier is held.
let eventCtrlKey: Dom.event => bool = %raw(`
  function(e) { return !!(e.ctrlKey || e.metaKey); }
`)

/// Prevent the browser's default action for an event.
let preventDefault: Dom.event => unit = %raw(`
  function(e) { e.preventDefault(); }
`)

// ---------------------------------------------------------------------------
// Colour constants — dark theme palette
// ---------------------------------------------------------------------------

/// Background colour for the application shell.
let colBg = "#0f1117"

/// Background colour for the toolbar and panels.
let colPanel = "#181a22"

/// Border colour between panels.
let colBorder = "#2a2d3a"

/// Primary text colour (light on dark).
let colText = "#e0e0e0"

/// Muted/secondary text colour.
let colTextMuted = "#6b7280"

/// Accent colour for active states and highlights.
let colAccent = "#3b82f6"

/// Canvas background (the editing area behind the grid).
let colCanvasBg = "#12141c"

/// Grid line colour on the canvas.
let colGrid = "#1e2030"

/// Tile fill colour (default empty tile).
let colTileEmpty = "#1a1c28"

/// Success/valid indicator colour.
let colValid = "#22c55e"

/// Error/invalid indicator colour.
let colInvalid = "#ef4444"

// ---------------------------------------------------------------------------
// Application state — mutable ref for the editor model
// ---------------------------------------------------------------------------

/// View mode determines which editing layer is active.
type viewMode =
  | Design
  | Physical
  | Network
  | Objects
  | Social
  | Crafting

/// Tool selected in the toolbar.
type activeTool =
  | Select
  | Paint
  | Erase
  | Wire

/// A single entry in the validation results panel.
type validationEntry = {
  /// Human-readable label for this check.
  label: string,
  /// Whether the check passed.
  passed: bool,
}

/// Recent level file entry returned by `list_levels`.
type recentFile = {
  /// Display name of the level.
  name: string,
  /// Filesystem path to the level JSON.
  path: string,
}

/// Top-level application state.
/// Stored in a mutable ref so event handlers can read/write it.
type appState = {
  /// Current view mode (determines which layer the canvas draws).
  mutable viewMode: viewMode,
  /// Currently selected tool.
  mutable activeTool: activeTool,
  /// Grid dimensions (columns, rows).
  mutable gridCols: int,
  mutable gridRows: int,
  /// Pixel size of each grid square.
  mutable squareSize: float,
  /// Whether grid lines are visible.
  mutable showGrid: bool,
  /// Currently selected tile coordinates (col, row), or None.
  mutable selectedTile: option<(int, int)>,
  /// Validation results (populated after calling validate_level_abi).
  mutable validationResults: array<validationEntry>,
  /// System info JSON (populated on startup via get_system_info).
  mutable systemInfo: option<Js.Json.t>,
  /// Recent level files (populated on startup via list_levels).
  mutable recentFiles: array<recentFile>,
  /// Status message displayed in the bottom bar.
  mutable statusMessage: string,
  /// Whether unsaved changes exist.
  mutable isDirty: bool,
}

/// The global application state instance.
let state: appState = {
  viewMode: Design,
  activeTool: Select,
  gridCols: 12,
  gridRows: 12,
  squareSize: 48.0,
  showGrid: true,
  selectedTile: None,
  validationResults: [],
  systemInfo: None,
  recentFiles: [],
  statusMessage: "Initialising...",
  isDirty: false,
}

// ---------------------------------------------------------------------------
// View mode helpers
// ---------------------------------------------------------------------------

/// Convert a viewMode variant to its display string.
let viewModeToString = (mode: viewMode): string =>
  switch mode {
  | Design => "Design"
  | Physical => "Physical"
  | Network => "Network"
  | Objects => "Objects"
  | Social => "Social"
  | Crafting => "Crafting"
  }

/// All available view modes, in toolbar order.
let allViewModes: array<viewMode> = [Design, Physical, Network, Objects, Social, Crafting]

/// Convert an activeTool variant to its display string.
let activeToolToString = (tool: activeTool): string =>
  switch tool {
  | Select => "Select"
  | Paint => "Paint"
  | Erase => "Erase"
  | Wire => "Wire"
  }

/// All available tools, in toolbar order.
let allTools: array<activeTool> = [Select, Paint, Erase, Wire]

// ---------------------------------------------------------------------------
// Canvas rendering
// ---------------------------------------------------------------------------

/// Render the level grid onto the canvas.
///
/// Clears the canvas, draws the background, then draws each grid cell.
/// If a tile is selected, highlights it with the accent colour.
/// Grid lines are drawn when `state.showGrid` is true.
let renderCanvas = (canvas: Dom.element): unit => {
  let ctx = getContext2d(canvas)
  let cols = state.gridCols
  let rows = state.gridRows
  let sq = state.squareSize
  let totalW = Float.fromInt(cols) *. sq
  let totalH = Float.fromInt(rows) *. sq

  // Set canvas pixel dimensions to match the grid.
  setCanvasWidth(canvas, Float.toInt(totalW))
  setCanvasHeight(canvas, Float.toInt(totalH))

  // Clear and fill background.
  clearRect(ctx, 0.0, 0.0, totalW, totalH)
  setFillStyle(ctx, colCanvasBg)
  fillRect(ctx, 0.0, 0.0, totalW, totalH)

  // Draw each tile cell.
  for col in 0 to cols - 1 {
    for row in 0 to rows - 1 {
      let x = Float.fromInt(col) *. sq
      let y = Float.fromInt(row) *. sq

      // Fill tile background.
      setFillStyle(ctx, colTileEmpty)
      fillRect(ctx, x +. 1.0, y +. 1.0, sq -. 2.0, sq -. 2.0)

      // Highlight selected tile.
      switch state.selectedTile {
      | Some((sc, sr)) if sc == col && sr == row => {
          setFillStyle(ctx, colAccent)
          fillRect(ctx, x +. 1.0, y +. 1.0, sq -. 2.0, sq -. 2.0)
        }
      | _ => ()
      }
    }
  }

  // Draw grid lines if enabled.
  if state.showGrid {
    setStrokeStyle(ctx, colGrid)
    setLineWidth(ctx, 1.0)
    for col in 0 to cols {
      let x = Float.fromInt(col) *. sq
      strokeRect(ctx, x, 0.0, 0.0, totalH)
    }
    for row in 0 to rows {
      let y = Float.fromInt(row) *. sq
      strokeRect(ctx, 0.0, y, totalW, 0.0)
    }
  }

  // Draw coordinate label on selected tile.
  switch state.selectedTile {
  | Some((sc, sr)) => {
      let tx = Float.fromInt(sc) *. sq +. sq /. 2.0
      let ty = Float.fromInt(sr) *. sq +. sq /. 2.0 +. 4.0
      setFillStyle(ctx, "#ffffff")
      setFont(ctx, "bold 11px system-ui")
      setTextAlign(ctx, "center")
      fillText(ctx, `${Int.toString(sc)},${Int.toString(sr)}`, tx, ty)
    }
  | None => ()
  }
}

// ---------------------------------------------------------------------------
// DOM construction helpers
// ---------------------------------------------------------------------------

/// Create a `<div>` element with the given inline style and text content.
let makeDiv = (~style: string, ~text: string=""): Dom.element => {
  let el = createElement(document, "div")
  setStyleCssText(el, style)
  if text != "" {
    setTextContent(el, text)
  }
  el
}

/// Create a `<button>` element with styling, label, and click handler.
let makeButton = (~style: string, ~label: string, ~onClick: unit => unit): Dom.element => {
  let btn = createElement(document, "button")
  setStyleCssText(btn, style)
  setTextContent(btn, label)
  addEventListener(btn, "click", _event => onClick())
  btn
}

// ---------------------------------------------------------------------------
// Build the toolbar (top bar)
// ---------------------------------------------------------------------------

/// Construct the toolbar element containing view mode tabs, tool selectors,
/// the grid toggle, and save/undo buttons.
///
/// Each button updates `state` and triggers a re-render of the canvas.
let buildToolbar = (~onRedraw: unit => unit): Dom.element => {
  let toolbar = makeDiv(
    ~style=`
      display: flex; align-items: center; justify-content: space-between;
      padding: 0 16px; height: 48px;
      background: ${colPanel}; border-bottom: 1px solid ${colBorder};
      font-family: system-ui, sans-serif; color: ${colText};
    `,
  )

  // Left section: app title.
  let title = makeDiv(
    ~style="font-size: 13px; font-weight: 800; letter-spacing: 0.12em; text-transform: uppercase;",
    ~text="IDApTIK Architect",
  )
  appendChild(toolbar, title)

  // Centre section: view mode tabs.
  let modeGroup = makeDiv(~style="display: flex; gap: 4px;")
  Array.forEach(allViewModes, mode => {
    let isActive = state.viewMode == mode
    let bg = isActive ? colAccent : "transparent"
    let col = isActive ? "#ffffff" : colTextMuted
    let btn = makeButton(
      ~style=`
        padding: 4px 12px; border: none; border-radius: 6px; cursor: pointer;
        font-size: 11px; font-weight: 700; text-transform: uppercase;
        background: ${bg}; color: ${col};
      `,
      ~label=viewModeToString(mode),
      ~onClick=() => {
        state.viewMode = mode
        onRedraw()
      },
    )
    appendChild(modeGroup, btn)
  })
  appendChild(toolbar, modeGroup)

  // Right section: tool selectors + action buttons.
  let rightGroup = makeDiv(~style="display: flex; gap: 8px; align-items: center;")

  // Tool selector buttons.
  Array.forEach(allTools, tool => {
    let isActive = state.activeTool == tool
    let bg = isActive ? "#2a2d3a" : "transparent"
    let col = isActive ? colText : colTextMuted
    let btn = makeButton(
      ~style=`
        padding: 4px 10px; border: 1px solid ${colBorder}; border-radius: 4px;
        cursor: pointer; font-size: 10px; font-weight: 600;
        background: ${bg}; color: ${col};
      `,
      ~label=activeToolToString(tool),
      ~onClick=() => {
        state.activeTool = tool
        onRedraw()
      },
    )
    appendChild(rightGroup, btn)
  })

  // Grid toggle.
  let gridBtn = makeButton(
    ~style=`
      padding: 4px 10px; border: 1px solid ${colBorder}; border-radius: 4px;
      cursor: pointer; font-size: 10px; font-weight: 600;
      background: transparent; color: ${colTextMuted};
    `,
    ~label=state.showGrid ? "Grid ON" : "Grid OFF",
    ~onClick=() => {
      state.showGrid = !state.showGrid
      onRedraw()
    },
  )
  appendChild(rightGroup, gridBtn)

  // Save button.
  let saveBtn = makeButton(
    ~style=`
      padding: 4px 14px; border: none; border-radius: 4px; cursor: pointer;
      font-size: 10px; font-weight: 700; background: ${colAccent}; color: #ffffff;
    `,
    ~label="SAVE",
    ~onClick=() => {
      state.statusMessage = "Saving..."
      onRedraw()
      let _ = tauriInvoke("save_level", {"name": "Untitled Level"})
      ()
    },
  )
  appendChild(rightGroup, saveBtn)

  appendChild(toolbar, rightGroup)
  toolbar
}

// ---------------------------------------------------------------------------
// Build the property panel (right sidebar)
// ---------------------------------------------------------------------------

/// Construct the property panel showing details of the selected tile/object.
///
/// When no tile is selected it shows a placeholder message. When a tile is
/// selected it shows the coordinates and the current view mode context.
let buildPropertyPanel = (): Dom.element => {
  let panel = makeDiv(
    ~style=`
      width: 260px; min-width: 260px;
      background: ${colPanel}; border-left: 1px solid ${colBorder};
      padding: 16px; overflow-y: auto;
      font-family: system-ui, sans-serif; color: ${colText};
    `,
  )

  let heading = makeDiv(
    ~style="font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.1em; margin-bottom: 16px;",
    ~text="Properties",
  )
  appendChild(panel, heading)

  switch state.selectedTile {
  | None => {
      let hint = makeDiv(
        ~style=`font-size: 12px; color: ${colTextMuted}; line-height: 1.6;`,
        ~text="Select a tile on the canvas to view and edit its properties.",
      )
      appendChild(panel, hint)
    }
  | Some((col, row)) => {
      let coordLabel = makeDiv(
        ~style="font-size: 12px; margin-bottom: 8px;",
        ~text=`Tile (${Int.toString(col)}, ${Int.toString(row)})`,
      )
      appendChild(panel, coordLabel)

      let modeLabel = makeDiv(
        ~style=`font-size: 11px; color: ${colTextMuted}; margin-bottom: 12px;`,
        ~text=`Layer: ${viewModeToString(state.viewMode)}`,
      )
      appendChild(panel, modeLabel)

      // Placeholder for layer-specific property editors.
      let placeholder = makeDiv(
        ~style=`
          padding: 12px; border: 1px dashed ${colBorder}; border-radius: 6px;
          font-size: 11px; color: ${colTextMuted}; text-align: center;
        `,
        ~text="Property editor — coming soon",
      )
      appendChild(panel, placeholder)
    }
  }

  panel
}

// ---------------------------------------------------------------------------
// Build the validation panel (bottom bar)
// ---------------------------------------------------------------------------

/// Construct the validation panel showing the five ABI proof statuses.
///
/// Each check is displayed as a labelled indicator dot (green = pass,
/// red = fail, grey = not yet run). The status message is shown on the left.
let buildValidationPanel = (): Dom.element => {
  let panel = makeDiv(
    ~style=`
      display: flex; align-items: center; justify-content: space-between;
      padding: 0 16px; height: 32px;
      background: ${colPanel}; border-top: 1px solid ${colBorder};
      font-family: system-ui, sans-serif; color: ${colTextMuted};
      font-size: 11px;
    `,
  )

  // Left: status message.
  let statusEl = makeDiv(~style="font-size: 11px;", ~text=state.statusMessage)
  appendChild(panel, statusEl)

  // Right: validation check indicators.
  let checksGroup = makeDiv(~style="display: flex; gap: 12px; align-items: center;")

  // Default check labels (the five ABI proofs).
  let defaultChecks = [
    "GuardsInZones",
    "DefenceTargets",
    "ZonesOrdered",
    "PBXConsistent",
    "DevicesExist",
  ]

  if Array.length(state.validationResults) > 0 {
    // Show actual results.
    Array.forEach(state.validationResults, entry => {
      let dotColor = entry.passed ? colValid : colInvalid
      let item = makeDiv(
        ~style=`display: flex; align-items: center; gap: 4px;`,
      )
      let dot = makeDiv(
        ~style=`width: 8px; height: 8px; border-radius: 50%; background: ${dotColor};`,
      )
      let label = makeDiv(~style="font-size: 10px;", ~text=entry.label)
      appendChild(item, dot)
      appendChild(item, label)
      appendChild(checksGroup, item)
    })
  } else {
    // Show grey placeholders — validation not yet run.
    Array.forEach(defaultChecks, checkName => {
      let item = makeDiv(
        ~style=`display: flex; align-items: center; gap: 4px;`,
      )
      let dot = makeDiv(
        ~style=`width: 8px; height: 8px; border-radius: 50%; background: #4b5563;`,
      )
      let label = makeDiv(~style="font-size: 10px;", ~text=checkName)
      appendChild(item, dot)
      appendChild(item, label)
      appendChild(checksGroup, item)
    })
  }

  appendChild(panel, checksGroup)
  panel
}

// ---------------------------------------------------------------------------
// Full application render
// ---------------------------------------------------------------------------

/// Re-render the entire application UI into the `#root` mount point.
///
/// This is a full teardown-and-rebuild approach — acceptable for a scaffold.
/// A production version would use incremental DOM updates or a virtual DOM.
let rec render = (): unit => {
  switch getElementById(document, "root")->Js.Nullable.toOption {
  | None => ()
  | Some(root) => {
      // Clear existing content.
      setInnerHTML(root, "")

      // Outer shell: column layout filling the viewport.
      setStyleCssText(
        root,
        `
        display: flex; flex-direction: column; height: 100%;
        background: ${colBg}; color: ${colText};
        font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      `,
      )

      // Toolbar (top).
      let toolbar = buildToolbar(~onRedraw=render)
      appendChild(root, toolbar)

      // Main content area: canvas + property panel side by side.
      let mainArea = makeDiv(
        ~style="display: flex; flex: 1; overflow: hidden;",
      )

      // Canvas container (centre, fills remaining space).
      let canvasContainer = makeDiv(
        ~style=`
          flex: 1; display: flex; align-items: center; justify-content: center;
          overflow: auto; background: ${colBg};
        `,
      )
      let canvas = createElement(document, "canvas")
      setId(canvas, "editor-canvas")
      setStyleCssText(
        canvas,
        `
        border: 1px solid ${colBorder}; border-radius: 4px;
        cursor: crosshair;
      `,
      )

      // Handle click on canvas to select a tile.
      addEventListener(canvas, "click", event => {
        // Extract click position relative to the canvas.
        let coords: (float, float) = %raw(`
          (function(e) {
            var rect = e.target.getBoundingClientRect();
            return [e.clientX - rect.left, e.clientY - rect.top];
          })(event)
        `)
        let (mx, my) = coords
        let col = Float.toInt(mx /. state.squareSize)
        let row = Float.toInt(my /. state.squareSize)
        if col >= 0 && col < state.gridCols && row >= 0 && row < state.gridRows {
          state.selectedTile = Some((col, row))
          state.statusMessage = `Selected tile (${Int.toString(col)}, ${Int.toString(row)})`
          render()
        }
      })

      appendChild(canvasContainer, canvas)
      appendChild(mainArea, canvasContainer)

      // Property panel (right sidebar).
      let propPanel = buildPropertyPanel()
      appendChild(mainArea, propPanel)

      appendChild(root, mainArea)

      // Validation panel (bottom bar).
      let validPanel = buildValidationPanel()
      appendChild(root, validPanel)

      // Now that the canvas is in the DOM, render the grid onto it.
      renderCanvas(canvas)
    }
  }
}

// ---------------------------------------------------------------------------
// Keyboard event handler
// ---------------------------------------------------------------------------

/// Global keyboard shortcut handler.
///
/// Wired shortcuts:
///   Ctrl+Z  — Undo (placeholder — logs to console)
///   Ctrl+S  — Save level via Gossamer invoke
///   Delete  — Clear selected tile
///   G       — Toggle grid visibility
///   Escape  — Deselect current tile
let handleKeyDown = (event: Dom.event): unit => {
  let key = eventKey(event)
  let ctrl = eventCtrlKey(event)

  if ctrl && key == "z" {
    // Undo — placeholder until undo stack is implemented.
    preventDefault(event)
    state.statusMessage = "Undo (not yet implemented)"
    render()
  } else if ctrl && key == "s" {
    // Save level via Gossamer backend.
    preventDefault(event)
    state.statusMessage = "Saving..."
    state.isDirty = false
    render()
    let _ = tauriInvoke("save_level", {"name": "Untitled Level"})
    ()
  } else if key == "Delete" {
    // Clear the selected tile.
    switch state.selectedTile {
    | Some((col, row)) => {
        state.statusMessage = `Cleared tile (${Int.toString(col)}, ${Int.toString(row)})`
        state.isDirty = true
        render()
      }
    | None => ()
    }
  } else if key == "g" || key == "G" {
    // Toggle grid visibility.
    state.showGrid = !state.showGrid
    state.statusMessage = state.showGrid ? "Grid visible" : "Grid hidden"
    render()
  } else if key == "Escape" {
    // Deselect current tile.
    state.selectedTile = None
    state.statusMessage = "Selection cleared"
    render()
  }
}

// ---------------------------------------------------------------------------
// Startup — fetch system info and recent files, then render
// ---------------------------------------------------------------------------

/// Bootstrap the application.
///
/// 1. Registers the global keyboard listener.
/// 2. Calls `get_system_info` to populate system metadata.
/// 3. Calls `list_levels` to populate the recent files list.
/// 4. Performs the initial render.
let init = (): unit => {
  // Register keyboard shortcuts on the window.
  windowAddEventListener(window, "keydown", handleKeyDown)

  // Fetch system info from the Gossamer backend.
  let _ =
    tauriInvoke("get_system_info", {})
    ->Js.Promise.then_(json => {
      state.systemInfo = Some(json)
      state.statusMessage = "System info loaded"
      render()
      Js.Promise.resolve()
    }, _)
    ->Js.Promise.catch_(_err => {
      state.statusMessage = "Ready (standalone mode)"
      render()
      Js.Promise.resolve()
    }, _)

  // Fetch the list of saved levels.
  let _ =
    tauriInvoke("list_levels", {})
    ->Js.Promise.then_(json => {
      // Parse the JSON array into recentFile records.
      let files: array<recentFile> = %raw(`
        (function(j) {
          if (!Array.isArray(j)) return [];
          return j.map(function(entry) {
            return { name: entry.name || "Untitled", path: entry.path || "" };
          });
        })(json)
      `)
      state.recentFiles = files
      if Array.length(files) > 0 {
        state.statusMessage = `${Int.toString(Array.length(files))} level(s) found`
      }
      render()
      Js.Promise.resolve()
    }, _)
    ->Js.Promise.catch_(_err => {
      // Non-fatal — the levels directory may not exist yet.
      Js.Promise.resolve()
    }, _)

  // Initial render.
  state.statusMessage = "IDApTIK UMS ready"
  render()
}

// ---------------------------------------------------------------------------
// Entry point — run init when the module loads
// ---------------------------------------------------------------------------

/// Kick off the application. This runs immediately when the ES module is
/// loaded by the `<script type="module">` tag in index.html.
init()
