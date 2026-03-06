// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Window.resi - Interface for Tauri window management bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type physicalPosition = {x: int, y: int}
type logicalPosition = {x: float, y: float}
type physicalSize = {width: int, height: int}
type logicalSize = {width: float, height: float}

type theme =
  | @as("light") Light
  | @as("dark") Dark

type focusChangedPayload = {focused: bool}
type scaleChangedPayload = {scaleFactor: float, size: physicalSize}

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

type window

// ============================================================================
// Window Instance Access
// ============================================================================

let getCurrentWindow: unit => window
let getAllWindows: unit => array<window>

// ============================================================================
// Window Properties (Getters)
// ============================================================================

let label: window => string
let scaleFactor: window => promise<float>
let innerPosition: window => promise<physicalPosition>
let outerPosition: window => promise<physicalPosition>
let innerSize: window => promise<physicalSize>
let outerSize: window => promise<physicalSize>
let isFullscreen: window => promise<bool>
let isMinimized: window => promise<bool>
let isMaximized: window => promise<bool>
let isFocused: window => promise<bool>
let isDecorated: window => promise<bool>
let isResizable: window => promise<bool>
let isMaximizable: window => promise<bool>
let isMinimizable: window => promise<bool>
let isClosable: window => promise<bool>
let isVisible: window => promise<bool>
let title: window => promise<string>
let theme: window => promise<Nullable.t<theme>>

// ============================================================================
// Window Properties (Setters)
// ============================================================================

let center: window => promise<unit>
let requestUserAttention: (window, Nullable.t<int>) => promise<unit>
let setResizable: (window, bool) => promise<unit>
let setMaximizable: (window, bool) => promise<unit>
let setMinimizable: (window, bool) => promise<unit>
let setClosable: (window, bool) => promise<unit>
let setTitle: (window, string) => promise<unit>
let maximize: window => promise<unit>
let unmaximize: window => promise<unit>
let toggleMaximize: window => promise<unit>
let minimize: window => promise<unit>
let unminimize: window => promise<unit>
let show: window => promise<unit>
let hide: window => promise<unit>
let close: window => promise<unit>
let destroy: window => promise<unit>
let setDecorations: (window, bool) => promise<unit>
let setShadow: (window, bool) => promise<unit>
let setAlwaysOnTop: (window, bool) => promise<unit>
let setAlwaysOnBottom: (window, bool) => promise<unit>
let setContentProtected: (window, bool) => promise<unit>
let setSize: (window, logicalSize) => promise<unit>
let setMinSize: (window, Nullable.t<logicalSize>) => promise<unit>
let setMaxSize: (window, Nullable.t<logicalSize>) => promise<unit>
let setPosition: (window, logicalPosition) => promise<unit>
let setFullscreen: (window, bool) => promise<unit>
let setFocus: window => promise<unit>
let setSkipTaskbar: (window, bool) => promise<unit>
let setCursorGrab: (window, bool) => promise<unit>
let setCursorVisible: (window, bool) => promise<unit>
let setCursorIcon: (window, cursorIcon) => promise<unit>
let setCursorPosition: (window, logicalPosition) => promise<unit>
let setIgnoreCursorEvents: (window, bool) => promise<unit>
let startDragging: window => promise<unit>
let startResizeDragging: window => promise<unit>
let setProgressBar: (window, {..}) => promise<unit>
let setVisibleOnAllWorkspaces: (window, bool) => promise<unit>

// ============================================================================
// Window Events
// ============================================================================

let onCloseRequested: (window, unit => promise<unit>) => promise<unit => unit>
let onFocusChanged: (window, focusChangedPayload => unit) => promise<unit => unit>
let onMoved: (window, physicalPosition => unit) => promise<unit => unit>
let onResized: (window, physicalSize => unit) => promise<unit => unit>
let onScaleChanged: (window, scaleChangedPayload => unit) => promise<unit => unit>
let onThemeChanged: (window, theme => unit) => promise<unit => unit>

// ============================================================================
// Helper Module
// ============================================================================

module Current: {
  let get: unit => window
  let center: unit => promise<unit>
  let close: unit => promise<unit>
  let minimize: unit => promise<unit>
  let maximize: unit => promise<unit>
  let setTitle: string => promise<unit>
  let setFullscreen: bool => promise<unit>
  let setSize: logicalSize => promise<unit>
  let setPosition: logicalPosition => promise<unit>
  let show: unit => promise<unit>
  let hide: unit => promise<unit>
  let isFocused: unit => promise<bool>
  let isMaximized: unit => promise<bool>
  let isMinimized: unit => promise<bool>
  let isFullscreen: unit => promise<bool>
  let getTitle: unit => promise<string>
  let getTheme: unit => promise<Nullable.t<theme>>
}
