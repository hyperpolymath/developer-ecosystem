// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Chat Server Example
 *
 * A simple WebSocket chat server that broadcasts messages to all connected clients.
 *
 * Run: deno run --allow-net examples/chat_server.res.js
 * Connect: websocat ws://localhost:8080/ws
 */

open WebSocket

// Track all connected clients
let clients: ref<array<Client.t>> = ref([])

// Remove a client from the list
let removeClient = (client: Client.t): unit => {
  clients := clients.contents->Array.filter(c => c !== client)
}

// Create the WebSocket handler
let wsHandler = Server.makeHandler(
  ~onConnect=socket => {
    let clientCount = clients.contents->Array.length + 1
    Console.log(`Client connected (${clientCount->Int.toString} total)`)

    // Add to clients list
    clients := clients.contents->Array.concat([socket])

    // Send welcome message
    socket->Client.send("Welcome to the chat!")

    // Notify others
    broadcast(
      clients.contents->Array.filter(c => c !== socket),
      "[System] A new user has joined the chat",
    )
  },
  ~onMessage=(socket, data) => {
    Console.log(`Message: ${data}`)

    // Broadcast to all other clients
    let others = clients.contents->Array.filter(c => c !== socket)
    broadcast(others, data)

    // Echo back to sender with prefix
    socket->Client.send(`[You] ${data}`)
  },
  ~onClose=(socket, event) => {
    Console.log(`Client disconnected: ${event.code->Int.toString}`)
    removeClient(socket)

    // Notify others
    broadcast(clients.contents, "[System] A user has left the chat")
  },
  ~onError=(socket, error) => {
    Console.error(`Client error: ${error.message}`)
    removeClient(socket)
  },
)

// HTTP handler that upgrades WebSocket requests
let handler = async (request: Server.request): Fetch.Response.t => {
  switch wsHandler(request) {
  | Some(response) => response
  | None => {
      // Regular HTTP response for non-WebSocket requests
      let html = `
<!DOCTYPE html>
<html>
<head><title>Chat Server</title></head>
<body>
  <h1>WebSocket Chat Server</h1>
  <p>Connect using a WebSocket client to ws://localhost:8080/ws</p>
  <p>Or use: <code>websocat ws://localhost:8080/ws</code></p>
</body>
</html>`
      Fetch.Response.make(html, ~init={headers: Dict.fromArray([("content-type", "text/html")])})
    }
  }
}

// Start the server
let _ = Server.serve(
  {
    port: 8080,
    hostname: "localhost",
    onListen: info => {
      Console.log(`Chat server running at http://${info["hostname"]}:${info["port"]->Int.toString}`)
      Console.log("WebSocket endpoint: ws://localhost:8080/ws")
    },
  },
  handler,
)
