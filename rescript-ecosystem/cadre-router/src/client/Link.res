// SPDX-License-Identifier: PMPL-1.0-or-later
// Link.res - Type-safe link component (React-based, optional)

open React

@react.component
let make = (
  ~href: string,
  ~onClick: option<ReactEvent.Mouse.t => unit>=?,
  ~className: option<string>=?,
  ~style: option<ReactDOM.Style.t>=?,
  ~target: option<string>=?,
  ~children: React.element,
) => {
  let handleClick = (event: ReactEvent.Mouse.t) => {
    switch onClick {
    | Some(handler) => handler(event)
    | None => ()
    }

    let shouldNavigate =
      !ReactEvent.Mouse.defaultPrevented(event) &&
      ReactEvent.Mouse.button(event) == 0 &&
      !ReactEvent.Mouse.metaKey(event) &&
      !ReactEvent.Mouse.altKey(event) &&
      !ReactEvent.Mouse.ctrlKey(event) &&
      !ReactEvent.Mouse.shiftKey(event) &&
      (switch target { | None => true | Some("_self") => true | _ => false })

    if shouldNavigate {
      ReactEvent.Mouse.preventDefault(event)
      Navigation.pushUrl(href)
    }
  }

  let props = {
    "href": href,
    "onClick": handleClick,
    "className": className,
    "style": style,
    "target": target
  }
  
  ReactDOM.createDOMElementVariadic("a", ~props=Obj.magic(props), [children])
}

// ============================================================================
// SafeLink — Link with href validation via rescript-dom-mounter
// ============================================================================
//
// Validates the href through Parser.sanitisePath before navigation.
// Rejects path-traversal and encoded-traversal attempts. Falls back
// to a no-op (logs error) if the href is rejected.

module SafeLink = {
  @react.component
  let make = (
    ~href: string,
    ~onClick: option<ReactEvent.Mouse.t => unit>=?,
    ~className: option<string>=?,
    ~style: option<ReactDOM.Style.t>=?,
    ~target: option<string>=?,
    ~children: React.element,
  ) => {
    let handleClick = (event: ReactEvent.Mouse.t) => {
      switch onClick {
      | Some(handler) => handler(event)
      | None => ()
      }

      let shouldNavigate =
        !ReactEvent.Mouse.defaultPrevented(event) &&
        ReactEvent.Mouse.button(event) == 0 &&
        !ReactEvent.Mouse.metaKey(event) &&
        !ReactEvent.Mouse.altKey(event) &&
        !ReactEvent.Mouse.ctrlKey(event) &&
        !ReactEvent.Mouse.shiftKey(event) &&
        (switch target { | None => true | Some("_self") => true | _ => false })

      if shouldNavigate {
        ReactEvent.Mouse.preventDefault(event)
        switch Parser.sanitisePath(href) {
        | Some(clean) => Navigation.pushUrl(clean)
        | None => Js.Console.error(`SafeLink: href rejected (traversal): ${href}`)
        }
      }
    }

    let props = {
      "href": href,
      "onClick": handleClick,
      "className": className,
      "style": style,
      "target": target
    }

    ReactDOM.createDOMElementVariadic("a", ~props=Obj.magic(props), [children])
  }
}

module Make = (R: {
  type t
  let toString: t => string
}) => {
  module Nav = Navigation.Make(R)

  @react.component
  let make = (
    ~route: R.t,
    ~className: option<string>=?,
    ~style: option<ReactDOM.Style.t>=?,
    ~children: React.element,
  ) => {
    let href = R.toString(route)

    let handleClick = (event: ReactEvent.Mouse.t) => {
      let shouldNavigate =
        !ReactEvent.Mouse.defaultPrevented(event) &&
        ReactEvent.Mouse.button(event) == 0 &&
        !ReactEvent.Mouse.metaKey(event) &&
        !ReactEvent.Mouse.altKey(event) &&
        !ReactEvent.Mouse.ctrlKey(event) &&
        !ReactEvent.Mouse.shiftKey(event)

      if shouldNavigate {
        ReactEvent.Mouse.preventDefault(event)
        Nav.pushRoute(route)
      }
    }

    let props = {
      "href": href,
      "onClick": handleClick,
      "className": className,
      "style": style
    }

    ReactDOM.createDOMElementVariadic("a", ~props=Obj.magic(props), [children])
  }
}
