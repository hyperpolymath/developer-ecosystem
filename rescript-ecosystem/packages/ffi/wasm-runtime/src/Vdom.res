// Pure ReScript Virtual DOM - No React/JS Framework Dependencies
// SPDX-License-Identifier: MPL-2.0

// Virtual DOM Node types
type rec vnode =
  | Text(string)
  | Element({
      tag: string,
      attrs: array<(string, string)>,
      events: array<(string, Dom.event => unit)>,
      children: array<vnode>,
    })
  | Fragment(array<vnode>)
  | Keyed(string, vnode)

// Attribute helpers
let attr = (name, value) => (name, value)
let class_ = value => ("class", value)
let id = value => ("id", value)
let style = value => ("style", value)

// Event helpers
let onClick = handler => ("click", handler)
let onInput = handler => ("input", handler)
let onSubmit = handler => ("submit", handler)
let onChange = handler => ("change", handler)
let onKeyDown = handler => ("keydown", handler)
let onKeyUp = handler => ("keyup", handler)

// Node constructors
let text = s => Text(s)

let el = (tag, ~attrs=[], ~events=[], children) =>
  Element({tag, attrs, events, children})

let div = (~attrs=[], ~events=[], children) => el("div", ~attrs, ~events, children)
let span = (~attrs=[], ~events=[], children) => el("span", ~attrs, ~events, children)
let p = (~attrs=[], ~events=[], children) => el("p", ~attrs, ~events, children)
let h1 = (~attrs=[], ~events=[], children) => el("h1", ~attrs, ~events, children)
let h2 = (~attrs=[], ~events=[], children) => el("h2", ~attrs, ~events, children)
let h3 = (~attrs=[], ~events=[], children) => el("h3", ~attrs, ~events, children)
let button = (~attrs=[], ~events=[], children) => el("button", ~attrs, ~events, children)
let input = (~attrs=[], ~events=[]) => el("input", ~attrs, ~events, [])
let form = (~attrs=[], ~events=[], children) => el("form", ~attrs, ~events, children)
let ul = (~attrs=[], ~events=[], children) => el("ul", ~attrs, ~events, children)
let ol = (~attrs=[], ~events=[], children) => el("ol", ~attrs, ~events, children)
let li = (~attrs=[], ~events=[], children) => el("li", ~attrs, ~events, children)
let a = (~attrs=[], ~events=[], children) => el("a", ~attrs, ~events, children)
let img = (~attrs=[], ~events=[]) => el("img", ~attrs, ~events, [])
let nav = (~attrs=[], ~events=[], children) => el("nav", ~attrs, ~events, children)
let header = (~attrs=[], ~events=[], children) => el("header", ~attrs, ~events, children)
let footer = (~attrs=[], ~events=[], children) => el("footer", ~attrs, ~events, children)
let main = (~attrs=[], ~events=[], children) => el("main", ~attrs, ~events, children)
let section = (~attrs=[], ~events=[], children) => el("section", ~attrs, ~events, children)
let article = (~attrs=[], ~events=[], children) => el("article", ~attrs, ~events, children)

let fragment = children => Fragment(children)
let keyed = (key, node) => Keyed(key, node)

// DOM bindings for rendering
@val external document: Dom.document = "document"
@send external getElementById: (Dom.document, string) => Nullable.t<Dom.element> = "getElementById"
@send external createElement: (Dom.document, string) => Dom.element = "createElement"
@send external createTextNode: (Dom.document, string) => Dom.text = "createTextNode"
@send external appendChild: (Dom.element, Dom.node) => unit = "appendChild"
@send external removeChild: (Dom.element, Dom.node) => unit = "removeChild"
@send external replaceChild: (Dom.element, Dom.node, Dom.node) => unit = "replaceChild"
@send external setAttribute: (Dom.element, string, string) => unit = "setAttribute"
@send external removeAttribute: (Dom.element, string) => unit = "removeAttribute"
@send external addEventListener: (Dom.element, string, Dom.event => unit) => unit = "addEventListener"
@send external removeEventListener: (Dom.element, string, Dom.event => unit) => unit = "removeEventListener"
@get external childNodes: Dom.element => array<Dom.node> = "childNodes"
@get external firstChild: Dom.element => Nullable.t<Dom.node> = "firstChild"
@send external textContentSet: (Dom.element, string) => unit = "textContent"

// External cast helpers
external elementToNode: Dom.element => Dom.node = "%identity"
external textToNode: Dom.text => Dom.node = "%identity"
external nodeToElement: Dom.node => Dom.element = "%identity"

// Render vnode to real DOM element
let rec render = (vnode: vnode): Dom.node => {
  switch vnode {
  | Text(s) => document->createTextNode(s)->textToNode
  | Element({tag, attrs, events, children}) => {
      let el = document->createElement(tag)
      attrs->Array.forEach(((name, value)) => el->setAttribute(name, value))
      events->Array.forEach(((name, handler)) => el->addEventListener(name, handler))
      children->Array.forEach(child => el->appendChild(render(child)))
      el->elementToNode
    }
  | Fragment(children) => {
      let container = document->createElement("div")
      children->Array.forEach(child => container->appendChild(render(child)))
      container->elementToNode
    }
  | Keyed(_, node) => render(node)
  }
}

// Mount vnode to DOM element
let mount = (root: Dom.element, vnode: vnode) => {
  // Clear existing children
  switch root->firstChild->Nullable.toOption {
  | Some(child) => root->removeChild(child)
  | None => ()
  }
  root->appendChild(render(vnode))
}

// Diff and patch (simplified - full implementation would be more complex)
type rec patch =
  | Replace(vnode)
  | UpdateAttrs(array<(string, string)>)
  | UpdateChildren(array<patch>)
  | Remove
  | Insert(vnode)
  | NoOp

let rec diff = (oldNode: vnode, newNode: vnode): patch => {
  switch (oldNode, newNode) {
  | (Text(a), Text(b)) if a == b => NoOp
  | (Text(_), Text(_)) => Replace(newNode)
  | (Element(old), Element(new_)) if old.tag == new_.tag => {
      // Simplified: just check if attrs changed
      if old.attrs != new_.attrs {
        UpdateAttrs(new_.attrs)
      } else {
        NoOp
      }
    }
  | _ => Replace(newNode)
  }
}

// Apply patch to DOM node
let rec applyPatch = (node: Dom.node, patch: patch, newVnode: vnode): Dom.node => {
  switch patch {
  | Replace(_) => render(newVnode)
  | UpdateAttrs(attrs) => {
      let el = node->nodeToElement
      attrs->Array.forEach(((name, value)) => el->setAttribute(name, value))
      node
    }
  | UpdateChildren(_) => node // Simplified
  | Remove => node
  | Insert(vnode) => render(vnode)
  | NoOp => node
  }
}
