// SPDX-License-Identifier: PMPL-1.0-or-later
// Global Network Data - Content-Addressable Storage
// File CONTENT stored once globally (hash-based IDs for automatic deduplication)
// File METADATA (paths, names, permissions) stored per-device in DeviceView

// ============================================
// Content-Addressable Storage
// ============================================

// Hash function for content-based IDs
let hashContent: string => string = %raw(`
  function(content) {
    const len = content.length;
    if (len < 100) {
      // Short content: use full content + length
      return 'hash-' + len + '-' + content;
    }
    // Long content: use length + first 50 + last 50 chars
    return 'hash-' + len + '-' + content.slice(0, 50) + '-' + content.slice(-50);
  }
`)

// Global file content (immutable once created)
type globalFileContent = {
  id: string, // Hash of content (for deduplication)
  content: string, // The actual file data
  sizeMB: float, // Size for bandwidth calculations
}

// Global content registry (content stored once)
let contentStore: dict<globalFileContent> = Dict.make()

// Get content by ID
let getContent = (id: string): option<globalFileContent> => {
  Dict.get(contentStore, id)
}

// Create or reuse content (automatic deduplication)
let storeContent = (~content: string, ~sizeMB: float): string => {
  let hash = hashContent(content)

  // Check if this content already exists
  switch Dict.get(contentStore, hash) {
  | Some(_) => hash // Already exists, reuse! 
  | None =>
    // Create new content entry
    Dict.set(
      contentStore,
      hash,
      {
        id: hash,
        content,
        sizeMB,
      },
    )
    hash
  }
}

// Update content (creates NEW content with new hash)
let updateContent = (~oldId: string, ~newContent: string): string => {
  // Get size from old content
  let sizeMB = switch Dict.get(contentStore, oldId) {
  | Some(old) => old.sizeMB
  | None => Int.toFloat(String.length(newContent)) /. 1024.0 /. 1024.0
  }

  // Store new content (may reuse if hash matches existing)
  storeContent(~content=newContent, ~sizeMB)
}

// Get all content IDs (for debugging)
let getAllContentIds = (): array<string> => {
  Dict.keysToArray(contentStore)
}

// Get content store size (for debugging)
let getContentStoreSize = (): int => {
  Dict.valuesToArray(contentStore)->Array.length
}

// Clear all content (for testing/reset)
let clearContent = (): unit => {
  Dict.keysToArray(contentStore)->Array.forEach(key => {
    Dict.delete(contentStore, key)
  })
}

// ============================================
// Initialize with default content
// ============================================

let initializeDefaultContent = (): unit => {
  // DB-SERVER-01 files
  let _ = storeContent(
    ~content="=== CUSTOMER DATABASE ===\nID,Name,Email,Phone\n1,John Doe,john@example.com,555-0101\n2,Jane Smith,jane@example.com,555-0102\n3,Bob Johnson,bob@example.com,555-0103\n[... 50,000 more records ...]",
    ~sizeMB=150.0,
  )

  let _ = storeContent(
    ~content="=== ADMIN PASSWORDS ===\nadmin:P@ssw0rd123\nroot:toor\ndbadmin:mysql_secure_2024\nsysadmin:Adm1n!2024",
    ~sizeMB=0.001,
  )

  let _ = storeContent(
    ~content=`{
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
    ~sizeMB=0.002,
  )

  // ADMIN-PANEL files
  let _ = storeContent(
    ~content="192.168.1.102 - - [08/Dec/2024:10:15:32] \"GET /admin HTTP/1.1\" 200 1234\n192.168.1.103 - - [08/Dec/2024:10:16:45] \"POST /login HTTP/1.1\" 302 0\n192.168.1.104 - - [08/Dec/2024:10:17:12] \"GET /dashboard HTTP/1.1\" 200 5678",
    ~sizeMB=5.0,
  )

  let _ = storeContent(
    ~content="DB_HOST=10.0.0.50\nDB_USER=webserver\nDB_PASS=W3bS3rv3r!2024\nAPI_KEY=sk_live_abcdef123456\nSECRET_KEY=super_secret_key_do_not_share",
    ~sizeMB=0.001,
  )

  let _ = storeContent(
    ~content=`[
  {"id": 1, "username": "admin", "email": "admin@corp.local", "role": "administrator"},
  {"id": 2, "username": "jdoe", "email": "john.doe@corp.local", "role": "user"}
]`,
    ~sizeMB=0.01,
  )

  // MAIL-SERVER files
  let _ = storeContent(
    ~content="From: security@corp.local\nSubject: Security Alert\n\nUnauthorized access attempt detected.\n\n---\nFrom: admin@corp.local\nSubject: Password Reset\n\nYour temporary password is: Temp123!",
    ~sizeMB=2.5,
  )

  let _ = storeContent(
    ~content="SMTP_HOST=10.0.0.25\nSMTP_PORT=25\nADMIN_EMAIL=admin@corp.local",
    ~sizeMB=0.001,
  )

  // SECRET-SERVER files
  let _ = storeContent(
    ~content="=== ENCRYPTED VAULT ===\n[ENCRYPTION KEY REQUIRED]\nAES-256 Encrypted Data...",
    ~sizeMB=10.0,
  )

  let _ = storeContent(
    ~content="-----BEGIN MASTER KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7x2...\n-----END MASTER KEY-----",
    ~sizeMB=0.005,
  )

  // CORP-INTRANET files
  let _ = storeContent(
    ~content="<html><head><title>Corp Intranet</title></head><body><h1>Welcome to Corporate Intranet</h1></body></html>",
    ~sizeMB=0.002,
  )

  let _ = storeContent(
    ~content="[SQLite Database - 5000 employee records with salaries, SSNs, and addresses]",
    ~sizeMB=25.0,
  )

  // Laptop 1 files
  let _ = storeContent(
    ~content="Meeting Notes - Dec 7, 2024\n- Server maintenance scheduled for Friday\n- Update firewall rules\n- Check database backup integrity\n- TODO: Change admin password (currently: P@ssw0rd123)\n- VPN key stored in C:\\sys\\keys\\vpn.key",
    ~sizeMB=0.001,
  )

  let _ = storeContent(
    ~content="-----BEGIN VPN KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEF\nAASCBKgwggSkAgEAAoIBAQC7x2\n-----END VPN KEY-----",
    ~sizeMB=0.001,
  )

  // Laptop 2 files
  let _ = storeContent(
    ~content="// Main application\nconst express = require('express');\nconst app = express();\n\n// Hardcoded credentials (TODO: move to env)\nconst DB_PASSWORD = 'dev_password_123';\n\napp.listen(3000);",
    ~sizeMB=0.05,
  )

  let _ = storeContent(
    ~content="-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA1234567890abcdef...\n-----END RSA PRIVATE KEY-----",
    ~sizeMB=0.002,
  )
}
