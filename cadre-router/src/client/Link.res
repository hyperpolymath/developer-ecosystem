// SPDX-License-Identifier: Apache-2.0
// Link.res - Type-safe link component (React-based, optional)

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
    // Call custom onClick if provided
    switch onClick {
    | Some(handler) => handler(event)
    | None => ()
    }

    // Only handle if:
    // - Not already prevented
    // - Left click (button 0)
    // - No modifier keys
    // - No target attribute (or target="_self")
    let shouldNavigate =
      !ReactEvent.Mouse.defaultPrevented(event) &&
      ReactEvent.Mouse.button(event) == 0 &&
      !ReactEvent.Mouse.metaKey(event) &&
      !ReactEvent.Mouse.altKey(event) &&
      !ReactEvent.Mouse.ctrlKey(event) &&
      !ReactEvent.Mouse.shiftKey(event) &&
      (target == None || target == Some("_self"))

    if shouldNavigate {
      ReactEvent.Mouse.preventDefault(event)
      Navigation.pushUrl(href)
    }
  }

  <a
    href
    onClick={handleClick}
    ?className
    ?style
    ?target
  >
    children
  </a>
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

    <a href onClick={handleClick} ?className ?style>
      children
    </a>
  }
}
