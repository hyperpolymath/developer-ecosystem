// SPDX-License-Identifier: Apache-2.0
// HashNavigation.res - Hash-based routing for static hosting

@val external locationHash: string = "window.location.hash"
let setLocationHash: string => unit = _hash => %raw(`window.location.hash = _hash`)
@val external historyPushState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.pushState"
@val external historyReplaceState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.replaceState"
@val external historyBack: unit => unit = "window.history.back"
@val external historyForward: unit => unit = "window.history.forward"
@val external addEventListener: (string, 'a => unit) => unit = "window.addEventListener"
@val external removeEventListener: (string, 'a => unit) => unit = "window.removeEventListener"
@val external locationOrigin: string = "window.location.origin"
@val external locationPathname: string = "window.location.pathname"

// Convert a path to a hash URL
let toHashUrl = (path: string): string => {
  // Ensure path starts with /
  let normalizedPath = if Js.String2.startsWith(path, "/") {
    path
  } else {
    "/" ++ path
  }
  "#" ++ normalizedPath
}

// Parse hash into Url.t
let parseHash = (hash: string): Url.t => {
  // Remove leading # and optional /
  let path = if Js.String2.startsWith(hash, "#/") {
    Js.String2.sliceToEnd(hash, ~from=1)
  } else if Js.String2.startsWith(hash, "#") {
    let rest = Js.String2.sliceToEnd(hash, ~from=1)
    if rest == "" { "/" } else { "/" ++ rest }
  } else {
    "/"
  }
  Url.fromString(path)
}

let pushUrl = (url: string): unit => {
  let hashUrl = toHashUrl(url)
  // Use pushState to add history entry, then update hash
  let fullUrl = locationOrigin ++ locationPathname ++ hashUrl
  historyPushState(Js.Nullable.null, "", fullUrl)
}

let replaceUrl = (url: string): unit => {
  let hashUrl = toHashUrl(url)
  let fullUrl = locationOrigin ++ locationPathname ++ hashUrl
  historyReplaceState(Js.Nullable.null, "", fullUrl)
}

let back = (): unit => {
  historyBack()
}

let forward = (): unit => {
  historyForward()
}

let currentUrl = (): Url.t => {
  parseHash(locationHash)
}

type unsubscribe = unit => unit

let onUrlChange = (callback: Url.t => unit): unsubscribe => {
  let handler = _ => {
    callback(currentUrl())
  }

  // Listen to both hashchange and popstate for comprehensive coverage
  addEventListener("hashchange", handler)
  addEventListener("popstate", handler)

  () => {
    removeEventListener("hashchange", handler)
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
