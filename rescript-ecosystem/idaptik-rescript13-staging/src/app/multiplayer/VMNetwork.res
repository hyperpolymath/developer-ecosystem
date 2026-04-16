// SPDX-License-Identifier: PMPL-1.0-or-later
// VMNetwork.res  Tier 5: Multi-VM networking
//
// Each network device in the game can host its own VM instance.
// VMNetwork manages the mesh of VM instances and the communication
// between them. This enables:
//
// 1. DISTRIBUTED EXECUTION: Run code on one device that affects another
//    (e.g., exploit runs on laptop  disables firewall on router)
//
// 2. COMPETITIVE UNDO: In asymmetric co-op, the "attacker" executes
//    forward on device A while the "defender" undoes on device B.
//    The network tracks instruction ordering across VMs.
//
// 3. INSTRUCTION INJECTION: SEND on VM-A writes to port "net:<device_B_ip>"
//    which queues the value in VM-B's input buffer. VM-B can RECV it.
//    This is how cross-device hacking works.
//
// 4. STATE SYNCHRONISATION: When a co-op partner joins, all VM states
//    are serialised and sent. On disconnect, the partner's VM actions
//    are replayed (or rolled back if competitive).
//
// 5. CAUSAL ORDERING: The network maintains a Lamport clock to order
//    instructions across VMs. Undo must respect causal dependencies 
//    you can't undo instruction X on VM-A if VM-B has consumed its output.

// --- Lamport clock for causal ordering ---

type lamportClock = {
  mutable time: int,
}

let globalClock: lamportClock = {time: 0}

let tick = (): int => {
  globalClock.time = globalClock.time + 1
  globalClock.time
}

let sync = (remoteTime: int): int => {
  globalClock.time = Math.Int.max(globalClock.time, remoteTime) + 1
  globalClock.time
}

// --- Instruction record (for cross-VM undo tracking) ---

type networkInstruction = {
  id: int, // Unique ID (Lamport timestamp)
  deviceId: string, // Which device's VM executed this
  playerId: string, // Which player executed it
  instruction: string, // Instruction string (e.g., "ADD x y")
  args: array<string>, // Parsed arguments
  timestamp: float, // Wall clock time
  mutable consumed: bool, // Has another VM consumed this instruction's output?
  mutable undone: bool, // Has this been undone?
  outputPorts: array<string>, // Ports this instruction wrote to
}

// Global instruction log (ordered by Lamport time)
let instructionLog: array<networkInstruction> = []

// --- Per-device VM instance ---

type deviceVM = {
  deviceId: string,
  ipAddress: string,
  mutable vm: VMBridge.vmState,
  mutable owner: option<string>, // Player who "owns" (hacked into) this device
  mutable locked: bool, // Locked by defender?
  mutable pendingInbox: array<(string, int)>, // (port, value) waiting to be received
}

// Registry of all device VMs
let deviceVMs: dict<deviceVM> = Dict.make()

// --- VM lifecycle ---

let createDeviceVM = (~deviceId: string, ~ipAddress: string, ~registers: dict<int>): deviceVM => {
  let vm = VMBridge.createVM(registers)
  let dvm: deviceVM = {
    deviceId,
    ipAddress,
    vm,
    owner: None,
    locked: false,
    pendingInbox: [],
  }
  Dict.set(deviceVMs, deviceId, dvm)
  dvm
}

let getDeviceVM = (deviceId: string): option<deviceVM> => {
  Dict.get(deviceVMs, deviceId)
}

let getDeviceVMByIp = (ip: string): option<deviceVM> => {
  Dict.valuesToArray(deviceVMs)-> Array.find(dvm => dvm.ipAddress == ip)
}

// --- Cross-VM message delivery ---
// When VM-A executes SEND to port "net:<ip_B>:<port>", the value
// is queued in VM-B's pendingInbox.

let routePortMessage = (sourceDeviceId: string, port: string, value: int): unit => {
  // Parse net:<ip>:<subport> format
  if String.startsWith(port, "net:") {
    let parts = String.split(port, ":")
    let targetIp = parts[1]->Option.getOr("")
    let _subPort = parts[2]->Option.getOr("default")
    switch getDeviceVMByIp(targetIp) {
    | Some(targetDvm) => ignore(Array.push(targetDvm.pendingInbox, (port, value)))
    | None => () // Target device not found
    }
    ignore(sourceDeviceId)
  } // Covert link channels: data passes through the covert link
  else if String.startsWith(port, "covert:") {
    let connId = String.sliceToEnd(port, ~start=7)
    switch CovertLink.Registry.get(connId) {
    | Some(conn) =>
      if conn.state == CovertLink.Active {
        // Find the other endpoint and deliver
        let sourceIp = switch getDeviceVM(sourceDeviceId) {
        | Some(dvm) => Some(dvm.ipAddress)
        | None => None
        }
        switch sourceIp {
        | Some(sip) =>
          switch CovertLink.otherEndpoint(conn, sip) {
          | Some(destIp) =>
            switch getDeviceVMByIp(destIp) {
            | Some(targetDvm) => ignore(Array.push(targetDvm.pendingInbox, (port, value)))
            | None => ()
            }
          | None => ()
          }
        | None => ()
        }
      }
    | None => ()
    }
  }
}

// --- Execute instruction on a device VM ---

let executeOnDevice = (~deviceId: string, ~instruction: string, ~playerId: string): option<
  string,
> => {
  switch getDeviceVM(deviceId) {
  | Some(dvm) => if dvm.locked {
      Some("Device is locked by defender.")
    } else {
      switch VMBridge.parseVMCommand(instruction) {
      | Some(instr) => {
          let result = VMBridge.executeInstruction(dvm.vm, instr)

          // Record in global instruction log
          let logEntry: networkInstruction = {
            id: tick(),
            deviceId,
            playerId,
            instruction,
            args: [],
            timestamp: Date.now(),
            consumed: false,
            undone: false,
            outputPorts: [], // Would be populated for SEND instructions
          }
          ignore(Array.push(instructionLog, logEntry))

          // Relay to co-op partner
          VMMessageBus.onLocalVMExecute(~deviceId, ~instruction)

          Some(result)
        }
      | None => Some(`Unknown instruction: ${instruction}`)
      }
    }
  | None => Some(`No VM on device ${deviceId}`)
  }
}

// --- Undo on a device VM (with causal ordering check) ---

let undoOnDevice = (~deviceId: string, ~playerId: string): option<string> => {
  switch getDeviceVM(deviceId) {
  | Some(dvm) => {
      // Check if the last instruction's output was consumed by another VM
      let lastInstr =
        instructionLog
        ->Array.filter(i => i.deviceId == deviceId && !i.undone)
        ->Array.at(-1)

      switch lastInstr {
      | Some(instr) =>
        if instr.consumed {
          Some("Cannot undo  output was consumed by another device's VM. Undo that first.")
        } else {
          switch VMBridge.undoLastInstruction(dvm.vm) {
          | Some(result) => {
              instr.undone = true
              VMMessageBus.onLocalVMUndo(~deviceId)
              ignore(playerId)
              Some(result)
            }
          | None => Some("Nothing to undo on this device.")
          }
        }
      | None =>
        switch VMBridge.undoLastInstruction(dvm.vm) {
        | Some(result) => {
            VMMessageBus.onLocalVMUndo(~deviceId)
            ignore(playerId)
            Some(result)
          }
        | None => Some("Nothing to undo on this device.")
        }
      }
    }
  | None => Some(`No VM on device ${deviceId}`)
  }
}

// --- Competitive undo (attacker vs defender) ---
// In competitive mode, the defender can lock a device to prevent
// the attacker from executing instructions. The attacker must first
// unlock it (e.g., by finding a covert link bypass).

let lockDevice = (~deviceId: string, ~_playerId: string): string => {
  switch getDeviceVM(deviceId) {
  | Some(dvm) => {
      dvm.locked = true
      `Device ${deviceId} LOCKED. Attacker cannot execute VM instructions.`
    }
  | None => `No VM on device ${deviceId}`
  }
}

let unlockDevice = (~deviceId: string, ~_playerId: string): string => {
  switch getDeviceVM(deviceId) {
  | Some(dvm) => {
      dvm.locked = false
      `Device ${deviceId} UNLOCKED.`
    }
  | None => `No VM on device ${deviceId}`
  }
}

// --- Process pending inbox (call from game loop) ---

let processPendingInbox = (_deltaSeconds: float): unit => {
  Dict.valuesToArray(deviceVMs)->Array.forEach(dvm => {
    if Array.length(dvm.pendingInbox) > 0 {
      // Mark any instruction that delivered data as "consumed"
      // (prevents undo of the sending instruction — Lamport causality)
      Array.forEach(dvm.pendingInbox, ((port, _value)) => {
        // Walk the instruction log backwards to find the most recent
        // SEND instruction targeting this port on this device
        let found = ref(false)
        let i = ref(Array.length(instructionLog) - 1)
        while i.contents >= 0 && !found.contents {
          let entry = Array.getUnsafe(instructionLog, i.contents)
          if (
            entry.deviceId == dvm.deviceId &&
            !entry.consumed &&
            !entry.undone &&
            Array.some(entry.outputPorts, p => p == port)
          ) {
            entry.consumed = true
            found := true
          }
          i := i.contents - 1
        }
      })
      // Clear inbox after processing
      let len = Array.length(dvm.pendingInbox)
      ignore(Array.splice(dvm.pendingInbox, ~start=0, ~remove=len, ~insert=[]))
    }
  })
}

// --- Serialisation (for network transport) ---

type serialisedVM = {
  deviceId: string,
  ipAddress: string,
  registers: array<(string, int)>,
  stack: array<int>,
  owner: option<string>,
  locked: bool,
  moveCount: int,
}

let serialiseDeviceVM = (dvm: deviceVM): serialisedVM => {
  let regs = ref([])
  Dict.toArray(dvm.vm.registers)->Array.forEach(((k, v)) => {
    regs := Array.concat(regs.contents, [(k, v)])
  })
  {
    deviceId: dvm.deviceId,
    ipAddress: dvm.ipAddress,
    registers: regs.contents,
    stack: dvm.vm.stack,
    owner: dvm.owner,
    locked: dvm.locked,
    moveCount: dvm.vm.moveCount,
  }
}

let serialiseAll = (): array<serialisedVM> => {
  Dict.valuesToArray(deviceVMs)->Array.map(serialiseDeviceVM)
}

// --- Network status display ---

let formatNetworkStatus = (): string => {
  let dvms = Dict.valuesToArray(deviceVMs)
  if Array.length(dvms) == 0 {
    "VM NETWORK: No device VMs active."
  } else {
    let header = `VM NETWORK (${Int.toString(Array.length(dvms))} devices, clock=${Int.toString(
        globalClock.time,
      )})\n`
    let lines = Array.map(dvms, dvm => {
      let lockStr = if dvm.locked {
        " [LOCKED]"
      } else {
        ""
      }
      let ownerStr = switch dvm.owner {
      | Some(pid) => ` owner:${pid}`
      | None => " unowned"
      }
      let regs = ref([])
      Dict.toArray(dvm.vm.registers)->Array.forEach(((k, v)) => {
        regs := Array.concat(regs.contents, [`${k}=${Int.toString(v)}`])
      })
      let regStr = Array.join(regs.contents, " ")
      `  ${dvm.deviceId} (${dvm.ipAddress})${ownerStr}${lockStr}  ${regStr} (${Int.toString(
          dvm.vm.moveCount,
        )} moves)`
    })
    header ++ Array.join(lines, "\n")
  }
}

// --- Per-frame update ---

let update = (deltaSeconds: float): unit => {
  processPendingInbox(deltaSeconds)
  // Update covert link TTLs
  CovertLink.Registry.updateAll(deltaSeconds)
}

// --- Initialise default device VMs for a level ---

let initializeDefaultLevel = (): unit => {
  // Clear existing
  let keys = Dict.keysToArray(deviceVMs)
  Array.forEach(keys, k => Dict.delete(deviceVMs, k))

  // Reset Lamport clock
  globalClock.time = 0

  // Create VMs for key network devices (IPs match LocationData "city" location)
  // Router: core network device
  ignore(
    createDeviceVM(
      ~deviceId="router",
      ~ipAddress="192.168.1.1",
      ~registers=Dict.fromArray([("acl", 0), ("routes", 0)]),
    ),
  )

  // Laptop: player's starting device
  ignore(
    createDeviceVM(
      ~deviceId="laptop",
      ~ipAddress="192.168.1.102",
      ~registers=Dict.fromArray([("x", 0), ("y", 0), ("z", 0)]),
    ),
  )

  // Mail server (DMZ): secondary target
  ignore(
    createDeviceVM(
      ~deviceId="mail",
      ~ipAddress="10.0.0.25",
      ~registers=Dict.fromArray([("inbox", 0), ("relay", 0), ("spam", 0)]),
    ),
  )

  // Database server: target objective
  ignore(
    createDeviceVM(
      ~deviceId="database",
      ~ipAddress="10.0.1.50",
      ~registers=Dict.fromArray([("data", 0), ("locked", 1), ("key", 42)]),
    ),
  )

  // Camera (IoT): security device
  ignore(
    createDeviceVM(
      ~deviceId="camera",
      ~ipAddress="192.168.100.10",
      ~registers=Dict.fromArray([("alert", 0), ("cameras", 4), ("recording", 1)]),
    ),
  )
}

// --- Query functions for SecurityAI ---

// Get all registered device IDs
let getAllDeviceIds = (): array<string> => {
  Dict.keysToArray(deviceVMs)
}

// Get undo-able instruction history for a device (non-undone instructions)
let getDeviceHistory = (deviceId: string): array<networkInstruction> => {
  instructionLog->Array.filter(i => i.deviceId == deviceId && !i.undone)
}
