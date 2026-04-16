// SPDX-License-Identifier: PMPL-1.0-or-later
// Laptop Desktop GUI (Windows-like) with shared state

open Pixi

// Separate type for drag offset
type dragOffset = {x: float, y: float}

// ============================================
// Simple draggable application window
// ============================================
module AppWindow = {
  type t = {
    container: Container.t,
    titleBar: Graphics.t,
    content: Container.t,
    closeBtn: Graphics.t,
    mutable isDragging: bool,
    mutable dragOffset: dragOffset,
    appName: string,
  }

  let make = (~title: string, ~w: float, ~h: float, ~appName: string, ~onClose: unit => unit, ()): t => {
    let container = Container.make()
    Container.setEventMode(container, "static")
    Container.setZIndex(container, 1)

    // Window background
    let bg = Graphics.make()
    let _ = bg
      ->Graphics.rect(0.0, 0.0, w, h)
      ->Graphics.fill({"color": 0xf0f0f0})
      ->Graphics.stroke({"width": 1, "color": 0x000000})
    let _ = Container.addChildGraphics(container, bg)

    // Title bar
    let titleBar = Graphics.make()
    let _ = titleBar->Graphics.rect(0.0, 0.0, w, 25.0)->Graphics.fill({"color": 0x0078D4})
    Graphics.setEventMode(titleBar, "static")
    Graphics.setCursor(titleBar, "grab")
    let _ = Container.addChildGraphics(container, titleBar)

    let titleText = Text.make({
      "text": title,
      "style": {"fontSize": 12, "fill": 0xffffff, "fontFamily": "Arial"},
    })
    Text.setX(titleText, 5.0)
    Text.setY(titleText, 6.0)
    let _ = Graphics.addChild(titleBar, titleText)

    // Close button
    let closeBtn = Graphics.make()
    let _ = closeBtn->Graphics.rect(w -. 25.0, 2.0, 20.0, 20.0)->Graphics.fill({"color": 0xff0000})
    Graphics.setEventMode(closeBtn, "static")
    Graphics.setCursor(closeBtn, "pointer")
    let closeX = Text.make({"text": "X", "style": {"fontSize": 12, "fill": 0xffffff}})
    Text.setX(closeX, w -. 18.0)
    Text.setY(closeX, 5.0)
    let _ = Graphics.addChild(closeBtn, closeX)
    let _ = Graphics.addChild(titleBar, closeBtn)

    // Content area
    let content = Container.make()
    Container.setY(content, 25.0)
    let _ = Container.addChild(container, content)

    let windowState = {
      container,
      titleBar,
      content,
      closeBtn,
      isDragging: false,
      dragOffset: {x: 0.0, y: 0.0},
      appName,
    }

    // Setup close
    Graphics.on(closeBtn, "pointertap", _ => {
      onClose()
      Container.destroy(container)
    })

    // Setup dragging
    Graphics.on(titleBar, "pointerdown", (e: FederatedPointerEvent.t) => {
      windowState.isDragging = true
      Graphics.setCursor(titleBar, "grabbing")
      windowState.dragOffset = {
        x: FederatedPointerEvent.global(e).x -. Container.x(container),
        y: FederatedPointerEvent.global(e).y -. Container.y(container),
      }

      switch Container.parent(container)->Nullable.toOption {
      | Some(parent) =>
        Container.on(parent, "pointermove", (e: FederatedPointerEvent.t) => {
          if windowState.isDragging {
            Container.setX(container, FederatedPointerEvent.global(e).x -. windowState.dragOffset.x)
            Container.setY(container, FederatedPointerEvent.global(e).y -. windowState.dragOffset.y)
          }
        })
        Container.on(parent, "pointerup", _ => {
          windowState.isDragging = false
          Graphics.setCursor(titleBar, "grab")
        })
        Container.on(parent, "pointerupoutside", _ => {
          windowState.isDragging = false
          Graphics.setCursor(titleBar, "grab")
        })
      | None => ()
      }
    })

    windowState
  }

  let getContent = (win: t): Container.t => win.content
}

// ============================================
// Main laptop state type
// ============================================
type t = {
  container: Container.t,
  desktop: Container.t,
  taskbar: Graphics.t,
  state: LaptopState.laptopState,
  mutable currentPath: string, // For file manager
}

// ============================================
// Terminal that uses shared filesystem
// ============================================

// Helper to split path into directory and filename
let splitPath = (path: string): (string, string) => {
  let parts = String.split(path, "\\")->Array.filter(p => p != "")
  let fileName = Array.pop(parts)->Option.getOr("")
  let dirPath = if Array.length(parts) == 0 { "C:\\" } else { Array.join(parts, "\\") }
  (dirPath, fileName)
}

// SSH session info
type sshSession = {
  remoteState: LaptopState.laptopState,
  remoteHost: string,
  previousDir: string, // Dir on local machine before SSH
}

// RDP callback type: (remoteState, remoteHost) => unit
type rdpCallback = (LaptopState.laptopState, string) => unit

/* COMMENTED OUT - Replaced with unified Terminal.res component
let createLaptopTerminal = (state: LaptopState.laptopState, ~width: float, ~height: float, ~onRdp: option<rdpCallback>=?, ()): Container.t => {
  let container = Container.make()
  Container.setEventMode(container, "static")

  // Background
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, 0.0, width, height)->Graphics.fillColor(0x000000)
  Graphics.setEventMode(bg, "static")
  Graphics.setCursor(bg, "text")
  let _ = Container.addChildGraphics(container, bg)

  let monoStyle = {"fontFamily": "monospace", "fontSize": 11, "fill": 0x00ff00}

  // Terminal state
  let currentDir = ref("C:\\Users\\Admin")
  let currentInput = ref("")
  let outputLines: ref<array<Text.t>> = ref([])
  let commandHistory: ref<array<string>> = ref([])
  let historyIndex: ref<int> = ref(-1)
  let maxLines = 18
  let lineHeight = 16.0

  // SSH session stack - when connected to remote, use remote state
  let sshStack: ref<array<sshSession>> = ref([])

  // Get current state (local or remote if in SSH session)
  let getCurrentState = (): LaptopState.laptopState => {
    switch Array.get(sshStack.contents, Array.length(sshStack.contents) - 1) {
    | Some(session) => session.remoteState
    | None => state
    }
  }

  // Check if in SSH session
  let isInSSH = (): bool => Array.length(sshStack.contents) > 0

  // Input line at bottom
  let inputLine = Text.make({"text": `${currentDir.contents}> `, "style": monoStyle})
  Text.setX(inputLine, 10.0)
  Text.setY(inputLine, height -. 25.0)
  let _ = Container.addChildText(container, inputLine)

  // Add output line
  let addOutput = (text: string): unit => {
    let lines = String.split(text, "\n")
    Array.forEach(lines, line => {
      let textObj = Text.make({"text": line, "style": monoStyle})
      Text.setX(textObj, 10.0)
      Text.setY(textObj, 10.0 +. Int.toFloat(Array.length(outputLines.contents)) *. lineHeight)
      let _ = Container.addChildText(container, textObj)
      outputLines := Array.concat(outputLines.contents, [textObj])
    })

    // Remove old lines
    while Array.length(outputLines.contents) > maxLines {
      switch Array.get(outputLines.contents, 0) {
      | Some(oldLine) =>
        Text.destroy(oldLine)
        outputLines := Array.sliceToEnd(outputLines.contents, ~start=1)
      | None => ()
      }
    }

    // Reposition lines
    Array.forEachWithIndex(outputLines.contents, (line, i) => {
      Text.setY(line, 10.0 +. Int.toFloat(i) *. lineHeight)
    })
  }

  // Update input display - show remote hostname if in SSH session
  let updateInput = (): unit => {
    let prompt = if isInSSH() {
      let currentState = getCurrentState()
      `${currentState.currentUser}@${currentState.hostname}:${currentDir.contents}$ `
    } else {
      `${currentDir.contents}> `
    }
    Text.setText(inputLine, `${prompt}${currentInput.contents}_`)
  }

  // Resolve path (absolute or relative)
  let resolveFull = (path: string): string => {
    if String.startsWith(path, "C:") {
      path
    } else if path == ".." {
      let parts = String.split(currentDir.contents, "\\")->Array.filter(p => p != "")
      let _ = Array.pop(parts)
      if Array.length(parts) == 0 { "C:\\" } else { Array.join(parts, "\\") }
    } else {
      currentDir.contents ++ "\\" ++ path
    }
  }

  // Execute command
  let executeCommand = (): unit => {
    let cmd = String.trim(currentInput.contents)
    // Show prompt with proper context (local or SSH)
    let prompt = if isInSSH() {
      let currentState = getCurrentState()
      `${currentState.currentUser}@${currentState.hostname}:${currentDir.contents}$ `
    } else {
      `${currentDir.contents}> `
    }
    addOutput(`${prompt}${cmd}`)

    if cmd != "" {
      // Add to history
      commandHistory := Array.concat(commandHistory.contents, [cmd])
      historyIndex := -1

      let parts = String.split(cmd, " ")->Array.filter(p => p != "")
      let cmdName = Array.get(parts, 0)->Option.getOr("")
      let args = Array.sliceToEnd(parts, ~start=1)

      // Get current state (local or remote if in SSH)
      let activeState = getCurrentState()

      // Add CPU spike for command execution
      LaptopState.addCpuSpike(activeState.processManager, 2.0)

      // Add to global history
      LaptopState.addToHistory(activeState, cmd)

      let output = switch cmdName {
      | "help" => `Available commands:
  dir, ls          - List directory contents
  cd <path>        - Change directory
  cat, type <file> - Display file contents
  cls, clear       - Clear screen
  pwd              - Print working directory
  mkdir <name>     - Create directory
  touch <name>     - Create empty file
  rm, del <name>   - Delete file or empty directory
  cp <src> <dest>  - Copy file
  mv <src> <dest>  - Move/rename file
  echo <text>      - Display text
  echo <text> > <file> - Write text to file
  history          - Show command history
  history -c       - Clear command history
  ps               - Show running processes
  kill <pid>       - Kill a process
  df               - Show storage usage
  stat <file>      - Show file info
  chmod +/-w <file>- Change file permissions
  tree             - Show directory tree
  find <pattern>   - Search for files
  netstat          - Show network connections
  ifconfig         - Show network config
  uname            - Show system info
  uptime           - Show uptime
  last             - Show login history
  who              - Show current user
  ping <host>      - Ping a host (supports hostnames)
  traceroute <host>- Trace route to host
  nslookup <host>  - DNS lookup
  dig <host>       - DNS lookup (detailed)
  ssh <host>       - SSH to remote host
  rdp <host>       - Remote desktop to host
  exit             - Exit SSH session
  shutdown         - Shutdown this device
  reboot           - Reboot this device
  help             - Show this help

Use up/down arrows to navigate command history.`
      | "cls" | "clear" =>
        Array.forEach(outputLines.contents, line => Text.destroy(line))
        outputLines := []
        ""
      | "pwd" => currentDir.contents
      | "dir" | "ls" =>
        let path = Array.get(args, 0)->Option.getOr(currentDir.contents)
        let fullPath = resolveFull(path)
        switch LaptopState.listDir(activeState.filesystem, fullPath) {
        | None => `Directory not found: ${path}`
        | Some(items) =>
          if Array.length(items) == 0 {
            "(empty directory)"
          } else {
            Array.map(items, ((name, isDir, isLocked, _size)) => {
              let prefix = if isDir { "[DIR] " } else { "[FILE]" }
              let suffix = if isLocked { " [LOCKED]" } else { "" }
              `${prefix} ${name}${suffix}`
            })->Array.join("\n")
          }
        }
      | "cd" =>
        let path = Array.get(args, 0)->Option.getOr("C:\\")
        let newPath = resolveFull(path)
        switch LaptopState.resolvePath(activeState.filesystem, newPath) {
        | Some(LaptopState.Dir(_)) =>
          currentDir := newPath
          ""
        | Some(LaptopState.File(_)) => `Not a directory: ${path}`
        | None => `Directory not found: ${path}`
        }
      | "type" | "cat" =>
        switch Array.get(args, 0) {
        | None => "Usage: cat <filename>"
        | Some(filename) =>
          let fullPath = resolveFull(filename)
          switch LaptopState.readFile(activeState.filesystem, fullPath) {
          | Ok(content) => content
          | Error(err) => err
          }
        }
      | "mkdir" =>
        switch Array.get(args, 0) {
        | None => "Usage: mkdir <dirname>"
        | Some(name) =>
          switch LaptopState.createDir(activeState.filesystem, currentDir.contents, name) {
          | Ok() => `Directory created: ${name}`
          | Error(err) => err
          }
        }
      | "touch" =>
        switch Array.get(args, 0) {
        | None => "Usage: touch <filename>"
        | Some(name) =>
          switch LaptopState.createFile(activeState.filesystem, currentDir.contents, name, "") {
          | Ok() => `File created: ${name}`
          | Error(err) => err
          }
        }
      | "rm" | "del" =>
        // Parse flags
        let hasRecursive = Array.some(args, arg => arg == "-r" || arg == "-rf" || arg == "-fr")
        let hasForce = Array.some(args, arg => arg == "-f" || arg == "-rf" || arg == "-fr")

        // Get filename (skip flags)
        let fileName = Array.find(args, arg => !String.startsWith(arg, "-"))

        switch fileName {
        | None => "Usage: rm [-rf] <filename>"
        | Some(name) =>
          // Use recursive deletion if -r flag is present
          let deleteResult = if hasRecursive {
            LaptopState.deleteNodeRecursive(activeState.filesystem, currentDir.contents, name)
          } else {
            LaptopState.deleteNode(activeState.filesystem, currentDir.contents, name)
          }

          switch deleteResult {
          | Ok() => `Deleted: ${name}`
          | Error(err) =>
            if hasForce && !String.includes(err, "Permission") {
              "" // Force flag suppresses non-permission errors
            } else {
              err
            }
          }
        }
      | "cp" | "copy" =>
        switch (Array.get(args, 0), Array.get(args, 1)) {
        | (None, _) | (_, None) => "Usage: cp <source> <destination>"
        | (Some(src), Some(dest)) =>
          let srcFull = resolveFull(src)
          let destFull = resolveFull(dest)
          let (destDir, destName) = splitPath(destFull)
          switch LaptopState.copyFile(activeState.filesystem, srcFull, destDir, destName) {
          | Ok() => `Copied: ${src} -> ${dest}`
          | Error(err) => err
          }
        }
      | "mv" | "move" | "ren" =>
        switch (Array.get(args, 0), Array.get(args, 1)) {
        | (None, _) | (_, None) => "Usage: mv <source> <destination>"
        | (Some(src), Some(dest)) =>
          let srcFull = resolveFull(src)
          let (srcDir, srcName) = splitPath(srcFull)
          let destFull = resolveFull(dest)
          let (destDir, destName) = splitPath(destFull)
          switch LaptopState.moveFile(activeState.filesystem, srcDir, srcName, destDir, destName) {
          | Ok() => `Moved: ${src} -> ${dest}`
          | Error(err) => err
          }
        }
      | "echo" =>
        // Check for redirection
        let argsStr = Array.join(args, " ")
        if String.includes(argsStr, ">") {
          let redirectParts = String.split(argsStr, ">")
          let text = String.trim(Array.get(redirectParts, 0)->Option.getOr(""))
          let filename = String.trim(Array.get(redirectParts, 1)->Option.getOr(""))
          if filename == "" {
            "Usage: echo <text> > <filename>"
          } else {
            let fullPath = resolveFull(filename)
            // Check if file exists
            switch LaptopState.resolvePath(activeState.filesystem, fullPath) {
            | Some(LaptopState.File(_)) =>
              switch LaptopState.writeFile(activeState.filesystem, fullPath, text) {
              | Ok() => ""
              | Error(err) => err
              }
            | Some(LaptopState.Dir(_)) => `Is a directory: ${filename}`
            | None =>
              // Create new file
              let (dir, name) = splitPath(fullPath)
              switch LaptopState.createFile(activeState.filesystem, dir, name, text) {
              | Ok() => ""
              | Error(err) => err
              }
            }
          }
        } else {
          argsStr
        }
      | "whoami" => activeState.currentUser
      | "hostname" => activeState.hostname
      | "date" => "Sun Dec 08 2024"
      | "time" => "09:45:32"
      | "history" =>
        switch Array.get(args, 0) {
        | Some("-c") =>
          LaptopState.clearHistory(activeState)
          "History cleared."
        | _ =>
          let hist = LaptopState.getHistory(activeState)
          if Array.length(hist) == 0 {
            "(no history)"
          } else {
            Array.mapWithIndex(hist, (cmd, i) =>
              `  ${Int.toString(i + 1)}  ${cmd}`
            )->Array.join("\n")
          }
        }
      | "ps" =>
        LaptopState.addCpuSpike(activeState.processManager, 3.0)
        let procs = LaptopState.getProcesses(activeState.processManager)
        let header = "  PID  NAME                      CPU%   Gq"
        let lines = Array.map(procs, p => {
          let pidStr = String.padStart(Int.toString(p.pid), 5, " ")
          let nameStr = String.padEnd(p.name, 24, " ")
          let cpuStr = String.padStart(Float.toFixed(p.cpuPercent, ~digits=1), 5, " ")
          let gqStr = String.padStart(Int.toString(p.sizeGq), 4, " ")
          `${pidStr}  ${nameStr} ${cpuStr}  ${gqStr}`
        })
        header ++ "\n" ++ Array.join(lines, "\n")
      | "kill" =>
        switch Array.get(args, 0) {
        | None => "Usage: kill <pid>"
        | Some(pidStr) =>
          switch Int.fromString(pidStr) {
          | None => "kill: invalid PID"
          | Some(pid) =>
            switch LaptopState.killProcess(activeState.processManager, pid, activeState.ipAddress) {
            | Ok() => `Process ${pidStr} terminated.`
            | Error(err) => `kill: ${err}`
            }
          }
        }
      | "df" =>
        LaptopState.addCpuSpike(activeState.processManager, 1.0)
        let (used, total) = LaptopState.getTotalStorageUsage(activeState.processManager, activeState.filesystem)
        let percent = Int.toFloat(used) /. Int.toFloat(total) *. 100.0
        `Filesystem      Size    Used    Avail   Use%
C:\\             ${Int.toString(total)} Gq  ${Int.toString(used)} Gq   ${Int.toString(total - used)} Gq  ${Float.toFixed(percent, ~digits=0)}%`
      | "stat" =>
        switch Array.get(args, 0) {
        | None => "Usage: stat <file>"
        | Some(path) =>
          let fullPath = resolveFull(path)
          switch LaptopState.getFileInfo(activeState.filesystem, fullPath) {
          | None => `stat: ${path}: No such file or directory`
          | Some((isDir, isLocked, size, contentLen)) =>
            let typeStr = if isDir { "directory" } else { "regular file" }
            let permStr = if isLocked { "r--r--r--" } else { "rw-rw-rw-" }
            `  File: ${path}
  Size: ${Int.toString(size)} Gq (${Int.toString(contentLen)} bytes)
  Type: ${typeStr}
Access: ${permStr}`
          }
        }
      | "chmod" =>
        switch (Array.get(args, 0), Array.get(args, 1)) {
        | (None, _) | (_, None) => "Usage: chmod +w/-w <file>"
        | (Some(mode), Some(path)) =>
          let fullPath = resolveFull(path)
          let locked = mode == "-w"
          switch LaptopState.setFileLocked(activeState.filesystem, fullPath, locked) {
          | Ok() => ""
          | Error(err) => `chmod: ${err}`
          }
        }
      | "tree" =>
        LaptopState.addCpuSpike(activeState.processManager, 2.0)
        // Simplified tree showing only current directory
        switch LaptopState.listDir(activeState.filesystem, currentDir.contents) {
        | None => "tree: cannot access directory"
        | Some(items) =>
          let lines = Array.mapWithIndex(items, ((name, isDir, _locked, _size), i) => {
            let prefix = if i == Array.length(items) - 1 { "`-- " } else { "|-- " }
            let suffix = if isDir { "/" } else { "" }
            prefix ++ name ++ suffix
          })
          currentDir.contents ++ "\n" ++ Array.join(lines, "\n")
        }
      | "find" =>
        switch Array.get(args, 0) {
        | None => "Usage: find <pattern>"
        | Some(pattern) =>
          LaptopState.addCpuSpike(activeState.processManager, 5.0)
          // Simplified find - just lists matching files in current dir
          switch LaptopState.listDir(activeState.filesystem, currentDir.contents) {
          | None => "find: cannot access directory"
          | Some(items) =>
            let matches = Array.filter(items, ((name, _isDir, _locked, _size)) =>
              String.includes(String.toLowerCase(name), String.toLowerCase(pattern))
            )
            if Array.length(matches) == 0 {
              `No files matching '${pattern}' found.`
            } else {
              Array.map(matches, ((name, _isDir, _locked, _size)) =>
                currentDir.contents ++ "\\" ++ name
              )->Array.join("\n")
            }
          }
        }
      | "netstat" =>
        LaptopState.addCpuSpike(activeState.processManager, 2.0)
        let ip = activeState.ipAddress
        `Active Network Connections:
  Proto  Local Address          Foreign Address        State
  TCP    ${ip}:445      0.0.0.0:0              LISTENING
  TCP    ${ip}:3389     0.0.0.0:0              LISTENING
  TCP    ${ip}:22       0.0.0.0:0              LISTENING
  TCP    ${ip}:49412    204.79.197.200:443     ESTABLISHED
  UDP    ${ip}:137      *:*
  UDP    ${ip}:138      *:*                    `
      | "ifconfig" | "ipconfig" =>
        let ip = activeState.ipAddress
        `Ethernet adapter Local Area Connection:

   Connection-specific DNS Suffix  . : local
   IPv4 Address. . . . . . . . . . . : ${ip}
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 192.168.1.1

Wireless LAN adapter WiFi:

   Media State . . . . . . . . . . . : Media disconnected`
      | "uname" =>
        let arg = Array.get(args, 0)->Option.getOr("")
        if arg == "-a" {
          `CorpOS ${activeState.hostname} 2.4.1 Build 9200 x86_64`
        } else {
          "CorpOS"
        }
      | "uptime" =>
        "09:45:32 up 3 days, 14:22, 1 user, load average: 0.08, 0.12, 0.10"
      | "last" =>
        let logins = activeState.loginHistory
        if Array.length(logins) == 0 {
          "(no login history)"
        } else {
          Array.map(logins, ((user, time)) =>
            `${user}    pts/0    ${time}`
          )->Array.join("\n")
        }
      | "who" =>
        `${activeState.currentUser}    pts/0    Dec  8 09:45 (console)`
      | "ping" =>
        switch Array.get(args, 0) {
        | None => "Usage: ping <host>"
        | Some(host) =>
          LaptopState.addCpuSpike(activeState.processManager, 3.0)
          // Check if host is reachable via current session's network interface
          switch activeState.networkInterface {
          | Some(ni) =>
            if ni.ping(host) {
              `Pinging ${host} with 32 bytes of data:
Reply from ${host}: bytes=32 time=12ms TTL=64
Reply from ${host}: bytes=32 time=11ms TTL=64
Reply from ${host}: bytes=32 time=13ms TTL=64

Ping statistics for ${host}:
    Packets: Sent = 3, Received = 3, Lost = 0 (0% loss)`
            } else {
              `Pinging ${host} with 32 bytes of data:
Request timed out.
Request timed out.
Request timed out.

Ping statistics for ${host}:
    Packets: Sent = 3, Received = 0, Lost = 3 (100% loss)`
            }
          | None =>
            // No network interface, just fake success
            `Pinging ${host} with 32 bytes of data:
Reply from ${host}: bytes=32 time=12ms TTL=64
Reply from ${host}: bytes=32 time=11ms TTL=64
Reply from ${host}: bytes=32 time=13ms TTL=64

Ping statistics for ${host}:
    Packets: Sent = 3, Received = 3, Lost = 0 (0% loss)`
          }
        }
      | "ssh" =>
        switch Array.get(args, 0) {
        | None => "Usage: ssh <user@host>"
        | Some(target) =>
          LaptopState.addCpuSpike(activeState.processManager, 2.0)
          // Parse user@host or just host
          let sshParts = String.split(target, "@")
          let host = if Array.length(sshParts) > 1 {
            Array.get(sshParts, 1)->Option.getOr(target)
          } else {
            target
          }
          // Check if host has SSH via current session's network interface
          // This is critical: when SSH'd into a machine, network access uses THAT machine's view
          switch activeState.networkInterface {
          | Some(ni) =>
            if ni.hasSSH(host) {
              // Get the remote state for this host
              switch ni.getRemoteState(host) {
              | Some(remoteState) =>
                // Spawn SSH client process on current host (the one initiating SSH)
                let clientPid = LaptopState.openApp(activeState.processManager, "ssh.exe")
                // Spawn SSHD connection handler on remote host
                let _ = LaptopState.openApp(remoteState.processManager, "sshd.exe")

                // Push SSH session onto stack
                let session: sshSession = {
                  remoteState,
                  remoteHost: host,
                  previousDir: currentDir.contents,
                }
                sshStack := Array.concat(sshStack.contents, [session])
                // Reset current directory for remote session
                currentDir := "C:\\Users\\Admin"
                `Connecting to ${host}...
[Local PID ${Int.toString(clientPid)}] SSH client started
SSH connection established to ${remoteState.hostname}.
Welcome to ${remoteState.hostname}
Type 'exit' to disconnect.`
              | None =>
                `ssh: connect to host ${host}: Connection refused`
              }
            } else if ni.ping(host) {
              `ssh: connect to host ${host}: Connection refused
(SSH service not running on this host)`
            } else {
              `ssh: connect to host ${host}: No route to host`
            }
          | None =>
            `ssh: connect to host ${target}: Connection refused
(Network not available)`
          }
        }
      | "rdp" | "mstsc" =>
        switch Array.get(args, 0) {
        | None => "Usage: rdp <host>"
        | Some(host) =>
          LaptopState.addCpuSpike(activeState.processManager, 2.0)
          // Check if host has RDP via current session's network interface
          switch activeState.networkInterface {
          | Some(ni) =>
            if ni.ping(host) {
              // Get the remote state for this host (RDP works on same devices as SSH)
              switch ni.getRemoteState(host) {
              | Some(remoteState) =>
                // Call the RDP callback if provided
                switch onRdp {
                | Some(callback) =>
                  callback(remoteState, host)
                  `Launching Remote Desktop to ${host}...
RDP connection initiated to ${remoteState.hostname}.`
                | None =>
                  `rdp: Remote Desktop not available in this context.
Use the RDP icon on the desktop instead.`
                }
              | None =>
                `rdp: connect to host ${host}: RDP not supported
(Host does not support remote desktop)`
              }
            } else {
              `rdp: connect to host ${host}: No route to host`
            }
          | None =>
            `rdp: connect to host ${host}: Connection refused
(Network not available)`
          }
        }
      | "traceroute" | "tracert" =>
        switch Array.get(args, 0) {
        | None => "Usage: traceroute <host>"
        | Some(host) =>
          LaptopState.addCpuSpike(activeState.processManager, 4.0)
          switch activeState.networkInterface {
          | Some(ni) =>
            // First try DNS resolution
            let resolvedIp = ni.resolveDns(host)
            switch resolvedIp {
            | None =>
              if ni.ping(host) {
                // Host is directly reachable by IP
                let hops = ni.traceRoute(host)
                if Array.length(hops) == 0 {
                  `traceroute: ${host}: No route to host`
                } else {
                  let header = `traceroute to ${host}, 30 hops max\n`
                  let lines = Array.mapWithIndex(hops, ((ip, name, latency), i) => {
                    let hopNum = String.padStart(Int.toString(i + 1), 2, " ")
                    `${hopNum}  ${name} (${ip})  ${Int.toString(latency)}ms`
                  })
                  header ++ Array.join(lines, "\n")
                }
              } else {
                `traceroute: ${host}: Name or service not known`
              }
            | Some(ip) =>
              let hops = ni.traceRoute(ip)
              if Array.length(hops) == 0 {
                `traceroute: ${host}: No route to host`
              } else {
                let header = `traceroute to ${host} (${ip}), 30 hops max\n`
                let lines = Array.mapWithIndex(hops, ((hopIp, name, latency), i) => {
                  let hopNum = String.padStart(Int.toString(i + 1), 2, " ")
                  `${hopNum}  ${name} (${hopIp})  ${Int.toString(latency)}ms`
                })
                header ++ Array.join(lines, "\n")
              }
            }
          | None =>
            `traceroute: ${host}: Network not available`
          }
        }
      | "nslookup" =>
        switch Array.get(args, 0) {
        | None => "Usage: nslookup <hostname>"
        | Some(host) =>
          LaptopState.addCpuSpike(activeState.processManager, 1.0)
          switch activeState.networkInterface {
          | Some(ni) =>
            switch ni.resolveDns(host) {
            | Some(ip) =>
              `Server:  dns.google
Address:  8.8.8.8

Name:    ${host}
Address: ${ip}`
            | None =>
              `Server:  dns.google
Address:  8.8.8.8

** server can't find ${host}: NXDOMAIN`
            }
          | None =>
            `nslookup: ${host}: Network not available`
          }
        }
      | "dig" =>
        switch Array.get(args, 0) {
        | None => "Usage: dig <hostname>"
        | Some(host) =>
          LaptopState.addCpuSpike(activeState.processManager, 1.0)
          switch activeState.networkInterface {
          | Some(ni) =>
            switch ni.resolveDns(host) {
            | Some(ip) =>
              `; <<>> DiG 9.16.1 <<>> ${host}
;; QUESTION SECTION:
;${host}.                  IN      A

;; ANSWER SECTION:
${host}.           300     IN      A       ${ip}

;; Query time: 12 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; MSG SIZE  rcvd: 56`
            | None =>
              `; <<>> DiG 9.16.1 <<>> ${host}
;; QUESTION SECTION:
;${host}.                  IN      A

;; AUTHORITY SECTION:
.                   86400   IN      SOA     a.root-servers.net.

;; Query time: 24 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)

** No answer for ${host}`
            }
          | None =>
            `dig: ${host}: Network not available`
          }
        }
      | "exit" | "logout" =>
        // Exit SSH session if in one
        if isInSSH() {
          let session = Array.get(sshStack.contents, Array.length(sshStack.contents) - 1)
          switch session {
          | Some(s) =>
            // Close SSH client on the machine that initiated the connection
            // Get the previous state (one level up in stack, or local state if exiting first SSH)
            let previousState = if Array.length(sshStack.contents) > 1 {
              switch Array.get(sshStack.contents, Array.length(sshStack.contents) - 2) {
              | Some(prevSession) => prevSession.remoteState
              | None => state
              }
            } else {
              state
            }
            LaptopState.closeApp(previousState.processManager, "ssh.exe")
            // Close SSHD handler on the remote (current) host
            LaptopState.closeApp(s.remoteState.processManager, "sshd.exe")
            // Restore previous directory
            currentDir := s.previousDir
          | None => ()
          }
          // Pop the session
          sshStack := Array.slice(sshStack.contents, ~start=0, ~end=Array.length(sshStack.contents) - 1)
          "Connection to remote host closed."
        } else {
          "logout: not in SSH session"
        }
      | "shutdown" =>
        let ip = activeState.ipAddress
        PowerManager.manualShutdownDevice(ip)
        "System is shutting down..."
      | "reboot" =>
        let ip = activeState.ipAddress
        let wasShutdown = PowerManager.isDeviceShutdown(ip)
        if wasShutdown {
          if PowerManager.deviceHasPower(ip) {
            PowerManager.bootDevice(ip)
            "System is rebooting..."
          } else {
            "reboot: no power available"
          }
        } else {
          PowerManager.manualShutdownDevice(ip)
          if PowerManager.deviceHasPower(ip) {
            PowerManager.bootDevice(ip)
            "System is rebooting..."
          } else {
            "reboot: no power available after shutdown"
          }
        }
      | "" => ""
      | _ => `'${cmdName}' is not recognized as an internal or external command.`
      }

      if output != "" {
        addOutput(output)
      }
    }

    currentInput := ""
    updateInput()
  }

  // Navigate history up
  let historyUp = (): unit => {
    let len = Array.length(commandHistory.contents)
    if len > 0 {
      if historyIndex.contents == -1 {
        historyIndex := len - 1
      } else if historyIndex.contents > 0 {
        historyIndex := historyIndex.contents - 1
      }
      currentInput := Array.get(commandHistory.contents, historyIndex.contents)->Option.getOr("")
      updateInput()
    }
  }

  // Navigate history down
  let historyDown = (): unit => {
    let len = Array.length(commandHistory.contents)
    if historyIndex.contents != -1 {
      if historyIndex.contents < len - 1 {
        historyIndex := historyIndex.contents + 1
        currentInput := Array.get(commandHistory.contents, historyIndex.contents)->Option.getOr("")
      } else {
        historyIndex := -1
        currentInput := ""
      }
      updateInput()
    }
  }

  // Keyboard handling
  let isFocused = ref(false)

  Graphics.on(bg, "pointerdown", _ => {
    isFocused := true
  })

  let setupKeyboard: (ref<bool>, ref<string>, unit => unit, unit => unit, unit => unit, unit => unit) => unit = %raw(`
    function(isFocused, currentInput, updateInput, executeCommand, historyUp, historyDown) {
      const handler = (e) => {
        if (!isFocused.contents) return;

        if (e.key === 'Enter') {
          e.preventDefault();
          executeCommand();
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          historyUp();
        } else if (e.key === 'ArrowDown') {
          e.preventDefault();
          historyDown();
        } else if (e.key === 'Backspace') {
          e.preventDefault();
          currentInput.contents = currentInput.contents.slice(0, -1);
          updateInput();
        } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
          e.preventDefault();
          currentInput.contents += e.key;
          updateInput();
        }
      };
      window.addEventListener('keydown', handler);
      return handler;
    }
  `)

  let _ = setupKeyboard(isFocused, currentInput, updateInput, executeCommand, historyUp, historyDown)

  // Welcome message
  addOutput("CorpOS Terminal [Version 2.4.1]")
  addOutput("Type 'help' for available commands.")
  addOutput("")
  updateInput()

  container
}
END OF COMMENTED OUT SECTION */

// ============================================
// Notepad with editable text using GlobalNetworkData
// ============================================
let openNotepad = (laptop: t, desktop: Container.t, ~filePath: option<string>=?, ()): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "notepad.exe")

  let path = filePath->Option.getOr("C:\\Users\\Admin\\Documents\\notes.txt")
  let fileName = String.split(path, "\\")->Array.get(_, Array.length(String.split(path, "\\")) - 1)->Option.getOr("Untitled")

  // Read file from device filesystem
  let initialContent = switch DeviceView.readFile(laptop.state.ipAddress, path) {
  | Ok(content) => content
  | Error(_) => "" // New file or error
  }

  let setInputFocused: bool => unit = %raw(`function(focused) { window.__pixiui_input_focused = focused; }`)

  let win = AppWindow.make(
    ~title=`Notepad - ${fileName}`,
    ~w=380.0,
    ~h=280.0,
    ~appName="Notepad",
    ~onClose=() => {
      setInputFocused(false)
      LaptopState.closeApp(laptop.state.processManager, "notepad.exe")
    },
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    Container.destroy(win.container)
  })
  Container.setX(win.container, 200.0)
  Container.setY(win.container, 150.0)

  let content = AppWindow.getContent(win)

  // Text area background
  let textBg = Graphics.make()
  let _ = textBg
    ->Graphics.rect(5.0, 5.0, 360.0, 235.0)
    ->Graphics.fill({"color": 0xffffff})
    ->Graphics.stroke({"width": 1, "color": 0xcccccc})
  Graphics.setEventMode(textBg, "static")
  Graphics.setCursor(textBg, "text")
  let _ = Container.addChildGraphics(content, textBg)

  // Use @pixi/ui Input for editable text
  let inputBg = Graphics.make()
  let _ = inputBg->Graphics.rect(0.0, 0.0, 350.0, 225.0)->Graphics.fill({"color": 0xffffff})

  let textInput = PixiUI.Input.make({
    "bg": inputBg,
    "value": initialContent,
    "textStyle": {
      "fontSize": 11,
      "fill": 0x000000,
      "fontFamily": "monospace",
      "wordWrap": true,
      "wordWrapWidth": 340,
    },
    "padding": 5,
  })
  PixiUI.Input.setX(textInput, 10.0)
  PixiUI.Input.setY(textInput, 10.0)
  let _ = Container.addChild(content, PixiUI.Input.toContainer(textInput))

  // Auto-save on change (copy-on-write: creates new content)
  PixiUI.Signal.connect(PixiUI.Input.onChange(textInput), newText => {
    let _ = DeviceView.writeFile(laptop.state.ipAddress, path, newText)
  })

  // Set global flag when input is clicked (for Terminal to check)
  let inputContainer = PixiUI.Input.toContainer(textInput)
  Container.setEventMode(inputContainer, "static")
  Container.on(inputContainer, "pointerdown", _ => setInputFocused(true))

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// File Manager using GlobalNetworkData (simplified)
// ============================================
let openFileManager = (laptop: t, desktop: Container.t): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "explorer.exe")

  let win = AppWindow.make(
    ~title="File Manager - All Files",
    ~w=420.0,
    ~h=320.0,
    ~appName="File Manager",
    ~onClose=() => LaptopState.closeApp(laptop.state.processManager, "explorer.exe"),
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    Container.destroy(win.container)
  })
  Container.setX(win.container, 150.0)
  Container.setY(win.container, 100.0)

  let content = AppWindow.getContent(win)

  // Current path state
  let currentPath = ref("C:\\")

  // Header with current path
  let headerText = Text.make({
    "text": `Files on ${laptop.state.hostname} (${laptop.state.ipAddress})`,
    "style": {"fontSize": 11, "fill": 0x000000, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  Text.setX(headerText, 10.0)
  Text.setY(headerText, 10.0)
  let _ = Container.addChildText(content, headerText)

  // Path display
  let pathText = Text.make({
    "text": `Path: ${currentPath.contents}`,
    "style": {"fontSize": 10, "fill": 0x666666, "fontFamily": "monospace"},
  })
  Text.setX(pathText, 10.0)
  Text.setY(pathText, 25.0)
  let _ = Container.addChildText(content, pathText)

  // File list container
  let fileList = Container.make()
  Container.setY(fileList, 45.0)
  let _ = Container.addChild(content, fileList)

  // Function to render current directory
  let rec renderDirectory = (): unit => {
    // Clear current list
    Container.removeChildren(fileList)

    let yOffset = ref(0.0)

    // Add ".." entry if not at root
    if currentPath.contents != "C:\\" {
      let item = Container.make()
      Container.setY(item, yOffset.contents)
      Container.setEventMode(item, "static")
      Container.setCursor(item, "pointer")

      let itemBg = Graphics.make()
      let _ = itemBg->Graphics.rect(0.0, 0.0, 400.0, 20.0)->Graphics.fill({"color": 0xf5f5f5})
      let _ = Container.addChildGraphics(item, itemBg)

      let itemText = Text.make({
        "text": "[DIR]  ..",
        "style": {"fontSize": 11, "fill": 0x000000, "fontFamily": "monospace"},
      })
      Text.setX(itemText, 10.0)
      Text.setY(itemText, 3.0)
      let _ = Container.addChildText(item, itemText)

      // Click to go up one level
      Container.on(item, "pointertap", _ => {
        // Remove last directory from path
        let parts = String.split(currentPath.contents, "\\")
        let newParts = Array.slice(parts, ~start=0, ~end=Array.length(parts) - 1)
        let newPath = if Array.length(newParts) <= 1 {
          "C:\\"
        } else {
          Array.join(newParts, "\\")
        }
        currentPath := newPath
        Text.setText(pathText, `Path: ${currentPath.contents}`)
        renderDirectory()
      })

      let _ = Container.addChild(fileList, item)
      yOffset := yOffset.contents +. 22.0
    }

    // Get files in current directory
    switch DeviceView.listFiles(laptop.state.ipAddress, currentPath.contents) {
    | Some(items) =>
      Array.forEach(items, ((itemName, isDir, isLocked, sizeMB)) => {

        let itemContainer = Container.make()
        Container.setY(itemContainer, yOffset.contents)
        Container.setEventMode(itemContainer, "static")
        Container.setCursor(itemContainer, "pointer")

        let itemBg = Graphics.make()
        let bgColor = if mod(Int.fromFloat(yOffset.contents /. 22.0), 2) == 0 { 0xffffff } else { 0xf5f5f5 }
        let _ = itemBg->Graphics.rect(0.0, 0.0, 400.0, 20.0)->Graphics.fill({"color": bgColor})
        let _ = Container.addChildGraphics(itemContainer, itemBg)

        let prefix = if isDir { "[DIR]  " } else { "[FILE] " }
        let color = if isLocked { 0xff0000 } else { 0x000000 }
        let suffix = if isLocked { " [LOCKED]" } else { "" }
        let sizeStr = if sizeMB >= 1.0 {
          ` (${Float.toFixed(sizeMB, ~digits=1)} MB)`
        } else if sizeMB > 0.0 {
          let kb = sizeMB *. 1024.0
          ` (${Float.toFixed(kb, ~digits=0)} KB)`
        } else {
          ""
        }

        let itemText = Text.make({
          "text": `${prefix}${itemName}${suffix}${sizeStr}`,
          "style": {"fontSize": 11, "fill": color, "fontFamily": "monospace"},
        })
        Text.setX(itemText, 10.0)
        Text.setY(itemText, 3.0)
        let _ = Container.addChildText(itemContainer, itemText)

        // Click handler
        Container.on(itemContainer, "pointertap", _ => {
          if isDir {
            // Navigate into directory
            let newPath = if currentPath.contents == "C:\\" {
              currentPath.contents ++ itemName
            } else {
              currentPath.contents ++ "\\" ++ itemName
            }
            currentPath := newPath
            Text.setText(pathText, `Path: ${currentPath.contents}`)
            renderDirectory()
          } else if !isLocked {
            // Open file in notepad if it's a text file
            if String.endsWith(itemName, ".txt") || String.endsWith(itemName, ".log") || String.endsWith(itemName, ".conf") || String.endsWith(itemName, ".key") || String.endsWith(itemName, ".dat") || String.endsWith(itemName, ".json") || String.endsWith(itemName, ".env") {
              let fullPath = if currentPath.contents == "C:\\" {
                currentPath.contents ++ itemName
              } else {
                currentPath.contents ++ "\\" ++ itemName
              }
              openNotepad(laptop, desktop, ~filePath=fullPath, ())
            }
          }
        })

        let _ = Container.addChild(fileList, itemContainer)
        yOffset := yOffset.contents +. 22.0
      })
    | None => ()
    }
  }

  // Initial render
  renderDirectory()

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// Network Manager - Visual Topology Map
// ============================================

// Type for grouping devices by subnet
type deviceGroup = {
  name: string,
  color: int,
  devices: array<(string, string, DeviceTypes.deviceType)>, // (ip, name, type)
  x: float,
  y: float,
}

// External reference to GlobalNetworkManager without circular import
@module("./GlobalNetworkManager.res.mjs") external getGlobalManager: unit => 'a = "get"

// Helper to get devices from manager
let getDevicesFromManager: 'a => array<DeviceTypes.device> = %raw(`
  function(manager) {
    return Object.values(manager.devices);
  }
`)

// Import isReachableFrom from NetworkManager module
@module("./NetworkManager.res.mjs")
external isReachableFromManager: ('a, string, string) => bool = "isReachableFrom"

let openNetworkManager = (laptop: t, desktop: Container.t): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "netman.exe")

  let win = AppWindow.make(
    ~title="Network Topology",
    ~w=700.0,
    ~h=500.0,
    ~appName="Network Topology",
    ~onClose=() => LaptopState.closeApp(laptop.state.processManager, "netman.exe"),
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    Container.destroy(win.container)
  })
  Container.setX(win.container, 100.0)
  Container.setY(win.container, 50.0)

  let content = AppWindow.getContent(win)

  // Get devices using external binding to avoid circular dependency
  {
      let manager = getGlobalManager()
      let allDevices = getDevicesFromManager(manager)

      // Filter to only show devices reachable from this laptop
      let sourceIp = laptop.state.ipAddress
      let devices = Array.filter(allDevices, device => {
        let info = device.getInfo()
        isReachableFromManager(manager, sourceIp, info.ipAddress)
      })

      // Group devices by zone (matches NetworkDesktop zones)
      // Named bindings avoid Array.getUnsafe and provide safe direct access
      // Edge Networks
      let lanGroup: deviceGroup = {
        name: "LAN (192.168.1.x)",
        color: 0x4CAF50,
        devices: [],
        x: 100.0,
        y: 150.0,
      }
      // Downtown Office Zones
      let dmzGroup: deviceGroup = {
        name: "DMZ (10.0.0.x)",
        color: 0xFF9800,
        devices: [],
        x: 280.0,
        y: 80.0,
      }
      let internalGroup: deviceGroup = {
        name: "Internal (10.0.1.x)",
        color: 0x2196F3,
        devices: [],
        x: 280.0,
        y: 160.0,
      }
      let devGroup: deviceGroup = {
        name: "Dev (10.0.2.x)",
        color: 0x9C27B0,
        devices: [],
        x: 280.0,
        y: 240.0,
      }
      let securityGroup: deviceGroup = {
        name: "Security (10.0.3.x)",
        color: 0xF44336,
        devices: [],
        x: 280.0,
        y: 320.0,
      }
      let mgmtGroup: deviceGroup = {
        name: "Mgmt (172.16.0.x)",
        color: 0x00BCD4,
        devices: [],
        x: 280.0,
        y: 400.0,
      }
      let iotGroup: deviceGroup = {
        name: "IoT (192.168.100.x)",
        color: 0xE91E63,
        devices: [],
        x: 100.0,
        y: 320.0,
      }
      let scadaGroup: deviceGroup = {
        name: "SCADA (10.10.1.x)",
        color: 0xFF5722,
        devices: [],
        x: 100.0,
        y: 400.0,
      }
      // Public Services
      let atlasGroup: deviceGroup = {
        name: "Atlas (8.8.8.x)",
        color: 0x4285F4,
        devices: [],
        x: 500.0,
        y: 80.0,
      }
      let nexusGroup: deviceGroup = {
        name: "Nexus (1.1.1.x)",
        color: 0xF38020,
        devices: [],
        x: 600.0,
        y: 200.0,
      }
      let devhubGroup: deviceGroup = {
        name: "DevHub (140.82.x.x)",
        color: 0x24292e,
        devices: [],
        x: 500.0,
        y: 320.0,
      }

      // Classify devices into groups (zone-based)
      let lanDevices = ref([])
      let ruralDevices = ref([])
      let dmzDevices = ref([])
      let internalDevices = ref([])
      let devDevices = ref([])
      let securityDevices = ref([])
      let managementDevices = ref([])
      let iotDevices = ref([])
      let scadaDevices = ref([])
      let atlasDevices = ref([])
      let nexusDevices = ref([])
      let devhubDevices = ref([])
      let _webDevices = ref([])

      Array.forEach(devices, device => {
        let info = device.getInfo()
        let ip = info.ipAddress
        let name = info.name
        let deviceType = info.deviceType

        // Skip routers - they're already shown as topology nodes
        if deviceType != DeviceTypes.Router {
          // Edge Networks
          if String.startsWith(ip, "192.168.1.") {
            lanDevices := Array.concat(lanDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "192.168.2.") {
            ruralDevices := Array.concat(ruralDevices.contents, [(ip, name, deviceType)])
          // Downtown Office Zones
          } else if String.startsWith(ip, "10.0.0.") {
            dmzDevices := Array.concat(dmzDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "10.0.1.") {
            internalDevices := Array.concat(internalDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "10.0.2.") {
            devDevices := Array.concat(devDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "10.0.3.") {
            securityDevices := Array.concat(securityDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "172.16.0.") {
            managementDevices := Array.concat(managementDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "192.168.100.") {
            iotDevices := Array.concat(iotDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "10.10.1.") {
            scadaDevices := Array.concat(scadaDevices.contents, [(ip, name, deviceType)])
          // Public Services
          } else if String.startsWith(ip, "8.8.8.") || String.startsWith(ip, "142.250.") {
            atlasDevices := Array.concat(atlasDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "1.1.1.") || String.startsWith(ip, "104.16.") {
            nexusDevices := Array.concat(nexusDevices.contents, [(ip, name, deviceType)])
          } else if String.startsWith(ip, "140.82.") {
            devhubDevices := Array.concat(devhubDevices.contents, [(ip, name, deviceType)])
          }
        }
      })

      // Update groups with actual devices (safe: named bindings, no array indexing)
      let _finalGroups = [
        {...lanGroup, devices: lanDevices.contents},
        {...dmzGroup, devices: dmzDevices.contents},
        {...internalGroup, devices: internalDevices.contents},
        {...devGroup, devices: devDevices.contents},
        {...securityGroup, devices: securityDevices.contents},
        {...mgmtGroup, devices: managementDevices.contents},
        {...iotGroup, devices: iotDevices.contents},
        {...scadaGroup, devices: scadaDevices.contents},
        {...atlasGroup, devices: atlasDevices.contents},
        {...nexusGroup, devices: nexusDevices.contents},
        {...devhubGroup, devices: devhubDevices.contents},
      ]

      // Draw topology with ISP tier structure (matches Network Desktop)
      let connectionLayer = Graphics.make()
      let _ = Container.addChildGraphics(content, connectionLayer)

      // Helper to draw a router node
      let drawRouter = (x: float, y: float, label: string, color: int): unit => {
        let icon = Graphics.make()
        let _ = icon
          ->Graphics.circle(0.0, 0.0, 8.0)
          ->Graphics.fill({"color": color})
          ->Graphics.stroke({"color": 0x000000, "width": 1.5})
        Graphics.setX(icon, x)
        Graphics.setY(icon, y)
        let _ = Container.addChildGraphics(content, icon)

        let text = Text.make({
          "text": label,
          "style": {"fontSize": 7, "fill": 0x000000, "fontWeight": "bold", "align": "center"},
        })
        Text.setX(text, x -. 25.0)
        Text.setY(text, y +. 10.0)
        let _ = Container.addChildText(content, text)
      }

      // Helper to draw a connection line
      let drawConnection = (x1: float, y1: float, x2: float, y2: float, color: int, width: float): unit => {
        let _ = connectionLayer
          ->Graphics.moveTo(x1, y1)
          ->Graphics.lineTo(x2, y2)
          ->Graphics.stroke({"color": color, "width": width, "alpha": 0.6})
      }

      // Layout positions (compact version for laptop screen)
      let edgeX = 80.0
      let tier3X = 200.0
      let tier2X = 300.0
      let tier1X = 400.0
      let serviceX = 550.0

      let mainRouterY = 120.0
      let ruralRouterY = 280.0
      let businessIspY = 80.0
      let ruralIspY = 240.0
      let regionalIspY = 160.0
      let backboneY = 160.0
      let atlasY = 80.0
      let nexusY = 200.0
      let devhubY = 320.0

      // Draw edge routers
      drawRouter(edgeX, mainRouterY, "Downtown\nRouter", 0xFF9800)
      drawRouter(edgeX, ruralRouterY, "Rural\nRouter", 0xFF9800)

      // Draw ISP tier 3
      drawRouter(tier3X, businessIspY, "Business\nISP", 0xFFFF00)
      drawRouter(tier3X, ruralIspY, "Rural\nISP", 0xFFFF00)

      // Draw ISP tier 2
      drawRouter(tier2X, regionalIspY, "Regional\nISP", 0xFF9800)

      // Draw ISP tier 1
      drawRouter(tier1X, backboneY, "Internet\nBackbone", 0xFF0000)

      // Draw service routers
      drawRouter(serviceX, atlasY, "Atlas", 0x4285F4)
      drawRouter(serviceX, nexusY, "Nexus", 0xF38020)
      drawRouter(serviceX, devhubY, "DevHub", 0x666666)

      // Draw connections (matches actual topology)
      // Edge to ISP Tier 3
      drawConnection(edgeX, mainRouterY, tier3X, businessIspY, 0xFFFF00, 2.0)
      drawConnection(edgeX, ruralRouterY, tier3X, ruralIspY, 0xFFFF00, 2.0)

      // Tier 3 to Tier 2
      drawConnection(tier3X, businessIspY, tier2X, regionalIspY, 0xFF9800, 2.5)
      drawConnection(tier3X, ruralIspY, tier2X, regionalIspY, 0xFF9800, 2.5)

      // Tier 2 to Tier 1
      drawConnection(tier2X, regionalIspY, tier1X, backboneY, 0xFF0000, 3.0)

      // Tier 1 to Services
      drawConnection(tier1X, backboneY, serviceX, atlasY, 0xFFFFFF, 2.0)
      drawConnection(tier1X, backboneY, serviceX, nexusY, 0xFFFFFF, 2.0)
      drawConnection(tier1X, backboneY, serviceX, devhubY, 0xFFFFFF, 2.0)

      // Draw local devices around edge routers
      let deviceRadius = 35.0

      // Downtown devices (LAN + all office zones)
      let downtownDevices = Array.concat(
        lanDevices.contents,
        Array.concat(
          dmzDevices.contents,
          Array.concat(
            internalDevices.contents,
            Array.concat(
              devDevices.contents,
              Array.concat(
                securityDevices.contents,
                Array.concat(managementDevices.contents, Array.concat(iotDevices.contents, scadaDevices.contents))
              )
            )
          )
        )
      )
      Array.forEachWithIndex(downtownDevices, ((_ip, _name, _deviceType), i) => {
        let angle = Int.toFloat(i) *. (6.28 /. Int.toFloat(Array.length(downtownDevices)))
        let dx = edgeX +. deviceRadius *. Math.cos(angle)
        let dy = mainRouterY +. deviceRadius *. Math.sin(angle)

        let dot = Graphics.make()
        let _ = dot->Graphics.circle(0.0, 0.0, 2.0)->Graphics.fill({"color": 0x4CAF50})
        Graphics.setX(dot, dx)
        Graphics.setY(dot, dy)
        let _ = Container.addChildGraphics(content, dot)

        drawConnection(edgeX, mainRouterY, dx, dy, 0x4CAF50, 1.0)
      })

      // Rural devices
      Array.forEachWithIndex(ruralDevices.contents, ((_ip, _name, _deviceType), i) => {
        let dx = edgeX +. 30.0
        let dy = ruralRouterY +. 25.0 +. Int.toFloat(i) *. 12.0

        let dot = Graphics.make()
        let _ = dot->Graphics.circle(0.0, 0.0, 2.0)->Graphics.fill({"color": 0x4CAF50})
        Graphics.setX(dot, dx)
        Graphics.setY(dot, dy)
        let _ = Container.addChildGraphics(content, dot)

        drawConnection(edgeX, ruralRouterY, dx, dy, 0x4CAF50, 1.0)
      })

      // Service provider devices (vertical stacks next to routers)
      let serviceDeviceOffset = 20.0

      // Atlas devices
      Array.forEachWithIndex(atlasDevices.contents, ((_ip, _name, _deviceType), i) => {
        let dx = serviceX +. serviceDeviceOffset
        let dy = atlasY -. 10.0 +. Int.toFloat(i) *. 12.0

        let dot = Graphics.make()
        let _ = dot->Graphics.circle(0.0, 0.0, 2.0)->Graphics.fill({"color": 0x4285F4})
        Graphics.setX(dot, dx)
        Graphics.setY(dot, dy)
        let _ = Container.addChildGraphics(content, dot)

        drawConnection(serviceX, atlasY, dx, dy, 0xFFFFFF, 1.0)
      })

      // Nexus devices
      Array.forEachWithIndex(nexusDevices.contents, ((_ip, _name, _deviceType), i) => {
        let dx = serviceX +. serviceDeviceOffset
        let dy = nexusY -. 10.0 +. Int.toFloat(i) *. 12.0

        let dot = Graphics.make()
        let _ = dot->Graphics.circle(0.0, 0.0, 2.0)->Graphics.fill({"color": 0xF38020})
        Graphics.setX(dot, dx)
        Graphics.setY(dot, dy)
        let _ = Container.addChildGraphics(content, dot)

        drawConnection(serviceX, nexusY, dx, dy, 0xFFFFFF, 1.0)
      })

      // DevHub devices
      Array.forEachWithIndex(devhubDevices.contents, ((_ip, _name, _deviceType), i) => {
        let dx = serviceX +. serviceDeviceOffset
        let dy = devhubY -. 10.0 +. Int.toFloat(i) *. 12.0

        let dot = Graphics.make()
        let _ = dot->Graphics.circle(0.0, 0.0, 2.0)->Graphics.fill({"color": 0x666666})
        Graphics.setX(dot, dx)
        Graphics.setY(dot, dy)
        let _ = Container.addChildGraphics(content, dot)

        drawConnection(serviceX, devhubY, dx, dy, 0xFFFFFF, 1.0)
      })

      // Legend
      let legend = Text.make({
        "text": "Yellow=Tier3 Orange=Tier2 Red=Tier1 White=Services Green=LAN Blue=VLAN",
        "style": {"fontSize": 7, "fill": 0x666666},
      })
      Text.setX(legend, 10.0)
      Text.setY(legend, 470.0)
      let _ = Container.addChildText(content, legend)
  }

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// Process Explorer using real process list (auto-refresh)
// ============================================

// setInterval binding
let setInterval: (unit => unit, int) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)

let openProcessExplorer = (laptop: t, desktop: Container.t): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "taskmgr.exe")

  let intervalId = ref(0)

  let win = AppWindow.make(
    ~title="Process Explorer",
    ~w=480.0,
    ~h=350.0,
    ~appName="Process Explorer",
    ~onClose=() => {
      clearInterval(intervalId.contents)
      LaptopState.closeApp(laptop.state.processManager, "taskmgr.exe")
    },
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    clearInterval(intervalId.contents)
    Container.destroy(win.container)
  })
  Container.setX(win.container, 160.0)
  Container.setY(win.container, 80.0)

  let content = AppWindow.getContent(win)

  // Stats text (will be updated)
  let statsText = Text.make({
    "text": "",
    "style": {"fontSize": 11, "fill": 0x0066cc, "fontFamily": "monospace"},
  })
  Text.setX(statsText, 10.0)
  Text.setY(statsText, 10.0)
  let _ = Container.addChildText(content, statsText)

  // Header
  let header = Text.make({
    "text": "PID    NAME                     CPU%     Gq",
    "style": {"fontSize": 11, "fill": 0x000000, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  Text.setX(header, 10.0)
  Text.setY(header, 35.0)
  let _ = Container.addChildText(content, header)

  // Process list container (can be cleared and re-rendered)
  let processList = Container.make()
  Container.setY(processList, 55.0)
  let _ = Container.addChild(content, processList)

  // Render function
  let renderProcesses = (): unit => {
    // Update stats - using unified storage model (Gq)
    let (usedGq, totalGq) = LaptopState.getTotalStorageUsage(laptop.state.processManager, laptop.state.ipAddress)
    let cpuUsage = LaptopState.getCpuUsage(laptop.state.processManager)
    Text.setText(statsText, `Storage: ${Int.toString(usedGq)} Gq / ${Int.toString(totalGq)} Gq   CPU: ${Float.toFixed(cpuUsage, ~digits=1)}%`)

    // Clear old process list
    Container.removeChildren(processList)

    // Render processes
    let processes = LaptopState.getProcesses(laptop.state.processManager)
    Array.forEachWithIndex(processes, (proc, i) => {
      if i < 15 {
        let pidStr = String.padStart(Int.toString(proc.pid), 5, " ")
        let nameStr = String.padEnd(proc.name, 24, " ")
        let cpuStr = String.padStart(Float.toFixed(proc.cpuPercent, ~digits=1), 5, " ")
        let gqStr = String.padStart(Int.toString(proc.sizeGq), 6, " ")

        let color = if proc.isSystem { 0x666666 } else { 0x000000 }

        let procText = Text.make({
          "text": `${pidStr}  ${nameStr} ${cpuStr}%  ${gqStr}`,
          "style": {"fontSize": 10, "fill": color, "fontFamily": "monospace"},
        })
        Text.setX(procText, 10.0)
        Text.setY(procText, Int.toFloat(i) *. 18.0)
        let _ = Container.addChildText(processList, procText)
      }
    })
  }

  // Initial render
  renderProcesses()

  // Auto-refresh every 1 second
  intervalId := setInterval(renderProcesses, 1000)

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// Recycle Bin
// ============================================
let openRecycleBin = (laptop: t, desktop: Container.t): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "recyclebin.exe")

  let win = AppWindow.make(
    ~title="Recycle Bin",
    ~w=350.0,
    ~h=200.0,
    ~appName="Recycle Bin",
    ~onClose=() => LaptopState.closeApp(laptop.state.processManager, "recyclebin.exe"),
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    Container.destroy(win.container)
  })
  Container.setX(win.container, 220.0)
  Container.setY(win.container, 180.0)

  let content = AppWindow.getContent(win)
  let msg = Text.make({
    "text": "Recycle Bin is empty.",
    "style": {"fontSize": 12, "fill": 0x666666, "fontStyle": "italic"},
  })
  Text.setX(msg, 10.0)
  Text.setY(msg, 50.0)
  let _ = Container.addChildText(content, msg)

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// Terminal window
// ============================================

// Forward declaration for RDP (openRemoteDesktop is defined later)
let openRemoteDesktopRef: ref<option<(t, Container.t, LaptopState.laptopState, string) => unit>> = ref(None)

let openTerminal = (laptop: t, desktop: Container.t): unit => {
  let pid = LaptopState.openApp(laptop.state.processManager, "cmd.exe")

  let win = AppWindow.make(
    ~title="Command Prompt",
    ~w=500.0,
    ~h=380.0,
    ~appName="Terminal",
    ~onClose=() => LaptopState.closeApp(laptop.state.processManager, "cmd.exe"),
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, pid, () => {
    Container.destroy(win.container)
  })
  Container.setX(win.container, 140.0)
  Container.setY(win.container, 60.0)

  let content = AppWindow.getContent(win)

  // Use unified Terminal component (same as servers)
  let terminal = Terminal.make(
    ~width=490.0,
    ~height=345.0,
    ~prompt=`${laptop.state.hostname}> `,
    ~ipAddress=laptop.state.ipAddress,
    ~deviceState=laptop.state,
    ()
  )
  let _ = Container.addChild(content, terminal.container)

  let _ = Container.addChild(desktop, win.container)
}

// ============================================
// Create a desktop icon
// ============================================
let createDesktopIcon = (
  ~name: string,
  ~x: float,
  ~y: float,
  ~onOpen: unit => unit,
): Container.t => {
  let icon = Container.make()
  Container.setX(icon, x)
  Container.setY(icon, y)
  Container.setEventMode(icon, "static")
  Container.setCursor(icon, "pointer")

  // Icon graphic
  let iconBg = Graphics.make()
  let _ = iconBg
    ->Graphics.rect(0.0, 0.0, 60.0, 60.0)
    ->Graphics.fill({"color": 0xffffff})
    ->Graphics.stroke({"width": 2, "color": 0x000000})
  let _ = Container.addChildGraphics(icon, iconBg)

  // Label
  let label = Text.make({
    "text": name,
    "style": {
      "fontSize": 10,
      "fill": 0xffffff,
      "align": "center",
      "wordWrap": true,
      "wordWrapWidth": 60,
    },
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.0)
  Text.setX(label, 30.0)
  Text.setY(label, 65.0)
  let _ = Container.addChildText(icon, label)

  Container.on(icon, "pointertap", _ => onOpen())

  icon
}

// ============================================
// Remote Desktop (RDP) - creates a nested desktop window
// ============================================

// Create a mini desktop for a remote machine (used by RDP)
// Note: openRemoteDesktopRef is declared earlier (before openTerminal)
let createRemoteDesktop = (
  remoteState: LaptopState.laptopState,
  ~width: float,
  ~height: float,
  ~parentDesktop as _: Container.t,
  ~localState as _: LaptopState.laptopState,
): Container.t => {
  let container = Container.make()
  Container.setSortableChildren(container, true)
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)

  // Desktop background - slightly different color to show it's remote
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, 0.0, width, height)->Graphics.fill({"color": 0x1e4d78})
  let _ = Container.addChildGraphics(container, bg)

  // Inner desktop for windows
  let innerDesktop = Container.make()
  Container.setSortableChildren(innerDesktop, true)
  Container.setEventMode(innerDesktop, "static")
  Container.setInteractiveChildren(innerDesktop, true)
  let _ = Container.addChild(container, innerDesktop)

  // Create a laptop type for the remote machine
  let remoteLaptop: t = {
    container,
    desktop: innerDesktop,
    taskbar: Graphics.make(),
    state: remoteState,
    currentPath: "C:\\Users\\Admin",
  }

  // Create desktop icons for the remote machine (scaled down slightly)
  let iconScale = 0.8
  let iconSpacing = 70.0

  let filesIcon = createDesktopIcon(~name="Files", ~x=15.0, ~y=15.0, ~onOpen=() => openFileManager(remoteLaptop, innerDesktop))
  ObservablePoint.set(Container.scale(filesIcon), iconScale, ~y=iconScale)
  let _ = Container.addChild(innerDesktop, filesIcon)

  let notepadIcon = createDesktopIcon(~name="Notepad", ~x=15.0, ~y=15.0 +. iconSpacing, ~onOpen=() => openNotepad(remoteLaptop, innerDesktop, ()))
  ObservablePoint.set(Container.scale(notepadIcon), iconScale, ~y=iconScale)
  let _ = Container.addChild(innerDesktop, notepadIcon)

  let tasksIcon = createDesktopIcon(~name="Tasks", ~x=15.0, ~y=15.0 +. iconSpacing *. 2.0, ~onOpen=() => openProcessExplorer(remoteLaptop, innerDesktop))
  ObservablePoint.set(Container.scale(tasksIcon), iconScale, ~y=iconScale)
  let _ = Container.addChild(innerDesktop, tasksIcon)

  let terminalIcon = createDesktopIcon(~name="Terminal", ~x=15.0, ~y=15.0 +. iconSpacing *. 3.0, ~onOpen=() => openTerminal(remoteLaptop, innerDesktop))
  ObservablePoint.set(Container.scale(terminalIcon), iconScale, ~y=iconScale)
  let _ = Container.addChild(innerDesktop, terminalIcon)

  // Add RDP icon to allow nested RDP from within this remote desktop
  // This uses the remote machine's network interface to check what hosts it can reach
  let rdpIcon = createDesktopIcon(
    ~name="RDP",
    ~x=15.0 +. 70.0,
    ~y=15.0,
    ~onOpen=() => {
      // When clicked, prompt for host via terminal
      // For nested RDP, user should use terminal's rdp command
      openTerminal(remoteLaptop, innerDesktop)
    },
  )
  ObservablePoint.set(Container.scale(rdpIcon), iconScale, ~y=iconScale)
  let _ = Container.addChild(innerDesktop, rdpIcon)

  // Mini taskbar
  let taskbar = Graphics.make()
  let _ = taskbar
    ->Graphics.rect(0.0, height -. 25.0, width, 25.0)
    ->Graphics.fill({"color": 0x0a0a0a})
  let _ = Container.addChildGraphics(container, taskbar)

  // Show hostname in taskbar
  let hostLabel = Text.make({
    "text": `[RDP] ${remoteState.hostname} (${remoteState.ipAddress})`,
    "style": {"fontSize": 10, "fill": 0x00ff00, "fontFamily": "monospace"},
  })
  Text.setX(hostLabel, 5.0)
  Text.setY(hostLabel, height -. 20.0)
  let _ = Container.addChildText(container, hostLabel)

  container
}

// Open a Remote Desktop connection to a remote host
let openRemoteDesktop = (laptop: t, desktop: Container.t, remoteState: LaptopState.laptopState, remoteHost: string): unit => {
  // Spawn RDP client on local machine
  let clientPid = LaptopState.openApp(laptop.state.processManager, "mstsc.exe")
  // Spawn RDP server handler on remote machine
  let _ = LaptopState.openApp(remoteState.processManager, "rdpserver.exe")

  let win = AppWindow.make(
    ~title=`Remote Desktop - ${remoteState.hostname} [${remoteHost}]`,
    ~w=520.0,
    ~h=420.0,
    ~appName="Remote Desktop",
    ~onClose=() => {
      LaptopState.closeApp(laptop.state.processManager, "mstsc.exe")
      LaptopState.closeApp(remoteState.processManager, "rdpserver.exe")
    },
    (),
  )

  // Register window closer for kill command
  LaptopState.registerWindowCloser(laptop.state.processManager, clientPid, () => {
    LaptopState.closeApp(remoteState.processManager, "rdpserver.exe")
    Container.destroy(win.container)
  })

  Container.setX(win.container, 80.0)
  Container.setY(win.container, 40.0)

  let content = AppWindow.getContent(win)

  // Create the remote desktop inside the window
  let remoteDesktopContainer = createRemoteDesktop(
    remoteState,
    ~width=510.0,
    ~height=380.0,
    ~parentDesktop=desktop,
    ~localState=laptop.state,
  )
  let _ = Container.addChild(content, remoteDesktopContainer)

  let _ = Container.addChild(desktop, win.container)
}

// Initialize the reference for recursive RDP
let _ = openRemoteDesktopRef := Some(openRemoteDesktop)

// ============================================
// Internal helper to create GUI with given state
// ============================================
let makeWithStateInternal = (~width: float, ~height: float, ~state: LaptopState.laptopState, ()): t => {
  let container = Container.make()
  Container.setSortableChildren(container, true)
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)

  // Desktop background
  let bg = Graphics.make()
  let _ = bg->Graphics.rect(0.0, 0.0, width, height)->Graphics.fill({"color": 0x2b5797})
  let _ = Container.addChildGraphics(container, bg)

  let desktop = Container.make()
  Container.setSortableChildren(desktop, true)
  Container.setEventMode(desktop, "static")
  Container.setInteractiveChildren(desktop, true)
  let _ = Container.addChild(container, desktop)

  let laptop = {
    container,
    desktop,
    taskbar: Graphics.make(), // Will be set below
    state,
    currentPath: "C:\\Users\\Admin",
  }

  // Power control function
  let togglePower = () => {
    let ip = state.ipAddress
    let isShutdown = PowerManager.isDeviceShutdown(ip)
    if isShutdown {
      if PowerManager.deviceHasPower(ip) {
        PowerManager.bootDevice(ip)
      }
    } else {
      PowerManager.manualShutdownDevice(ip)
    }
  }

  // Create desktop icons
  let icons = [
    ("Recycle Bin", 20.0, 20.0, () => openRecycleBin(laptop, desktop)),
    ("File Manager", 20.0, 100.0, () => openFileManager(laptop, desktop)),
    ("Network", 20.0, 180.0, () => openNetworkManager(laptop, desktop)),
    ("Notepad", 20.0, 260.0, () => openNotepad(laptop, desktop, ())),
    ("Tasks", 100.0, 20.0, () => openProcessExplorer(laptop, desktop)),
    ("Terminal", 100.0, 100.0, () => openTerminal(laptop, desktop)),
    ("Power", 100.0, 180.0, togglePower),
  ]

  Array.forEach(icons, ((name, x, y, onOpen)) => {
    let icon = createDesktopIcon(~name, ~x, ~y, ~onOpen)
    let _ = Container.addChild(desktop, icon)
  })

  // Taskbar
  let taskbar = Graphics.make()
  let _ = taskbar
    ->Graphics.rect(0.0, height -. 40.0, width, 40.0)
    ->Graphics.fill({"color": 0x1e1e1e})
  let _ = Container.addChildGraphics(container, taskbar)

  let startBtn = Text.make({
    "text": "START",
    "style": {"fontSize": 14, "fill": 0xffffff, "fontWeight": "bold"},
  })
  Text.setX(startBtn, 10.0)
  Text.setY(startBtn, height -. 30.0)
  let _ = Container.addChildText(container, startBtn)

  {...laptop, taskbar}
}

// ============================================
// Create the laptop GUI with existing state (for shared state)
// ============================================
let makeWithState = (~width: float, ~height: float, ~state: LaptopState.laptopState, ()): t => {
  makeWithStateInternal(~width, ~height, ~state, ())
}

// ============================================
// Create the laptop GUI with new state
// ============================================
let make = (~width: float, ~height: float, ~ipAddress: string="192.168.1.102", ~hostname: string="WORKSTATION-PC", ()): t => {
  // Create new state with IP and hostname
  let state = LaptopState.createLaptopState(~ipAddress, ~hostname, ())
  makeWithStateInternal(~width, ~height, ~state, ())
}
