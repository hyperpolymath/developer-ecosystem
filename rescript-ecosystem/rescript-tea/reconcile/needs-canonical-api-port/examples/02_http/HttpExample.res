// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
HTTP example demonstrating data fetching with TEA.
Fetches users from JSONPlaceholder API with loading and error states.
")

open Tea

// ============================================================================
// Types
// ============================================================================

type user = {
  id: int,
  name: string,
  email: string,
  username: string,
}

type remoteData<'a, 'e> =
  | NotAsked
  | Loading
  | Success('a)
  | Failure('e)

type model = {users: remoteData<array<user>, string>}

type msg =
  | FetchUsers
  | GotUsers(result<array<user>, Http.httpError>)

// ============================================================================
// Decoders
// ============================================================================

let userDecoder: Json.decoder<user> = Json.map4(
  (id, name, email, username) => {id, name, email, username},
  Json.field("id", Json.int),
  Json.field("name", Json.string),
  Json.field("email", Json.string),
  Json.field("username", Json.string),
)

let usersDecoder: Json.decoder<array<user>> = Json.array(userDecoder)

// ============================================================================
// Init
// ============================================================================

let init = _ => ({users: NotAsked}, Cmd.none)

// ============================================================================
// Update
// ============================================================================

let update = (msg, model) => {
  switch msg {
  | FetchUsers => (
      {users: Loading},
      Http.getJson("https://jsonplaceholder.typicode.com/users", usersDecoder, result => GotUsers(
        result,
      )),
    )
  | GotUsers(Ok(users)) => ({users: Success(users)}, Cmd.none)
  | GotUsers(Error(err)) => ({users: Failure(Http.errorToString(err))}, Cmd.none)
  }
}

// ============================================================================
// View
// ============================================================================

let viewUser = (user: user) => {
  <div
    key={Int.toString(user.id)}
    style={{
      padding: "12px",
      marginBottom: "8px",
      backgroundColor: "#f5f5f5",
      borderRadius: "4px",
    }}
  >
    <div style={{fontWeight: "bold", marginBottom: "4px"}}> {React.string(user.name)} </div>
    <div style={{fontSize: "14px", color: "#666"}}> {React.string(`@${user.username}`)} </div>
    <div style={{fontSize: "14px", color: "#888"}}> {React.string(user.email)} </div>
  </div>
}

let view = (model, dispatch) => {
  <div
    style={{
      maxWidth: "600px",
      margin: "0 auto",
      padding: "20px",
      fontFamily: "system-ui, sans-serif",
    }}
  >
    <h1> {React.string("Users")} </h1>
    <button
      onClick={_ => dispatch(FetchUsers)}
      disabled={model.users == Loading}
      style={{
        padding: "10px 20px",
        fontSize: "16px",
        cursor: "pointer",
        marginBottom: "20px",
      }}
    >
      {React.string(
        switch model.users {
        | Loading => "Loading..."
        | _ => "Fetch Users"
        },
      )}
    </button>
    {switch model.users {
    | NotAsked => <p style={{color: "#666"}}> {React.string("Click the button to fetch users")} </p>
    | Loading =>
      <div style={{textAlign: "center", padding: "40px"}}>
        <div> {React.string("Loading...")} </div>
      </div>
    | Success(users) =>
      <div>
        <p style={{color: "#666", marginBottom: "16px"}}>
          {React.string(`Loaded ${Int.toString(Array.length(users))} users`)}
        </p>
        {users->Array.map(viewUser)->React.array}
      </div>
    | Failure(error) =>
      <div
        style={{
          color: "#d32f2f",
          padding: "16px",
          backgroundColor: "#ffebee",
          borderRadius: "4px",
        }}
      >
        <strong> {React.string("Error: ")} </strong>
        {React.string(error)}
      </div>
    }}
  </div>
}

// ============================================================================
// Subscriptions
// ============================================================================

let subscriptions = _model => Sub.none

// ============================================================================
// App
// ============================================================================

module App = MakeWithDispatch({
  type model = model
  type msg = msg
  type flags = unit
  let init = init
  let update = update
  let view = view
  let subscriptions = subscriptions
})

// ============================================================================
// Mount
// ============================================================================

let mount = () => {
  switch ReactDOM.querySelector("#root") {
  | Some(root) => {
      let rootElement = ReactDOM.Client.createRoot(root)
      rootElement->ReactDOM.Client.Root.render(<App flags=() />)
    }
  | None => Console.error("Could not find #root element")
  }
}
