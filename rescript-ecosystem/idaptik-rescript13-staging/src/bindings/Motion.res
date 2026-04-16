// SPDX-License-Identifier: PMPL-1.0-or-later
// Motion library bindings for ReScript

type animationControls
type easing =
  | @as("linear") Linear
  | @as("easeOut") EaseOut
  | @as("easeIn") EaseIn
  | @as("backOut") BackOut
  | @as("backIn") BackIn

type animateOptions = {
  duration?: float,
  ease?: string,
  delay?: float,
}

@module("motion") external animate: ('target, {..}, animateOptions) => animationControls = "animate"
@send external then_: (animationControls, unit => unit) => promise<unit> = "then"
@send external thenCatch: (animationControls, exn => unit) => unit = "catch"

// Promise-based animate
let animateAsync: ('target, {..}, animateOptions) => promise<unit> = (target, props, options) => {
  Promise.make((resolve, _reject) => {
    let controls = animate(target, props, options)
    let _ = controls->then_(() => resolve())
  })
}
