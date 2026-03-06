// GraphQL server example (simplified without external library)
// Demonstrates query parsing and resolution

// Simple GraphQL schema representation
type fieldType = String | Int | Boolean | Object(string) | List(fieldType)

type field = {
  name: string,
  type_: fieldType,
  resolver: Js.Dict.t<Js.Json.t> => Js.Json.t
}

type objectType = {
  name: string,
  fields: array<field>
}

// Sample data
type user = {
  id: int,
  name: string,
  email: string,
  age: int,
}

type post = {
  id: int,
  title: string,
  content: string,
  authorId: int,
}

let users = [
  {id: 1, name: "Alice Johnson", email: "alice@example.com", age: 28},
  {id: 2, name: "Bob Smith", email: "bob@example.com", age: 35},
  {id: 3, name: "Carol White", email: "carol@example.com", age: 42},
]

let posts = [
  {id: 1, title: "GraphQL Basics", content: "Introduction to GraphQL", authorId: 1},
  {id: 2, title: "ReScript Guide", content: "Getting started with ReScript", authorId: 1},
  {id: 3, title: "WASM Performance", content: "WebAssembly optimization tips", authorId: 2},
]

// Resolvers
let resolveUser = (args: Js.Dict.t<Js.Json.t>): Js.Json.t => {
  let idOpt = Js.Dict.get(args, "id")
    ->Option.flatMap(Js.Json.decodeNumber)
    ->Option.map(Float.toInt)

  switch idOpt {
  | Some(id) => {
      switch users->Array.find(u => u.id === id) {
      | Some(user) => {
          Js.Json.object_(Js.Dict.fromArray([
            ("id", Js.Json.number(Int.toFloat(user.id))),
            ("name", Js.Json.string(user.name)),
            ("email", Js.Json.string(user.email)),
            ("age", Js.Json.number(Int.toFloat(user.age)))
          ]))
        }
      | None => Js.Json.null
      }
    }
  | None => Js.Json.null
  }
}

let resolveUsers = (_args: Js.Dict.t<Js.Json.t>): Js.Json.t => {
  let usersJson = users->Array.map(user => {
    Js.Json.object_(Js.Dict.fromArray([
      ("id", Js.Json.number(Int.toFloat(user.id))),
      ("name", Js.Json.string(user.name)),
      ("email", Js.Json.string(user.email)),
      ("age", Js.Json.number(Int.toFloat(user.age)))
    ]))
  })

  Js.Json.array(usersJson)
}

let resolvePosts = (_args: Js.Dict.t<Js.Json.t>): Js.Json.t => {
  let postsJson = posts->Array.map(post => {
    Js.Json.object_(Js.Dict.fromArray([
      ("id", Js.Json.number(Int.toFloat(post.id))),
      ("title", Js.Json.string(post.title)),
      ("content", Js.Json.string(post.content)),
      ("authorId", Js.Json.number(Int.toFloat(post.authorId)))
    ]))
  })

  Js.Json.array(postsJson)
}

// HTTP handlers
let handleGraphQL = async (req: Deno.request): promise<Deno.response> => {
  try {
    let body = await Deno.Request.json(req)

    // Extract query from body
    let query = switch Js.Json.decodeObject(body) {
    | None => None
    | Some(obj) => Js.Dict.get(obj, "query")->Option.flatMap(Js.Json.decodeString)
    }

    switch query {
    | None => {
        Deno.Response.json(
          Js.Json.object_(Js.Dict.fromArray([
            ("errors", Js.Json.array([
              Js.Json.object_(Js.Dict.fromArray([
                ("message", Js.Json.string("No query provided"))
              ]))
            ]))
          ])),
          ~status=400,
          ()
        )
      }
    | Some(queryStr) => {
        // Simple query parsing (very basic, for demo purposes)
        let result = if Js.String2.includes(queryStr, "users") {
          if Js.String2.includes(queryStr, "user(id:") {
            // Extract ID from query (simplified)
            resolveUser(Js.Dict.fromArray([
              ("id", Js.Json.number(1.0))
            ]))
          } else {
            resolveUsers(Js.Dict.empty())
          }
        } else if Js.String2.includes(queryStr, "posts") {
          resolvePosts(Js.Dict.empty())
        } else {
          Js.Json.null
        }

        Deno.Response.json(
          Js.Json.object_(Js.Dict.fromArray([
            ("data", result)
          ])),
          ()
        )
      }
    }
  } catch {
  | _ => {
      Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("errors", Js.Json.array([
            Js.Json.object_(Js.Dict.fromArray([
              ("message", Js.Json.string("Invalid request"))
            ]))
          ]))
        ])),
        ~status=400,
        ()
      )
    }
  }
}

let handlePlayground = async (_req: Deno.request): promise<Deno.response> => {
  let html = `
<!DOCTYPE html>
<html>
<head>
  <title>GraphQL Playground</title>
  <style>
    body { font-family: monospace; margin: 0; padding: 20px; background: #1e1e1e; color: #d4d4d4; }
    h1 { color: #e535ab; }
    .container { max-width: 1200px; margin: 0 auto; }
    .query-area { display: flex; gap: 20px; margin: 20px 0; }
    textarea { flex: 1; min-height: 200px; background: #2d2d2d; color: #d4d4d4; border: 1px solid #404040; padding: 10px; font-family: monospace; }
    button { background: #e535ab; color: white; border: none; padding: 10px 20px; cursor: pointer; font-size: 16px; }
    button:hover { background: #c62a91; }
    .result { background: #2d2d2d; border: 1px solid #404040; padding: 15px; min-height: 200px; white-space: pre-wrap; }
    .examples { margin: 20px 0; }
    .example { background: #2d2d2d; padding: 10px; margin: 10px 0; cursor: pointer; }
    .example:hover { background: #404040; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 GraphQL Playground</h1>

    <div class="examples">
      <h3>Example Queries:</h3>
      <div class="example" onclick="setQuery(query1)">
        Query 1: Get all users
      </div>
      <div class="example" onclick="setQuery(query2)">
        Query 2: Get user by ID
      </div>
      <div class="example" onclick="setQuery(query3)">
        Query 3: Get all posts
      </div>
    </div>

    <div class="query-area">
      <textarea id="query" placeholder="Enter your GraphQL query...">
{
  users {
    id
    name
    email
  }
}
      </textarea>
    </div>

    <button onclick="executeQuery()">Execute Query</button>

    <h3>Result:</h3>
    <div class="result" id="result">Click "Execute Query" to see results</div>
  </div>

  <script>
    const query1 = \`{
  users {
    id
    name
    email
    age
  }
}\`;

    const query2 = \`{
  user(id: 1) {
    id
    name
    email
  }
}\`;

    const query3 = \`{
  posts {
    id
    title
    content
  }
}\`;

    function setQuery(query) {
      document.getElementById('query').value = query;
    }

    async function executeQuery() {
      const query = document.getElementById('query').value;
      const resultDiv = document.getElementById('result');

      try {
        const response = await fetch('/graphql', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ query })
        });

        const result = await response.json();
        resultDiv.textContent = JSON.stringify(result, null, 2);
      } catch (error) {
        resultDiv.textContent = 'Error: ' + error.message;
      }
    }
  </script>
</body>
</html>
  `

  Deno.Response.html(html, ())
}

let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.post("/graphql", handleGraphQL)
  ->Router.get("/graphql", handleGraphQL)
  ->Router.get("/", handlePlayground)

Server.withRouter(~port=8000, router)

Deno.log("GraphQL server running on http://127.0.0.1:8000")
Deno.log("Open http://127.0.0.1:8000 for GraphQL Playground")
