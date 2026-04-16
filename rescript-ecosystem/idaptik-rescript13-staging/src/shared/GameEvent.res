// SPDX-License-Identifier: PMPL-1.0-or-later
// GameEvent.res  Cross-component event types
//
// These events flow between components at runtime. The VM emits events
// via I/O ports, the game listens and dispatches to devices, and the
// sync server relays events between players in co-op mode.

// Direction of an event in the game
type direction =
  | PlayerToVM      // Player typed a command, VM executes it
  | VMToGame        // VM sent output via SEND, game renders it
  | GameToDevice    // Game routes an event to a specific device
  | DeviceToPlayer  // Device shows feedback to player
  | PlayerToPlayer  // Co-op: one player sends to another
  | ServerBroadcast // Sync server pushes to all connected clients

// Security alert levels (used by guard AI and firewall)
type alertLevel =
  | Green   // Normal  no suspicion
  | Yellow  // Elevated  guards more attentive
  | Orange  // High  active search, lockdowns possible
  | Red     // Critical  full pursuit, system shutdowns

// Core event types that cross component boundaries
type t =
  // VM events (from SEND/RECV ports)
  | VMInstructionExecuted({instruction: string, args: array<string>})
  | VMInstructionUndone({instruction: string})
  | VMStateChanged({registers: array<(string, int)>})
  | VMPuzzleSolved({name: string, moves: int, maxMoves: int})
  | VMPortOutput({port: string, value: int})

  // Device events
  | DeviceAccessed({deviceId: string, deviceType: string})
  | DeviceLocked({deviceId: string, reason: string})
  | DeviceUnlocked({deviceId: string})
  | FirewallBlocked({ruleId: string, packet: string})
  | FirewallBypassed({deviceId: string})

  // Network events
  | NetworkScan({sourceDevice: string, targetSubnet: string})
  | SSHConnected({from: string, to: string})
  | SSHDisconnected({from: string, to: string})
  | DataTransferStarted({from: string, to: string, size: int})
  | DataTransferComplete({from: string, to: string})

  // Player events
  | PlayerMoved({x: float, y: float})
  | PlayerInteracted({deviceId: string})
  | PlayerDetected({byGuard: string, alertLevel: alertLevel})
  | PlayerHidden

  // Hardware wiring events (ADR-0012)
  | CableConnected({from: string, to: string, cableType: string})
  | CableDisconnected({from: string, to: string})
  | WiringCompleted({challengeId: string})
  | WiringFailed({challengeId: string, reason: string})

  // Inventory events (ADR-0013)
  | ItemPickedUp({itemId: string, slot: int})
  | ItemUsed({itemId: string, targetDevice: string})
  | ItemDropped({itemId: string})
  | InventoryFull({attemptedItem: string})

  // Co-op / multiplayer events
  | PlayerJoined({playerId: string, role: string})
  | PlayerLeft({playerId: string})
  | SyncStateRequest({fromPlayer: string})
  | SyncStateResponse({vmState: array<(string, int)>})

// Serialize an event to a simple tag string (for port communication)
let toTag = (event: t): string => {
  switch event {
  | VMInstructionExecuted({instruction}) => `vm:exec:${instruction}`
  | VMInstructionUndone({instruction}) => `vm:undo:${instruction}`
  | VMStateChanged(_) => "vm:state"
  | VMPuzzleSolved({name}) => `vm:solved:${name}`
  | VMPortOutput({port, value}) => `vm:port:${port}:${Int.toString(value)}`
  | DeviceAccessed({deviceId}) => `device:access:${deviceId}`
  | DeviceLocked({deviceId}) => `device:lock:${deviceId}`
  | DeviceUnlocked({deviceId}) => `device:unlock:${deviceId}`
  | FirewallBlocked(_) => "firewall:block"
  | FirewallBypassed(_) => "firewall:bypass"
  | NetworkScan(_) => "net:scan"
  | SSHConnected({to}) => `ssh:connect:${to}`
  | SSHDisconnected({to}) => `ssh:disconnect:${to}`
  | DataTransferStarted(_) => "net:transfer:start"
  | DataTransferComplete(_) => "net:transfer:done"
  | PlayerMoved(_) => "player:move"
  | PlayerInteracted({deviceId}) => `player:interact:${deviceId}`
  | PlayerDetected({alertLevel}) => {
      let level = switch alertLevel {
      | Green => "green"
      | Yellow => "yellow"
      | Orange => "orange"
      | Red => "red"
      }
      `player:detected:${level}`
    }
  | PlayerHidden => "player:hidden"
  | CableConnected(_) => "wiring:connect"
  | CableDisconnected(_) => "wiring:disconnect"
  | WiringCompleted({challengeId}) => `wiring:done:${challengeId}`
  | WiringFailed(_) => "wiring:fail"
  | ItemPickedUp({itemId}) => `item:pickup:${itemId}`
  | ItemUsed({itemId}) => `item:use:${itemId}`
  | ItemDropped({itemId}) => `item:drop:${itemId}`
  | InventoryFull(_) => "item:full"
  | PlayerJoined({playerId}) => `coop:join:${playerId}`
  | PlayerLeft({playerId}) => `coop:leave:${playerId}`
  | SyncStateRequest(_) => "coop:sync:req"
  | SyncStateResponse(_) => "coop:sync:resp"
  }
}
