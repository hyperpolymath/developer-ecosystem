// TEA (The Elm Architecture) for WASM runtime

type rec cmd<'msg> =
  | NoCmd
  | Cmd(unit => option<'msg>)
  | BatchCmd(array<cmd<'msg>>)

type rec sub<'msg> =
  | NoSub
  | Sub({
      key: string,
      subscribe: ('msg => unit) => unit => unit,
    })
  | BatchSub(array<sub<'msg>>)

type program<'model, 'msg> = {
  init: unit => ('model, cmd<'msg>),
  update: ('msg, 'model) => ('model, cmd<'msg>),
  view: 'model => Vdom.vnode,
  subscriptions: 'model => sub<'msg>,
}

let none = NoCmd
let cmd = f => Cmd(f)
let batch = cmds => BatchCmd(cmds)

let noSub = NoSub
let sub = (key, subscribe) => Sub({key, subscribe})
let batchSub = subs => BatchSub(subs)

module Effect = {
  let none = NoCmd
  let after = (_ms, _msg) => NoCmd
  let random = (_min, _max, _toMsg) => NoCmd
  let focus = (_id) => NoCmd
}

module Subscriptions = {
  let none = NoSub
  let every = (_ms, _toMsg) => NoSub
  let onResize = (_toMsg) => NoSub
  let onKeyDown = (_toMsg) => NoSub
}

let run = (_program: program<'model, 'msg>, _flags: string) => ()

let simple = (
  ~init: unit => 'model,
  ~update: ('msg, 'model) => 'model,
  ~view: 'model => Vdom.vnode,
): program<'model, 'msg> => {
  {
    init: () => (init(), NoCmd),
    update: (msg, model) => (update(msg, model), NoCmd),
    view: view,
    subscriptions: _ => NoSub,
  }
}
