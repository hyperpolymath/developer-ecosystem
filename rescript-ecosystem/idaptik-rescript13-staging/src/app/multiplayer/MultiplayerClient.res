// SPDX-License-Identifier: PMPL-1.0-or-later
// MultiplayerClient.res  Game multiplayer client
//
// High-level multiplayer interface that wraps PhoenixSocket.
// Provides game-specific operations:
//   - Session management (create/join/leave)
//   - Co-op player position sync
//   - VM instruction relay between co-op partners
//   - Covert link sharing
//   - In-game chat
//   - Event callbacks for game integration

// --- Types ---

type playerRole =
  | Hacker // Primary player  executes VM instructions, hacks devices
  | Observer // Support player  monitors cameras, shares covert link discoveries

type coopPlayer = {
  id: string,
  role: playerRole,
  mutable x: float,
  mutable y: float,
  mutable lastSeen: float,
}

type chatMessage = {
  playerId: string,
  message: string,
  timestamp: float,
}

type multiplayerState =
  | Offline // Not connected to sync server
  | InLobby // Connected, not in a session
  | InSession(string) // In a game session (session ID)

// Event callbacks the game can register
type eventHandlers = {
  mutable onPlayerJoined: option<coopPlayer => unit>,
  mutable onPlayerLeft: option<string => unit>,
  mutable onPlayerMoved: option<(string, float, float) => unit>,
  mutable onVMExecute: option<(string, string, string, array<string>) => unit>,
  mutable onVMUndo: option<(string, string) => unit>,
  mutable onVMState: option<(string, string, JSON.t) => unit>,
  mutable onCovertLinkDiscovered: option<(string, string) => unit>,
  mutable onCovertLinkActivated: option<(string, string) => unit>,
  mutable onCovertLinkCoopRequest: option<(string, string) => unit>,
  mutable onDeviceAccessed: option<(string, string) => unit>,
  mutable onChat: option<chatMessage => unit>,
  mutable onAlertChanged: option<(string, string) => unit>,
  mutable onStateChange: option<multiplayerState => unit>,
}

type t = {
  mutable socket: option<PhoenixSocket.t>,
  mutable gameChannel: option<PhoenixSocket.channel>,
  mutable state: multiplayerState,
  mutable playerId: string,
  mutable role: playerRole,
  mutable sessionId: option<string>,
  coopPlayers: dict<coopPlayer>,
  chatHistory: array<chatMessage>,
  handlers: eventHandlers,
  mutable serverUrl: string,
}

// --- Helpers ---

let roleToString = (role: playerRole): string => {
  switch role {
  | Hacker => "hacker"
  | Observer => "observer"
  }
}

let roleFromString = (s: string): playerRole => {
  switch s {
  | "observer" => Observer
  | _ => Hacker
  }
}

let jsonString = (s: string): JSON.t => JSON.Encode.string(s)

let makePayload = (pairs: array<(string, JSON.t)>): JSON.t => {
  let obj = Dict.make()
  Array.forEach(pairs, ((k, v)) => Dict.set(obj, k, v))
  JSON.Encode.object(obj)
}

let getJsonString = (json: JSON.t, key: string): string => {
  switch JSON.Decode.object(json) {
  | Some(obj) => Dict.get(obj, key)->Option.flatMap(x => JSON.Decode.string(x))->Option.getOr("")
  | None => ""
  }
}

let getJsonFloat = (json: JSON.t, key: string): float => {
  switch JSON.Decode.object(json) {
  | Some(obj) => Dict.get(obj, key)->Option.flatMap(x => JSON.Decode.float(x))->Option.getOr(0.0)
  | None => 0.0
  }
}

let getJsonArray = (json: JSON.t, key: string): array<JSON.t> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    Dict.get(obj, key)
    ->Option.flatMap(x =>
      switch JSON.Classify.classify(x) {
      | JSON.Classify.Array(arr) => Some(arr)
      | _ => None
      }
    )
    ->Option.getOr([])
  | None => []
  }
}

// --- Create client ---

// Base URL without query params. vsn=2.0.0 and player_id are appended at
// connect time so the player ID is always current (see connect/1 below).
let defaultServerUrl = "ws://localhost:4000/socket/websocket"

let make = (
  ~serverUrl: string=defaultServerUrl,
  ~playerId: string="player_1",
  ~role: playerRole=Hacker,
): t => {
  socket: None,
  gameChannel: None,
  state: Offline,
  playerId,
  role,
  sessionId: None,
  coopPlayers: Dict.make(),
  chatHistory: [],
  handlers: {
    onPlayerJoined: None,
    onPlayerLeft: None,
    onPlayerMoved: None,
    onVMExecute: None,
    onVMUndo: None,
    onVMState: None,
    onCovertLinkDiscovered: None,
    onCovertLinkActivated: None,
    onCovertLinkCoopRequest: None,
    onDeviceAccessed: None,
    onChat: None,
    onAlertChanged: None,
    onStateChange: None,
  },
  serverUrl,
}

let notifyState = (client: t) => {
  switch client.handlers.onStateChange {
  | Some(cb) => cb(client.state)
  | None => ()
  }
}

// --- Connection ---

let connect = (client: t) => {
  // Append vsn=2.0.0 so Phoenix negotiates the V2 array wire format, and
  // player_id so the UserSocket assigns a stable identity to this connection.
  let url = `${client.serverUrl}?vsn=2.0.0&player_id=${client.playerId}`
  let sock = PhoenixSocket.make(~url, ~onStateChange=state => {
    switch state {
    | PhoenixSocket.Connected => {
        client.state = InLobby
        notifyState(client)
      }
    | PhoenixSocket.Disconnected => {
        client.state = Offline
        notifyState(client)
      }
    | PhoenixSocket.Connecting => ()
    }
  })
  client.socket = Some(sock)
  PhoenixSocket.connect(sock)
}

let disconnect = (client: t) => {
  switch client.socket {
  | Some(sock) => PhoenixSocket.disconnect(sock)
  | None => ()
  }
  client.socket = None
  client.gameChannel = None
  client.state = Offline
  notifyState(client)
}

// --- Session management ---

let setupChannelHandlers = (client: t, ch: PhoenixSocket.channel) => {
  // Player joined
  PhoenixSocket.on(ch, ~event="player:joined", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let prole = getJsonString(payload, "role")
    let player: coopPlayer = {
      id: pid,
      role: roleFromString(prole),
      x: 0.0,
      y: 0.0,
      lastSeen: Date.now(),
    }
    Dict.set(client.coopPlayers, pid, player)
    switch client.handlers.onPlayerJoined {
    | Some(cb) => cb(player)
    | None => ()
    }
  })

  // Player left
  PhoenixSocket.on(ch, ~event="player:left", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    Dict.delete(client.coopPlayers, pid)
    switch client.handlers.onPlayerLeft {
    | Some(cb) => cb(pid)
    | None => ()
    }
  })

  // Player position
  PhoenixSocket.on(ch, ~event="position", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let x = getJsonFloat(payload, "x")
    let y = getJsonFloat(payload, "y")
    switch Dict.get(client.coopPlayers, pid) {
    | Some(player) => {
        player.x = x
        player.y = y
        player.lastSeen = Date.now()
      }
    | None => ()
    }
    switch client.handlers.onPlayerMoved {
    | Some(cb) => cb(pid, x, y)
    | None => ()
    }
  })

  // VM instruction execution from partner
  PhoenixSocket.on(ch, ~event="vm:execute", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let instr = getJsonString(payload, "instruction")
    let deviceId = getJsonString(payload, "device_id")
    let args =
      getJsonArray(payload, "args")->Array.map(j => JSON.Decode.string(j)->Option.getOr(""))
    switch client.handlers.onVMExecute {
    | Some(cb) => cb(pid, instr, deviceId, args)
    | None => ()
    }
  })

  // VM undo from partner
  PhoenixSocket.on(ch, ~event="vm:undo", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let deviceId = getJsonString(payload, "device_id")
    switch client.handlers.onVMUndo {
    | Some(cb) => cb(pid, deviceId)
    | None => ()
    }
  })

  // VM state sync
  PhoenixSocket.on(ch, ~event="vm:state", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let deviceId = getJsonString(payload, "device_id")
    let state = switch JSON.Decode.object(payload) {
    | Some(obj) => Dict.get(obj, "state")->Option.getOr(JSON.Encode.null)
    | None => JSON.Encode.null
    }
    switch client.handlers.onVMState {
    | Some(cb) => cb(pid, deviceId, state)
    | None => ()
    }
  })

  // Bebop connection events (ADR-0010)
  PhoenixSocket.on(ch, ~event="bebop:discovered", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let connId = getJsonString(payload, "connection_id")
    switch client.handlers.onCovertLinkDiscovered {
    | Some(cb) => cb(pid, connId)
    | None => ()
    }
  })

  PhoenixSocket.on(ch, ~event="bebop:activated", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let connId = getJsonString(payload, "connection_id")
    switch client.handlers.onCovertLinkActivated {
    | Some(cb) => cb(pid, connId)
    | None => ()
    }
  })

  PhoenixSocket.on(ch, ~event="bebop:coop_request", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let connId = getJsonString(payload, "connection_id")
    switch client.handlers.onCovertLinkCoopRequest {
    | Some(cb) => cb(pid, connId)
    | None => ()
    }
  })

  PhoenixSocket.on(ch, ~event="bebop:coop_accept", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let connId = getJsonString(payload, "connection_id")
    // Note: server typically broadcasts bebop:activated after coop_accept
    let _ = pid
    let _ = connId
  })

  // Device access
  PhoenixSocket.on(ch, ~event="device:accessed", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let deviceId = getJsonString(payload, "device_id")
    switch client.handlers.onDeviceAccessed {
    | Some(cb) => cb(pid, deviceId)
    | None => ()
    }
  })

  // Chat
  PhoenixSocket.on(ch, ~event="chat", ~handler=payload => {
    let msg: chatMessage = {
      playerId: getJsonString(payload, "player_id"),
      message: getJsonString(payload, "message"),
      timestamp: getJsonFloat(payload, "timestamp"),
    }
    ignore(Array.push(client.chatHistory, msg))
    switch client.handlers.onChat {
    | Some(cb) => cb(msg)
    | None => ()
    }
  })

  // Alert changes
  PhoenixSocket.on(ch, ~event="alert:changed", ~handler=payload => {
    let pid = getJsonString(payload, "player_id")
    let level = getJsonString(payload, "level")
    switch client.handlers.onAlertChanged {
    | Some(cb) => cb(pid, level)
    | None => ()
    }
  })
}

let joinSession = (client: t, ~sessionId: string) => {
  switch client.socket {
  | Some(sock) => {
      let ch = PhoenixSocket.channel(sock, ~topic=`game:${sessionId}`)
      client.gameChannel = Some(ch)
      client.sessionId = Some(sessionId)

      setupChannelHandlers(client, ch)

      // Handle join response (session state)
      PhoenixSocket.on(ch, ~event="phx_reply", ~handler=payload => {
        let status = getJsonString(payload, "status")
        if status == "ok" {
          switch JSON.Decode.object(payload) {
          | Some(obj) =>
            switch Dict.get(obj, "response") {
            | Some(resp) =>
              switch JSON.Decode.object(resp) {
              | Some(session) => {
                  // Process players already in session
                  let players = getJsonArray(JSON.Encode.object(session), "players")
                  // ... (logic to sync initial state would go here)
                  let _ = players
                }
              | None => ()
              }
            | None => ()
            }
          | None => ()
          }
        }
      })

      let payload = makePayload([
        ("player_id", jsonString(client.playerId)),
        ("role", jsonString(roleToString(client.role))),
      ])
      PhoenixSocket.joinChannel(sock, ch, ~payload)

      client.state = InSession(sessionId)
      notifyState(client)
    }
  | None => ()
  }
}

let leaveSession = (client: t) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) => {
      PhoenixSocket.leaveChannel(sock, ch)
      client.gameChannel = None
      client.sessionId = None
      client.state = InLobby
      // Clear co-op state
      let keys = Dict.keysToArray(client.coopPlayers)
      Array.forEach(keys, k => Dict.delete(client.coopPlayers, k))
      notifyState(client)
    }
  | _ => ()
  }
}

// --- Outbound messages ---

let sendPosition = (client: t, ~x: float, ~y: float) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="position",
      ~payload=makePayload([("x", JSON.Encode.float(x)), ("y", JSON.Encode.float(y))]),
    )
  | _ => ()
  }
}

let sendVMExecute = (
  client: t,
  ~instruction: string,
  ~deviceId: string,
  ~args: array<string>=[],
) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="vm:execute",
      ~payload=makePayload([
        ("instruction", jsonString(instruction)),
        ("device_id", jsonString(deviceId)),
        ("args", JSON.Encode.array(Array.map(args, jsonString))),
      ]),
    )
  | _ => ()
  }
}

let sendVMUndo = (client: t, ~deviceId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="vm:undo",
      ~payload=makePayload([("device_id", jsonString(deviceId))]),
    )
  | _ => ()
  }
}

let sendVMState = (client: t, ~deviceId: string, ~state: JSON.t) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="vm:state",
      ~payload=makePayload([("device_id", jsonString(deviceId)), ("state", state)]),
    )
  | _ => ()
  }
}

let sendVMSyncRequest = (client: t, ~deviceId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="vm:sync_request",
      ~payload=makePayload([("device_id", jsonString(deviceId))]),
    )
  | _ => ()
  }
}

let sendCovertLinkDiscovered = (client: t, ~connectionId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="bebop:discovered",
      ~payload=makePayload([("connection_id", jsonString(connectionId))]),
    )
  | _ => ()
  }
}

let sendCovertLinkActivated = (client: t, ~connectionId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="bebop:activated",
      ~payload=makePayload([("connection_id", jsonString(connectionId))]),
    )
  | _ => ()
  }
}

let sendCovertLinkCoopRequest = (client: t, ~connectionId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="bebop:coop_request",
      ~payload=makePayload([("connection_id", jsonString(connectionId))]),
    )
  | _ => ()
  }
}

let sendCovertLinkCoopAccept = (client: t, ~connectionId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="bebop:coop_accept",
      ~payload=makePayload([("connection_id", jsonString(connectionId))]),
    )
  | _ => ()
  }
}

let sendDeviceAccessed = (client: t, ~deviceId: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="device:accessed",
      ~payload=makePayload([("device_id", jsonString(deviceId))]),
    )
  | _ => ()
  }
}

let sendChat = (client: t, ~message: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="chat",
      ~payload=makePayload([("message", jsonString(message))]),
    )
  | _ => ()
  }
}

let sendAlertChanged = (client: t, ~level: string) => {
  switch (client.socket, client.gameChannel) {
  | (Some(sock), Some(ch)) =>
    PhoenixSocket.push(
      sock,
      ch,
      ~event="alert:changed",
      ~payload=makePayload([("level", jsonString(level))]),
    )
  | _ => ()
  }
}

// --- Query state ---

let getCoopPlayers = (client: t): array<coopPlayer> => {
  Dict.valuesToArray(client.coopPlayers)
}

let getCoopPartner = (client: t): option<coopPlayer> => {
  Dict.valuesToArray(client.coopPlayers)-> Array.find(p => p.id != client.playerId)
}

let stateToString = (state: multiplayerState): string => {
  switch state {
  | Offline => "OFFLINE"
  | InLobby => "LOBBY"
  | InSession(id) => `SESSION:${id}`
  }
}

// --- Terminal display ---

let formatStatus = (client: t): string => {
  let connStr = stateToString(client.state)
  let playerStr = `Player: ${client.playerId} (${roleToString(client.role)})`
  let coopStr = switch getCoopPartner(client) {
  | Some(partner) =>
    `\nCo-op partner: ${partner.id} (${roleToString(partner.role)}) at (${Float.toString(
        partner.x,
      )}, ${Float.toString(partner.y)})`
  | None => "\nNo co-op partner connected."
  }
  let sessionStr = switch client.sessionId {
  | Some(id) => `\nSession: ${id}`
  | None => ""
  }
  `MULTIPLAYER STATUS: ${connStr}\n${playerStr}${sessionStr}${coopStr}`
}

let formatChat = (client: t, ~limit: int=20): string => {
  let len = Array.length(client.chatHistory)
  let start = if len > limit {
    len - limit
  } else {
    0
  }
  let recent = Array.slice(client.chatHistory, ~start, ~end=len)
  if Array.length(recent) == 0 {
    "No messages yet."
  } else {
    Array.map(recent, msg => `[${msg.playerId}] ${msg.message}`)->Array.join("\n")
  }
}
