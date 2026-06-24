// SPDX-License-Identifier: MPL-2.0
// CadreTeaRouter_Guards.res - Navigation guards for TEA applications

open CadreTeaRouter_Url

@ocaml.doc("Result of a guard check")
type guardResult =
  | Allow
  | Block(string)  // Block with reason
  | Redirect(string)  // Redirect to different path

@ocaml.doc("A navigation guard function")
type guard = CadreTeaRouter_Url.t => guardResult

@ocaml.doc("An asynchronous navigation guard function")
type asyncGuard = CadreTeaRouter_Url.t => promise<guardResult>

@ocaml.doc("Configuration for navigation guards")
type guardConfig = {
  guards: array<guard>,
  asyncGuards: array<asyncGuard>,
}

@ocaml.doc("Empty guard configuration")
let emptyConfig: guardConfig = {
  guards: [],
  asyncGuards: [],
}

@ocaml.doc("Run all synchronous guards and return first blocking result")
let runGuards = (guards: array<guard>, url: CadreTeaRouter_Url.t): guardResult => {
  let rec check = (idx: int): guardResult => {
    if idx >= Belt.Array.length(guards) {
      Allow
    } else {
      switch Belt.Array.getExn(guards, idx)(url) {
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
        if idx >= Belt.Array.length(config.asyncGuards) {
          Promise.resolve(Allow)
        } else {
          switch await Belt.Array.getExn(config.asyncGuards, idx)(url) {
          | Allow => await checkAsync(idx + 1)
          | result => Promise.resolve(result)
          }
        }
      }
      await checkAsync(0)
    }
  | result => Promise.resolve(result)
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
  | Block(_) => false
  | Redirect(target) => {
      CadreTeaRouter_Navigation.execute(CadreTeaRouter_Navigation.Push(parse(target)))
      true
    }
  }
}
