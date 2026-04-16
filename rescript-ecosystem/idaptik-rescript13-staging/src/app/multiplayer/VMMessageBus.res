// SPDX-License-Identifier: PMPL-1.0-or-later
// VMMessageBus.res  Bridge between VM I/O ports and game events
//
// The VM communicates through named ports (SEND/RECV instructions).
// This bus:
//   1. Reads VM output port buffers  dispatches as game events
//   2. Writes incoming game events  VM input port buffers
//   3. Relays co-op events through the multiplayer client
//   4. Manages per-device VM instances for Tier 5 networking
//
// This is the key integration point where reversible computation
// becomes a multiplayer mechanic. When player A executes an instruction
// on device X, the bus:
//   - Reads any SEND output from the VM
//   - Routes it to the target device (via game events)
//   - If co-op, relays to partner via WebSocket channel
//   - Partner can UNDO the instruction (competitive mode)
//
// Port naming convention (from shared/PortNames.res):
//   console        terminal text output
//   display        HUD/overlay messages
//   firewall       firewall ACL control
//   coop:sync      state synchronisation with partner
//   coop:chat      player-to-player messages
//   coop:item      item passing between players
//   covert:<id>    covert link data channel

// --- Port output buffer ---
//
// VMBridge currently supports Tiers 0-2 only (no SEND/RECV instructions yet).
// Instead of reading from the VM's register/memory model, we maintain a
// dedicated per-port output buffer that:
//   - Game code can push to via writePortOutput() when a terminal command,
//     network event, or covert-link action produces port-addressed data.
//   - readPortOutput() drains (destructive read) — each frame the bus
//     flushes any accumulated values and routes them to game systems.
//
// When Tier 4 SEND/RECV are added to VMBridge, the SEND handler will call
// writePortOutput() directly, and this buffer becomes the canonical output
// path for both scripted and VM-generated port messages.
//
// Buffer layout:  Dict<portName, array<int>>
// Each port accumulates values in arrival order.  readPortOutput drains
// the entire port slice in one call (FIFO consumption).

type portMessage = {
  port: string,
  values: array<int>,
}

// Module-level singleton port output buffer.
// Keyed by port name (e.g. "console", "coop:sync", "covert:conn-1").
let portOutputBuffer: dict<array<int>> = Dict.make()

// Append values to a port's output buffer.
// Called by game code (terminal handlers, network events, covert-link
// activation) when it wants the message bus to route data on the next
// call to readPortOutput / flushPortMessages.
let writePortOutput = (port: string, values: array<int>): unit => {
  let existing = Dict.get(portOutputBuffer, port)->Option.getOr([])
  Dict.set(portOutputBuffer, port, Array.concat(existing, values))
}

// Read and drain all pending output from the named port.
//
// The `vmState` parameter is accepted for forward-compatibility: once
// VMBridge gains SEND/RECV (Tier 4), the VM's own output buffers will
// also be drained here.  For now only the module-level buffer is read.
//
// Returns a snapshot of the buffered values and resets the port's slice
// to [] so each value is delivered exactly once.
let readPortOutput = (vmState: VMBridge.vmState, port: string): array<int> => {
  let _ = vmState // Reserved for Tier 4 SEND/RECV integration
  switch Dict.get(portOutputBuffer, port) {
  | None => []
  | Some(values) =>
    // Drain: replace the port's slice with an empty array before returning
    // so concurrent callers (if any) get distinct snapshots.
    Dict.set(portOutputBuffer, port, [])
    values
  }
}

// --- Message dispatch: route port messages to game systems ---

type messageTarget =
  | Console // Terminal text output
  | Display // HUD overlay
  | Firewall // Firewall ACL modification
  | CoopSync // State sync with partner
  | CoopChat // Chat message to partner
  | CoopItem // Item transfer to partner
  | CovertLinkChannel // Data through a covert link
  | DevicePort // Generic device port

let classifyPort = (port: string): messageTarget => {
  if port == "console" {
    Console
  } else if port == "display" {
    Display
  } else if port == "firewall" {
    Firewall
  } else if port == "coop:sync" {
    CoopSync
  } else if port == "coop:chat" {
    CoopChat
  } else if port == "coop:item" {
    CoopItem
  } else if String.startsWith(port, "covert:") {
    CovertLinkChannel
  } else {
    DevicePort
  }
}

// --- Co-op event queue ---
// Events that need to be sent to the co-op partner via the multiplayer client.
// The game loop drains this queue each frame.

type coopEvent =
  | VMExecuted({deviceId: string, instruction: string, args: array<string>})
  | VMUndone({deviceId: string})
  | StateSync({deviceId: string, registers: array<(string, int)>})
  | PortData({port: string, values: array<int>})
  | CovertLinkFound({connectionId: string})
  | CovertLinkActivated({connectionId: string})
  | ChatSent({message: string})

let coopOutbox: array<coopEvent> = []

let enqueueCoopEvent = (event: coopEvent): unit => {
  let _ = Array.push(coopOutbox, event)
}

// Drain the outbox and send via multiplayer client
let flushCoopOutbox = (): unit => {
  let client = MultiplayerGlobal.client
  Array.forEach(coopOutbox, event => {
    switch event {
    | VMExecuted({deviceId, instruction, args}) =>
      MultiplayerClient.sendVMExecute(client, ~instruction, ~deviceId, ~args)
    | VMUndone({deviceId}) => MultiplayerClient.sendVMUndo(client, ~deviceId)
    | StateSync({deviceId, registers}) => {
        let obj = Dict.make()
        Array.forEach(registers, ((k, v)) => Dict.set(obj, k, JSON.Encode.float(Int.toFloat(v))))
        MultiplayerClient.sendVMState(client, ~deviceId, ~state=JSON.Encode.object(obj))
      }
    | PortData(_) => () // Port data goes through VM state sync
    | CovertLinkFound({connectionId}) =>
      MultiplayerClient.sendCovertLinkDiscovered(client, ~connectionId)
    | CovertLinkActivated({connectionId}) =>
      MultiplayerClient.sendCovertLinkActivated(client, ~connectionId)
    | ChatSent({message}) => MultiplayerClient.sendChat(client, ~message)
    }
  })
  // Clear outbox
  let len = Array.length(coopOutbox)
  if len > 0 {
    let _ = Array.splice(coopOutbox, ~start=0, ~remove=len, ~insert=[])
  }
}

// --- Inbound event processing ---
// Handle events received from co-op partner via the multiplayer client.

type inboundHandler = {
  mutable onRemoteVMExecute: option<(string, string, array<string>) => unit>,
  mutable onRemoteVMUndo: option<string => unit>,
  mutable onRemoteStateSync: option<(string, JSON.t) => unit>,
  mutable onRemoteCovertLinkDiscovered: option<string => unit>,
  mutable onRemoteCovertLinkActivated: option<string => unit>,
}

let inboundHandlers: inboundHandler = {
  onRemoteVMExecute: None,
  onRemoteVMUndo: None,
  onRemoteStateSync: None,
  onRemoteCovertLinkDiscovered: None,
  onRemoteCovertLinkActivated: None,
}

// Wire inbound handlers to the multiplayer client
let wireInboundHandlers = (): unit => {
  let client = MultiplayerGlobal.client

  // When partner executes a VM instruction
  client.handlers.onVMExecute = Some(
    (_playerId, instruction, deviceId, args) => {
      switch inboundHandlers.onRemoteVMExecute {
      | Some(cb) => cb(deviceId, instruction, args)
      | None => ()
      }
    },
  )

  // When partner undoes a VM instruction
  client.handlers.onVMUndo = Some(
    (_playerId, deviceId) => {
      switch inboundHandlers.onRemoteVMUndo {
      | Some(cb) => cb(deviceId)
      | None => ()
      }
    },
  )

  // When partner sends full VM state
  client.handlers.onVMState = Some(
    (_playerId, deviceId, state) => {
      switch inboundHandlers.onRemoteStateSync {
      | Some(cb) => cb(deviceId, state)
      | None => ()
      }
    },
  )

  // When partner discovers a covert link
  client.handlers.onCovertLinkDiscovered = Some(
    (_playerId, connId) => {
      // Auto-discover locally too
      switch CovertLink.Registry.get(connId) {
      | Some(conn) => {
          let _ = CovertLink.discover(conn)
        }
      | None => ()
      }
      switch inboundHandlers.onRemoteCovertLinkDiscovered {
      | Some(cb) => cb(connId)
      | None => ()
      }
    },
  )

  // When partner activates a covert link
  client.handlers.onCovertLinkActivated = Some(
    (_playerId, connId) => {
      switch CovertLink.Registry.get(connId) {
      | Some(conn) => {
          let _ = CovertLink.activate(conn)
        }
      | None => ()
      }
      switch inboundHandlers.onRemoteCovertLinkActivated {
      | Some(cb) => cb(connId)
      | None => ()
      }
    },
  )
}

// Wire inbound handlers to execute remote partner actions.
// Uses callback refs to avoid circular dependency with VMNetwork.
let remoteExecuteRef: ref<option<(~deviceId: string, ~instruction: string, ~playerId: string) => option<string>>> = ref(None)
let remoteUndoRef: ref<option<(~deviceId: string, ~playerId: string) => option<string>>> = ref(None)

let wireInboundVMHandlers = (
  ~executeOnDevice: (~deviceId: string, ~instruction: string, ~playerId: string) => option<string>,
  ~undoOnDevice: (~deviceId: string, ~playerId: string) => option<string>,
): unit => {
  remoteExecuteRef := Some(executeOnDevice)
  remoteUndoRef := Some(undoOnDevice)

  // When partner executes a VM instruction, replay it locally
  inboundHandlers.onRemoteVMExecute = Some(
    (deviceId, instruction, _args) => {
      switch remoteExecuteRef.contents {
      | Some(exec) => ignore(exec(~deviceId, ~instruction, ~playerId="remote"))
      | None => ()
      }
    },
  )

  // When partner undoes a VM instruction, undo it locally
  inboundHandlers.onRemoteVMUndo = Some(
    deviceId => {
      switch remoteUndoRef.contents {
      | Some(undo) => ignore(undo(~deviceId, ~playerId="remote"))
      | None => ()
      }
    },
  )
}

// --- Per-frame update ---
// Call from the game loop to process outgoing co-op events.

let update = (_deltaSeconds: float): unit => {
  if MultiplayerGlobal.enabled.contents {
    flushCoopOutbox()
  }
}

// --- Integration hooks ---
// Call these from game code when VM actions happen.

let onLocalVMExecute = (~deviceId: string, ~instruction: string, ~args: array<string>=[]): unit => {
  if MultiplayerGlobal.enabled.contents {
    enqueueCoopEvent(VMExecuted({deviceId, instruction, args}))
  }
}

let onLocalVMUndo = (~deviceId: string): unit => {
  if MultiplayerGlobal.enabled.contents {
    enqueueCoopEvent(VMUndone({deviceId: deviceId}))
  }
}

let onLocalCovertLinkDiscovered = (~connectionId: string): unit => {
  if MultiplayerGlobal.enabled.contents {
    enqueueCoopEvent(CovertLinkFound({connectionId: connectionId}))
  }
}

let onLocalCovertLinkActivated = (~connectionId: string): unit => {
  if MultiplayerGlobal.enabled.contents {
    enqueueCoopEvent(CovertLinkActivated({connectionId: connectionId}))
  }
}

let onLocalStateSync = (~deviceId: string, ~registers: array<(string, int)>): unit => {
  if MultiplayerGlobal.enabled.contents {
    enqueueCoopEvent(StateSync({deviceId, registers}))
  }
}
