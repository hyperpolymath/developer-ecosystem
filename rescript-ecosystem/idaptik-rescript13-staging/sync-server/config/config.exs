# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
import Config

# Phoenix.Endpoint configuration
config :idaptik_sync_server, IDApixiTIK.SyncServerWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  server: true,
  pubsub_server: IDApixiTIK.SyncServer.PubSub,
  adapter: Bandit.PhoenixAdapter,
  secret_key_base: String.duplicate("idaptik_dev_secret_", 4),
  # Allow WebSocket connections from any origin so that the browser game
  # client (served from vite dev server on port 5173) and CLI smoke tests
  # (Deno, no browser Origin header) can both connect without 403 errors.
  # In production the SECRET_KEY_BASE is overridden via runtime.exs.
  check_origin: false

# Jason as default JSON library for Phoenix
config :phoenix, :json_library, Jason

# ---------------------------------------------------------------------------
# Database Federation — ArangoDB (game data) + VerisimDB (level architect data)
# Dev defaults — overridden by env vars in config/runtime.exs for production.
# ---------------------------------------------------------------------------

# ArangoDB: Joshua's live game data (players, sessions, network topology graph)
config :idaptik_sync_server, IDApixiTIK.SyncServer.ArangoClient,
  url: "http://localhost:8529",
  database: "idaptik",
  user: "root",
  password: ""

# VerisimDB: Level architect data (level hexads, version history, similarity search)
config :idaptik_sync_server, IDApixiTIK.SyncServer.VerisimClient,
  url: "http://localhost:8080/api/v1",
  timeout: 30_000

# Import environment-specific config. Must be at the bottom of this file.
import_config "#{config_env()}.exs"
