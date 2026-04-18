// SPDX-License-Identifier: Apache-2.0
// Navigation.res - Browser History API abstraction

// External bindings to browser APIs
@val external historyPushState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.pushState"
@val external historyReplaceState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.replaceState"
@val external historyBack: unit => unit = "window.history.back"
@val external historyForward: unit => unit = "window.history.forward"
@val external historyGo: int => unit = "window.history.go"

@val external addEventListener: (string, 'a => unit) => unit = "window.addEventListener"
@val external removeEventListener: (string, 'a => unit) => unit = "window.removeEventListener"

let pushUrl = (url: string): unit => {
  historyPushState(Js.Nullable.null, "", url)
}

let replaceUrl = (url: string): unit => {
  historyReplaceState(Js.Nullable.null, "", url)
}

let back = (): unit => {
  historyBack()
}

let forward = (): unit => {
  historyForward()
}

let go = (delta: int): unit => {
  historyGo(delta)
}

let currentUrl = (): Url.t => {
  Url.fromLocation()
}

type unsubscribe = unit => unit

let onUrlChange = (callback: Url.t => unit): unsubscribe => {
  let handler = _ => {
    callback(Url.fromLocation())
  }

  addEventListener("popstate", handler)

  () => {
    removeEventListener("popstate", handler)
  }
}

module Make = (R: {
  type t
  let toString: t => string
}) => {
  let pushRoute = (route: R.t): unit => {
    pushUrl(R.toString(route))
  }

  let replaceRoute = (route: R.t): unit => {
    replaceUrl(R.toString(route))
  }
}
