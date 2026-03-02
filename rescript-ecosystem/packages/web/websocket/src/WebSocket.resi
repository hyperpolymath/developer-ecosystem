// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Type-safe WebSocket client and server for ReScript.
 */

module Client: {
  type readyState =
    | @as(0) Connecting
    | @as(1) Open
    | @as(2) Closing
    | @as(3) Closed

  type t

  type closeEvent = {
    code: int,
    reason: string,
    wasClean: bool,
  }

  type messageEvent = {data: string}
  type errorEvent = {message: string}

  let make: string => t
  let makeWithProtocols: (string, array<string>) => t
  let readyState: t => readyState
  let url: t => string
  let protocol: t => string
  let bufferedAmount: t => int
  let send: (t, string) => unit
  let sendArrayBuffer: (t, ArrayBuffer.t) => unit
  let close: t => unit
  let closeWithCode: (t, int, string) => unit
  let onOpen: (t, unit => unit) => unit
  let onClose: (t, closeEvent => unit) => unit
  let onMessage: (t, messageEvent => unit) => unit
  let onError: (t, errorEvent => unit) => unit
  let isOpen: t => bool
  let isConnecting: t => bool
  let isClosed: t => bool
  let sendJson: (t, JSON.t) => unit
  let waitForOpen: t => promise<unit>
}

module Server: {
  type socket = Client.t
  type server
  type request

  type serveOptions = {
    port?: int,
    hostname?: string,
    onListen?: {"port": int, "hostname": string} => unit,
  }

  type handler = request => promise<Fetch.Response.t>

  let upgradeWebSocket: request => {"socket": socket, "response": Fetch.Response.t}
  let serve: (serveOptions, handler) => server
  let serveHandler: handler => server
  let shutdown: server => promise<unit>
  let requestUrl: request => string

  let makeHandler: (
    ~onConnect: socket => unit,
    ~onMessage: (socket, string) => unit,
    ~onClose: (socket, Client.closeEvent) => unit,
    ~onError: (socket, Client.errorEvent) => unit=?,
  ) => (request => option<Fetch.Response.t>)
}

let broadcast: (array<Client.t>, string) => unit
let broadcastJson: (array<Client.t>, JSON.t) => unit
