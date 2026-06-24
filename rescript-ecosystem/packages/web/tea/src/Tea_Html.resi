// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Type-safe HTML helpers for TEA applications.
This is a thin wrapper around React elements - users can also use JSX directly.
")

@ocaml.doc("HTML element type - just a React element")
type t<'msg> = React.element

@ocaml.doc("Attribute type for HTML elements")
type attr<'msg>

// Attributes
let className: string => attr<'msg>
let id: string => attr<'msg>
let style: ReactDOM.Style.t => attr<'msg>
let placeholder: string => attr<'msg>
let value: string => attr<'msg>
let checked: bool => attr<'msg>
let disabled: bool => attr<'msg>
let type_: string => attr<'msg>
let href: string => attr<'msg>
let src: string => attr<'msg>
let alt: string => attr<'msg>
let title: string => attr<'msg>
let name: string => attr<'msg>
let for_: string => attr<'msg>
let rows: int => attr<'msg>
let cols: int => attr<'msg>
let maxLength: int => attr<'msg>
let minLength: int => attr<'msg>
let pattern: string => attr<'msg>
let required: bool => attr<'msg>
let readOnly: bool => attr<'msg>
let autoFocus: bool => attr<'msg>
let autoComplete: string => attr<'msg>
let tabIndex: int => attr<'msg>
let role: string => attr<'msg>
let ariaLabel: string => attr<'msg>
let ariaHidden: bool => attr<'msg>

@ocaml.doc("Create a data-* attribute. Usage: data(\"testid\", \"my-button\") creates data-testid=\"my-button\"")
let data: (string, string) => attr<'msg>

// Events
let onClick: 'msg => attr<'msg>
let onInput: (string => 'msg) => attr<'msg>
let onChange: (string => 'msg) => attr<'msg>
let onSubmit: 'msg => attr<'msg>
let onKeyDown: (string => 'msg) => attr<'msg>
let onKeyUp: (string => 'msg) => attr<'msg>
let onFocus: 'msg => attr<'msg>
let onBlur: 'msg => attr<'msg>
let onMouseEnter: 'msg => attr<'msg>
let onMouseLeave: 'msg => attr<'msg>

// Text and empty
let text: string => t<'msg>
let none: t<'msg>

// Keyed rendering
module Keyed: {
  let node: (string, t<'msg>) => t<'msg>
}

// Lazy rendering
let lazy_: (unit => t<'msg>) => t<'msg>
let lazyWith: ('a, 'a => t<'msg>) => t<'msg>

// Mapping
let map: ('a => 'b, t<'a>) => t<'b>
