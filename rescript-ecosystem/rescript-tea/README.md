# rescript-tea

The Elm Architecture (TEA) for ReScript, providing a principled way to build web applications with guaranteed state consistency, exhaustive event handling, and time-travel debugging.

## Features

- **Single source of truth** - One model, one update pathway
- **Pure updates** - Easy to test, easy to reason about
- **Type-safe** - Compiler catches missing message handlers
- **React integration** - Uses React for rendering, compatible with existing components
- **Commands & Subscriptions** - Declarative side effects

## Installation

```bash
npm install rescript-tea
```

Add to your `rescript.json`:

```json
{
  "bs-dependencies": ["rescript-tea", "@rescript/react"]
}
```

## Quick Start

```rescript
open Tea

// 1. Define your model
type model = {count: int}

// 2. Define your messages
type msg =
  | Increment
  | Decrement

// 3. Initialize your app
let init = () => ({count: 0}, Cmd.none)

// 4. Handle updates
let update = (msg, model) => {
  switch msg {
  | Increment => ({count: model.count + 1}, Cmd.none)
  | Decrement => ({count: model.count - 1}, Cmd.none)
  }
}

// 5. Render your view
let view = model => {
  <div>
    <button onClick={_ => Decrement}> {React.string("-")} </button>
    <span> {model.count->Int.toString->React.string} </span>
    <button onClick={_ => Increment}> {React.string("+")} </button>
  </div>
}

// 6. Declare subscriptions (none for this simple example)
let subscriptions = _model => Sub.none

// 7. Create the app component
module App = MakeSimple({
  type model = model
  type msg = msg
  let app = {init, update, view, subscriptions}
})

// 8. Mount it
switch ReactDOM.querySelector("#root") {
| Some(root) => ReactDOM.render(<App />, root)
| None => ()
}
```

## Core Concepts

### Model

Your application state is a single value (typically a record):

```rescript
type model = {
  user: option<user>,
  posts: array<post>,
  loading: bool,
}
```

### Messages

All possible events are variants of a single type:

```rescript
type msg =
  | FetchPosts
  | GotPosts(result<array<post>, error>)
  | SelectPost(int)
  | Logout
```

### Update

A pure function that handles messages:

```rescript
let update = (msg, model) => {
  switch msg {
  | FetchPosts => (model, fetchPostsCmd)
  | GotPosts(Ok(posts)) => ({...model, posts, loading: false}, Cmd.none)
  | GotPosts(Error(_)) => ({...model, loading: false}, Cmd.none)
  | SelectPost(id) => ({...model, selectedId: Some(id)}, Cmd.none)
  | Logout => ({...model, user: None}, Cmd.none)
  }
}
```

### Commands

Descriptions of side effects to perform:

```rescript
// Do nothing
Cmd.none

// Batch multiple commands
Cmd.batch([cmd1, cmd2, cmd3])

// Perform an async operation
Cmd.perform(() => fetchUser("alice"), user => GotUser(user))

// Handle potential failures
Cmd.attempt(() => fetchUser("alice"), result => GotUser(result))
```

### Subscriptions

Declarations of external event sources:

```rescript
let subscriptions = model => {
  if model.timerRunning {
    Sub.Time.every(1000, time => Tick(time))
  } else {
    Sub.none
  }
}
```

Built-in subscriptions:
- `Sub.Time.every(ms, toMsg)` - Timer
- `Sub.Keyboard.downs(toMsg)` - Key down events
- `Sub.Keyboard.ups(toMsg)` - Key up events
- `Sub.Mouse.clicks(toMsg)` - Mouse clicks
- `Sub.Mouse.moves(toMsg)` - Mouse movement
- `Sub.Window.resizes(toMsg)` - Window resize

## Modules

### Tea.Cmd

Commands for side effects.

### Tea.Sub

Subscriptions for external events.

### Tea.Json

Type-safe JSON decoding:

```rescript
open Tea.Json

let userDecoder = map3(
  (id, name, email) => {id, name, email},
  field("id", int),
  field("name", string),
  field("email", string),
)

// Use it
switch decodeString(userDecoder, jsonString) {
| Ok(user) => // use user
| Error(err) => Console.log(errorToString(err))
}
```

### Tea.Html

Optional HTML helpers (you can also use JSX directly):

```rescript
open Tea.Html

let view = model => {
  div([className("container")], [
    h1([], [text("Hello")]),
    button([onClick(Increment)], [text("+")]),
  ])
}
```

### Tea.Test

Testing utilities:

```rescript
// Simulate a sequence of messages
let finalModel = Tea.Test.simulate(
  ~init,
  ~update,
  ~msgs=[Increment, Increment, Decrement],
)

// Collect commands for inspection
let cmds = Tea.Test.collectCmds(
  ~init,
  ~update,
  ~msgs=[FetchUser("alice")],
)
```

## Examples

See the `examples/` directory:

- `01_counter/` - Basic counter
- More coming soon...

## Why TEA?

| Bug Type | How TEA Prevents It |
|----------|---------------------|
| Stale UI | View is pure function of Model |
| Forgotten state updates | View recomputes entirely |
| Unhandled events | Variant types = compiler warnings |
| Race conditions | Single update pathway |
| Untestable code | Pure functions = easy testing |

## License

MIT
