// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Window.res - Tauri 2.0 window management bindings
// ReScript bindings for @tauri-apps/api/window

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Physical position in screen coordinates */
type physicalPosition = {x: int, y: int}

/** Logical position (DPI-aware) */
type logicalPosition = {x: float, y: float}

/** Physical size in pixels */
type physicalSize = {width: int, height: int}

/** Logical size (DPI-aware) */
type logicalSize = {width: float, height: float}

/** Window theme */
type theme =
  | @as("light") Light
  | @as("dark") Dark

/** Focus changed event payload */
type focusChangedPayload = {focused: bool}

/** Scale changed event payload */
type scaleChangedPayload = {scaleFactor: float, size: physicalSize}

/** Cursor icon types */
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
  | @as("contextMenu") ContextMenu
  | @as("cell") Cell
  | @as("verticalText") VerticalText
  | @as("alias") Alias
  | @as("copy") Copy
  | @as("noDrop") NoDrop
  | @as("grab") Grab
  | @as("grabbing") Grabbing
  | @as("allScroll") AllScroll
  | @as("zoomIn") ZoomIn
  | @as("zoomOut") ZoomOut
  | @as("eResize") EResize
  | @as("nResize") NResize
  | @as("neResize") NeResize
  | @as("nwResize") NwResize
  | @as("sResize") SResize
  | @as("seResize") SeResize
  | @as("swResize") SwResize
  | @as("wResize") WResize
  | @as("ewResize") EwResize
  | @as("nsResize") NsResize
  | @as("neswResize") NeswResize
  | @as("nwseResize") NwseResize
  | @as("colResize") ColResize
  | @as("rowResize") RowResize

/** Window handle - opaque type */
type window

// ============================================================================
// Window Instance Access
// ============================================================================

/** Get the current window instance */
@module("@tauri-apps/api/window")
external getCurrentWindow: unit => window = "getCurrentWindow"

/** Get all windows */
@module("@tauri-apps/api/window")
external getAllWindows: unit => array<window> = "getAllWindows"

// ============================================================================
// Window Properties (Getters)
// ============================================================================

@send external label: window => string = "label"
@send external scaleFactor: window => promise<float> = "scaleFactor"
@send external innerPosition: window => promise<physicalPosition> = "innerPosition"
@send external outerPosition: window => promise<physicalPosition> = "outerPosition"
@send external innerSize: window => promise<physicalSize> = "innerSize"
@send external outerSize: window => promise<physicalSize> = "outerSize"
@send external isFullscreen: window => promise<bool> = "isFullscreen"
@send external isMinimized: window => promise<bool> = "isMinimized"
@send external isMaximized: window => promise<bool> = "isMaximized"
@send external isFocused: window => promise<bool> = "isFocused"
@send external isDecorated: window => promise<bool> = "isDecorated"
@send external isResizable: window => promise<bool> = "isResizable"
@send external isMaximizable: window => promise<bool> = "isMaximizable"
@send external isMinimizable: window => promise<bool> = "isMinimizable"
@send external isClosable: window => promise<bool> = "isClosable"
@send external isVisible: window => promise<bool> = "isVisible"
@send external title: window => promise<string> = "title"
@send external theme: window => promise<Nullable.t<theme>> = "theme"

// ============================================================================
// Window Properties (Setters)
// ============================================================================

@send external center: window => promise<unit> = "center"
@send external requestUserAttention: (window, Nullable.t<int>) => promise<unit> = "requestUserAttention"
@send external setResizable: (window, bool) => promise<unit> = "setResizable"
@send external setMaximizable: (window, bool) => promise<unit> = "setMaximizable"
@send external setMinimizable: (window, bool) => promise<unit> = "setMinimizable"
@send external setClosable: (window, bool) => promise<unit> = "setClosable"
@send external setTitle: (window, string) => promise<unit> = "setTitle"
@send external maximize: window => promise<unit> = "maximize"
@send external unmaximize: window => promise<unit> = "unmaximize"
@send external toggleMaximize: window => promise<unit> = "toggleMaximize"
@send external minimize: window => promise<unit> = "minimize"
@send external unminimize: window => promise<unit> = "unminimize"
@send external show: window => promise<unit> = "show"
@send external hide: window => promise<unit> = "hide"
@send external close: window => promise<unit> = "close"
@send external destroy: window => promise<unit> = "destroy"
@send external setDecorations: (window, bool) => promise<unit> = "setDecorations"
@send external setShadow: (window, bool) => promise<unit> = "setShadow"
@send external setAlwaysOnTop: (window, bool) => promise<unit> = "setAlwaysOnTop"
@send external setAlwaysOnBottom: (window, bool) => promise<unit> = "setAlwaysOnBottom"
@send external setContentProtected: (window, bool) => promise<unit> = "setContentProtected"
@send external setSize: (window, logicalSize) => promise<unit> = "setSize"
@send external setMinSize: (window, Nullable.t<logicalSize>) => promise<unit> = "setMinSize"
@send external setMaxSize: (window, Nullable.t<logicalSize>) => promise<unit> = "setMaxSize"
@send external setPosition: (window, logicalPosition) => promise<unit> = "setPosition"
@send external setFullscreen: (window, bool) => promise<unit> = "setFullscreen"
@send external setFocus: window => promise<unit> = "setFocus"
@send external setSkipTaskbar: (window, bool) => promise<unit> = "setSkipTaskbar"
@send external setCursorGrab: (window, bool) => promise<unit> = "setCursorGrab"
@send external setCursorVisible: (window, bool) => promise<unit> = "setCursorVisible"
@send external setCursorIcon: (window, cursorIcon) => promise<unit> = "setCursorIcon"
@send external setCursorPosition: (window, logicalPosition) => promise<unit> = "setCursorPosition"
@send external setIgnoreCursorEvents: (window, bool) => promise<unit> = "setIgnoreCursorEvents"
@send external startDragging: window => promise<unit> = "startDragging"
@send external startResizeDragging: window => promise<unit> = "startResizeDragging"
@send external setProgressBar: (window, {..}) => promise<unit> = "setProgressBar"
@send external setVisibleOnAllWorkspaces: (window, bool) => promise<unit> = "setVisibleOnAllWorkspaces"

// ============================================================================
// Window Events
// ============================================================================

@send
external onCloseRequested: (window, unit => promise<unit>) => promise<unit => unit> =
  "onCloseRequested"

@send
external onFocusChanged: (window, focusChangedPayload => unit) => promise<unit => unit> =
  "onFocusChanged"

@send
external onMoved: (window, physicalPosition => unit) => promise<unit => unit> = "onMoved"

@send
external onResized: (window, physicalSize => unit) => promise<unit => unit> = "onResized"

@send
external onScaleChanged: (window, scaleChangedPayload => unit) => promise<unit => unit> =
  "onScaleChanged"

@send
external onThemeChanged: (window, theme => unit) => promise<unit => unit> = "onThemeChanged"

// ============================================================================
// Helper Module
// ============================================================================

module Current = {
  /** Get the current window */
  let get = getCurrentWindow

  /** Convenience functions for current window */
  let center = () => getCurrentWindow()->center
  let close = () => getCurrentWindow()->close
  let minimize = () => getCurrentWindow()->minimize
  let maximize = () => getCurrentWindow()->maximize
  let setTitle = title => getCurrentWindow()->setTitle(title)
  let setFullscreen = fullscreen => getCurrentWindow()->setFullscreen(fullscreen)
  let setSize = size => getCurrentWindow()->setSize(size)
  let setPosition = pos => getCurrentWindow()->setPosition(pos)
  let show = () => getCurrentWindow()->show
  let hide = () => getCurrentWindow()->hide
  let isFocused = () => getCurrentWindow()->isFocused
  let isMaximized = () => getCurrentWindow()->isMaximized
  let isMinimized = () => getCurrentWindow()->isMinimized
  let isFullscreen = () => getCurrentWindow()->isFullscreen
  let getTitle = () => getCurrentWindow()->title
  let getTheme = () => getCurrentWindow()->theme
}
