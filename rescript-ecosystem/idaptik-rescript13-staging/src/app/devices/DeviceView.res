// SPDX-License-Identifier: PMPL-1.0-or-later
// Device View - Per-Device Filesystem Trees
// Each device has a filesystem tree where files reference global content IDs
// Paths, names, permissions are device-specific

// ============================================
// Filesystem Tree Structure
// ============================================

type rec fileNode =
  | File({name: string, mutable globalContentId: string, mutable locked: bool}) // Points to GlobalNetworkData content // Device-specific permission
  | Directory({name: string, mutable contents: dict<fileNode>})

// Device filesystem (tree structure)
type deviceFilesystem = {
  deviceIp: string,
  deviceName: string,
  root: fileNode, // Root directory
}

// Global registry of device filesystems
let filesystems: dict<deviceFilesystem> = Dict.make()

// ============================================
// Path Resolution
// ============================================

// Resolve a path to a node
let resolvePath = (fs: deviceFilesystem, path: string): option<fileNode> => {
  let normalizedPath = path->String.replaceAll("/", "\\")
  let parts =
    String.split(normalizedPath, "\\")->Array.filter(p =>
      p != "" && p != "." && p != "C:" && p != "/"
    )

  if Array.length(parts) == 0 {
    Some(fs.root)
  } else {
    let current = ref(fs.root)
    let found = ref(true)

    Array.forEach(parts, part => {
      if found.contents {
        switch current.contents {
        | Directory({contents}) =>
          switch Dict.get(contents, part) {
          | Some(node) => current := node
          | None => found := false
          }
        | File(_) => found := false
        }
      }
    })

    if found.contents {
      Some(current.contents)
    } else {
      None
    }
  }
}

// Get parent directory of a path
let getParentPath = (path: string): string => {
  let parts = String.split(path, "\\")->Array.filter(p => p != "")
  let _ = Array.pop(parts)
  if Array.length(parts) == 0 {
    "C:\\"
  } else {
    Array.join(parts, "\\")
  }
}

// Get filename from path
let getFilename = (path: string): string => {
  let parts = String.split(path, "\\")->Array.filter(p => p != "")
  parts[Array.length(parts) - 1]->Option.getOr("Untitled")
}

// ============================================
// File Operations
// ============================================

// Get filesystem for device
let getFilesystem = (deviceIp: string): option<deviceFilesystem> => {
  Dict.get(filesystems, deviceIp)
}

// List files at a path
let listFiles = (deviceIp: string, path: string): option<array<(string, bool, bool, float)>> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => None
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | Some(Directory({contents})) =>
      let items = Dict.toArray(contents)->Array.map(((name, node)) => {
        switch node {
        | Directory(_) => (name, true, false, 0.0) // (name, isDir, isLocked, sizeMB)
        | File({locked, globalContentId, _}) =>
          let sizeMB = switch GlobalNetworkData.getContent(globalContentId) {
          | Some(content) => content.sizeMB
          | None => 0.0
          }
          (name, false, locked, sizeMB)
        }
      })
      Some(items)
    | _ => None
    }
  }
}

// Read file at path
let readFile = (deviceIp: string, path: string): result<string, string> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | None => Error(`File not found: ${path}`)
    | Some(Directory(_)) => Error(`Is a directory: ${path}`)
    | Some(File({locked: true, _})) => Error(`Permission denied: ${path}`)
    | Some(File({globalContentId, _})) =>
      switch GlobalNetworkData.getContent(globalContentId) {
      | Some(content) => Ok(content.content)
      | None => Error("Content not found in global store")
      }
    }
  }
}

// Write file at path (copy-on-write: creates new content)
let writeFile = (deviceIp: string, path: string, newContent: string): result<unit, string> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | None => Error(`File not found: ${path}`)
    | Some(Directory(_)) => Error(`Is a directory: ${path}`)
    | Some(File({locked: true, _})) => Error(`Permission denied: ${path}`)
    | Some(File(file)) =>
      // Copy-on-write: create new content with new hash
      let newContentId = GlobalNetworkData.updateContent(~oldId=file.globalContentId, ~newContent)
      file.globalContentId = newContentId
      Ok()
    }
  }
}

// Create directory at path
let createDirectory = (deviceIp: string, path: string, name: string): result<unit, string> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | None => Error(`Directory not found: ${path}`)
    | Some(File(_)) => Error(`Not a directory: ${path}`)
    | Some(Directory({contents})) =>
      switch Dict.get(contents, name) {
      | Some(_) => Error(`Already exists: ${name}`)
      | None =>
        Dict.set(
          contents,
          name,
          Directory({
            name,
            contents: Dict.make(),
          }),
        )
        Ok()
      }
    }
  }
}

// Create file at path
let createFile = (deviceIp: string, path: string, name: string, content: string): result<
  unit,
  string,
> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | None => Error(`Directory not found: ${path}`)
    | Some(File(_)) => Error(`Not a directory: ${path}`)
    | Some(Directory({contents})) =>
      switch Dict.get(contents, name) {
      | Some(_) => Error(`Already exists: ${name}`)
      | None =>
        let contentId = GlobalNetworkData.storeContent(
          ~content,
          ~sizeMB=Float.fromInt(String.length(content)) /. 1024.0 /. 1024.0,
        )
        Dict.set(
          contents,
          name,
          File({
            name,
            globalContentId: contentId,
            locked: false,
          }),
        )
        Ok()
      }
    }
  }
}

// Copy file (creates new reference to SAME content initially, copy-on-write on modification)
let copyFile = (deviceIp: string, sourcePath: string, destPath: string, destName: string): result<
  unit,
  string,
> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    // Get source file
    switch resolvePath(fs, sourcePath) {
    | None => Error(`Source not found: ${sourcePath}`)
    | Some(Directory(_)) => Error(`Cannot copy directory: ${sourcePath}`)
    | Some(File({globalContentId, _})) =>
      // Get destination directory
      switch resolvePath(fs, destPath) {
      | None => Error(`Destination not found: ${destPath}`)
      | Some(File(_)) => Error(`Not a directory: ${destPath}`)
      | Some(Directory({contents})) =>
        switch Dict.get(contents, destName) {
        | Some(_) => Error(`Already exists: ${destName}`)
        | None =>
          // Create new file entry pointing to SAME content (deduplication!)
          Dict.set(
            contents,
            destName,
            File({
              name: destName,
              globalContentId, // Same content ID!
              locked: false,
            }),
          )
          Ok()
        }
      }
    }
  }
}

// Delete file or empty directory
let deleteFile = (deviceIp: string, path: string, name: string, recursive: bool): result<
  unit,
  string,
> => {
  switch Dict.get(filesystems, deviceIp) {
  | None => Error("Device not found")
  | Some(fs) =>
    switch resolvePath(fs, path) {
    | None => Error(`Directory not found: ${path}`)
    | Some(File(_)) => Error(`Not a directory: ${path}`)
    | Some(Directory({contents})) =>
      switch Dict.get(contents, name) {
      | None => Error(`Not found: ${name}`)
      | Some(File({locked: true, _})) => Error(`Permission denied: ${name}`)
      | Some(File(_)) =>
        Dict.delete(contents, name)->ignore
        Ok()
      | Some(Directory({contents: dirContents})) =>
        if !recursive && Dict.valuesToArray(dirContents)->Array.length > 0 {
          Error(`Directory not empty: ${name}`)
        } else {
          Dict.delete(contents, name)->ignore
          Ok()
        }
      }
    }
  }
}

// Get total storage used on device
let getTotalStorageUsed = (deviceIp: string): float => {
  let rec calculateSize = (node: fileNode): float => {
    switch node {
    | File({globalContentId, _}) =>
      switch GlobalNetworkData.getContent(globalContentId) {
      | Some(content) => content.sizeMB
      | None => 0.0
      }
    | Directory({contents}) =>
      Dict.valuesToArray(contents)->Array.reduce(0.0, (acc, child) => acc +. calculateSize(child))
    }
  }

  switch Dict.get(filesystems, deviceIp) {
  | None => 0.0
  | Some(fs) => calculateSize(fs.root)
  }
}

// ============================================
// Initialization
// ============================================

// Clear all filesystems
let clear = (): unit => {
  Dict.keysToArray(filesystems)->Array.forEach(key => Dict.delete(filesystems, key)->ignore)
}

// Create empty filesystem for device
let createFilesystem = (~deviceIp: string, ~deviceName: string): unit => {
  Dict.set(
    filesystems,
    deviceIp,
    {
      deviceIp,
      deviceName,
      root: Directory({
        name: "C:",
        contents: Dict.make(),
      }),
    },
  )
}

// Helper to add file to filesystem
let addFileToFilesystem = (
  deviceIp: string,
  path: string,
  name: string,
  content: string,
  locked: bool,
  sizeMB: float,
): unit => {
  let contentId = GlobalNetworkData.storeContent(~content, ~sizeMB)

  switch Dict.get(filesystems, deviceIp) {
  | None => ()
  | Some(fs) =>
    // Create directory structure if needed
    let parts = String.split(path, "\\")->Array.filter(p => p != "" && p != "C:")
    let current = ref(fs.root)

    Array.forEach(parts, part => {
      switch current.contents {
      | Directory({contents}) =>
        switch Dict.get(contents, part) {
        | Some(Directory(_) as dir) => current := dir
        | Some(File(_)) => () // Path blocked by file
        | None =>
          let newDir = Directory({name: part, contents: Dict.make()})
          Dict.set(contents, part, newDir)
          current := newDir
        }
      | File(_) => () // Can't navigate into file
      }
    })

    // Add file to current directory
    switch current.contents {
    | Directory({contents}) =>
      Dict.set(
        contents,
        name,
        File({
          name,
          globalContentId: contentId,
          locked,
        }),
      )
    | File(_) => ()
    }
  }
}

// Initialize default filesystems with files
let initializeDefaultFilesystems = (): unit => {
  // Create filesystems for all devices
  createFilesystem(~deviceIp="192.168.1.1", ~deviceName="MAIN-ROUTER")
  createFilesystem(~deviceIp="192.168.1.102", ~deviceName="CORP-LAPTOP-42")
  createFilesystem(~deviceIp="192.168.1.103", ~deviceName="CORP-LAPTOP-17")
  createFilesystem(~deviceIp="192.168.1.200", ~deviceName="ADMIN-PANEL")
  createFilesystem(~deviceIp="192.168.2.1", ~deviceName="RURAL-ROUTER")
  createFilesystem(~deviceIp="192.168.2.100", ~deviceName="HOME-LAPTOP")
  createFilesystem(~deviceIp="100.64.1.1", ~deviceName="RURAL-ISP")
  createFilesystem(~deviceIp="100.64.2.1", ~deviceName="BUSINESS-ISP")
  createFilesystem(~deviceIp="198.51.100.1", ~deviceName="REGIONAL-ISP")
  createFilesystem(~deviceIp="203.0.113.1", ~deviceName="TIER1-BACKBONE")
  createFilesystem(~deviceIp="10.0.0.25", ~deviceName="MAIL-SERVER")
  createFilesystem(~deviceIp="10.0.0.50", ~deviceName="DB-SERVER-01")
  createFilesystem(~deviceIp="10.0.0.99", ~deviceName="SECRET-SERVER")
  createFilesystem(~deviceIp="10.0.0.100", ~deviceName="CORP-INTRANET")

  // Add files to devices (metadata + content references)
  // DB-SERVER-01
  addFileToFilesystem(
    "10.0.0.50",
    "C:\\data",
    "customers.db",
    "=== CUSTOMER DATABASE ===\nID,Name,Email,Phone\n1,John Doe,john@example.com,555-0101\n2,Jane Smith,jane@example.com,555-0102\n3,Bob Johnson,bob@example.com,555-0103\n[... 50,000 more records ...]",
    true,
    150.0,
  )
  addFileToFilesystem(
    "10.0.0.50",
    "C:\\admin",
    "passwords.txt",
    "=== ADMIN PASSWORDS ===\nadmin:P@ssw0rd123\nroot:toor\ndbadmin:mysql_secure_2024\nsysadmin:Adm1n!2024",
    true,
    0.001,
  )
  addFileToFilesystem(
    "10.0.0.50",
    "C:\\config",
    "server.json",
    `{
  "database": {
    "host": "localhost",
    "port": 3306,
    "user": "dbadmin",
    "password": "mysql_secure_2024"
  },
  "api": {
    "port": 8080,
    "ssl": true
  }
}`,
    true,
    0.002,
  )

  // ADMIN-PANEL
  addFileToFilesystem(
    "192.168.1.200",
    "C:\\var\\log\\apache2",
    "access.log",
    "192.168.1.102 - - [08/Dec/2024:10:15:32] \"GET /admin HTTP/1.1\" 200 1234\n192.168.1.103 - - [08/Dec/2024:10:16:45] \"POST /login HTTP/1.1\" 302 0\n192.168.1.104 - - [08/Dec/2024:10:17:12] \"GET /dashboard HTTP/1.1\" 200 5678",
    true,
    5.0,
  )
  addFileToFilesystem(
    "192.168.1.200",
    "C:\\var\\www\\html",
    ".env",
    "DB_HOST=10.0.0.50\nDB_USER=webserver\nDB_PASS=W3bS3rv3r!2024\nAPI_KEY=sk_live_abcdef123456\nSECRET_KEY=super_secret_key_do_not_share",
    true,
    0.001,
  )
  addFileToFilesystem(
    "192.168.1.200",
    "C:\\var\\www\\html\\data",
    "users.json",
    `[
  {"id": 1, "username": "admin", "email": "admin@corp.local", "role": "administrator"},
  {"id": 2, "username": "jdoe", "email": "john.doe@corp.local", "role": "user"}
]`,
    false,
    0.01,
  )

  // MAIL-SERVER
  addFileToFilesystem(
    "10.0.0.25",
    "C:\\var\\mail",
    "inbox.mbox",
    "From: security@corp.local\nSubject: Security Alert\n\nUnauthorized access attempt detected.\n\n---\nFrom: admin@corp.local\nSubject: Password Reset\n\nYour temporary password is: Temp123!",
    true,
    2.5,
  )
  addFileToFilesystem(
    "10.0.0.25",
    "C:\\etc\\mail",
    "mail.conf",
    "SMTP_HOST=10.0.0.25\nSMTP_PORT=25\nADMIN_EMAIL=admin@corp.local",
    true,
    0.001,
  )

  // SECRET-SERVER
  addFileToFilesystem(
    "10.0.0.99",
    "C:\\secure",
    "vault.dat",
    "=== ENCRYPTED VAULT ===\n[ENCRYPTION KEY REQUIRED]\nAES-256 Encrypted Data...",
    true,
    10.0,
  )
  addFileToFilesystem(
    "10.0.0.99",
    "C:\\secure",
    "master.key",
    "-----BEGIN MASTER KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7x2...\n-----END MASTER KEY-----",
    true,
    0.005,
  )

  // CORP-INTRANET
  addFileToFilesystem(
    "10.0.0.100",
    "C:\\var\\www\\intranet",
    "index.html",
    "<html><head><title>Corp Intranet</title></head><body><h1>Welcome to Corporate Intranet</h1></body></html>",
    false,
    0.002,
  )
  addFileToFilesystem(
    "10.0.0.100",
    "C:\\var\\www\\intranet\\data",
    "employees.db",
    "[SQLite Database - 5000 employee records with salaries, SSNs, and addresses]",
    true,
    25.0,
  )

  // Laptop 1
  addFileToFilesystem(
    "192.168.1.102",
    "C:\\Users\\Admin\\Documents",
    "notes.txt",
    "Meeting Notes - Dec 7, 2024\n- Server maintenance scheduled for Friday\n- Update firewall rules\n- Check database backup integrity\n- TODO: Change admin password (currently: P@ssw0rd123)\n- VPN key stored in C:\\sys\\keys\\vpn.key",
    false,
    0.001,
  )
  addFileToFilesystem(
    "192.168.1.102",
    "C:\\sys\\keys",
    "vpn.key",
    "-----BEGIN VPN KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEF\nAASCBKgwggSkAgEAAoIBAQC7x2\n-----END VPN KEY-----",
    true,
    0.001,
  )

  // Laptop 2
  addFileToFilesystem(
    "192.168.1.103",
    "C:\\projects\\webapp",
    "app.js",
    "// Main application\nconst express = require('express');\nconst app = express();\n\n// Hardcoded credentials (TODO: move to env)\nconst DB_PASSWORD = process.env.DB_PASSWORD || 'redacted_physical_access_only';",
    false,
    0.05,
  )
  addFileToFilesystem(
    "192.168.1.103",
    "C:\\Users\\Developer\\.ssh",
    "id_rsa",
    "[REDACTED RSA PRIVATE KEY]",
    true,
    0.002,
  )

  // Home Laptop (Rural Outpost - Player starting location)
  addFileToFilesystem(
    "192.168.2.100",
    "C:\\Users\\Player\\Documents",
    "readme.txt",
    "Welcome to your home network!\n\nYou're connected to a small rural router.\nTry exploring the network with commands like:\n- ping <ip>\n- ssh <ip>\n- nmap\n\nGood luck!",
    false,
    0.001,
  )
  addFileToFilesystem(
    "192.168.2.100",
    "C:\\Users\\Player\\Downloads",
    "tools.zip",
    "[Archive containing network scanning tools]",
    false,
    0.5,
  )
}
