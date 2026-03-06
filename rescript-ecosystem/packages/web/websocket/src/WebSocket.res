// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Type-safe WebSocket client and server for ReScript.
 * Works with Deno's native WebSocket API.
 */

module Client = {
  /** WebSocket ready states */
  type readyState =
    | @as(0) Connecting
    | @as(1) Open
    | @as(2) Closing
    | @as(3) Closed

  /** A WebSocket connection */
  type t

  /** WebSocket close event */
  type closeEvent = {
    code: int,
    reason: string,
    wasClean: bool,
  }

  /** WebSocket message event */
  type messageEvent = {data: string}

  /** WebSocket error event */
  type errorEvent = {message: string}

  /** Create a new WebSocket connection */
  @new
  external make: string => t = "WebSocket"

  /** Create a WebSocket with subprotocols */
  @new
  external makeWithProtocols: (string, array<string>) => t = "WebSocket"

  /** Get the ready state */
  @get
  external readyState: t => readyState = "readyState"

  /** Get the URL */
  @get
  external url: t => string = "url"

  /** Get the selected protocol */
  @get
  external protocol: t => string = "protocol"

  /** Get buffered amount */
  @get
  external bufferedAmount: t => int = "bufferedAmount"

  /** Send a text message */
  @send
  external send: (t, string) => unit = "send"

  /** Send binary data */
  @send
  external sendArrayBuffer: (t, ArrayBuffer.t) => unit = "send"

  /** Close the connection */
  @send
  external close: t => unit = "close"

  /** Close with code and reason */
  @send
  external closeWithCode: (t, int, string) => unit = "close"

  /** Set onopen handler */
  @set
  external onOpen: (t, unit => unit) => unit = "onopen"

  /** Set onclose handler */
  @set
  external onClose: (t, closeEvent => unit) => unit = "onclose"

  /** Set onmessage handler */
  @set
  external onMessage: (t, messageEvent => unit) => unit = "onmessage"

  /** Set onerror handler */
  @set
  external onError: (t, errorEvent => unit) => unit = "onerror"

  /** Check if the connection is open */
  let isOpen = (ws: t): bool => {
    readyState(ws) == Open
  }

  /** Check if the connection is connecting */
  let isConnecting = (ws: t): bool => {
    readyState(ws) == Connecting
  }

  /** Check if the connection is closed */
  let isClosed = (ws: t): bool => {
    let state = readyState(ws)
    state == Closed || state == Closing
  }

  /** Send JSON data */
  let sendJson = (ws: t, data: JSON.t): unit => {
    send(ws, JSON.stringify(data))
  }

  /** Create a promise that resolves when connected */
  let waitForOpen = (ws: t): promise<unit> => {
    Promise.make((resolve, _reject) => {
      if isOpen(ws) {
        resolve()
      } else {
        onOpen(ws, () => resolve())
      }
    })
  }
}

module Server = {
  /** WebSocket upgrade request info */
  type upgradeInfo = {
    url: string,
    headers: Dict.t<string>,
  }

  /** Server-side WebSocket connection */
  type socket = Client.t

  /** Deno HTTP server */
  type server

  /** Request object */
  type request

  /** Response init options */
  type responseInit = {
    status?: int,
    headers?: Dict.t<string>,
  }

  /** Get request URL */
  @get
  external requestUrl: request => string = "url"

  /** Get request headers */
  @get
  external requestHeaders: request => Fetch.Headers.t = "headers"

  /** Upgrade HTTP connection to WebSocket */
  @val @scope("Deno")
  external upgradeWebSocket: request => {"socket": socket, "response": Fetch.Response.t} =
    "upgradeWebSocket"

  /** Serve options */
  type serveOptions = {
    port?: int,
    hostname?: string,
    onListen?: {"port": int, "hostname": string} => unit,
  }

  /** Handler function type */
  type handler = request => promise<Fetch.Response.t>

  /** Serve HTTP/WebSocket */
  @val @scope("Deno")
  external serve: (serveOptions, handler) => server = "serve"

  /** Serve with just handler */
  @val @scope("Deno")
  external serveHandler: handler => server = "serve"

  /** Shutdown server */
  @send
  external shutdown: server => promise<unit> = "shutdown"

  /** Create a WebSocket handler */
  let makeHandler = (
    ~onConnect: socket => unit,
    ~onMessage: (socket, string) => unit,
    ~onClose: (socket, Client.closeEvent) => unit,
    ~onError: (socket, Client.errorEvent) => unit=_ => (),
  ): (request => option<Fetch.Response.t>) => {
    request => {
      let url = requestUrl(request)
      if url->String.includes("websocket") || url->String.endsWith("/ws") {
        let upgrade = upgradeWebSocket(request)
        let socket = upgrade["socket"]

        socket->Client.onOpen(() => onConnect(socket))
        socket->Client.onMessage(event => onMessage(socket, event.data))
        socket->Client.onClose(event => onClose(socket, event))
        socket->Client.onError(event => onError(socket, event))

        Some(upgrade["response"])
      } else {
        None
      }
    }
  }
}

/** Broadcast a message to multiple connections */
let broadcast = (connections: array<Client.t>, message: string): unit => {
  connections->Array.forEach(ws => {
    if Client.isOpen(ws) {
      ws->Client.send(message)
    }
  })
}

/** Broadcast JSON to multiple connections */
let broadcastJson = (connections: array<Client.t>, data: JSON.t): unit => {
  broadcast(connections, JSON.stringify(data))
}
