// SPDX-License-Identifier: PMPL-1.0-or-later
// PixiJS Bindings for ReScript

// DOM types
type window
type htmlElement
type htmlCanvasElement
type event

// Event helpers
@send external stopPropagation: 'a => unit = "stopPropagation"

@val external window: window = "window"
@val external document: {..} = "document"
@send external getElementById: ({..}, string) => Nullable.t<htmlElement> = "getElementById"
@send external appendChild: (htmlElement, htmlCanvasElement) => unit = "appendChild"
@send external addEventListener: ({..}, string, event => unit) => unit = "addEventListener"
@send external removeEventListener: ({..}, string, event => unit) => unit = "removeEventListener"
@get external hidden: {..} => bool = "hidden"
@get external innerWidth: window => int = "innerWidth"
@get external innerHeight: window => int = "innerHeight"
@get external devicePixelRatio: window => float = "devicePixelRatio"

// Point type
module Point = {
  type t
  @new @module("pixi.js") external make: (~x: float, ~y: float) => t = "Point"
  @get external x: t => float = "x"
  @get external y: t => float = "y"
  @set external setX: (t, float) => unit = "x"
  @set external setY: (t, float) => unit = "y"
  @send external set: (t, float, float) => unit = "set"
}

// Hit area types
module Circle = {
  type t
  @new @module("pixi.js") external make: (~x: float, ~y: float, ~radius: float) => t = "Circle"
}

module Rectangle = {
  type t
  @new @module("pixi.js") external make: (~x: float, ~y: float, ~width: float, ~height: float) => t = "Rectangle"
}

// Generic hit area (can be Circle, Rectangle, etc.)
type hitArea

// ObservablePoint type (for anchors, pivots)
module ObservablePoint = {
  type t
  @get external x: t => float = "x"
  @get external y: t => float = "y"
  @set external setX: (t, float) => unit = "x"
  @set external setY: (t, float) => unit = "y"
  @send external set: (t, float, ~y: float=?) => unit = "set"
}

// Texture type
module Texture = {
  type t
  @module("pixi.js") @scope("Texture") external from: string => t = "from"
  @module("pixi.js") @scope("Texture") external white: t = "WHITE"
}

// Generic Filter type (for Container.setFilters)
type filter

// Forward declarations
module rec Container: {
  type t
  @new @module("pixi.js") external make: unit => t = "Container"

  @get external x: t => float = "x"
  @get external y: t => float = "y"
  @set external setX: (t, float) => unit = "x"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external width: t => float = "width"
  @get external height: t => float = "height"
  @get external scale: t => ObservablePoint.t = "scale"
  @get external pivot: t => ObservablePoint.t = "pivot"
  @get external position: t => ObservablePoint.t = "position"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external parent: t => Nullable.t<t> = "parent"
  @get external zIndex: t => int = "zIndex"
  @set external setZIndex: (t, int) => unit = "zIndex"
  @get external sortableChildren: t => bool = "sortableChildren"
  @set external setSortableChildren: (t, bool) => unit = "sortableChildren"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @get external cursor: t => string = "cursor"
  @set external setCursor: (t, string) => unit = "cursor"
  @get external interactiveChildren: t => bool = "interactiveChildren"
  @set external setInteractiveChildren: (t, bool) => unit = "interactiveChildren"
  @get external visible: t => bool = "visible"
  @set external setVisible: (t, bool) => unit = "visible"
  @get external worldVisible: t => bool = "worldVisible"
  @get external filters: t => Nullable.t<array<filter>> = "filters"
  @set external setFilters: (t, array<filter>) => unit = "filters"
  // Note: No clearFilters in PixiJS 8 — use setFilters(c, []) instead
  @set external setHitArea: (t, hitArea) => unit = "hitArea"
  @set external setHitAreaCircle: (t, Circle.t) => unit = "hitArea"
  @set external setHitAreaRectangle: (t, Rectangle.t) => unit = "hitArea"

  @send external addChild: (t, t) => t = "addChild"
  @send external addChildSprite: (t, Sprite.t) => Sprite.t = "addChild"
  @send external addChildGraphics: (t, Graphics.t) => Graphics.t = "addChild"
  @send external addChildText: (t, Text.t) => Text.t = "addChild"
  @send external addChildAt: (t, t, int) => t = "addChildAt"
  @send external removeChild: (t, t) => t = "removeChild"
  @send external removeChildren: t => unit = "removeChildren"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  @send external off: (t, string, 'a => unit) => unit = "off"
  @send external getChildCount: t => int = "children.length"
  @send external getChildAt: (t, int) => t = "getChildAt"
  @set external setAccessible: (t, bool) => unit = "accessible"
  @set external setAccessibleTitle: (t, string) => unit = "accessibleTitle"
  @set external setAccessibleType: (t, string) => unit = "accessibleType"
  @set external setTabIndex: (t, int) => unit = "tabIndex"
} = {
  type t
  @new @module("pixi.js") external make: unit => t = "Container"

  @get external x: t => float = "x"
  @get external y: t => float = "y"
  @set external setX: (t, float) => unit = "x"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external width: t => float = "width"
  @get external height: t => float = "height"
  @get external scale: t => ObservablePoint.t = "scale"
  @get external pivot: t => ObservablePoint.t = "pivot"
  @get external position: t => ObservablePoint.t = "position"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external parent: t => Nullable.t<t> = "parent"
  @get external zIndex: t => int = "zIndex"
  @set external setZIndex: (t, int) => unit = "zIndex"
  @get external sortableChildren: t => bool = "sortableChildren"
  @set external setSortableChildren: (t, bool) => unit = "sortableChildren"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @get external cursor: t => string = "cursor"
  @set external setCursor: (t, string) => unit = "cursor"
  @get external interactiveChildren: t => bool = "interactiveChildren"
  @set external setInteractiveChildren: (t, bool) => unit = "interactiveChildren"
  @get external visible: t => bool = "visible"
  @set external setVisible: (t, bool) => unit = "visible"
  @get external worldVisible: t => bool = "worldVisible"
  @get external filters: t => Nullable.t<array<filter>> = "filters"
  @set external setFilters: (t, array<filter>) => unit = "filters"
  // Note: No clearFilters in PixiJS 8 — use setFilters(c, []) instead
  @set external setHitArea: (t, hitArea) => unit = "hitArea"
  @set external setHitAreaCircle: (t, Circle.t) => unit = "hitArea"
  @set external setHitAreaRectangle: (t, Rectangle.t) => unit = "hitArea"

  @send external addChild: (t, t) => t = "addChild"
  @send external addChildSprite: (t, Sprite.t) => Sprite.t = "addChild"
  @send external addChildGraphics: (t, Graphics.t) => Graphics.t = "addChild"
  @send external addChildText: (t, Text.t) => Text.t = "addChild"
  @send external addChildAt: (t, t, int) => t = "addChildAt"
  @send external removeChild: (t, t) => t = "removeChild"
  @send external removeChildren: t => unit = "removeChildren"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  @send external off: (t, string, 'a => unit) => unit = "off"
  @send external getChildCount: t => int = "children.length"
  @send external getChildAt: (t, int) => t = "getChildAt"
  @set external setAccessible: (t, bool) => unit = "accessible"
  @set external setAccessibleTitle: (t, string) => unit = "accessibleTitle"
  @set external setAccessibleType: (t, string) => unit = "accessibleType"
  @set external setTabIndex: (t, int) => unit = "tabIndex"
}
and Sprite: {
  type t
  @new @module("pixi.js") external make: {..} => t = "Sprite"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external width: t => float = "width"
  @set external setWidth: (t, float) => unit = "width"
  @get external height: t => float = "height"
  @set external setHeight: (t, float) => unit = "height"
  @get external scale: t => ObservablePoint.t = "scale"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external position: t => ObservablePoint.t = "position"
  @get external tint: t => int = "tint"
  @set external setTint: (t, int) => unit = "tint"
  @get external interactive: t => bool = "interactive"
  @set external setInteractive: (t, bool) => unit = "interactive"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  let toContainer: t => Container.t
} = {
  type t
  @new @module("pixi.js") external make: {..} => t = "Sprite"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external width: t => float = "width"
  @set external setWidth: (t, float) => unit = "width"
  @get external height: t => float = "height"
  @set external setHeight: (t, float) => unit = "height"
  @get external scale: t => ObservablePoint.t = "scale"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external position: t => ObservablePoint.t = "position"
  @get external tint: t => int = "tint"
  @set external setTint: (t, int) => unit = "tint"
  @get external interactive: t => bool = "interactive"
  @set external setInteractive: (t, bool) => unit = "interactive"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  external toContainer: t => Container.t = "%identity"
}
and AnimatedSprite: {
  type t
  @new @module("pixi.js") external make: array<Texture.t> => t = "AnimatedSprite"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external scale: t => ObservablePoint.t = "scale"
  @set external setAnimationSpeed: (t, float) => unit = "animationSpeed"
  @set external setLoop: (t, bool) => unit = "loop"
  @set external setTextures: (t, array<Texture.t>) => unit = "textures"
  @set external setTint: (t, int) => unit = "tint"
  @set external setWidth: (t, float) => unit = "width"
  @set external setHeight: (t, float) => unit = "height"
  @send external play: t => unit = "play"
  @send external stop: t => unit = "stop"
  let toContainer: t => Container.t
} = {
  type t
  @new @module("pixi.js") external make: array<Texture.t> => t = "AnimatedSprite"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @get external scale: t => ObservablePoint.t = "scale"
  @set external setAnimationSpeed: (t, float) => unit = "animationSpeed"
  @set external setLoop: (t, bool) => unit = "loop"
  @set external setTextures: (t, array<Texture.t>) => unit = "textures"
  @set external setTint: (t, int) => unit = "tint"
  @set external setWidth: (t, float) => unit = "width"
  @set external setHeight: (t, float) => unit = "height"
  @send external play: t => unit = "play"
  @send external stop: t => unit = "stop"
  external toContainer: t => Container.t = "%identity"
}
and Graphics: {
  type t
  @new @module("pixi.js") external make: unit => t = "Graphics"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @get external interactiveChildren: t => bool = "interactiveChildren"
  @set external setInteractiveChildren: (t, bool) => unit = "interactiveChildren"
  @get external cursor: t => string = "cursor"
  @set external setCursor: (t, string) => unit = "cursor"
  @send external rect: (t, float, float, float, float) => t = "rect"
  @send external roundRect: (t, float, float, float, float, float) => t = "roundRect"
  @send external circle: (t, float, float, float) => t = "circle"
  @send external fill: (t, {..}) => t = "fill"
  @send external fillColor: (t, int) => t = "fill"
  @send external stroke: (t, {..}) => t = "stroke"
  @send external moveTo: (t, float, float) => t = "moveTo"
  @send external lineTo: (t, float, float) => t = "lineTo"
  @send external quadraticCurveTo: (t, float, float, float, float) => t = "quadraticCurveTo"
  @send external clear: t => t = "clear"
  @send external addChild: (t, 'a) => 'a = "addChild"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  @send external off: (t, string, 'a => unit) => unit = "off"
  let toContainer: t => Container.t
} = {
  type t
  @new @module("pixi.js") external make: unit => t = "Graphics"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external eventMode: t => string = "eventMode"
  @set external setEventMode: (t, string) => unit = "eventMode"
  @get external interactiveChildren: t => bool = "interactiveChildren"
  @set external setInteractiveChildren: (t, bool) => unit = "interactiveChildren"
  @get external cursor: t => string = "cursor"
  @set external setCursor: (t, string) => unit = "cursor"
  @send external rect: (t, float, float, float, float) => t = "rect"
  @send external roundRect: (t, float, float, float, float, float) => t = "roundRect"
  @send external circle: (t, float, float, float) => t = "circle"
  @send external fill: (t, {..}) => t = "fill"
  @send external fillColor: (t, int) => t = "fill"
  @send external stroke: (t, {..}) => t = "stroke"
  @send external moveTo: (t, float, float) => t = "moveTo"
  @send external lineTo: (t, float, float) => t = "lineTo"
  @send external quadraticCurveTo: (t, float, float, float, float) => t = "quadraticCurveTo"
  @send external clear: t => t = "clear"
  @send external addChild: (t, 'a) => 'a = "addChild"
  @send external destroy: t => unit = "destroy"
  @send external on: (t, string, 'a => unit) => unit = "on"
  @send external off: (t, string, 'a => unit) => unit = "off"
  external toContainer: t => Container.t = "%identity"
}
and Text: {
  type t
  @new @module("pixi.js") external make: {..} => t = "Text"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external text: t => string = "text"
  @set external setText: (t, string) => unit = "text"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @send external destroy: t => unit = "destroy"
  @set external setStyle: (t, TextStyle.t) => unit = "style"
  @get external style: t => TextStyle.t = "style"
  let toContainer: t => Container.t
} = {
  type t
  @new @module("pixi.js") external make: {..} => t = "Text"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external text: t => string = "text"
  @set external setText: (t, string) => unit = "text"
  @get external alpha: t => float = "alpha"
  @set external setAlpha: (t, float) => unit = "alpha"
  @get external anchor: t => ObservablePoint.t = "anchor"
  @send external destroy: t => unit = "destroy"
  @set external setStyle: (t, TextStyle.t) => unit = "style"
  @get external style: t => TextStyle.t = "style"
  external toContainer: t => Container.t = "%identity"
}
and TextStyle: {
  type t
  @new @module("pixi.js") external make: {..} => t = "TextStyle"
} = {
  type t
  @new @module("pixi.js") external make: {..} => t = "TextStyle"
}

// NineSliceSprite
module NineSliceSprite = {
  type t
  @new @module("pixi.js") external make: {..} => t = "NineSliceSprite"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external width: t => float = "width"
  @set external setWidth: (t, float) => unit = "width"
  @get external height: t => float = "height"
  @set external setHeight: (t, float) => unit = "height"
  external toContainer: t => Container.t = "%identity"
}

// BlurFilter
module BlurFilter = {
  type t
  @new @module("pixi.js") external make: {..} => t = "BlurFilter"
  external toFilter: t => filter = "%identity"
}

// Ticker
module Ticker = {
  type t
  @get external deltaTime: t => float = "deltaTime"
  @get external deltaMS: t => float = "deltaMS"
  @send external add: (t, t => unit, 'context) => unit = "add"
  @send external remove: (t, t => unit, 'context) => unit = "remove"
}

// FederatedPointerEvent
module FederatedPointerEvent = {
  type t
  type globalPoint = {x: float, y: float}
  @get external global: t => globalPoint = "global"
  @send external preventDefault: t => unit = "preventDefault"
  @send external getLocalPosition: (t, Container.t) => globalPoint = "getLocalPosition"
}

// BigPool
module BigPool = {
  @module("pixi.js") @scope("BigPool") external get: 'constructor => 'instance = "get"
}

// Assets
type bundleManifest
module Assets = {
  @module("pixi.js") @scope("Assets") external init: {..} => promise<unit> = "init"
  @module("pixi.js") @scope("Assets") external loadBundle: (array<string>, float => unit) => promise<unit> = "loadBundle"
  @module("pixi.js") @scope("Assets") external loadBundleString: string => promise<unit> = "loadBundle"
  @module("pixi.js") @scope("Assets") external backgroundLoadBundle: array<string> => unit = "backgroundLoadBundle"
}

// Extensions
module Extensions = {
  @module("pixi.js") @scope("extensions") external add: 'a => unit = "add"
  @module("pixi.js") @scope("extensions") external remove: 'a => unit = "remove"
}

// ExtensionType
module ExtensionType = {
  @module("pixi.js") @scope("ExtensionType") external application: string = "Application"
}

// ResizePlugin (to remove)
module ResizePlugin = {
  type t
  @module("pixi.js") external resizePlugin: t = "ResizePlugin"
}

// Renderer
module Renderer = {
  type t
  @get external width: t => float = "width"
  @get external height: t => float = "height"
  @get external canvas: t => htmlCanvasElement = "canvas"
  @send external resize: (t, float, float) => unit = "resize"
  @send external on: (t, string, unit => unit) => unit = "on"
}

// Canvas style
module CanvasStyle = {
  @set external setWidth: (htmlCanvasElement, string) => unit = "style.width"
  @set external setHeight: (htmlCanvasElement, string) => unit = "style.height"
}

// Application
module Application = {
  type t
  type initOptions = {
    background?: string,
    resizeTo?: window,
    resolution?: float,
  }

  @new @module("pixi.js") external make: unit => t = "Application"
  @send external init: (t, {..}) => promise<unit> = "init"
  @get external stage: t => Container.t = "stage"
  @get external ticker: t => Ticker.t = "ticker"
  @get external canvas: t => htmlCanvasElement = "canvas"
  @get external renderer: t => Renderer.t = "renderer"
  @send external resize: t => unit = "resize"
  @send external destroy: (t, ~removeView: bool=?, ~options: {..}=?) => unit = "destroy"
}
