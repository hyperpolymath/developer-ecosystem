// SPDX-License-Identifier: PMPL-1.0-or-later
// @pixi/ui Bindings for ReScript

open Pixi

// Signal type for connecting handlers
module Signal = {
  type t<'a>
  @send external connect: (t<'a>, 'a => unit) => unit = "connect"
}

// Animation options type (opaque to avoid unbound type vars)
type animationOptions

// FancyButton
module FancyButton = {
  type t

  @new @module("@pixi/ui") external make: {..} => t = "FancyButton"
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
  @get external onPress: t => Signal.t<unit> = "onPress"
  @get external onDown: t => Signal.t<unit> = "onDown"
  @get external onHover: t => Signal.t<unit> = "onHover"
  @set external setText: (t, string) => unit = "text"
  @send external toContainer: t => Container.t = "%identity"
}

// Slider
module Slider = {
  type t

  @new @module("@pixi/ui") external make: {..} => t = "Slider"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external value: t => float = "value"
  @set external setValue: (t, float) => unit = "value"
  @get external onUpdate: t => Signal.t<float> = "onUpdate"
  @send external addChild: (t, 'a) => 'a = "addChild"
  @send external toContainer: t => Container.t = "%identity"
}

// ProgressBar
module ProgressBar = {
  type t

  @new @module("@pixi/ui") external make: {..} => t = "ProgressBar"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external progress: t => float = "progress"
  @set external setProgress: (t, float) => unit = "progress"
  @get external scale: t => ObservablePoint.t = "scale"
  @get external position: t => ObservablePoint.t = "position"
  @send external toContainer: t => Container.t = "%identity"
}

// List
module List = {
  type t
  type listType = | @as("vertical") Vertical | @as("horizontal") Horizontal

  @new @module("@pixi/ui") external make: {..} => t = "List"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @send external addChild: (t, 'a) => 'a = "addChild"
  @send external toContainer: t => Container.t = "%identity"
}

// Input (text input field)
module Input = {
  type t

  @new @module("@pixi/ui") external make: {..} => t = "Input"
  @get external x: t => float = "x"
  @set external setX: (t, float) => unit = "x"
  @get external y: t => float = "y"
  @set external setY: (t, float) => unit = "y"
  @get external width: t => float = "width"
  @set external setWidth: (t, float) => unit = "width"
  @get external height: t => float = "height"
  @set external setHeight: (t, float) => unit = "height"
  @get external value: t => string = "value"
  @set external setValue: (t, string) => unit = "value"
  @get external onEnter: t => Signal.t<string> = "onEnter"
  @get external onChange: t => Signal.t<string> = "onChange"
  @send external toContainer: t => Container.t = "%identity"
}
