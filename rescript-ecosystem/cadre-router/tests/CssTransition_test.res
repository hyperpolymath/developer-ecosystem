// SPDX-License-Identifier: PMPL-1.0-or-later
// CssTransition_test.res - Tests for CSS transition delegation
//
// Tests the CssTransition module which offloads animation to the browser's
// CSS engine. Because CssTransition interacts with DOM elements (classList,
// addEventListener, removeEventListener), we use lightweight mock elements
// to verify class application/removal and event listener wiring without
// requiring a full browser environment.

// =============================================================================
// Test Harness
// =============================================================================

let passed = ref(0)
let failed = ref(0)

let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, actual: bool): unit => {
  if actual {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected true`)
  }
}

let assertFalse = (name: string, actual: bool): unit => {
  if !actual {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected false`)
  }
}

let assertSome = (name: string, actual: option<'a>): unit => {
  switch actual {
  | Some(_) =>
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  | None =>
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected Some, got None`)
  }
}

let summary = () => {
  let total = passed.contents + failed.contents
  Js.Console.log("")
  Js.Console.log(`=== Summary: ${Belt.Int.toString(passed.contents)}/${Belt.Int.toString(total)} passed ===`)
  if failed.contents > 0 {
    Js.Console.error(`${Belt.Int.toString(failed.contents)} tests failed`)
  }
}

// =============================================================================
// Test Route Types
// =============================================================================

type route =
  | Home
  | About
  | Contact
  | Products
  | NotFound

let routeEq = (a: route, b: route): bool => a == b

// =============================================================================
// Mock DOM Element
// =============================================================================
//
// A lightweight mock that tracks:
//   - classNames: which CSS classes are currently applied
//   - eventListeners: which event handlers are registered (by event name)
//   - classLog: ordered history of add/remove operations
//
// This avoids any real browser dependency while giving us full observability
// into what CssTransition does to the DOM element.

// Type for class operation log entries, tracking the sequence of adds/removes
type classOp =
  | Added(string)
  | Removed(string)

// Create a mock DOM element that records classList operations and event
// listeners. Returns a tuple of (mockElement cast to Dom.element, accessor
// object for inspecting state in assertions).
let makeMockElement: unit => (Dom.element, {
  "getClasses": unit => array<string>,
  "getClassLog": unit => array<classOp>,
  "getListenerCount": string => int,
  "fireEvent": string => unit,
  "hasClass": string => bool,
}) = %raw(`
  function() {
    var classes = {};
    var classLog = [];
    var listeners = {};

    var classList = {
      add: function(className) {
        classes[className] = true;
        classLog.push({ TAG: 0, _0: className });
      },
      remove: function(className) {
        delete classes[className];
        classLog.push({ TAG: 1, _0: className });
      },
      contains: function(className) {
        return !!classes[className];
      }
    };

    var element = {
      classList: classList,
      addEventListener: function(eventName, handler) {
        if (!listeners[eventName]) listeners[eventName] = [];
        listeners[eventName].push(handler);
      },
      removeEventListener: function(eventName, handler) {
        if (listeners[eventName]) {
          listeners[eventName] = listeners[eventName].filter(function(h) {
            return h !== handler;
          });
        }
      }
    };

    var accessors = {
      getClasses: function() {
        return Object.keys(classes);
      },
      getClassLog: function() {
        return classLog.slice();
      },
      getListenerCount: function(eventName) {
        return (listeners[eventName] || []).length;
      },
      fireEvent: function(eventName) {
        var handlers = (listeners[eventName] || []).slice();
        handlers.forEach(function(h) { h({}); });
      },
      hasClass: function(className) {
        return !!classes[className];
      }
    };

    return [element, accessors];
  }
`)

// =============================================================================
// SECTION 1: addClass / removeClass Helper Tests
// =============================================================================

let testAddClass = () => {
  Js.Console.log("\n--- addClass / removeClass ---")

  let (el, mock) = makeMockElement()

  Transition.CssTransition.addClass(el, "fade-in")
  assertTrue("addClass: class is present", mock["hasClass"]("fade-in"))
  assertEq("addClass: classes list", mock["getClasses"](), ["fade-in"])
}

let testRemoveClass = () => {
  let (el, mock) = makeMockElement()

  Transition.CssTransition.addClass(el, "fade-in")
  Transition.CssTransition.removeClass(el, "fade-in")
  assertFalse("removeClass: class is removed", mock["hasClass"]("fade-in"))
  assertEq("removeClass: classes empty", mock["getClasses"](), [])
}

let testAddMultipleClasses = () => {
  let (el, mock) = makeMockElement()

  Transition.CssTransition.addClass(el, "route-exit")
  Transition.CssTransition.addClass(el, "active")

  assertTrue("addMultiple: has route-exit", mock["hasClass"]("route-exit"))
  assertTrue("addMultiple: has active", mock["hasClass"]("active"))
  assertEq("addMultiple: two classes", Belt.Array.length(mock["getClasses"]()), 2)
}

let testRemoveNonexistentClass = () => {
  let (el, mock) = makeMockElement()

  // Removing a class that was never added should not throw
  Transition.CssTransition.removeClass(el, "never-existed")
  assertEq("removeNonexistent: no classes", mock["getClasses"](), [])
}

let testClassLogOrdering = () => {
  let (el, mock) = makeMockElement()

  Transition.CssTransition.addClass(el, "route-exit")
  Transition.CssTransition.addClass(el, "active")
  Transition.CssTransition.removeClass(el, "route-exit")
  Transition.CssTransition.removeClass(el, "active")

  let log = mock["getClassLog"]()
  assertEq("classLog: length", Belt.Array.length(log), 4)
  assertEq("classLog: first is add exit", log[0], Some(Added("route-exit")))
  assertEq("classLog: second is add active", log[1], Some(Added("active")))
  assertEq("classLog: third is remove exit", log[2], Some(Removed("route-exit")))
  assertEq("classLog: fourth is remove active", log[3], Some(Removed("active")))
}

// =============================================================================
// SECTION 2: CssTransition.animate — Exit Phase
// =============================================================================
//
// CssTransition.animate proceeds in two phases:
//   Phase 1 (Exit): Adds exitClass + activeClass, listens for transitionend
//   Phase 2 (Enter): On transitionend, removes exit classes, adds enterClass
//                     + activeClass, listens for another transitionend
//
// These tests verify Phase 1 behaviour before any transitionend fires.

let testAnimateStartsTransition = () => {
  Js.Console.log("\n--- CssTransition.animate: exit phase ---")

  let manager = Transition.make(Home)
  let (el, _mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // The manager should now be in Transitioning state
  assertTrue("animate: starts transition", Transition.isTransitioning(manager))

  switch Transition.getState(manager) {
  | Transition.Transitioning({from, to}) =>
    assertEq("animate: from Home", from, Home)
    assertEq("animate: to About", to, About)
  | _ => Js.Console.error("[FAIL] animate: should be Transitioning")
  }
}

let testAnimateAppliesExitClasses = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // Default exitClass is "route-exit", default activeClass is "active"
  assertTrue("animate exit: has route-exit class", mock["hasClass"]("route-exit"))
  assertTrue("animate exit: has active class", mock["hasClass"]("active"))
}

let testAnimateCustomClassNames = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="fade-out",
    ~enterClass="fade-in",
    ~activeClass="running",
    ~eq=routeEq,
  )

  assertTrue("animate custom: has fade-out", mock["hasClass"]("fade-out"))
  assertTrue("animate custom: has running", mock["hasClass"]("running"))
  assertFalse("animate custom: no route-exit (default)", mock["hasClass"]("route-exit"))
  assertFalse("animate custom: no active (default)", mock["hasClass"]("active"))
}

let testAnimateRegistersTransitionendListener = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // Should have registered exactly one transitionend listener for exit phase
  assertEq(
    "animate exit: transitionend listener registered",
    mock["getListenerCount"]("transitionend"),
    1,
  )
}

let testAnimateSameRouteNoOp = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    Home,
    ~element=el,
    ~eq=routeEq,
  )

  // When target route equals current route, startTransition is a no-op,
  // but CssTransition.animate still adds exit classes (it does not check
  // for same-route before applying classes). The manager state stays Idle.
  assertFalse("animate same route: not transitioning", Transition.isTransitioning(manager))
}

// =============================================================================
// SECTION 3: CssTransition.animate — Enter Phase (transitionend fired)
// =============================================================================

let testExitTransitionendTriggersEnterPhase = () => {
  Js.Console.log("\n--- CssTransition.animate: enter phase ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="route-exit",
    ~enterClass="route-enter",
    ~activeClass="active",
    ~eq=routeEq,
  )

  // Simulate the browser firing transitionend after exit animation completes
  mock["fireEvent"]("transitionend")

  // After exit transitionend:
  //   - exitClass and activeClass should be removed (from exit phase cleanup)
  //   - enterClass and activeClass should be added (enter phase begins)
  assertFalse("enter phase: route-exit removed", mock["hasClass"]("route-exit"))
  assertTrue("enter phase: route-enter added", mock["hasClass"]("route-enter"))
  assertTrue("enter phase: active re-added", mock["hasClass"]("active"))

  // Manager should STILL be transitioning (not yet complete)
  assertTrue("enter phase: still transitioning", Transition.isTransitioning(manager))
}

let testEnterTransitionendCompletesTransition = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="route-exit",
    ~enterClass="route-enter",
    ~activeClass="active",
    ~eq=routeEq,
  )

  // Phase 1: Fire exit transitionend
  mock["fireEvent"]("transitionend")

  // Phase 2: Fire enter transitionend
  mock["fireEvent"]("transitionend")

  // After both phases:
  //   - All animation classes should be removed
  //   - Transition should be complete
  //   - Current route should be updated
  assertFalse("complete: route-exit removed", mock["hasClass"]("route-exit"))
  assertFalse("complete: route-enter removed", mock["hasClass"]("route-enter"))
  assertFalse("complete: active removed", mock["hasClass"]("active"))

  assertFalse("complete: not transitioning", Transition.isTransitioning(manager))
  assertEq("complete: route updated to About", Transition.getCurrentRoute(manager), About)
}

let testOnCompleteCallbackFires = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()
  let completeCalled = ref(false)

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
    ~onComplete=() => {
      completeCalled := true
    },
  )

  // Fire both transitionend events
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertTrue("onComplete: callback fired", completeCalled.contents)
}

let testOnCompleteNotFiredDuringExitPhase = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()
  let completeCalled = ref(false)

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
    ~onComplete=() => {
      completeCalled := true
    },
  )

  // Fire only exit transitionend
  mock["fireEvent"]("transitionend")

  assertFalse("onComplete: not fired during exit phase", completeCalled.contents)
}

// =============================================================================
// SECTION 4: CssTransition.animate — Class Log Sequence Verification
// =============================================================================
//
// Verify the exact sequence of class operations through a full animation.

let testFullAnimationClassSequence = () => {
  Js.Console.log("\n--- CssTransition.animate: class log sequence ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="route-exit",
    ~enterClass="route-enter",
    ~activeClass="active",
    ~eq=routeEq,
  )

  // After animate() call (before any transitionend):
  // Expected: +route-exit, +active
  let logBeforeExit = mock["getClassLog"]()
  assertEq("sequence: initial log length", Belt.Array.length(logBeforeExit), 2)
  assertEq("sequence: 1st op is add route-exit", logBeforeExit[0], Some(Added("route-exit")))
  assertEq("sequence: 2nd op is add active", logBeforeExit[1], Some(Added("active")))

  // Fire exit transitionend
  mock["fireEvent"]("transitionend")

  // After exit transitionend:
  // Expected additions: -route-exit, -active, +route-enter, +active
  let logAfterExit = mock["getClassLog"]()
  assertEq("sequence: after exit log length", Belt.Array.length(logAfterExit), 6)
  assertEq("sequence: 3rd op is remove route-exit", logAfterExit[2], Some(Removed("route-exit")))
  assertEq("sequence: 4th op is remove active", logAfterExit[3], Some(Removed("active")))
  assertEq("sequence: 5th op is add route-enter", logAfterExit[4], Some(Added("route-enter")))
  assertEq("sequence: 6th op is add active", logAfterExit[5], Some(Added("active")))

  // Fire enter transitionend
  mock["fireEvent"]("transitionend")

  // After enter transitionend:
  // Expected additions: -route-enter, -active
  let logFinal = mock["getClassLog"]()
  assertEq("sequence: final log length", Belt.Array.length(logFinal), 8)
  assertEq("sequence: 7th op is remove route-enter", logFinal[6], Some(Removed("route-enter")))
  assertEq("sequence: 8th op is remove active", logFinal[7], Some(Removed("active")))
}

// =============================================================================
// SECTION 5: CssTransition.animate — Cancel Function
// =============================================================================

let testCancelBeforeExitTransitionend = () => {
  Js.Console.log("\n--- CssTransition.animate: cancellation ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="route-exit",
    ~enterClass="route-enter",
    ~activeClass="active",
    ~eq=routeEq,
  )

  // Cancel before exit transitionend fires
  cancel()

  // After cancel:
  //   - All classes should be removed
  //   - Transition should be cancelled (back to Idle)
  //   - Route should be unchanged
  assertFalse("cancel: route-exit removed", mock["hasClass"]("route-exit"))
  assertFalse("cancel: route-enter removed", mock["hasClass"]("route-enter"))
  assertFalse("cancel: active removed", mock["hasClass"]("active"))
  assertFalse("cancel: not transitioning", Transition.isTransitioning(manager))
  assertEq("cancel: route unchanged", Transition.getCurrentRoute(manager), Home)
}

let testCancelRemovesTransitionendListener = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // Before cancel, there should be a transitionend listener
  assertEq("cancel listener: before cancel", mock["getListenerCount"]("transitionend"), 1)

  cancel()

  // After cancel, the exit handler should be removed
  assertEq("cancel listener: after cancel", mock["getListenerCount"]("transitionend"), 0)
}

let testCancelPreventsFurtherExecution = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()
  let completeCalled = ref(false)

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
    ~onComplete=() => {
      completeCalled := true
    },
  )

  cancel()

  // Even if transitionend somehow fires after cancel, it should be a no-op
  // because the cancelled flag is set. The listener was removed, but test
  // the flag mechanism by simulating the event anyway.
  mock["fireEvent"]("transitionend")

  assertFalse("cancel prevents: onComplete not called", completeCalled.contents)
  assertFalse("cancel prevents: still not transitioning", Transition.isTransitioning(manager))
  assertEq("cancel prevents: route still Home", Transition.getCurrentRoute(manager), Home)
}

// =============================================================================
// SECTION 6: CssTransition.animate — Subscription Event Verification
// =============================================================================

let testAnimateEmitsTransitionStartEvent = () => {
  Js.Console.log("\n--- CssTransition.animate: subscription events ---")

  let manager = Transition.make(Home)
  let (el, _mock) = makeMockElement()
  let startReceived = ref(false)

  let _ = Transition.subscribe(manager, event => {
    switch event {
    | Transition.TransitionStart({from, to}) =>
      if from == Home && to == About {
        startReceived := true
      }
    | _ => ()
    }
  })

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  assertTrue("events: TransitionStart emitted", startReceived.contents)
}

let testAnimateEmitsTransitionEndEvent = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()
  let endReceived = ref(false)

  let _ = Transition.subscribe(manager, event => {
    switch event {
    | Transition.TransitionEnd({from, to}) =>
      if from == Home && to == About {
        endReceived := true
      }
    | _ => ()
    }
  })

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // Fire exit + enter transitionend
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertTrue("events: TransitionEnd emitted", endReceived.contents)
}

let testCancelEmitsTransitionCancelEvent = () => {
  let manager = Transition.make(Home)
  let (el, _mock) = makeMockElement()
  let cancelReceived = ref(false)

  let _ = Transition.subscribe(manager, event => {
    switch event {
    | Transition.TransitionCancel({from, to}) =>
      if from == Home && to == About {
        cancelReceived := true
      }
    | _ => ()
    }
  })

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  cancel()

  assertTrue("events: TransitionCancel emitted", cancelReceived.contents)
}

// =============================================================================
// SECTION 7: CssTransition.animate — Direction Integration
// =============================================================================

let testAnimatePreservesDirection = () => {
  Js.Console.log("\n--- CssTransition.animate: direction integration ---")

  let manager = Transition.make(Home)
  Transition.navigateTo(manager, About, ~eq=routeEq)
  Transition.navigateTo(manager, Contact, ~eq=routeEq)

  let (el, _mock) = makeMockElement()

  // Navigate back to About — should detect Backward direction
  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("direction: backward detected", direction, Transition.Backward)
  | _ => Js.Console.error("[FAIL] direction: should be Transitioning")
  }
}

let testAnimateForwardDirection = () => {
  let manager = Transition.make(Home)
  let (el, _mock) = makeMockElement()

  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("direction: forward for new route", direction, Transition.Forward)
  | _ => Js.Console.error("[FAIL] direction: should be Transitioning")
  }
}

// =============================================================================
// SECTION 8: CssTransition.animate — Multiple Sequential Transitions
// =============================================================================

let testSequentialTransitions = () => {
  Js.Console.log("\n--- CssTransition.animate: sequential transitions ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  // First transition: Home -> About
  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertEq("sequential 1: route is About", Transition.getCurrentRoute(manager), About)

  // Second transition: About -> Contact
  let _ = Transition.CssTransition.animate(
    manager,
    Contact,
    ~element=el,
    ~eq=routeEq,
  )

  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertEq("sequential 2: route is Contact", Transition.getCurrentRoute(manager), Contact)
  assertFalse("sequential 2: not transitioning", Transition.isTransitioning(manager))
}

let testCancelThenNewTransition = () => {
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  // Start and cancel first transition
  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )
  cancel()

  assertEq("cancel+new: route still Home", Transition.getCurrentRoute(manager), Home)

  // Start new transition to Contact
  let _ = Transition.CssTransition.animate(
    manager,
    Contact,
    ~element=el,
    ~eq=routeEq,
  )

  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertEq("cancel+new: route is Contact", Transition.getCurrentRoute(manager), Contact)
}

// =============================================================================
// SECTION 9: CssTransition.animate — History Stack Integration
// =============================================================================

let testAnimateUpdatesHistoryStack = () => {
  Js.Console.log("\n--- CssTransition.animate: history integration ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  // Animate Home -> About (completes)
  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  // Animate About -> Contact (completes)
  let _ = Transition.CssTransition.animate(
    manager,
    Contact,
    ~element=el,
    ~eq=routeEq,
  )
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  // Now animate back to About — should be detected as Backward
  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  switch Transition.getState(manager) {
  | Transition.Transitioning({direction}) =>
    assertEq("history: backward direction detected", direction, Transition.Backward)
  | _ => Js.Console.error("[FAIL] history: should be Transitioning")
  }
}

// =============================================================================
// SECTION 10: Edge Cases
// =============================================================================

let testAnimateWithEmptyClassNames = () => {
  Js.Console.log("\n--- CssTransition.animate: edge cases ---")

  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  // Empty class names should still work (just add/remove empty strings)
  let _ = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~exitClass="",
    ~enterClass="",
    ~activeClass="",
    ~eq=routeEq,
  )

  // Should not throw, transition should start
  assertTrue("empty classes: is transitioning", Transition.isTransitioning(manager))

  // Complete the transition
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertFalse("empty classes: completes", Transition.isTransitioning(manager))
  assertEq("empty classes: route updated", Transition.getCurrentRoute(manager), About)
}

let testDoubleCancelIsIdempotent = () => {
  let manager = Transition.make(Home)
  let (el, _mock) = makeMockElement()

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  // Cancel twice should not throw or cause any inconsistency
  cancel()
  cancel()

  assertFalse("double cancel: not transitioning", Transition.isTransitioning(manager))
  assertEq("double cancel: route unchanged", Transition.getCurrentRoute(manager), Home)
}

let testManagerStateAfterCancelledExitEvent = () => {
  // Tests the cancelled flag: after cancel(), if transitionend fires,
  // the handler should be a no-op.
  let manager = Transition.make(Home)
  let (el, mock) = makeMockElement()

  let cancel = Transition.CssTransition.animate(
    manager,
    About,
    ~element=el,
    ~eq=routeEq,
  )

  cancel()

  // Manually fire events (even though listener was removed, test robustness)
  mock["fireEvent"]("transitionend")
  mock["fireEvent"]("transitionend")

  assertEq("post-cancel events: route stays Home", Transition.getCurrentRoute(manager), Home)

  switch Transition.getState(manager) {
  | Transition.Idle(r) => assertEq("post-cancel events: idle at Home", r, Home)
  | _ => Js.Console.error("[FAIL] post-cancel events: should be Idle")
  }
}

// =============================================================================
// Run All Tests
// =============================================================================

let runAll = () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  CSS TRANSITION TESTS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // Section 1: addClass / removeClass
  testAddClass()
  testRemoveClass()
  testAddMultipleClasses()
  testRemoveNonexistentClass()
  testClassLogOrdering()

  // Section 2: Exit phase
  testAnimateStartsTransition()
  testAnimateAppliesExitClasses()
  testAnimateCustomClassNames()
  testAnimateRegistersTransitionendListener()
  testAnimateSameRouteNoOp()

  // Section 3: Enter phase
  testExitTransitionendTriggersEnterPhase()
  testEnterTransitionendCompletesTransition()
  testOnCompleteCallbackFires()
  testOnCompleteNotFiredDuringExitPhase()

  // Section 4: Class log sequence
  testFullAnimationClassSequence()

  // Section 5: Cancellation
  testCancelBeforeExitTransitionend()
  testCancelRemovesTransitionendListener()
  testCancelPreventsFurtherExecution()

  // Section 6: Subscription events
  testAnimateEmitsTransitionStartEvent()
  testAnimateEmitsTransitionEndEvent()
  testCancelEmitsTransitionCancelEvent()

  // Section 7: Direction
  testAnimatePreservesDirection()
  testAnimateForwardDirection()

  // Section 8: Sequential transitions
  testSequentialTransitions()
  testCancelThenNewTransition()

  // Section 9: History integration
  testAnimateUpdatesHistoryStack()

  // Section 10: Edge cases
  testAnimateWithEmptyClassNames()
  testDoubleCancelIsIdempotent()
  testManagerStateAfterCancelledExitEvent()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  CSS TRANSITION TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run tests
let _ = runAll()
