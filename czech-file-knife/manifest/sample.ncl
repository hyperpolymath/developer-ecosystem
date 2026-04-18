{
  meta = {
    manifestVersion = "1.0.0",
    owner = "Hyperpolymath",
    runLabel = "secure-archive-pilot-2025-10",
  },

  providers = [
    { name = "gdrive-main", type = "gdrive", authRef = "secret:gdrive-pilot", root = "root" },
    { name = "dropbox-secure", type = "dropbox", authRef = "secret:dropbox-archive", root = "/secure/archive" }
  ],

  selection = {
    provider = "gdrive-main",
    query = { pathPrefix = "Sensitive_Docs", mimeTypes = ["application/pdf", "text/plain"] }
  },

  flow = {
    files = select(selection),
    
    steps = [
      step "hash"    = { plugin = "Hasher", config = { algo = "sha256" } }.map(files),
      step "search"  = { plugin = "Search", config = { regex = "SSN|CONFIDENTIAL|DOB" } }.map(hash),
      step "xfer"    = { plugin = "Transfer", config = { from = "gdrive-main", to = "dropbox-secure", mode = "copy" } }.map(search),
      step "verify"  = { plugin = "Verify", config = { method = "hash", algo = "sha256" } }.map(xfer)
    ],

    assertions = [
      assert "hash_present" on hash: "ctx.hash != null"
    ]
  },

  policies = {
    idempotency = true,
    dryRun = true,
  }
}
