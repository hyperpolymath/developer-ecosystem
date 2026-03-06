// RESTful API server with CRUD operations

// In-memory data store
type todo = {
  id: int,
  title: string,
  completed: bool,
  createdAt: float
}

let todos: ref<array<todo>> = ref([])
let nextId = ref(1)

// Helper to create JSON response
let jsonResponse = (data: Js.Json.t, ~status=200): promise<Deno.response> => {
  Promise.resolve(Deno.Response.json(data, ~status, ()))
}

let errorResponse = (message: string, ~status=400): promise<Deno.response> => {
  let error = Js.Dict.fromArray([("error", Js.Json.string(message))])
  jsonResponse(Js.Json.object_(error), ~status)
}

// Encode todo to JSON
let todoToJson = (todo: todo): Js.Json.t => {
  Js.Json.object_(Js.Dict.fromArray([
    ("id", Js.Json.number(Int.toFloat(todo.id))),
    ("title", Js.Json.string(todo.title)),
    ("completed", Js.Json.boolean(todo.completed)),
    ("createdAt", Js.Json.number(todo.createdAt))
  ]))
}

// GET /todos - List all todos
let listTodos = async (_req: Deno.request): promise<Deno.response> => {
  let todosJson = todos.contents->Array.map(todoToJson)->Js.Json.array
  jsonResponse(todosJson)
}

// GET /todos/:id - Get single todo
let getTodo = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => errorResponse("Invalid ID", ~status=400)
    | Some(id) => {
        switch todos.contents->Array.find(t => t.id === id) {
        | None => errorResponse("Todo not found", ~status=404)
        | Some(todo) => jsonResponse(todoToJson(todo))
        }
      }
    }
  } else {
    errorResponse("Invalid path", ~status=400)
  }
}

// POST /todos - Create todo
let createTodo = async (req: Deno.request): promise<Deno.response> => {
  try {
    let body = await Deno.Request.json(req)

    // Parse title from JSON
    let title = switch Js.Json.decodeObject(body) {
    | None => None
    | Some(obj) => {
        switch Js.Dict.get(obj, "title") {
        | None => None
        | Some(titleJson) => Js.Json.decodeString(titleJson)
        }
      }
    }

    switch title {
    | None => errorResponse("Title is required", ~status=400)
    | Some(titleStr) => {
        let newTodo: todo = {
          id: nextId.contents,
          title: titleStr,
          completed: false,
          createdAt: Deno.now()
        }

        nextId := nextId.contents + 1
        todos := Array.concat(todos.contents, [newTodo])

        jsonResponse(todoToJson(newTodo), ~status=201)
      }
    }
  } catch {
  | _ => errorResponse("Invalid JSON", ~status=400)
  }
}

// PUT /todos/:id - Update todo
let updateTodo = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => errorResponse("Invalid ID", ~status=400)
    | Some(id) => {
        try {
          let body = await Deno.Request.json(req)

          let index = todos.contents->Array.findIndex(t => t.id === id)

          if index === -1 {
            errorResponse("Todo not found", ~status=404)
          } else {
            let currentTodo = Array.getUnsafe(todos.contents, index)

            // Parse updates
            let (newTitle, newCompleted) = switch Js.Json.decodeObject(body) {
            | None => (currentTodo.title, currentTodo.completed)
            | Some(obj) => {
                let title = switch Js.Dict.get(obj, "title") {
                | None => currentTodo.title
                | Some(t) => Js.Json.decodeString(t)->Option.getWithDefault(currentTodo.title)
                }

                let completed = switch Js.Dict.get(obj, "completed") {
                | None => currentTodo.completed
                | Some(c) => Js.Json.decodeBoolean(c)->Option.getWithDefault(currentTodo.completed)
                }

                (title, completed)
              }
            }

            let updatedTodo = {...currentTodo, title: newTitle, completed: newCompleted}
            todos := todos.contents->Array.mapWithIndex((i, t) => i === index ? updatedTodo : t)

            jsonResponse(todoToJson(updatedTodo))
          }
        } catch {
        | _ => errorResponse("Invalid JSON", ~status=400)
        }
      }
    }
  } else {
    errorResponse("Invalid path", ~status=400)
  }
}

// DELETE /todos/:id - Delete todo
let deleteTodo = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => errorResponse("Invalid ID", ~status=400)
    | Some(id) => {
        let initialLength = Array.length(todos.contents)
        todos := todos.contents->Array.keep(t => t.id !== id)

        if Array.length(todos.contents) === initialLength {
          errorResponse("Todo not found", ~status=404)
        } else {
          jsonResponse(Js.Json.object_(Js.Dict.fromArray([
            ("message", Js.Json.string("Todo deleted"))
          ])))
        }
      }
    }
  } else {
    errorResponse("Invalid path", ~status=400)
  }
}

// Create router
let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.get("/todos", listTodos)
  ->Router.get("/todos/:id", getTodo)
  ->Router.post("/todos", createTodo)
  ->Router.put("/todos/:id", updateTodo)
  ->Router.del("/todos/:id", deleteTodo)
  ->Router.get("/", async _req => {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("message", Js.Json.string("Todo API")),
        ("endpoints", Js.Json.array([
          Js.Json.string("GET /todos"),
          Js.Json.string("GET /todos/:id"),
          Js.Json.string("POST /todos"),
          Js.Json.string("PUT /todos/:id"),
          Js.Json.string("DELETE /todos/:id")
        ]))
      ])),
      ()
    )
  })

Server.withRouter(~port=8000, router)
