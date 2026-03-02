// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Echo Client Example
 *
 * Connects to a WebSocket echo server, sends a message,
 * and prints the response.
 *
 * Run: deno run examples/echo_client.res.js
 */

open WebSocket

let main = async () => {
  let url = "wss://echo.websocket.org"
  Console.log(`Connecting to ${url}...`)

  let ws = Client.make(url)

  // Wait for connection
  await ws->Client.waitForOpen
  Console.log("Connected!")

  // Set up message handler
  ws->Client.onMessage(event => {
    Console.log(`Received: ${event.data}`)
    // Close after receiving echo
    ws->Client.closeWithCode(1000, "Done")
  })

  // Set up close handler
  ws->Client.onClose(event => {
    Console.log(`Connection closed: ${event.code->Int.toString} - ${event.reason}`)
  })

  // Set up error handler
  ws->Client.onError(error => {
    Console.error(`Error: ${error.message}`)
  })

  // Send a test message
  let message = "Hello from ReScript WebSocket!"
  Console.log(`Sending: ${message}`)
  ws->Client.send(message)
}

let _ = main()
