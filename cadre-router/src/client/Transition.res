// SPDX-License-Identifier: Apache-2.0
// Transition.res - Route transition hooks for animations

// Transition direction (useful for slide animations)
type direction =
  | Forward
  | Backward
  | Replace
  | Initial

// Transition state during navigation
type state<'route> =
  | Idle('route)
  | Transitioning({
      from: 'route,
      to: 'route,
      direction: direction,
      progress: float,
    })

// Transition event for callbacks
type event<'route> =
  | TransitionStart({from: 'route, to: 'route, direction: direction})
  | TransitionProgress({from: 'route, to: 'route, progress: float})
  | TransitionEnd({from: 'route, to: 'route})
  | TransitionCancel({from: 'route, to: 'route})

// Listener type
type listener<'route> = event<'route> => unit

// Unsubscribe function
type unsubscribe = unit => unit

// Transition manager
type t<'route> = {
  mutable currentRoute: 'route,
  mutable state: state<'route>,
  mutable listeners: array<listener<'route>>,
  mutable historyStack: array<'route>,
  mutable historyIndex: int,
}

// Create a transition manager
let make = (initialRoute: 'route): t<'route> => {
  {
    currentRoute: initialRoute,
    state: Idle(initialRoute),
    listeners: [],
    historyStack: [initialRoute],
    historyIndex: 0,
  }
}

// Notify all listeners
let notify = (manager: t<'route>, event: event<'route>): unit => {
  manager.listeners->Belt.Array.forEach(listener => listener(event))
}

// Subscribe to transition events
let subscribe = (manager: t<'route>, listener: listener<'route>): unsubscribe => {
  manager.listeners = Belt.Array.concat(manager.listeners, [listener])

  () => {
    manager.listeners =
      manager.listeners->Belt.Array.keep(l => l !== listener)
  }
}

// Determine direction based on history
let determineDirection = (manager: t<'route>, newRoute: 'route, ~eq: ('route, 'route) => bool): direction => {
  // Check if going back in history
  if manager.historyIndex > 0 {
    switch manager.historyStack[manager.historyIndex - 1] {
    | Some(prevRoute) if eq(prevRoute, newRoute) => Backward
    | _ => Forward
    }
  } else {
    Forward
  }
}

// Start a transition
let startTransition = (
  manager: t<'route>,
  newRoute: 'route,
  ~direction: option<direction>=?,
  ~eq: ('route, 'route) => bool
): unit => {
  let from = manager.currentRoute

  // Skip if same route
  if eq(from, newRoute) {
    ()
  } else {
    let dir = switch direction {
    | Some(d) => d
    | None => determineDirection(manager, newRoute, ~eq)
    }

    manager.state = Transitioning({
      from,
      to: newRoute,
      direction: dir,
      progress: 0.0,
    })

    notify(manager, TransitionStart({from, to: newRoute, direction: dir}))
  }
}

// Update transition progress (0.0 to 1.0)
let updateProgress = (manager: t<'route>, progress: float): unit => {
  switch manager.state {
  | Transitioning(t) =>
    manager.state = Transitioning({...t, progress})
    notify(manager, TransitionProgress({from: t.from, to: t.to, progress}))
  | Idle(_) => ()
  }
}

// Complete the transition
let completeTransition = (manager: t<'route>): unit => {
  switch manager.state {
  | Transitioning({from, to, direction}) =>
    manager.currentRoute = to
    manager.state = Idle(to)

    // Update history stack
    switch direction {
    | Forward =>
      // Truncate forward history and add new route
      manager.historyStack = Belt.Array.concat(
        Belt.Array.slice(manager.historyStack, ~offset=0, ~len=manager.historyIndex + 1),
        [to],
      )
      manager.historyIndex = manager.historyIndex + 1
    | Backward =>
      manager.historyIndex = max(0, manager.historyIndex - 1)
    | Replace =>
      let _ = Belt.Array.set(manager.historyStack, manager.historyIndex, to)
    | Initial => ()
    }

    notify(manager, TransitionEnd({from, to}))
  | Idle(_) => ()
  }
}

// Cancel the transition
let cancelTransition = (manager: t<'route>): unit => {
  switch manager.state {
  | Transitioning({from, to}) =>
    manager.state = Idle(from)
    notify(manager, TransitionCancel({from, to}))
  | Idle(_) => ()
  }
}

// Instant transition (no animation)
let navigateTo = (manager: t<'route>, route: 'route, ~eq: ('route, 'route) => bool): unit => {
  startTransition(manager, route, ~eq)
  completeTransition(manager)
}

// Check if currently transitioning
let isTransitioning = (manager: t<'route>): bool => {
  switch manager.state {
  | Transitioning(_) => true
  | Idle(_) => false
  }
}

// Get current route (the settled one, not the target)
let getCurrentRoute = (manager: t<'route>): 'route => {
  manager.currentRoute
}

// Get the current state
let getState = (manager: t<'route>): state<'route> => {
  manager.state
}

// Animation helpers
module Animation = {
  // Request animation frame binding
  @val external requestAnimationFrame: (float => unit) => int = "requestAnimationFrame"
  @val external cancelAnimationFrame: int => unit = "cancelAnimationFrame"

  // Easing functions
  let linear = (t: float): float => t

  let easeInOut = (t: float): float => {
    if t < 0.5 {
      2.0 *. t *. t
    } else {
      1.0 -. (-2.0 *. t +. 2.0) ** 2.0 /. 2.0
    }
  }

  let easeOut = (t: float): float => {
    1.0 -. (1.0 -. t) ** 2.0
  }

  let easeIn = (t: float): float => {
    t *. t
  }

  // Animate a transition over duration
  let animate = (
    manager: t<'route>,
    newRoute: 'route,
    ~duration: float,
    ~easing: float => float=easeInOut,
    ~eq: ('route, 'route) => bool,
    ~onComplete: option<unit => unit>=?
  ): unsubscribe => {
    startTransition(manager, newRoute, ~eq)

    let startTime = ref(None)
    let frameId = ref(None)

    let rec loop = (timestamp: float): unit => {
      let start = switch startTime.contents {
      | Some(s) => s
      | None =>
        startTime := Some(timestamp)
        timestamp
      }

      let elapsed = timestamp -. start
      let rawProgress = Js.Math.min_float(1.0, elapsed /. duration)
      let easedProgress = easing(rawProgress)

      updateProgress(manager, easedProgress)

      if rawProgress < 1.0 {
        frameId := Some(requestAnimationFrame(loop))
      } else {
        completeTransition(manager)
        switch onComplete {
        | Some(cb) => cb()
        | None => ()
        }
      }
    }

    frameId := Some(requestAnimationFrame(loop))

    // Return cancel function
    () => {
      switch frameId.contents {
      | Some(id) =>
        cancelAnimationFrame(id)
        cancelTransition(manager)
      | None => ()
      }
    }
  }
}

// React hook integration
module React = {
  // Hook to use transition state in a component
  let useTransition = (manager: t<'route>): state<'route> => {
    let (state, setState) = React.useState(() => getState(manager))

    React.useEffect1(() => {
      let unsubscribe = subscribe(manager, event => {
        switch event {
        | TransitionStart(_)
        | TransitionProgress(_) =>
          setState(_ => getState(manager))
        | TransitionEnd(_)
        | TransitionCancel(_) =>
          setState(_ => getState(manager))
        }
      })
      Some(unsubscribe)
    }, [manager])

    state
  }

  // Hook to get transition progress (0.0 when idle, 0.0-1.0 during transition)
  let useProgress = (manager: t<'route>): float => {
    let state = useTransition(manager)
    switch state {
    | Idle(_) => 0.0
    | Transitioning({progress}) => progress
    }
  }

  // Hook to get transition direction
  let useDirection = (manager: t<'route>): option<direction> => {
    let state = useTransition(manager)
    switch state {
    | Idle(_) => None
    | Transitioning({direction}) => Some(direction)
    }
  }
}

// Integration with Navigation module
module WithNavigation = {
  // Create a transition-aware navigation wrapper
  let make = (
    manager: t<'route>,
    ~parse: Url.t => option<'route>,
    ~toString: 'route => string,
    ~eq: ('route, 'route) => bool,
    ~animationDuration: float=300.0
  ): {
    "push": 'route => unit,
    "replace": 'route => unit,
    "back": unit => unit,
    "forward": unit => unit,
    "subscribe": unit => unsubscribe,
  } => {
    let push = (route: 'route): unit => {
      let _ = Animation.animate(
        manager,
        route,
        ~duration=animationDuration,
        ~eq,
        ~onComplete=() => {
          Navigation.pushUrl(toString(route))
        },
      )
    }

    let replace = (route: 'route): unit => {
      startTransition(manager, route, ~direction=Replace, ~eq)
      completeTransition(manager)
      Navigation.replaceUrl(toString(route))
    }

    let back = (): unit => {
      Navigation.back()
    }

    let forward = (): unit => {
      Navigation.forward()
    }

    let subscribeToNav = (): unsubscribe => {
      Navigation.onUrlChange(url => {
        switch parse(url) {
        | Some(route) =>
          let _ = Animation.animate(manager, route, ~duration=animationDuration, ~eq)
        | None => ()
        }
      })
    }

    {
      "push": push,
      "replace": replace,
      "back": back,
      "forward": forward,
      "subscribe": subscribeToNav,
    }
  }
}
