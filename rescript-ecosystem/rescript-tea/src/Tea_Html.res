@@ocaml.doc("
Type-safe HTML helpers for TEA applications.
This is a thin wrapper around React elements - users can also use JSX directly.
")

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("HTML element type - just a React element")
type t<'msg> = React.element

@ocaml.doc("Attribute type for HTML elements")
type attr<'msg>

// Internal representation of attributes
type internalAttr<'msg> =
  | ClassName(string)
  | Id(string)
  | Style(ReactDOM.Style.t)
  | OnClick('msg)
  | OnInput(string => 'msg)
  | OnChange(string => 'msg)
  | OnSubmit('msg)
  | OnKeyDown(string => 'msg)
  | OnKeyUp(string => 'msg)
  | OnFocus('msg)
  | OnBlur('msg)
  | OnMouseEnter('msg)
  | OnMouseLeave('msg)
  | Placeholder(string)
  | Value(string)
  | Checked(bool)
  | Disabled(bool)
  | Type(string)
  | Href(string)
  | Src(string)
  | Alt(string)
  | Title(string)
  | Name(string)
  | For(string)
  | Rows(int)
  | Cols(int)
  | MaxLength(int)
  | MinLength(int)
  | Pattern(string)
  | Required(bool)
  | ReadOnly(bool)
  | AutoFocus(bool)
  | AutoComplete(string)
  | TabIndex(int)
  | Role(string)
  | AriaLabel(string)
  | AriaHidden(bool)
  | DataAttribute(string, string)

external makeAttr: internalAttr<'msg> => attr<'msg> = "%identity"
external getAttr: attr<'msg> => internalAttr<'msg> = "%identity"

// ============================================================================
// Attribute constructors
// ============================================================================

let className = (name: string): attr<'msg> => makeAttr(ClassName(name))
let id = (id: string): attr<'msg> => makeAttr(Id(id))
let style = (s: ReactDOM.Style.t): attr<'msg> => makeAttr(Style(s))
let placeholder = (text: string): attr<'msg> => makeAttr(Placeholder(text))
let value = (v: string): attr<'msg> => makeAttr(Value(v))
let checked = (b: bool): attr<'msg> => makeAttr(Checked(b))
let disabled = (b: bool): attr<'msg> => makeAttr(Disabled(b))
let type_ = (t: string): attr<'msg> => makeAttr(Type(t))
let href = (url: string): attr<'msg> => makeAttr(Href(url))
let src = (url: string): attr<'msg> => makeAttr(Src(url))
let alt = (text: string): attr<'msg> => makeAttr(Alt(text))
let title = (text: string): attr<'msg> => makeAttr(Title(text))
let name = (n: string): attr<'msg> => makeAttr(Name(n))
let for_ = (id: string): attr<'msg> => makeAttr(For(id))
let rows = (n: int): attr<'msg> => makeAttr(Rows(n))
let cols = (n: int): attr<'msg> => makeAttr(Cols(n))
let maxLength = (n: int): attr<'msg> => makeAttr(MaxLength(n))
let minLength = (n: int): attr<'msg> => makeAttr(MinLength(n))
let pattern = (p: string): attr<'msg> => makeAttr(Pattern(p))
let required = (b: bool): attr<'msg> => makeAttr(Required(b))
let readOnly = (b: bool): attr<'msg> => makeAttr(ReadOnly(b))
let autoFocus = (b: bool): attr<'msg> => makeAttr(AutoFocus(b))
let autoComplete = (v: string): attr<'msg> => makeAttr(AutoComplete(v))
let tabIndex = (n: int): attr<'msg> => makeAttr(TabIndex(n))
let role = (r: string): attr<'msg> => makeAttr(Role(r))
let ariaLabel = (label: string): attr<'msg> => makeAttr(AriaLabel(label))
let ariaHidden = (b: bool): attr<'msg> => makeAttr(AriaHidden(b))
let data = (key: string, value: string): attr<'msg> => makeAttr(DataAttribute(key, value))

// ============================================================================
// Event handlers
// ============================================================================

let onClick = (msg: 'msg): attr<'msg> => makeAttr(OnClick(msg))
let onInput = (toMsg: string => 'msg): attr<'msg> => makeAttr(OnInput(toMsg))
let onChange = (toMsg: string => 'msg): attr<'msg> => makeAttr(OnChange(toMsg))
let onSubmit = (msg: 'msg): attr<'msg> => makeAttr(OnSubmit(msg))
let onKeyDown = (toMsg: string => 'msg): attr<'msg> => makeAttr(OnKeyDown(toMsg))
let onKeyUp = (toMsg: string => 'msg): attr<'msg> => makeAttr(OnKeyUp(toMsg))
let onFocus = (msg: 'msg): attr<'msg> => makeAttr(OnFocus(msg))
let onBlur = (msg: 'msg): attr<'msg> => makeAttr(OnBlur(msg))
let onMouseEnter = (msg: 'msg): attr<'msg> => makeAttr(OnMouseEnter(msg))
let onMouseLeave = (msg: 'msg): attr<'msg> => makeAttr(OnMouseLeave(msg))

// ============================================================================
// Internal: Convert attributes to React props
// ============================================================================

type reactProps = {
  mutable className: option<string>,
  mutable id: option<string>,
  mutable style: option<ReactDOM.Style.t>,
  mutable onClick: option<ReactEvent.Mouse.t => unit>,
  mutable onInput: option<ReactEvent.Form.t => unit>,
  mutable onChange: option<ReactEvent.Form.t => unit>,
  mutable onSubmit: option<ReactEvent.Form.t => unit>,
  mutable onKeyDown: option<ReactEvent.Keyboard.t => unit>,
  mutable onKeyUp: option<ReactEvent.Keyboard.t => unit>,
  mutable onFocus: option<ReactEvent.Focus.t => unit>,
  mutable onBlur: option<ReactEvent.Focus.t => unit>,
  mutable onMouseEnter: option<ReactEvent.Mouse.t => unit>,
  mutable onMouseLeave: option<ReactEvent.Mouse.t => unit>,
  mutable placeholder: option<string>,
  mutable value: option<string>,
  mutable checked: option<bool>,
  mutable disabled: option<bool>,
  mutable \"type": option<string>,
  mutable href: option<string>,
  mutable src: option<string>,
  mutable alt: option<string>,
  mutable title: option<string>,
  mutable name: option<string>,
  mutable htmlFor: option<string>,
  mutable rows: option<int>,
  mutable cols: option<int>,
  mutable maxLength: option<int>,
  mutable minLength: option<int>,
  mutable pattern: option<string>,
  mutable required: option<bool>,
  mutable readOnly: option<bool>,
  mutable autoFocus: option<bool>,
  mutable autoComplete: option<string>,
  mutable tabIndex: option<int>,
  mutable role: option<string>,
  mutable \"aria-label": option<string>,
  mutable \"aria-hidden": option<bool>,
}

let emptyProps = (): reactProps => {
  className: None,
  id: None,
  style: None,
  onClick: None,
  onInput: None,
  onChange: None,
  onSubmit: None,
  onKeyDown: None,
  onKeyUp: None,
  onFocus: None,
  onBlur: None,
  onMouseEnter: None,
  onMouseLeave: None,
  placeholder: None,
  value: None,
  checked: None,
  disabled: None,
  \"type": None,
  href: None,
  src: None,
  alt: None,
  title: None,
  name: None,
  htmlFor: None,
  rows: None,
  cols: None,
  maxLength: None,
  minLength: None,
  pattern: None,
  required: None,
  readOnly: None,
  autoFocus: None,
  autoComplete: None,
  tabIndex: None,
  role: None,
  \"aria-label": None,
  \"aria-hidden": None,
}

let attrsToProps = (attrs: array<attr<'msg>>, dispatch: 'msg => unit): reactProps => {
  let props = emptyProps()
  Belt.Array.forEach(attrs, attr => {
    switch getAttr(attr) {
    | ClassName(name) => props.className = Some(name)
    | Id(id) => props.id = Some(id)
    | Style(s) => props.style = Some(s)
    | OnClick(msg) => props.onClick = Some(_ => dispatch(msg))
    | OnInput(toMsg) =>
      props.onInput = Some(e => dispatch(toMsg(ReactEvent.Form.target(e)["value"])))
    | OnChange(toMsg) =>
      props.onChange = Some(e => dispatch(toMsg(ReactEvent.Form.target(e)["value"])))
    | OnSubmit(msg) =>
      props.onSubmit = Some(e => {
        ReactEvent.Form.preventDefault(e)
        dispatch(msg)
      })
    | OnKeyDown(toMsg) => props.onKeyDown = Some(e => dispatch(toMsg(ReactEvent.Keyboard.key(e))))
    | OnKeyUp(toMsg) => props.onKeyUp = Some(e => dispatch(toMsg(ReactEvent.Keyboard.key(e))))
    | OnFocus(msg) => props.onFocus = Some(_ => dispatch(msg))
    | OnBlur(msg) => props.onBlur = Some(_ => dispatch(msg))
    | OnMouseEnter(msg) => props.onMouseEnter = Some(_ => dispatch(msg))
    | OnMouseLeave(msg) => props.onMouseLeave = Some(_ => dispatch(msg))
    | Placeholder(text) => props.placeholder = Some(text)
    | Value(v) => props.value = Some(v)
    | Checked(b) => props.checked = Some(b)
    | Disabled(b) => props.disabled = Some(b)
    | Type(t) => props.\"type" = Some(t)
    | Href(url) => props.href = Some(url)
    | Src(url) => props.src = Some(url)
    | Alt(text) => props.alt = Some(text)
    | Title(text) => props.title = Some(text)
    | Name(n) => props.name = Some(n)
    | For(id) => props.htmlFor = Some(id)
    | Rows(n) => props.rows = Some(n)
    | Cols(n) => props.cols = Some(n)
    | MaxLength(n) => props.maxLength = Some(n)
    | MinLength(n) => props.minLength = Some(n)
    | Pattern(p) => props.pattern = Some(p)
    | Required(b) => props.required = Some(b)
    | ReadOnly(b) => props.readOnly = Some(b)
    | AutoFocus(b) => props.autoFocus = Some(b)
    | AutoComplete(v) => props.autoComplete = Some(v)
    | TabIndex(n) => props.tabIndex = Some(n)
    | Role(r) => props.role = Some(r)
    | AriaLabel(label) => props.\"aria-label" = Some(label)
    | AriaHidden(b) => props.\"aria-hidden" = Some(b)
    | DataAttribute(_key, _value) => () // TODO: Handle data attributes
    }
  })
  props
}

// ============================================================================
// Element constructors
// These require a dispatch function, so they're typically used with Tea_App
// ============================================================================

@ocaml.doc("Create a text node")
let text = (content: string): t<'msg> => React.string(content)

@ocaml.doc("Empty element (renders nothing)")
let none: t<'msg> = React.null

// ============================================================================
// Keyed elements for efficient list rendering
// ============================================================================

module Keyed = {
  @ocaml.doc("Create a keyed node wrapper for efficient list rendering")
  let node = (key: string, element: t<'msg>): t<'msg> => {
    React.cloneElement(element, {"key": key})
  }
}

// ============================================================================
// Lazy rendering (memoization)
// ============================================================================

@ocaml.doc("Lazy render - only re-renders when the function changes")
let lazy_ = (render: unit => t<'msg>): t<'msg> => {
  render()
}

@ocaml.doc("Lazy render with explicit dependency - re-renders only when arg changes")
let lazyWith = (arg: 'a, render: 'a => t<'msg>): t<'msg> => {
  render(arg)
}

// ============================================================================
// Mapping
// ============================================================================

@ocaml.doc("Map over the message type of an element - identity since React elements don't carry msg type at runtime")
let map = (_f: 'a => 'b, element: t<'a>): t<'b> => {
  Obj.magic(element)
}
