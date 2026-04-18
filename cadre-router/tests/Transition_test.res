// SPDX-License-Identifier: Apache-2.0
// Transition_test.res - Tests for route transitions

// Test harness
let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, actual: bool): unit => {
  if actual {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name} - expected true`)
  }
}

let assertFalse = (name: string, actual: bool): unit => {
  if !actual {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name} - expected false`)
  }
}

// ============================================================
// Test Route Types
// ============================================================

type route =
  | Home
  | About
  | Contact
  | Products
  | NotFound

let routeEq = (a: route, b: route): bool => a == b

// ============================================================
// Manager Tests
// ============================================================

let testMakeManager = () => {
  let manager = Transition.make(Home)
  assertEq("make: initial route", Transition.getCurrentRoute(manager), Home)
  assertFalse("make: not transitioning", Transition.isTransitioning(manager))
}

let testGetState = () => {
  let manager = Transition.make(Home)
  let state = Transition.getState(manager)
  switch state {
  | Transition.Idle(r) => assertEq("getState: idle with initial route", r, Home)
  | _ => Js.Console.error("[FAIL] getState: should be Idle")
  }
}

// ============================================================
// Transition Tests
// ============================================================

let testStartTransition = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, About, ~eq=routeEq)

  assertTrue("startTransition: is transitioning", Transition.isTransitioning(manager))

  switch Transition.getState(manager) {
  | Transition.Transitioning({from, to, direction}) =>
    assertEq("startTransition: from", from, Home)
    assertEq("startTransition: to", to, About)
    assertEq("startTransition: direction", direction, Transition.Forward)
  | _ => Js.Console.error("[FAIL] startTransition: should be Transitioning")
  }
}

let testStartTransitionSameRoute = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, Home, ~eq=routeEq)

  // Should not transition to same route
  assertFalse("startTransition same: not transitioning", Transition.isTransitioning(manager))
}

let testUpdateProgress = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, About, ~eq=routeEq)
  Transition.updateProgress(manager, 0.5)

  switch Transition.getState(manager) {
  | Transition.Transitioning({progress}) =>
    assertEq("updateProgress: progress value", progress, 0.5)
  | _ => Js.Console.error("[FAIL] updateProgress: should be Transitioning")
  }
}

let testCompleteTransition = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, About, ~eq=routeEq)
  Transition.completeTransition(manager)

  assertFalse("completeTransition: not transitioning", Transition.isTransitioning(manager))
  assertEq("completeTransition: current route updated", Transition.getCurrentRoute(manager), About)

  switch Transition.getState(manager) {
  | Transition.Idle(r) => assertEq("completeTransition: idle with new route", r, About)
  | _ => Js.Console.error("[FAIL] completeTransition: should be Idle")
  }
}

let testCancelTransition = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, About, ~eq=routeEq)
  Transition.cancelTransition(manager)

  assertFalse("cancelTransition: not transitioning", Transition.isTransitioning(manager))
  assertEq("cancelTransition: route unchanged", Transition.getCurrentRoute(manager), Home)
}

let testNavigateTo = () => {
  let manager = Transition.make(Home)
  Transition.navigateTo(manager, Contact, ~eq=routeEq)

  assertFalse("navigateTo: not transitioning (instant)", Transition.isTransitioning(manager))
  assertEq("navigateTo: route updated", Transition.getCurrentRoute(manager), Contact)
}

// ============================================================
// Direction Tests
// ============================================================

let testDirectionForward = () => {
  let manager = Transition.make(Home)
  Transition.navigateTo(manager, About, ~eq=routeEq)
  Transition.startTransition(manager, Contact, ~eq=routeEq)

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("direction: forward for new route", direction, Transition.Forward)
  | _ => Js.Console.error("[FAIL] direction: should be Transitioning")
  }

  Transition.completeTransition(manager)
}

let testDirectionBackward = () => {
  let manager = Transition.make(Home)

  // Navigate forward
  Transition.navigateTo(manager, About, ~eq=routeEq)
  Transition.navigateTo(manager, Contact, ~eq=routeEq)

  // Now go back to About
  Transition.startTransition(manager, About, ~eq=routeEq)

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("direction: backward for previous route", direction, Transition.Backward)
  | _ => Js.Console.error("[FAIL] direction: should be Transitioning")
  }
}

let testExplicitDirection = () => {
  let manager = Transition.make(Home)
  Transition.startTransition(manager, About, ~direction=Transition.Replace, ~eq=routeEq)

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("explicit direction: uses provided direction", direction, Transition.Replace)
  | _ => Js.Console.error("[FAIL] explicit direction: should be Transitioning")
  }
}

// ============================================================
// Subscription Tests
// ============================================================

let testSubscribe = () => {
  let manager = Transition.make(Home)
  let events = ref([])

  let unsubscribe = Transition.subscribe(manager, event => {
    events := Belt.Array.concat(events.contents, [event])
  })

  Transition.startTransition(manager, About, ~eq=routeEq)
  Transition.updateProgress(manager, 0.5)
  Transition.completeTransition(manager)

  // Should have received: TransitionStart, TransitionProgress, TransitionEnd
  assertEq("subscribe: received 3 events", Belt.Array.length(events.contents), 3)

  // Test unsubscribe
  unsubscribe()
  Transition.navigateTo(manager, Contact, ~eq=routeEq)
  // Should not receive any more events
  assertEq("unsubscribe: no more events", Belt.Array.length(events.contents), 3)
}

let testSubscribeCancel = () => {
  let manager = Transition.make(Home)
  let cancelled = ref(false)

  let _ = Transition.subscribe(manager, event => {
    switch event {
    | Transition.TransitionCancel(_) => cancelled := true
    | _ => ()
    }
  })

  Transition.startTransition(manager, About, ~eq=routeEq)
  Transition.cancelTransition(manager)

  assertTrue("subscribe cancel: received cancel event", cancelled.contents)
}

// ============================================================
// Animation Easing Tests
// ============================================================

let testEasingLinear = () => {
  assertEq("easing linear 0", Transition.Animation.linear(0.0), 0.0)
  assertEq("easing linear 0.5", Transition.Animation.linear(0.5), 0.5)
  assertEq("easing linear 1", Transition.Animation.linear(1.0), 1.0)
}

let testEasingBounds = () => {
  // All easing functions should map 0 to 0 and 1 to 1
  let easings = [
    ("linear", Transition.Animation.linear),
    ("easeIn", Transition.Animation.easeIn),
    ("easeOut", Transition.Animation.easeOut),
    ("easeInOut", Transition.Animation.easeInOut),
  ]

  easings->Belt.Array.forEach(((name, fn)) => {
    let at0 = fn(0.0)
    let at1 = fn(1.0)
    // Use approximate equality for floating point
    if Js.Math.abs_float(at0) < 0.0001 {
      Js.Console.log(`[PASS] ${name} at 0`)
    } else {
      Js.Console.error(`[FAIL] ${name} at 0: got ${Belt.Float.toString(at0)}`)
    }
    if Js.Math.abs_float(at1 -. 1.0) < 0.0001 {
      Js.Console.log(`[PASS] ${name} at 1`)
    } else {
      Js.Console.error(`[FAIL] ${name} at 1: got ${Belt.Float.toString(at1)}`)
    }
  })
}

// ============================================================
// Run All Tests
// ============================================================

let runTests = () => {
  Js.Console.log("=== Transition Tests ===")

  // Manager
  testMakeManager()
  testGetState()

  // Transitions
  testStartTransition()
  testStartTransitionSameRoute()
  testUpdateProgress()
  testCompleteTransition()
  testCancelTransition()
  testNavigateTo()

  // Direction
  testDirectionForward()
  testDirectionBackward()
  testExplicitDirection()

  // Subscriptions
  testSubscribe()
  testSubscribeCancel()

  // Animation easing
  testEasingLinear()
  testEasingBounds()

  Js.Console.log("=== Transition Tests Complete ===")
}

// Auto-run tests
let _ = runTests()
