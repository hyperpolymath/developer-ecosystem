// WebSocket server example for real-time communication

// WebSocket bindings
module WebSocket = {
  type t
  type event

  @send external send: (t, string) => unit = "send"
  @send external close: t => unit = "close"
  @get external readyState: t => int = "readyState"
}

type client = {
  id: string,
  ws: WebSocket.t,
  joinedAt: float
}

let clients: ref<array<client>> = ref([])
let nextClientId = ref(1)

// Broadcast message to all clients
let broadcast = (message: string, ~excludeId=?, ()): unit => {
  clients.contents->Array.forEach(client => {
    switch excludeId {
    | Some(id) => if client.id !== id {
        WebSocket.send(client.ws, message)
      }
    | None => WebSocket.send(client.ws, message)
    }
  })
}

// Handle WebSocket upgrade request
let handleWebSocket = async (req: Deno.request): promise<Deno.response> => {
  let headers = Deno.Request.headers(req)

  switch Js.Dict.get(headers, "upgrade") {
  | Some(upgrade) when upgrade === "websocket" => {
      // In a real implementation, we'd upgrade the connection here
      // This is a placeholder showing the structure

      Deno.Response.text("WebSocket endpoint - upgrade required", ~status=426, ())
    }
  | _ => {
      Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Expected WebSocket upgrade"))
        ])),
        ~status=400,
        ()
      )
    }
  }
}

// HTTP handler for connection info
let handleInfo = async (_req: Deno.request): promise<Deno.response> => {
  Deno.Response.json(
    Js.Json.object_(Js.Dict.fromArray([
      ("clients", Js.Json.number(Int.toFloat(Array.length(clients.contents)))),
      ("message", Js.Json.string("WebSocket server running"))
    ])),
    ()
  )
}

let router = Router.make()
  ->Router.get("/ws", handleWebSocket)
  ->Router.get("/", handleInfo)

Server.withRouter(~port=8000, router)
