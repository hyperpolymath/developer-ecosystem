// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Gossamer_Window.res — Gossamer window management bindings.
//
// Provides window manipulation (resize, move, minimize, maximize, etc.) via
// the Gossamer IPC channel. This is the Gossamer equivalent of Tauri_Window.res
// (which wraps @tauri-apps/api/window).

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/// Physical position in screen coordinates.
type physicalPosition = {x: int, y: int}

/// Logical position (DPI-aware).
type logicalPosition = {x: float, y: float}

/// Physical size in pixels.
type physicalSize = {width: int, height: int}

/// Logical size (DPI-aware).
type logicalSize = {width: float, height: float}

/// Window theme.
type theme =
  | @as("light") Light
  | @as("dark") Dark

/// Focus changed event payload.
type focusChangedPayload = {focused: bool}

/// Scale changed event payload.
type scaleChangedPayload = {scaleFactor: float, size: physicalSize}

/// Cursor icon types.
type cursorIcon =
  | @as("default") Default
  | @as("crosshair") Crosshair
  | @as("hand") Hand
  | @as("arrow") Arrow
  | @as("move") Move
  | @as("text") Text
  | @as("wait") Wait
  | @as("help") Help
  | @as("progress") Progress
  | @as("notAllowed") NotAllowed

/// Window handle — opaque reference to a Gossamer window.
type window = {label: string}

// ============================================================================
// Window Instance Access
// ============================================================================

/// Get the current window instance.
let getCurrentWindow = (): promise<window> => {
  Gossamer_Core.invokeRaw("__gossamer_window_get_current", {})
}

/// Get all windows.
let getAllWindows = (): promise<array<window>> => {
  Gossamer_Core.invokeRaw("__gossamer_window_get_all", {})
}

// ============================================================================
// Window Properties (Getters)
// ============================================================================

let scaleFactor = (win: window): promise<float> => {
  Gossamer_Core.invokeRaw("__gossamer_window_scale_factor", {"label": win.label})
}

let innerPosition = (win: window): promise<physicalPosition> => {
  Gossamer_Core.invokeRaw("__gossamer_window_inner_position", {"label": win.label})
}

let outerPosition = (win: window): promise<physicalPosition> => {
  Gossamer_Core.invokeRaw("__gossamer_window_outer_position", {"label": win.label})
}

let innerSize = (win: window): promise<physicalSize> => {
  Gossamer_Core.invokeRaw("__gossamer_window_inner_size", {"label": win.label})
}

let outerSize = (win: window): promise<physicalSize> => {
  Gossamer_Core.invokeRaw("__gossamer_window_outer_size", {"label": win.label})
}

let isFullscreen = (win: window): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_window_is_fullscreen", {"label": win.label})
}

let isMinimized = (win: window): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_window_is_minimized", {"label": win.label})
}

let isMaximized = (win: window): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_window_is_maximized", {"label": win.label})
}

let isFocused = (win: window): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_window_is_focused", {"label": win.label})
}

let isVisible = (win: window): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_window_is_visible", {"label": win.label})
}

let title = (win: window): promise<string> => {
  Gossamer_Core.invokeRaw("__gossamer_window_title", {"label": win.label})
}

let getTheme = (win: window): promise<Nullable.t<theme>> => {
  Gossamer_Core.invokeRaw("__gossamer_window_theme", {"label": win.label})
}

// ============================================================================
// Window Properties (Setters)
// ============================================================================

let center = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_center", {"label": win.label})
}

let setResizable = (win: window, resizable: bool): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_resizable", {"label": win.label, "resizable": resizable})
}

let setTitle = (win: window, newTitle: string): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_title", {"label": win.label, "title": newTitle})
}

let maximize = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_maximize", {"label": win.label})
}

let unmaximize = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_unmaximize", {"label": win.label})
}

let toggleMaximize = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_toggle_maximize", {"label": win.label})
}

let minimize = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_minimize", {"label": win.label})
}

let unminimize = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_unminimize", {"label": win.label})
}

let show = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_show", {"label": win.label})
}

let hide = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_hide", {"label": win.label})
}

let close = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_close", {"label": win.label})
}

let destroy = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_destroy", {"label": win.label})
}

let setDecorations = (win: window, decorations: bool): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_decorations", {"label": win.label, "decorations": decorations})
}

let setAlwaysOnTop = (win: window, alwaysOnTop: bool): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_always_on_top", {"label": win.label, "alwaysOnTop": alwaysOnTop})
}

let setSize = (win: window, size: logicalSize): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_size", {"label": win.label, "width": size.width, "height": size.height})
}

let setMinSize = (win: window, size: Nullable.t<logicalSize>): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_min_size", {"label": win.label, "size": size})
}

let setMaxSize = (win: window, size: Nullable.t<logicalSize>): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_max_size", {"label": win.label, "size": size})
}

let setPosition = (win: window, pos: logicalPosition): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_position", {"label": win.label, "x": pos.x, "y": pos.y})
}

let setFullscreen = (win: window, fullscreen: bool): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_fullscreen", {"label": win.label, "fullscreen": fullscreen})
}

let setFocus = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_focus", {"label": win.label})
}

let setCursorIcon = (win: window, icon: cursorIcon): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_cursor_icon", {"label": win.label, "icon": icon})
}

let setCursorVisible = (win: window, visible: bool): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_set_cursor_visible", {"label": win.label, "visible": visible})
}

let startDragging = (win: window): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_window_start_dragging", {"label": win.label})
}

// ============================================================================
// Window Events
// ============================================================================

let onCloseRequested = (win: window, handler: unit => promise<unit>): promise<unit => unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_window_on_close_requested",
    {"label": win.label, "handler": handler},
  )
}

let onFocusChanged = (win: window, handler: focusChangedPayload => unit): promise<unit => unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_window_on_focus_changed",
    {"label": win.label, "handler": handler},
  )
}

let onResized = (win: window, handler: physicalSize => unit): promise<unit => unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_window_on_resized",
    {"label": win.label, "handler": handler},
  )
}

let onMoved = (win: window, handler: physicalPosition => unit): promise<unit => unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_window_on_moved",
    {"label": win.label, "handler": handler},
  )
}

// ============================================================================
// Helper Module — convenience functions for the current window
// ============================================================================

module Current = {
  let get = getCurrentWindow

  let centerCurrent = async () => {
    let win = await getCurrentWindow()
    await center(win)
  }

  let closeCurrent = async () => {
    let win = await getCurrentWindow()
    await close(win)
  }

  let minimizeCurrent = async () => {
    let win = await getCurrentWindow()
    await minimize(win)
  }

  let maximizeCurrent = async () => {
    let win = await getCurrentWindow()
    await maximize(win)
  }

  let setTitleCurrent = async (newTitle: string) => {
    let win = await getCurrentWindow()
    await setTitle(win, newTitle)
  }

  let setFullscreenCurrent = async (fs: bool) => {
    let win = await getCurrentWindow()
    await setFullscreen(win, fs)
  }

  let setSizeCurrent = async (size: logicalSize) => {
    let win = await getCurrentWindow()
    await setSize(win, size)
  }

  let setPositionCurrent = async (pos: logicalPosition) => {
    let win = await getCurrentWindow()
    await setPosition(win, pos)
  }

  let showCurrent = async () => {
    let win = await getCurrentWindow()
    await show(win)
  }

  let hideCurrent = async () => {
    let win = await getCurrentWindow()
    await hide(win)
  }

  let isFocusedCurrent = async () => {
    let win = await getCurrentWindow()
    await isFocused(win)
  }

  let isMaximizedCurrent = async () => {
    let win = await getCurrentWindow()
    await isMaximized(win)
  }

  let isMinimizedCurrent = async () => {
    let win = await getCurrentWindow()
    await isMinimized(win)
  }

  let isFullscreenCurrent = async () => {
    let win = await getCurrentWindow()
    await isFullscreen(win)
  }

  let getTitleCurrent = async () => {
    let win = await getCurrentWindow()
    await title(win)
  }

  let getThemeCurrent = async () => {
    let win = await getCurrentWindow()
    await getTheme(win)
  }
}
