// SPDX-License-Identifier: PMPL-1.0-or-later
// PhoenixSocket.res  Phoenix Channel protocol client for browser WebSocket
//
// Implements the Phoenix V2 WebSocket wire protocol:
//   - Array message framing: [join_ref, ref, topic, event, payload]
//   - Negotiated via ?vsn=2.0.0 query parameter
//   - Join/leave lifecycle with joinRef tracking
//   - Heartbeat keepalive (every 30 s)
//   - Reconnection with exponential backoff (cap 30 s)
//   - Channel multiplexing over single socket
//
// V2 vs V1 summary (V1 is a JSON object; V2 is a JSON array):
//   V1: {"topic":T,"event":E,"payload":P,"ref":R}
//   V2: [join_ref, message_ref, topic, event, payload]
// The server negotiates V2 when the client connects with ?vsn=2.0.0.
//
// This is a pure ReScript implementation — no phoenix.js dependency.

// --- External bindings ---

type webSocket
@new external createWebSocket: string => webSocket = "WebSocket"
@send external wsSend: (webSocket, string) => unit = "send"
@set external wsOnOpen: (webSocket, unit => unit) => unit = "onopen"
@set external wsOnClose: (webSocket, {..} => unit) => unit = "onclose"
@set external wsOnError: (webSocket, {..} => unit) => unit = "onerror"
@set external wsOnMessage: (webSocket, {"data": string} => unit) => unit = "onmessage"
@get external wsReadyState: webSocket => int = "readyState"
@send external wsClose: webSocket => unit = "close"

@val external setTimeout: (unit => unit, int) => int = "setTimeout"
@val external setInterval: (unit => unit, int) => int = "setInterval"
@val external clearInterval: int => unit = "clearInterval"

// --- Phoenix V2 protocol types ---

// Phoenix V2 wire message: [join_ref, message_ref, topic, event, payload]
// join_ref — the ref used when the channel was joined (None for socket-level messages)
// ref      — unique per-message reference for correlation
type phoenixMessage = {
  topic: string,
  event: string,
  payload: JSON.t,
  ref: option<string>,
  joinRef: option<string>,
}

type channelState =
  | Closed
  | Joining
  | Joined
  | Leaving

type messageHandler = JSON.t => unit

type channel = {
  topic: string,
  mutable state: channelState,
  handlers: dict<array<messageHandler>>,
  mutable joinRef: option<string>,
}

type connectionState =
  | Disconnected
  | Connecting
  | Connected

type t = {
  url: string,
  mutable socket: option<webSocket>,
  mutable state: connectionState,
  mutable refCounter: int,
  channels: dict<channel>,
  mutable heartbeatTimer: option<int>,
  mutable reconnectAttempts: int,
  mutable onStateChange: option<connectionState => unit>,
}

// --- Helpers ---

let nextRef = (socket: t): string => {
  socket.refCounter = socket.refCounter + 1
  Int.toString(socket.refCounter)
}

// Encode a Phoenix V2 message as a JSON array:
//   [join_ref_or_null, ref_or_null, topic, event, payload]
let encodeMessage = (msg: phoenixMessage): string => {
  let arr = [
    switch msg.joinRef {
    | Some(r) => JSON.Encode.string(r)
    | None => JSON.Encode.null
    },
    switch msg.ref {
    | Some(r) => JSON.Encode.string(r)
    | None => JSON.Encode.null
    },
    JSON.Encode.string(msg.topic),
    JSON.Encode.string(msg.event),
    msg.payload,
  ]
  JSON.stringify(JSON.Encode.array(arr))
}

// Decode a raw WebSocket frame in Phoenix V2 array format.
// Falls back to None on malformed JSON or wrong structure; errors logged via
// PanicHandler so the game degrades gracefully rather than throwing.
let decodeMessage = (data: string): option<phoenixMessage> => {
  switch SafeJson.parse(data) {
  | Ok(json) =>
    switch JSON.Classify.classify(json) {
    | JSON.Classify.Array(arr) if Array.length(arr) >= 5 => {
        let joinRef = Array.get(arr, 0)->Option.flatMap(JSON.Decode.string)
        let ref = Array.get(arr, 1)->Option.flatMap(JSON.Decode.string)
        let topic = Array.get(arr, 2)->Option.flatMap(JSON.Decode.string)->Option.getOr("")
        let event = Array.get(arr, 3)->Option.flatMap(JSON.Decode.string)->Option.getOr("")
        let payload = Array.get(arr, 4)->Option.getOr(JSON.Encode.null)
        Some({topic, event, payload, ref, joinRef})
      }
    | _ => None
    }
  | Error(err) =>
    PanicHandler.reportProvenError(err, ~severity="Warning")
    None
  }
}

// --- Socket lifecycle ---

let make = (~url: string, ~onStateChange: option<connectionState => unit>=?): t => {
  url,
  socket: None,
  state: Disconnected,
  refCounter: 0,
  channels: Dict.make(),
  heartbeatTimer: None,
  reconnectAttempts: 0,
  onStateChange,
}

let notifyStateChange = (socket: t) => {
  switch socket.onStateChange {
  | Some(cb) => cb(socket.state)
  | None => ()
  }
}

let sendMessage = (socket: t, msg: phoenixMessage) => {
  switch socket.socket {
  | Some(ws) =>
    if wsReadyState(ws) == 1 {
      // OPEN
      wsSend(ws, encodeMessage(msg))
    }
  | None => ()
  }
}

let startHeartbeat = (socket: t) => {
  // Phoenix expects a heartbeat on the "phoenix" topic every 30 seconds.
  // join_ref is None for socket-level (non-channel) messages.
  let timer = setInterval(() => {
    sendMessage(
      socket,
      {
        topic: "phoenix",
        event: "heartbeat",
        payload: JSON.Encode.object(Dict.make()),
        ref: Some(nextRef(socket)),
        joinRef: None,
      },
    )
  }, 30_000)
  socket.heartbeatTimer = Some(timer)
}

let stopHeartbeat = (socket: t) => {
  switch socket.heartbeatTimer {
  | Some(timer) => {
      clearInterval(timer)
      socket.heartbeatTimer = None
    }
  | None => ()
  }
}

// Dispatch an incoming V2 message to the appropriate channel handler.
let dispatchMessage = (socket: t, msg: phoenixMessage) => {
  switch Dict.get(socket.channels, msg.topic) {
  | Some(channel) => {
      // Handle join reply — update channel state on successful join ack
      if msg.event == "phx_reply" && channel.state == Joining {
        let statusOk = switch JSON.Decode.object(msg.payload) {
        | Some(obj) =>
          switch Dict.get(obj, "status") {
          | Some(s) => JSON.Decode.string(s) == Some("ok")
          | None => false
          }
        | None => false
        }
        if statusOk {
          channel.state = Joined
        }
      }

      // Handle phx_close / phx_error — mark channel closed
      if msg.event == "phx_close" || msg.event == "phx_error" {
        channel.state = Closed
      }

      // Dispatch to all registered handlers for this event
      switch Dict.get(channel.handlers, msg.event) {
      | Some(handlers) => Array.forEach(handlers, h => h(msg.payload))
      | None => ()
      }
    }
  | None => ()
  }
}

let rec connect = (socket: t) => {
  socket.state = Connecting
  notifyStateChange(socket)

  let ws = createWebSocket(socket.url)
  socket.socket = Some(ws)

  wsOnOpen(ws, () => {
    socket.state = Connected
    socket.reconnectAttempts = 0
    notifyStateChange(socket)
    startHeartbeat(socket)

    // Rejoin all channels that were previously joined after reconnect.
    // join_ref == message_ref for join messages (Phoenix convention).
    Dict.toArray(socket.channels)->Array.forEach(((_topic, channel)) => {
      if channel.state == Joined || channel.state == Joining {
        channel.state = Joining
        let ref = nextRef(socket)
        channel.joinRef = Some(ref)
        sendMessage(
          socket,
          {
            topic: channel.topic,
            event: "phx_join",
            payload: JSON.Encode.object(Dict.make()),
            ref: Some(ref),
            joinRef: Some(ref),
          },
        )
      }
    })
  })

  wsOnClose(ws, _evt => {
    socket.state = Disconnected
    stopHeartbeat(socket)
    notifyStateChange(socket)

    // Reconnect with exponential backoff (cap at 30 s)
    let backoffMs = Float.toInt(
      1000.0 *. Math.pow(2.0, ~exp=Int.toFloat(socket.reconnectAttempts)),
    )
    let delay = if backoffMs < 30_000 {
      backoffMs
    } else {
      30_000
    }
    socket.reconnectAttempts = socket.reconnectAttempts + 1
    let _ = setTimeout(() => connect(socket), delay)
  })

  wsOnError(ws, _evt => {
    // Error will trigger onclose — no additional handling needed here
    ()
  })

  wsOnMessage(ws, evt => {
    switch decodeMessage(evt["data"]) {
    | Some(msg) => dispatchMessage(socket, msg)
    | None => ()
    }
  })
}

let disconnect = (socket: t) => {
  stopHeartbeat(socket)
  switch socket.socket {
  | Some(ws) => wsClose(ws)
  | None => ()
  }
  socket.state = Disconnected
  socket.socket = None
  notifyStateChange(socket)
}

// --- Channel operations ---

let channel = (socket: t, ~topic: string): channel => {
  let ch: channel = {
    topic,
    state: Closed,
    handlers: Dict.make(),
    joinRef: None,
  }
  Dict.set(socket.channels, topic, ch)
  ch
}

// Join a channel. For join messages, join_ref == message_ref (Phoenix V2 spec).
let joinChannel = (socket: t, ch: channel, ~payload: JSON.t=JSON.Encode.object(Dict.make())) => {
  ch.state = Joining
  let ref = nextRef(socket)
  ch.joinRef = Some(ref)
  sendMessage(
    socket,
    {
      topic: ch.topic,
      event: "phx_join",
      payload,
      ref: Some(ref),
      joinRef: Some(ref),
    },
  )
}

let leaveChannel = (socket: t, ch: channel) => {
  ch.state = Leaving
  sendMessage(
    socket,
    {
      topic: ch.topic,
      event: "phx_leave",
      payload: JSON.Encode.object(Dict.make()),
      ref: Some(nextRef(socket)),
      joinRef: ch.joinRef,
    },
  )
  ch.state = Closed
  Dict.delete(socket.channels, ch.topic)
}

let on = (ch: channel, ~event: string, ~handler: messageHandler) => {
  let existing = Dict.get(ch.handlers, event)->Option.getOr([])
  Dict.set(ch.handlers, event, Array.concat(existing, [handler]))
}

// Push an event to the server. join_ref carries the channel's original join ref
// so Phoenix can route the message to the correct channel process.
let push = (socket: t, ch: channel, ~event: string, ~payload: JSON.t) => {
  if ch.state == Joined {
    sendMessage(
      socket,
      {
        topic: ch.topic,
        event,
        payload,
        ref: Some(nextRef(socket)),
        joinRef: ch.joinRef,
      },
    )
  }
}

// --- Convenience ---

let isConnected = (socket: t): bool => socket.state == Connected

let stateToString = (state: connectionState): string => {
  switch state {
  | Disconnected => "DISCONNECTED"
  | Connecting => "CONNECTING"
  | Connected => "CONNECTED"
  }
}
