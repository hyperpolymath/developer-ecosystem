// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@ocaml.doc("
Route guards for preventing navigation during critical operations.
Use to block navigation when WASM data sync is in progress.
")

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("Result of a guard check")
type guardResult =
  | Allow
  | Block(string)  // Block with reason
  | Redirect(string)  // Redirect to different path

@ocaml.doc("Guard function signature")
type guard = CadreTeaRouter_Url.t => guardResult

@ocaml.doc("Async guard for operations that need to check external state")
type asyncGuard = CadreTeaRouter_Url.t => promise<guardResult>

@ocaml.doc("Guard configuration")
type guardConfig = {
  guards: array<guard>,
  asyncGuards: array<asyncGuard>,
  onBlock: option<string => unit>,
  onRedirect: option<string => unit>,
}

// ============================================================================
// Global State (for sync-in-progress blocking)
// ============================================================================

@ocaml.doc("Internal state for tracking blocking conditions")
type blockingState = {
  mutable isSyncing: bool,
  mutable syncReason: option<string>,
  mutable customBlockers: Js.Dict.t<string>,
}

let globalState: blockingState = {
  isSyncing: false,
  syncReason: None,
  customBlockers: Js.Dict.empty(),
}

// ============================================================================
// Sync State Management
// ============================================================================

@ocaml.doc("Mark that a WASM sync operation has started")
let startSync = (~reason: string="Data synchronization in progress"): unit => {
  globalState.isSyncing = true
  globalState.syncReason = Some(reason)
}

@ocaml.doc("Mark that a WASM sync operation has completed")
let endSync = (): unit => {
  globalState.isSyncing = false
  globalState.syncReason = None
}

@ocaml.doc("Check if sync is currently in progress")
let isSyncing = (): bool => {
  globalState.isSyncing
}

@ocaml.doc("Get the current sync reason if syncing")
let getSyncReason = (): option<string> => {
  if globalState.isSyncing {
    globalState.syncReason
  } else {
    None
  }
}

// ============================================================================
// Custom Blockers
// ============================================================================

@ocaml.doc("Add a custom navigation blocker")
let addBlocker = (id: string, reason: string): unit => {
  Js.Dict.set(globalState.customBlockers, id, reason)
}

@ocaml.doc("Remove a custom navigation blocker")
let removeBlocker = (id: string): unit => {
  // Create new dict without the key
  let entries = Js.Dict.entries(globalState.customBlockers)
  globalState.customBlockers = Js.Dict.fromArray(
    entries->Array.filter(((k, _)) => k != id)
  )
}

@ocaml.doc("Check if any custom blockers are active")
let hasBlockers = (): bool => {
  Array.length(Js.Dict.keys(globalState.customBlockers)) > 0
}

@ocaml.doc("Get all active blocker reasons")
let getBlockerReasons = (): array<string> => {
  Js.Dict.values(globalState.customBlockers)
}

// ============================================================================
// Built-in Guards
// ============================================================================

@ocaml.doc("Guard that blocks during WASM sync")
let syncGuard: guard = _url => {
  if globalState.isSyncing {
    Block(globalState.syncReason->Option.getOr("Operation in progress"))
  } else {
    Allow
  }
}

@ocaml.doc("Guard that blocks if any custom blockers are active")
let blockerGuard: guard = _url => {
  if hasBlockers() {
    let reasons = getBlockerReasons()->Array.join(", ")
    Block(reasons)
  } else {
    Allow
  }
}

@ocaml.doc("Guard that requires a specific query param to be present")
let requireParam = (paramName: string): guard => url => {
  let params = CadreTeaRouter_QueryParams.parse(url.query->Option.getOr(""))
  if CadreTeaRouter_QueryParams.has(params, paramName) {
    Allow
  } else {
    Block(`Missing required parameter: ${paramName}`)
  }
}

@ocaml.doc("Guard that blocks certain paths")
let blockPaths = (paths: array<string>): guard => url => {
  if paths->Array.includes(url.path) {
    Block(`Path ${url.path} is blocked`)
  } else {
    Allow
  }
}

@ocaml.doc("Guard that only allows certain paths")
let allowPaths = (paths: array<string>): guard => url => {
  if paths->Array.includes(url.path) {
    Allow
  } else {
    Block(`Path ${url.path} is not allowed`)
  }
}

@ocaml.doc("Guard that redirects from one path to another")
let redirectFrom = (from: string, to: string): guard => url => {
  if url.path == from {
    Redirect(to)
  } else {
    Allow
  }
}

// ============================================================================
// Guard Runner
// ============================================================================

@ocaml.doc("Run all synchronous guards and return first blocking result")
let runGuards = (guards: array<guard>, url: CadreTeaRouter_Url.t): guardResult => {
  let rec check = (idx: int): guardResult => {
    if idx >= Array.length(guards) {
      Allow
    } else {
      switch guards->Array.getUnsafe(idx)(url) {
      | Allow => check(idx + 1)
      | result => result
      }
    }
  }
  check(0)
}

@ocaml.doc("Run all guards including async ones")
let runAllGuards = async (config: guardConfig, url: CadreTeaRouter_Url.t): promise<guardResult> => {
  // First run sync guards
  switch runGuards(config.guards, url) {
  | Allow => {
      // Then run async guards
      let rec checkAsync = async (idx: int): promise<guardResult> => {
        if idx >= Array.length(config.asyncGuards) {
          Allow
        } else {
          switch await config.asyncGuards->Array.getUnsafe(idx)(url) {
          | Allow => await checkAsync(idx + 1)
          | result => result
          }
        }
      }
      await checkAsync(0)
    }
  | result => result
  }
}

// ============================================================================
// Navigation Integration
// ============================================================================

@ocaml.doc("Guarded navigation - only navigates if guards pass")
let guardedPush = (config: guardConfig, url: CadreTeaRouter_Url.t): bool => {
  switch runGuards(config.guards, url) {
  | Allow => {
      CadreTeaRouter_Navigation.execute(CadreTeaRouter_Navigation.Push(url))
      true
    }
  | Block(reason) => {
      switch config.onBlock {
      | Some(handler) => handler(reason)
      | None => ()
      }
      false
    }
  | Redirect(path) => {
      switch config.onRedirect {
      | Some(handler) => handler(path)
      | None => ()
      }
      CadreTeaRouter_Navigation.execute(
        CadreTeaRouter_Navigation.Replace(CadreTeaRouter_Url.parse(path))
      )
      true
    }
  }
}

@ocaml.doc("Guarded navigation with async guards")
let guardedPushAsync = async (config: guardConfig, url: CadreTeaRouter_Url.t): promise<bool> => {
  switch await runAllGuards(config, url) {
  | Allow => {
      CadreTeaRouter_Navigation.execute(CadreTeaRouter_Navigation.Push(url))
      true
    }
  | Block(reason) => {
      switch config.onBlock {
      | Some(handler) => handler(reason)
      | None => ()
      }
      false
    }
  | Redirect(path) => {
      switch config.onRedirect {
      | Some(handler) => handler(path)
      | None => ()
      }
      CadreTeaRouter_Navigation.execute(
        CadreTeaRouter_Navigation.Replace(CadreTeaRouter_Url.parse(path))
      )
      true
    }
  }
}

// ============================================================================
// BeforeUnload Integration (browser tab close warning)
// ============================================================================

@ocaml.doc("Set up browser beforeunload warning when blockers are active")
let setupBeforeUnload = (): unit => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    %raw(`
      window.addEventListener('beforeunload', function(e) {
        if (globalState.isSyncing || Object.keys(globalState.customBlockers).length > 0) {
          e.preventDefault();
          e.returnValue = '';
          return '';
        }
      })
    `)()
  }
}

// ============================================================================
// Default Configuration
// ============================================================================

@ocaml.doc("Default guard config with sync and blocker guards")
let defaultConfig: guardConfig = {
  guards: [syncGuard, blockerGuard],
  asyncGuards: [],
  onBlock: None,
  onRedirect: None,
}

@ocaml.doc("Create a config with custom block handler")
let withBlockHandler = (config: guardConfig, handler: string => unit): guardConfig => {
  {...config, onBlock: Some(handler)}
}

@ocaml.doc("Create a config with custom redirect handler")
let withRedirectHandler = (config: guardConfig, handler: string => unit): guardConfig => {
  {...config, onRedirect: Some(handler)}
}

@ocaml.doc("Add a guard to config")
let addGuard = (config: guardConfig, guard: guard): guardConfig => {
  {...config, guards: Array.concat(config.guards, [guard])}
}

@ocaml.doc("Add an async guard to config")
let addAsyncGuard = (config: guardConfig, guard: asyncGuard): guardConfig => {
  {...config, asyncGuards: Array.concat(config.asyncGuards, [guard])}
}
