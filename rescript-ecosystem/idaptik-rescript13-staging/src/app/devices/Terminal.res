// SPDX-License-Identifier: PMPL-1.0-or-later
// Interactive Terminal Component

open Pixi

// SSH session tracking
type sshSession = {
  remoteState: LaptopState.laptopState,
  remoteHost: string,
  previousDir: string,
}

type t = {
  container: Container.t,
  bg: Graphics.t,
  mutable outputLines: array<Text.t>,
  mutable commandHistory: array<string>,
  mutable currentDirectory: string,
  mutable currentInput: string,
  mutable showCursor: bool,
  mutable cursorBlink: float,
  inputLine: Text.t,
  prompt: string, // Original prompt (for restoring after SSH)
  mutable currentPrompt: string, // Current prompt (changes during SSH)
  width: float,
  height: float,
  maxLines: int,
  lineHeight: float,
  ipAddress: option<string>, // Optional IP of the device this terminal runs on
  deviceState: option<LaptopState.laptopState>, // Device state for network operations
  mutable sshStack: array<sshSession>, // Track nested SSH sessions
}

// Add output to terminal
let addOutput = (terminal: t, text: string): unit => {
  let scaledFontSize = FontScale.sizeInt(11)
  let monoStyle = {"fontFamily": "monospace", "fontSize": scaledFontSize, "fill": 0x00ff00}

  let lines = String.split(text, "\n")
  Array.forEach(lines, line => {
    let textObj = Text.make({"text": line, "style": monoStyle})
    Text.setX(textObj, 10.0)
    Text.setY(
      textObj,
      10.0 +. Int.toFloat(Array.length(terminal.outputLines)) *. terminal.lineHeight,
    )
    let _ = Container.addChildText(terminal.container, textObj)
    terminal.outputLines = Array.concat(terminal.outputLines, [textObj])
  })

  // Announce terminal output for screen readers
  Announcer.terminalOutput(text)

  // Remove old lines
  while Array.length(terminal.outputLines) > terminal.maxLines {
    switch terminal.outputLines[0] {
    | Some(oldLine) =>
      Text.destroy(oldLine)
      terminal.outputLines = Array.sliceToEnd(terminal.outputLines, ~start=1)
    | None => ()
    }
  }

  // Reposition lines
  Array.forEachWithIndex(terminal.outputLines, (line, i) => {
    Text.setY(line, 10.0 +. Int.toFloat(i) *. terminal.lineHeight)
  })
}

// Update input line display
let updateInputLine = (terminal: t): unit => {
  let cursor = if terminal.showCursor {
    "_"
  } else {
    " "
  }
  Text.setText(terminal.inputLine, terminal.currentPrompt ++ terminal.currentInput ++ cursor)
}

// List directory
let listDirectory = (terminal: t, path: string, activeIp: string): string => {
  switch Some(activeIp) {
  | Some(ip) =>
    let fullPath = if String.startsWith(path, "C:\\") || String.startsWith(path, "/") {
      path
    } else {
      terminal.currentDirectory ++ "\\" ++ path
    }

    switch DeviceView.listFiles(ip, fullPath) {
    | None => `ls: cannot access '${path}': No such file or directory`
    | Some(items) =>
      if Array.length(items) == 0 {
        "(empty directory)"
      } else {
        let formatted = Array.map(items, ((name, isDir, isLocked, sizeMB)) => {
          let typeStr = if isDir {
            "[DIR] "
          } else {
            "[FILE]"
          }
          let lockStr = if isLocked {
            " "
          } else {
            ""
          }
          let sizeStr = if sizeMB >= 1.0 {
            ` (${Float.toFixed(sizeMB, ~digits=1)} MB)`
          } else if sizeMB > 0.0 {
            let kb = sizeMB *. 1024.0
            ` (${Int.toString(Float.toInt(kb))} KB)`
          } else {
            ""
          }
          `${typeStr} ${name}${lockStr}${sizeStr}`
        })
        Array.join(formatted, "\n")
      }
    }
  | None => "ls: no device IP configured"
  }
}

// Change directory
let changeDirectory = (terminal: t, path: string, activeIp: string): string => {
  switch Some(activeIp) {
  | None => "cd: no device IP configured"
  | Some(ip) =>
    if path == ".." {
      let parts =
        String.split(terminal.currentDirectory, "\\")->Array.filter(p => p != "" && p != "C:")
      let _ = Array.pop(parts)
      terminal.currentDirectory = if Array.length(parts) == 0 {
        "C:\\"
      } else {
        "C:\\" ++ Array.join(parts, "\\")
      }
      ""
    } else {
      let newPath = if String.startsWith(path, "C:\\") {
        path
      } else {
        terminal.currentDirectory ++ "\\" ++ path
      }

      // Check if path exists and is a directory
      switch DeviceView.listFiles(ip, newPath) {
      | Some(_) =>
        terminal.currentDirectory = newPath
        ""
      | None => `cd: ${path}: No such file or directory`
      }
    }
  }
}

// Read file
let readFile = (terminal: t, fileName: string, activeIp: string): string => {
  switch Some(activeIp) {
  | None => "cat: no device IP configured"
  | Some(ip) =>
    let fullPath = if String.startsWith(fileName, "C:\\") {
      fileName
    } else {
      terminal.currentDirectory ++ "\\" ++ fileName
    }

    switch DeviceView.readFile(ip, fullPath) {
    | Ok(content) =>
      if content == "" {
        "(empty file)"
      } else {
        content
      }
    | Error(msg) => `cat: ${msg}`
    }
  }
}

//  Global PBX State 
// The PBX state is shared across all terminals on the network.
// Set by GameLoop when a PBX device exists in the level.
let globalPBX: ref<option<Distraction.pbxState>> = ref(None)

let registerPBX = (pbx: Distraction.pbxState): unit => {
  globalPBX := Some(pbx)
}

let unregisterPBX = (): unit => {
  globalPBX := None
}

let getPBXState = (): option<Distraction.pbxState> => {
  globalPBX.contents
}

// Get active state (local device or SSH'd device)
let getActiveState = (terminal: t): option<LaptopState.laptopState> => {
  let sshStackLen = Array.length(terminal.sshStack)
  if sshStackLen > 0 {
    // We're SSH'd into a remote machine
    switch terminal.sshStack[sshStackLen - 1] {
    | Some(session) => Some(session.remoteState)
    | None => terminal.deviceState
    }
  } else {
    // Local terminal
    terminal.deviceState
  }
}

// Handle built-in commands
let handleBuiltInCommand = (terminal: t, cmd: string, args: array<string>): string => {
  switch cmd {
  | "help" => `Available commands:
  ls [path]       - List directory contents
  cd <path>       - Change directory
  cat <file>      - Display file contents
  pwd             - Print working directory
  mkdir <name>    - Create directory
  rm <file>       - Remove file
  cp <src> <dst>  - Copy file
  kill <pid>      - Kill process by PID
  ssh <host>      - SSH to remote host
  ping <host>     - Ping remote host
  scan <host>     - Port scan a device
  crack <host>    - Attempt password crack
  vm <instr>      - Execute reversible VM instruction
  vm undo         - Undo last VM instruction
  vm state        - Show VM register state
  puzzle          - List available puzzles
  puzzle <name>   - Start a puzzle challenge
  send <d>:<cmd>  - Dispatch coprocessor op (crypto/io/maths/vector/...)
  recv            - Collect pending coprocessor results
  coproc          - Show coprocessor resource usage
  covert          - Show discovered covert links
  covert scan     - Scan for hidden network paths
  covert activate - Activate a discovered connection
  vmnet           - VM network status (Tier 5 multi-VM)
  vmnet exec      - Execute on remote device VM
  coop            - Co-op multiplayer status & commands
  coop join <id>  - Join a co-op session
  coop chat <msg> - Chat with co-op partner
  pbx status      - Show PBX system status
  pbx call <type> - Place distraction call (pizza/fire/maintenance/prank/police)
  exit            - Exit SSH session
  clear           - Clear terminal
  shutdown        - Shutdown this device
  reboot          - Reboot this device
  help            - Show this help`
  | "clear" =>
    Array.forEach(terminal.outputLines, line => Text.destroy(line))
    terminal.outputLines = []
    ""
  | "pwd" => terminal.currentDirectory
  | "ls" =>
    switch getActiveState(terminal) {
    | None => "ls: no device state"
    | Some(activeState) =>
      let path = args[0]->Option.getOr(terminal.currentDirectory)
      listDirectory(terminal, path, activeState.ipAddress)
    }
  | "cd" =>
    switch getActiveState(terminal) {
    | None => "cd: no device state"
    | Some(activeState) =>
      let path = args[0]->Option.getOr("/")
      changeDirectory(terminal, path, activeState.ipAddress)
    }
  | "cat" =>
    switch args[0] {
    | None => "cat: missing file operand"
    | Some(path) =>
      switch getActiveState(terminal) {
      | None => "cat: no device state"
      | Some(activeState) => readFile(terminal, path, activeState.ipAddress)
      }
    }
  | "mkdir" =>
    switch args[0] {
    | None => "mkdir: missing operand"
    | Some(dirName) =>
      switch getActiveState(terminal) {
      | None => "mkdir: no device state"
      | Some(activeState) =>
        switch DeviceView.createDirectory(
          activeState.ipAddress,
          terminal.currentDirectory,
          dirName,
        ) {
        | Error(msg) => `mkdir: ${msg}`
        | Ok() => `Created directory: ${dirName}`
        }
      }
    }
  | "rm" =>
    // Parse flags
    let hasRecursive = Array.some(args, arg => arg == "-r" || arg == "-rf" || arg == "-fr")
    let hasForce = Array.some(args, arg => arg == "-f" || arg == "-rf" || arg == "-fr")

    // Get filename (skip flags)
    let fileName = Array.find(args, arg => !String.startsWith(arg, "-"))

    switch fileName {
    | None => "rm: missing operand"
    | Some(fileName) =>
      switch getActiveState(terminal) {
      | None => "rm: no device state"
      | Some(activeState) =>
        switch DeviceView.deleteFile(
          activeState.ipAddress,
          terminal.currentDirectory,
          fileName,
          hasRecursive,
        ) {
        | Error(msg) =>
          if hasForce && !String.includes(msg, "Permission") {
            "" // Force flag: suppress non-permission errors
          } else {
            `rm: ${msg}`
          }
        | Ok() =>
          // Log file deletion on servers
          SystemLogs.addLog(activeState.ipAddress, `File deleted: ${fileName}`, #Info)
          `Removed '${fileName}'`
        }
      }
    }
  | "cp" =>
    switch (args[0], args[1]) {
    | (None, _) => "cp: missing file operand"
    | (Some(_), None) => "cp: missing destination file operand"
    | (Some(sourceName), Some(destName)) =>
      switch getActiveState(terminal) {
      | None => "cp: no device state"
      | Some(activeState) =>
        let sourcePath = if String.startsWith(sourceName, "C:\\") {
          sourceName
        } else {
          terminal.currentDirectory ++ "\\" ++ sourceName
        }

        let destPath = terminal.currentDirectory

        switch DeviceView.copyFile(activeState.ipAddress, sourcePath, destPath, destName) {
        | Error(msg) => `cp: ${msg}`
        | Ok() => `Copied '${sourceName}' to '${destName}'`
        }
      }
    }
  | "shutdown" =>
    switch terminal.ipAddress {
    | Some(ip) =>
      PowerManager.manualShutdownDevice(ip)
      "System is shutting down..."
    | None => "shutdown: cannot determine device IP"
    }
  | "kill" =>
    switch args[0] {
    | None => "Usage: kill <pid>"
    | Some(pidStr) =>
      switch Int.fromString(pidStr) {
      | None => "kill: invalid PID"
      | Some(pid) =>
        switch getActiveState(terminal) {
        | None => "kill: no device state"
        | Some(activeState) =>
          switch LaptopState.killProcess(activeState.processManager, pid, activeState.ipAddress) {
          | Ok() =>
            // Log process termination on servers
            SystemLogs.addLog(activeState.ipAddress, `Process ${pidStr} terminated`, #Info)
            `Process ${pidStr} terminated.`
          | Error(err) => `kill: ${err}`
          }
        }
      }
    }
  | "ssh" =>
    switch args[0] {
    | None => "Usage: ssh <user@host>"
    | Some(target) =>
      switch getActiveState(terminal) {
      | None => "ssh: terminal not properly initialized"
      | Some(activeState) =>
        LaptopState.addCpuSpike(activeState.processManager, 2.0)
        // Parse user@host or just host
        let sshParts = String.split(target, "@")
        let host = if Array.length(sshParts) > 1 {
          sshParts[1]->Option.getOr(target)
        } else {
          target
        }
        // Check if host has SSH via network interface
        switch activeState.networkInterface {
        | Some(ni) =>
          if ni.hasSSH(host) {
            // Get the remote state for this host
            switch ni.getRemoteState(host) {
            | Some(remoteState) =>
              // Spawn SSH client process on current host
              let clientPid = LaptopState.openApp(activeState.processManager, "ssh.exe")
              // Spawn SSHD connection handler on remote host
              let _ = LaptopState.openApp(remoteState.processManager, "sshd.exe")

              // Record activity for both source and destination devices
              DeviceActivity.recordActivity(activeState.ipAddress)
              DeviceActivity.recordActivity(host)

              // Log SSH connection on server if it's a server device
              SystemLogs.addLog(host, `SSH connection from ${activeState.ipAddress}`, #Info)

              // Push SSH session onto stack
              let session: sshSession = {
                remoteState,
                remoteHost: host,
                previousDir: terminal.currentDirectory,
              }
              terminal.sshStack = Array.concat(terminal.sshStack, [session])

              // Reset current directory for remote session (start at root)
              terminal.currentDirectory = "C:\\"

              // Update prompt to show remote hostname
              terminal.currentPrompt = `${remoteState.hostname}> `
              `Connecting to ${host}...
[Local PID ${Int.toString(clientPid)}] SSH client started
SSH connection established to ${remoteState.hostname}.
Welcome to ${remoteState.hostname}
Type 'exit' to disconnect.`
            | None => `ssh: connect to host ${host}: Connection refused`
            }
          } else if ni.ping(host) {
            `ssh: connect to host ${host}: Connection refused
(SSH service not running on this host)`
          } else {
            `ssh: connect to host ${host}: No route to host`
          }
        | None =>
          `ssh: connect to host ${target}: Connection refused
(No network interface available)`
        }
      }
    }
  | "ping" =>
    switch args[0] {
    | None => "Usage: ping <host>"
    | Some(host) =>
      switch getActiveState(terminal) {
      | None => "ping: terminal not properly initialized"
      | Some(activeState) =>
        LaptopState.addCpuSpike(activeState.processManager, 1.0)
        switch activeState.networkInterface {
        | Some(ni) =>
          if ni.ping(host) {
            `Pinging ${host}...

Reply from ${host}: bytes=32 time=12ms TTL=64
Reply from ${host}: bytes=32 time=15ms TTL=64
Reply from ${host}: bytes=32 time=10ms TTL=64

Ping statistics for ${host}:
    Packets: Sent = 3, Received = 3, Lost = 0 (0% loss)`
          } else {
            `Pinging ${host}...
Request timed out.
Request timed out.
Request timed out.

Ping statistics for ${host}:
    Packets: Sent = 3, Received = 0, Lost = 3 (100% loss)`
          }
        | None => "ping: No network interface available"
        }
      }
    }
  | "exit" =>
    // Check if we're in an SSH session
    if Array.length(terminal.sshStack) > 0 {
      // Pop the SSH session
      switch terminal.sshStack[Array.length(terminal.sshStack) - 1] {
      | Some(session) =>
        // Log SSH disconnection on server
        SystemLogs.addLog(session.remoteHost, `SSH connection closed from client`, #Info)

        // Restore previous directory
        terminal.currentDirectory = session.previousDir
        terminal.sshStack = Array.slice(
          terminal.sshStack,
          ~start=0,
          ~end=Array.length(terminal.sshStack) - 1,
        )

        // Restore prompt to show current host (either local or previous SSH'd host)
        terminal.currentPrompt = if Array.length(terminal.sshStack) > 0 {
          // Still in an SSH session (nested)
          switch terminal.sshStack[Array.length(terminal.sshStack) - 1] {
          | Some(prevSession) => `${prevSession.remoteState.hostname}> `
          | None => terminal.prompt
          }
        } else {
          // Back to local terminal
          terminal.prompt
        }

        `Connection to ${session.remoteHost} closed.`
      | None => ""
      }
    } else {
      "exit: not in SSH session (use 'shutdown' to power off)"
    }
  | "reboot" =>
    switch terminal.ipAddress {
    | Some(ip) =>
      // Reboot = shutdown then immediately boot
      let wasShutdown = PowerManager.isDeviceShutdown(ip)
      if wasShutdown {
        // Already shutdown, just boot
        if PowerManager.deviceHasPower(ip) {
          PowerManager.bootDevice(ip)
          "System is rebooting..."
        } else {
          "reboot: no power available"
        }
      } else {
        // Shutdown then boot
        PowerManager.manualShutdownDevice(ip)
        if PowerManager.deviceHasPower(ip) {
          PowerManager.bootDevice(ip)
          "System is rebooting..."
        } else {
          "reboot: no power available after shutdown"
        }
      }
    | None => "reboot: cannot determine device IP"
    }
  | "scan" => {
      let targetIp = args[0]
      switch targetIp {
      | Some(ip) => {
          let state = getActiveState(terminal)
          switch state {
          | Some(s) => {
              let device = Dict.get(s.networkDevices, ip)
              switch device {
              | Some(d) => {
                  let info = d.getInfo()
                  let result = PortScanner.scan(ip, info)
                  PortScanner.formatResult(result)
                }
              | None => `scan: host ${ip} not found on network`
              }
            }
          | None => "scan: no network access"
          }
        }
      | None => "Usage: scan <ip_address>"
      }
    }
  | "crack" => {
      let targetIp = args[0]
      switch targetIp {
      | Some(ip) => {
          let state = getActiveState(terminal)
          switch state {
          | Some(s) => {
              let device = Dict.get(s.networkDevices, ip)
              switch device {
              | Some(d) => {
                  let info = d.getInfo()
                  let targetHash = PasswordCracker.simpleHash(info.name)
                  let startMsg = PasswordCracker.formatAttackStart(
                    ~targetIp=ip,
                    ~service="ssh",
                    ~method=Dictionary,
                  )
                  let result = PasswordCracker.dictionaryAttack(
                    ~targetHash,
                    ~securityLevel=(info.securityLevel :> DeviceType.securityLevel),
                  )
                  `${startMsg}\n${PasswordCracker.formatResult(result)}`
                }
              | None => `crack: host ${ip} not found on network`
              }
            }
          | None => "crack: no network access"
          }
        }
      | None => "Usage: crack <ip_address>"
      }
    }
  | "vm" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let vmArgs = Array.join(args, " ")
      VMBridge.handleVMCommand(vmArgs)
    } else {
      `Unknown command: vm`
    }
  | "puzzle" | "puzzles" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let puzzleName = Array.join(args, " ")
      VMBridge.handlePuzzleCommand(puzzleName)
    } else {
      `Unknown command: ${cmd}`
    }
  // SEND — dispatch a coprocessor operation on the active (hacked) device.
  // Format: send <domain>:<cmd> [int ...]
  // Result is buffered asynchronously; collect with RECV.
  | "send" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let spec     = args[0]->Option.getOr("")
      let dataArgs = Array.sliceToEnd(args, ~start=1)
      let deviceId = getActiveState(terminal)->Option.map(s => s.ipAddress)->Option.getOr("")
      CoprocessorBridge.handleSend(deviceId, spec, dataArgs)
    } else {
      `bash: ${cmd}: command not found`
    }
  // RECV — drain and print all resolved coprocessor results for the active device.
  | "recv" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let deviceId = getActiveState(terminal)->Option.map(s => s.ipAddress)->Option.getOr("")
      CoprocessorBridge.handleRecv(deviceId)
    } else {
      `bash: ${cmd}: command not found`
    }
  // COPROC — display resource usage summary for the active device.
  | "coproc" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let deviceId = getActiveState(terminal)->Option.map(s => s.ipAddress)->Option.getOr("")
      CoprocessorBridge.getDeviceStatus(deviceId)
    } else {
      `bash: ${cmd}: command not found`
    }
  | "covert" => {
      let subCmd = args[0]->Option.getOr("list")
      switch subCmd {
      | "list" | "ls" => CovertLink.Registry.formatOverlay()
      | "info" =>
        switch args[1] {
        | Some(id) =>
          switch CovertLink.Registry.get(id) {
          | Some(conn) => CovertLink.formatInfo(conn)
          | None => `covert: connection '${id}' not found`
          }
        | None => "Usage: covert info <connection_id>"
        }
      | "activate" =>
        switch args[1] {
        | Some(id) =>
          switch CovertLink.Registry.get(id) {
          | Some(conn) =>
            if CovertLink.activate(conn) {
              `[+] Covert link '${id}' ACTIVATED\n    Port: ${CovertLink.portName(
                  conn,
                )}\n    ${conn.endpointA} <===> ${conn.endpointB}`
            } else {
              switch conn.state {
              | CovertLink.Unknown => `covert: connection '${id}' not yet discovered`
              | Active => `covert: connection '${id}' is already active`
              | Dead => `covert: connection '${id}' is dead  cannot reactivate`
              | Discovered => `covert: activation failed`
              }
            }
          | None => `covert: connection '${id}' not found`
          }
        | None => "Usage: covert activate <connection_id>"
        }
      | "scan" => // Scan for undiscovered covert links from current device
        switch terminal.ipAddress {
        | Some(myIp) => {
            let unknown = CovertLink.Registry.getByState(CovertLink.Unknown)
            let discoverable =
              unknown->Array.filter(c =>
                CovertLink.hasEndpoint(c, myIp) &&
                (c.discoveryMethod == CovertLink.PortScan ||
                  c.discoveryMethod == CovertLink.TrafficAnomaly)
              )
            if Array.length(discoverable) > 0 {
              let discovered = discoverable->Array.map(c => {
                let _ = CovertLink.discover(c)
                `  [!] ${CovertLink.formatShort(c)}\n      "${c.discoveryHint}"`
              })
              `[*] Scanning for hidden network paths...\n${Array.join(discovered, "\n")}`
            } else {
              "[*] Scanning for hidden network paths...\n    No new connections found from this device."
            }
          }
        | None => "covert scan: no network access"
        }
      | "help" | _ => `Covert Link  hidden network pathways
  covert list           Show discovered connections
  covert info <id>      Show connection details
  covert activate <id>  Activate a discovered connection
  covert scan           Scan for hidden connections from this device
  covert help           Show this help`
      }
    }
  | "vmnet" =>
    if FeaturePacks.isInvertibleProgrammingEnabled() {
      let subCmd = args[0]->Option.getOr("status")
      switch subCmd {
      | "status" | "s" => VMNetwork.formatNetworkStatus()
      | "exec" => {
          let deviceId = args[1]->Option.getOr("")
          let instruction = Array.sliceToEnd(args, ~start=2)->Array.join(" ")
          if deviceId == "" || instruction == "" {
            "Usage: vmnet exec <device_id> <instruction>"
          } else {
            switch VMNetwork.executeOnDevice(
              ~deviceId,
              ~instruction,
              ~playerId=MultiplayerGlobal.client.playerId,
            ) {
            | Some(result) => result
            | None => "Execution failed."
            }
          }
        }
      | "undo" => {
          let deviceId = args[1]->Option.getOr("")
          if deviceId == "" {
            "Usage: vmnet undo <device_id>"
          } else {
            switch VMNetwork.undoOnDevice(~deviceId, ~playerId=MultiplayerGlobal.client.playerId) {
            | Some(result) => result
            | None => "Undo failed."
            }
          }
        }
      | "lock" => {
          let deviceId = args[1]->Option.getOr("")
          if deviceId == "" {
            "Usage: vmnet lock <device_id>"
          } else {
            VMNetwork.lockDevice(~deviceId, ~_playerId=MultiplayerGlobal.client.playerId)
          }
        }
      | "unlock" => {
          let deviceId = args[1]->Option.getOr("")
          if deviceId == "" {
            "Usage: vmnet unlock <device_id>"
          } else {
            VMNetwork.unlockDevice(~deviceId, ~_playerId=MultiplayerGlobal.client.playerId)
          }
        }
      | "help" | _ => `VM Network  distributed VM mesh (Tier 5)
  vmnet status                 Show all device VMs
  vmnet exec <dev> <instr>     Execute instruction on a device's VM
  vmnet undo <dev>             Undo last instruction on a device's VM
  vmnet lock <dev>             Lock device (defender)
  vmnet unlock <dev>           Unlock device (attacker)
  vmnet help                   Show this help

Causal ordering: Can't undo if another VM consumed the output.
Cross-VM: Use SEND to port "net:<ip>:<port>" to deliver data.`
      }
    } else {
      `Unknown command: vmnet`
    }
  | "coop" => {
      let subCmd = args[0]->Option.getOr("status")
      switch subCmd {
      | "status" | "s" => MultiplayerClient.formatStatus(MultiplayerGlobal.client)
      | "connect" => {
          MultiplayerClient.connect(MultiplayerGlobal.client)
          "Connecting to sync server..."
        }
      | "disconnect" => {
          MultiplayerClient.disconnect(MultiplayerGlobal.client)
          "Disconnected from sync server."
        }
      | "join" =>
        switch args[1] {
        | Some(sessionId) => {
            MultiplayerClient.joinSession(MultiplayerGlobal.client, ~sessionId)
            `Joining session ${sessionId}...`
          }
        | None => "Usage: coop join <session_id>"
        }
      | "leave" => {
          MultiplayerClient.leaveSession(MultiplayerGlobal.client)
          "Left session."
        }
      | "chat" | "say" => {
          let message = Array.sliceToEnd(args, ~start=1)->Array.join(" ")
          if String.length(String.trim(message)) > 0 {
            MultiplayerClient.sendChat(MultiplayerGlobal.client, ~message)
            `[you] ${message}`
          } else {
            MultiplayerClient.formatChat(MultiplayerGlobal.client)
          }
        }
      | "players" => {
          let players = MultiplayerClient.getCoopPlayers(MultiplayerGlobal.client)
          if Array.length(players) == 0 {
            "No co-op players connected."
          } else {
            let lines = Array.map(players, p =>
              `  ${p.id} (${MultiplayerClient.roleToString(p.role)}) at (${Float.toString(
                  p.x,
                )}, ${Float.toString(p.y)})`
            )
            `Co-op players:\n${Array.join(lines, "\n")}`
          }
        }
      | "role" =>
        switch args[1] {
        | Some("hacker") => {
            MultiplayerGlobal.client.role = MultiplayerClient.Hacker
            "Role set to HACKER (primary player)"
          }
        | Some("observer") => {
            MultiplayerGlobal.client.role = MultiplayerClient.Observer
            "Role set to OBSERVER (support player)"
          }
        | _ =>
          `Current role: ${MultiplayerClient.roleToString(
              MultiplayerGlobal.client.role,
            )}\nUsage: coop role <hacker|observer>`
        }
      | "server" =>
        switch args[1] {
        | Some(url) => {
            MultiplayerGlobal.client.serverUrl = url
            `Server URL set to: ${url}`
          }
        | None =>
          `Current server: ${MultiplayerGlobal.client.serverUrl}\nUsage: coop server <ws://host:port/socket/websocket>`
        }
      | "help" | _ => `Co-op Multiplayer
  coop status             Connection status
  coop connect            Connect to sync server
  coop disconnect         Disconnect
  coop join <session_id>  Join a game session
  coop leave              Leave current session
  coop chat <message>     Send chat to co-op partner
  coop players            List connected players
  coop role <role>        Set role (hacker|observer)
  coop server <url>       Set sync server URL
  coop help               Show this help`
      }
    }
  | "pbx" => {
      let subCmd = args[0]->Option.getOr("status")
      // PBX commands require a global PBX state  look it up via the pbxRef
      switch getPBXState() {
      | None => "pbx: no PBX system found on this network"
      | Some(pbx) =>
        if !pbx.hacked {
          "pbx: access denied  PBX system has not been compromised\n     Hack the PBX device first, then use `pbx` from any terminal."
        } else {
          switch subCmd {
          | "status" | "s" => Distraction.formatStatus(pbx)
          | "call" =>
            switch args[1] {
            | None => "Usage: pbx call <pizza|maintenance|fire|prank|police>"
            | Some(typeStr) =>
              switch Distraction.kindFromString(typeStr) {
              | None =>
                `pbx: unknown call type '${typeStr}'\nAvailable: pizza, maintenance, fire, prank, police`
              | Some(kind) =>
                switch Distraction.call(pbx, ~kind) {
                | Distraction.Success(d) => Distraction.formatCallSuccess(d)
                | Distraction.NotHacked => "pbx: access denied  PBX not hacked"
                | Distraction.OnCooldown(remaining) =>
                  `pbx: phone lines busy  wait ${Int.toString(Float.toInt(remaining))}s`
                | Distraction.NoUsesLeft => `pbx: no more ${typeStr} calls available this mission`
                | Distraction.UnknownType => `pbx: unknown call type '${typeStr}'`
                }
              }
            }
          | "help" | _ => Distraction.formatHelp()
          }
        }
      }
    }
  | "undo" =>
    // Shortcut for vm undo when in puzzle mode
    if VMBridge.bridge.puzzleMode {
      VMBridge.handleVMCommand("undo")
    } else {
      `bash: ${cmd}: command not found`
    }
  | _ =>
    // When in puzzle mode, try parsing as a VM instruction directly
    if VMBridge.bridge.puzzleMode {
      let fullInput = cmd ++ " " ++ Array.join(args, " ")
      switch VMBridge.parseVMCommand(String.trim(fullInput)) {
      | Some(_) => VMBridge.handleVMCommand(String.trim(fullInput))
      | None => `bash: ${cmd}: command not found`
      }
    } else {
      `bash: ${cmd}: command not found`
    }
  }
}

// Execute command
let executeCommand = (terminal: t): unit => {
  let fullCommand = String.trim(terminal.currentInput)
  if fullCommand == "" {
    addOutput(terminal, "")
    terminal.currentInput = ""
    updateInputLine(terminal)
  } else {
    addOutput(terminal, terminal.currentDirectory ++ terminal.prompt ++ fullCommand)

    let parts = String.split(fullCommand, " ")->Array.filter(p => p != "")
    let cmd = parts[0]->Option.getOr("")
    let args = Array.sliceToEnd(parts, ~start=1)

    let output = handleBuiltInCommand(terminal, cmd, args)
    if output != "" {
      addOutput(terminal, output)
    }

    terminal.commandHistory = Array.concat(terminal.commandHistory, [fullCommand])
    terminal.currentInput = ""
    updateInputLine(terminal)
  }
}

// Global focus tracker stored on window object for JS access
let setGlobalFocusedTerminal: option<t> => unit = %raw(`
  function(terminal) {
    window.__focusedTerminal = terminal;
  }
`)

let getGlobalFocusedTerminal: unit => option<t> = %raw(`
  function() {
    return window.__focusedTerminal || undefined;
  }
`)

// Handle key input for a terminal
let handleKeyInput = (terminal: t, key: string): unit => {
  if key == "Enter" {
    executeCommand(terminal)
  } else if key == "Backspace" {
    terminal.currentInput = String.slice(
      terminal.currentInput,
      ~start=0,
      ~end=String.length(terminal.currentInput) - 1,
    )
    updateInputLine(terminal)
  } else if String.length(key) == 1 {
    terminal.currentInput = terminal.currentInput ++ key
    updateInputLine(terminal)
  }
}

// Setup keyboard handler (external JS)
let setupGlobalKeyboardHandler: (
  unit => option<t>,
  (t, string) => unit,
  unit => unit,
) => unit = %raw(`
  function(getFocused, handleKey, unfocusAll) {
    if (!window.__terminalKeyboardSetup) {
      window.__terminalKeyboardSetup = true;

      // Unfocus terminal when clicking on input elements
      document.addEventListener('focusin', (e) => {
        if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
          unfocusAll();
        }
      });

      window.addEventListener('keydown', (e) => {
        const focused = getFocused();
        // PixiJS v8 uses 'visible' property, check if container exists and is visible
        const isVisible = focused?.container?.visible !== false;
        if (!focused || !isVisible) return;

        // Check if any DOM input/textarea has focus (PixiUI inputs, HTML inputs, etc.)
        const activeElement = document.activeElement;
        if (activeElement && (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA')) {
          return; // DOM input has focus, don't handle terminal input
        }

        // Check if any PixiUI Input is focused (they set a global flag)
        if (window.__pixiui_input_focused) {
          return; // PixiUI Input has focus, don't handle terminal input
        }

        // Only prevent default for our terminal keys
        if (e.key === 'Enter' || e.key === 'Backspace' || (e.key.length === 1 && !e.ctrlKey && !e.metaKey)) {
          e.preventDefault();
          handleKey(focused, e.key);
        }
      });
    }
  }
`)

// Focus this terminal
let focus = (terminal: t): unit => {
  setGlobalFocusedTerminal(Some(terminal))
  Graphics.setAlpha(terminal.bg, 1.0)
}

// Unfocus terminal
let unfocus = (terminal: t): unit => {
  switch getGlobalFocusedTerminal() {
  | Some(focused) if focused === terminal =>
    setGlobalFocusedTerminal(None)
    Graphics.setAlpha(terminal.bg, 0.9)
  | _ => ()
  }
}

// Create a terminal
let make = (
  ~width: float,
  ~height: float,
  ~prompt: string="> ",
  ~ipAddress: option<string>=?,
  ~deviceState: option<LaptopState.laptopState>=?,
  (),
): t => {
  let container = Container.make()
  Container.setEventMode(container, "static")

  // Background
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, 0.0, width, height)->Graphics.fillColor(0x000000)
  Graphics.setEventMode(bg, "static")
  Graphics.setCursor(bg, "text")
  let _ = Container.addChildGraphics(container, bg)

  // Input line at bottom
  let monoStyle = {"fontFamily": "monospace", "fontSize": 11, "fill": 0x00ff00}
  let inputLine = Text.make({"text": prompt, "style": monoStyle})
  Text.setX(inputLine, 10.0)
  Text.setY(inputLine, height -. 25.0)
  let _ = Container.addChildText(container, inputLine)

  // Calculate maxLines based on height (leave room for input line)
  let lineHeight = 16.0
  let maxLines = Float.toInt((height -. 30.0) /. lineHeight) // 30px for input + padding

  let terminal = {
    container,
    bg,
    outputLines: [],
    commandHistory: [],
    currentDirectory: "C:\\",
    currentInput: "",
    showCursor: true,
    cursorBlink: 0.0,
    inputLine,
    prompt,
    currentPrompt: prompt, // Start with original prompt
    width,
    height,
    maxLines,
    lineHeight,
    ipAddress,
    deviceState,
    sshStack: [],
  }

  // Welcome message
  addOutput(terminal, "Terminal initialized. Type 'help' for commands.")
  addOutput(terminal, "")

  // Setup keyboard input - use global focus management
  Graphics.on(bg, "pointerdown", _ => {
    focus(terminal)
  })

  // Unfocus when clicking outside the terminal
  // (handled by parent containers/windows that implement click-to-focus)

  // Setup the global keyboard handler (only adds listener once)
  // Pass in the getter, handler, and unfocus functions so JS can call them
  let unfocusAll = () => setGlobalFocusedTerminal(None)
  setupGlobalKeyboardHandler(getGlobalFocusedTerminal, handleKeyInput, unfocusAll)

  terminal
}

// Update cursor blink
let update = (terminal: t, deltaTime: float): unit => {
  terminal.cursorBlink = terminal.cursorBlink +. deltaTime
  if terminal.cursorBlink > 0.5 {
    terminal.showCursor = !terminal.showCursor
    terminal.cursorBlink = 0.0
    updateInputLine(terminal)
  }
}
