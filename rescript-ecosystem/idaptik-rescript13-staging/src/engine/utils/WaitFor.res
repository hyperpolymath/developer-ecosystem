// SPDX-License-Identifier: PMPL-1.0-or-later
// Delay utility for ReScript


@val external setTimeout: (unit => unit, int) => int = "setTimeout"

// Pause the code for a certain amount of time, in seconds
let waitFor = (~delayInSecs=1.0, ()): promise<unit> => {
  Promise.make((resolve, _reject) => {
    let _ = setTimeout(() => resolve(.), Float.toInt(delayInSecs *. 1000.0))
  })
}
