@@ocaml.doc("
A simple counter example demonstrating the basics of TEA.
")

open Tea

// ============================================================================
// Model
// ============================================================================

type model = {count: int}

// ============================================================================
// Messages
// ============================================================================

type msg =
  | Increment
  | Decrement
  | Reset
  | Set(int)

// ============================================================================
// Init
// ============================================================================

let init = () => ({count: 0}, Cmd.none)

// ============================================================================
// Update
// ============================================================================

let update = (msg, model) => {
  switch msg {
  | Increment => ({count: model.count + 1}, Cmd.none)
  | Decrement => ({count: model.count - 1}, Cmd.none)
  | Reset => ({count: 0}, Cmd.none)
  | Set(n) => ({count: n}, Cmd.none)
  }
}

// ============================================================================
// View
// ============================================================================

let view = (model, dispatch) => {
  <div
    style={ReactDOM.Style.make(
      ~display="flex",
      ~flexDirection="column",
      ~alignItems="center",
      ~gap="16px",
      ~padding="32px",
      ~fontFamily="system-ui, sans-serif",
      (),
    )}>
    <h1> {React.string("Counter")} </h1>
    <div
      style={ReactDOM.Style.make(
        ~display="flex",
        ~alignItems="center",
        ~gap="16px",
        (),
      )}>
      <button
        onClick={_ => dispatch(Decrement)}
        style={ReactDOM.Style.make(~padding="8px 16px", ~fontSize="18px", ~cursor="pointer", ())}>
        {React.string("-")}
      </button>
      <span
        style={ReactDOM.Style.make(
          ~fontSize="48px",
          ~fontWeight="bold",
          ~minWidth="80px",
          ~textAlign="center",
          (),
        )}>
        {model.count->Belt.Int.toString->React.string}
      </span>
      <button
        onClick={_ => dispatch(Increment)}
        style={ReactDOM.Style.make(~padding="8px 16px", ~fontSize="18px", ~cursor="pointer", ())}>
        {React.string("+")}
      </button>
    </div>
    <button
      onClick={_ => dispatch(Reset)}
      style={ReactDOM.Style.make(~padding="8px 24px", ~fontSize="14px", ~cursor="pointer", ())}>
      {React.string("Reset")}
    </button>
  </div>
}

// ============================================================================
// Subscriptions
// ============================================================================

let subscriptions = _model => Sub.none

// ============================================================================
// Application
// ============================================================================

module App = MakeWithDispatch({
  type model = model
  type msg = msg
  type flags = unit
  let init = _ => init()
  let update = update
  let view = view
  let subscriptions = subscriptions
})

// ============================================================================
// Mount (for standalone use)
// ============================================================================

let mount = () => {
  switch ReactDOM.querySelector("#root") {
  | Some(root) => {
      let rootElement = ReactDOM.Client.createRoot(root)
      rootElement->ReactDOM.Client.Root.render(<App flags=() />)
    }
  | None => Js.Console.error("Could not find #root element")
  }
}
