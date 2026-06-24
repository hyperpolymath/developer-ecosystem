// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
The TEA application runtime. Creates React components from app specifications.
Handles the update loop, command execution, and subscription management.
")

// ============================================================================
// Application specification types
// ============================================================================

@ocaml.doc("Full application specification with flags")
type app<'flags, 'model, 'msg> = {
  init: 'flags => ('model, Tea_Cmd.t<'msg>),
  update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  view: 'model => React.element,
  subscriptions: 'model => Tea_Sub.t<'msg>,
}

@ocaml.doc("Simple application specification without flags")
type simpleApp<'model, 'msg> = {
  init: unit => ('model, Tea_Cmd.t<'msg>),
  update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  view: 'model => React.element,
  subscriptions: 'model => Tea_Sub.t<'msg>,
}

// ============================================================================
// Internal: Subscription diffing and management
// ============================================================================

module SubManager = {
  type cleanup = unit => unit
  type cleanups = dict<cleanup>

  let diff = (
    oldSubs: Tea_Sub.t<'msg>,
    newSubs: Tea_Sub.t<'msg>,
    dispatch: 'msg => unit,
    cleanups: cleanups,
  ): unit => {
    let oldInternals = Tea_Sub.toInternals(oldSubs)
    let newInternals = Tea_Sub.toInternals(newSubs)

    // Create sets of keys for comparison
    let oldKeys = Belt.Array.map(oldInternals, s => s.key)
    let newKeys = Belt.Array.map(newInternals, s => s.key)

    let oldKeySet = Belt.Set.String.fromArray(oldKeys)
    let newKeySet = Belt.Set.String.fromArray(newKeys)

    // Remove subscriptions that are no longer present
    Belt.Set.String.forEach(oldKeySet, key => {
      if !Belt.Set.String.has(newKeySet, key) {
        switch Dict.get(cleanups, key) {
        | Some(cleanup) =>
          cleanup()
          // Remove from dict using raw JS delete
          %raw(`delete cleanups[key]`)
        | None => ()
        }
      }
    })

    // Add new subscriptions
    Belt.Array.forEach(newInternals, internal => {
      if !Belt.Set.String.has(oldKeySet, internal.key) {
        switch internal.setup(dispatch) {
        | Some(cleanup) => Dict.set(cleanups, internal.key, cleanup)
        | None => ()
        }
      }
    })
  }

  let cleanupAll = (cleanups: cleanups): unit => {
    let keys = Dict.keysToArray(cleanups)
    Belt.Array.forEach(keys, key => {
      switch Dict.get(cleanups, key) {
      | Some(cleanup) => cleanup()
      | None => ()
      }
    })
  }
}

// ============================================================================
// Make functor - creates a React component from an app specification
// ============================================================================

module Make = (
  Config: {
    type model
    type msg
    type flags
    let app: app<flags, model, msg>
  },
) => {
  @react.component
  let make = (~flags: Config.flags) => {
    // Initialize
    let (initialModel, initialCmd) = Config.app.init(flags)

    // State
    let (model, setModel) = React.useState(() => initialModel)

    // Refs to avoid stale closures
    let modelRef = React.useRef(model)
    let subsRef = React.useRef(Tea_Sub.none)
    let cleanupsRef = React.useRef(Dict.make())
    let dispatchRef = React.useRef((_: Config.msg) => ())

    // Keep model ref in sync
    React.useEffect1(() => {
      modelRef.current = model
      None
    }, [model])

    // Dispatch function
    let dispatch = React.useCallback0((msg: Config.msg) => {
      let currentModel = modelRef.current
      let (newModel, cmd) = Config.app.update(msg, currentModel)
      setModel(_ => newModel)
      Tea_Cmd.execute(cmd, dispatchRef.current)
    })

    // Store dispatch in ref for subscription callbacks
    React.useEffect0(() => {
      dispatchRef.current = dispatch
      None
    })

    // Initial command
    React.useEffect0(() => {
      Tea_Cmd.execute(initialCmd, dispatch)
      None
    })

    // Subscription management
    React.useEffect1(() => {
      let oldSubs = subsRef.current
      let newSubs = Config.app.subscriptions(model)
      SubManager.diff(oldSubs, newSubs, dispatch, cleanupsRef.current)
      subsRef.current = newSubs
      None
    }, [model])

    // Cleanup on unmount
    React.useEffect0(() => {
      Some(() => SubManager.cleanupAll(cleanupsRef.current))
    })

    // Render
    Config.app.view(model)
  }
}

// ============================================================================
// MakeSimple functor - for apps without flags
// ============================================================================

module MakeSimple = (
  Config: {
    type model
    type msg
    let app: simpleApp<model, msg>
  },
) => {
  module Internal = Make({
    type model = Config.model
    type msg = Config.msg
    type flags = unit
    let app: app<unit, Config.model, Config.msg> = {
      init: () => Config.app.init(),
      update: Config.app.update,
      view: Config.app.view,
      subscriptions: Config.app.subscriptions,
    }
  })

  @react.component
  let make = () => Internal.make(~flags=())
}

// ============================================================================
// MakeWithDispatch functor - view receives dispatch function
// ============================================================================

module MakeWithDispatch = (
  Config: {
    type model
    type msg
    type flags
    let init: flags => (model, Tea_Cmd.t<msg>)
    let update: (msg, model) => (model, Tea_Cmd.t<msg>)
    let view: (model, msg => unit) => React.element
    let subscriptions: model => Tea_Sub.t<msg>
  },
) => {
  @react.component
  let make = (~flags: Config.flags) => {
    // Initialize
    let (initialModel, initialCmd) = Config.init(flags)

    // State
    let (model, setModel) = React.useState(() => initialModel)

    // Refs
    let modelRef = React.useRef(model)
    let subsRef = React.useRef(Tea_Sub.none)
    let cleanupsRef = React.useRef(Dict.make())
    let dispatchRef = React.useRef((_: Config.msg) => ())

    // Keep model ref in sync
    React.useEffect1(() => {
      modelRef.current = model
      None
    }, [model])

    // Dispatch
    let dispatch = React.useCallback0((msg: Config.msg) => {
      let currentModel = modelRef.current
      let (newModel, cmd) = Config.update(msg, currentModel)
      setModel(_ => newModel)
      Tea_Cmd.execute(cmd, dispatchRef.current)
    })

    // Store dispatch in ref
    React.useEffect0(() => {
      dispatchRef.current = dispatch
      None
    })

    // Initial command
    React.useEffect0(() => {
      Tea_Cmd.execute(initialCmd, dispatch)
      None
    })

    // Subscriptions
    React.useEffect1(() => {
      let oldSubs = subsRef.current
      let newSubs = Config.subscriptions(model)
      SubManager.diff(oldSubs, newSubs, dispatch, cleanupsRef.current)
      subsRef.current = newSubs
      None
    }, [model])

    // Cleanup
    React.useEffect0(() => {
      Some(() => SubManager.cleanupAll(cleanupsRef.current))
    })

    // Render
    Config.view(model, dispatch)
  }
}
