// SPDX-License-Identifier: Apache-2.0
// Link.resi - Type-safe link component (React-based, optional)
//
// NOTE: This module requires @rescript/react as a peer dependency.
// For rescript-tea, see cadre-tea-router which provides tea-native links.

/**
 * Basic link component that uses client-side navigation.
 * Intercepts clicks and uses pushState instead of full page reload.
 */
@react.component
let make: (
  ~href: string,
  ~onClick: ReactEvent.Mouse.t => unit=?,
  ~className: string=?,
  ~style: ReactDOM.Style.t=?,
  ~target: string=?,
  ~children: React.element,
) => React.element

/**
 * Functor to create a type-safe link component for your route type.
 *
 * Usage:
 * ```rescript
 * module MyLink = Link.Make({
 *   type t = Route.t
 *   let toString = Route.toString
 * })
 *
 * // In JSX:
 * <MyLink route={Route.Profile}>"Profile"</MyLink>
 * ```
 */
module Make: (R: {
  type t
  let toString: t => string
}) => {
  @react.component
  let make: (
    ~route: R.t,
    ~className: string=?,
    ~style: ReactDOM.Style.t=?,
    ~children: React.element,
  ) => React.element
}
