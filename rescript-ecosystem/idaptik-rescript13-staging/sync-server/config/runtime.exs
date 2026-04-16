# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
# config/runtime.exs — Evaluated at OTP release startup, not compile time.
#
# This is the correct place for environment-variable-driven configuration in
# Elixir Mix releases.  config/config.exs values are baked in at `mix release`
# time; only runtime.exs sees the actual OS environment when the release boots.
#
# Required env vars (prod):
#   SECRET_KEY_BASE  — Phoenix secret (generate with `mix phx.gen.secret`)
#
# Optional env vars (defaults shown):
#   PHX_HOST         — Public hostname for URL generation (default: "localhost")
#   PORT             — HTTP listen port (default: 4000)
#   SESSION_DETS_PATH — DETS persistence path (default: "/tmp/idaptik_dev_sessions.dets")

import Config

if config_env() == :prod do
  # ── Secret key base ──────────────────────────────────────────────────────
  # Must be at least 64 bytes of random data.  Generate with:
  #   mix phx.gen.secret
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      SECRET_KEY_BASE environment variable is not set.
      Generate one with: mix phx.gen.secret
      In containers, set it in podman-compose.yml under the sync service environment.
      """

  # ── Network binding ──────────────────────────────────────────────────────
  phx_host = System.get_env("PHX_HOST", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :idaptik_sync_server, IDApixiTIK.SyncServerWeb.Endpoint,
    # Bind on all interfaces so the container port mapping works.
    http: [port: port, ip: {0, 0, 0, 0}],
    url: [host: phx_host, port: port],
    secret_key_base: secret_key_base

  # ── Database Federation ──────────────────────────────────────────────────
  # ArangoDB: Joshua's game data (network topology, players, sessions)
  config :idaptik_sync_server, IDApixiTIK.SyncServer.ArangoClient,
    url: System.get_env("ARANGO_URL", "http://localhost:8529"),
    database: System.get_env("ARANGO_DB", "idaptik"),
    user: System.get_env("ARANGO_USER", "root"),
    password: System.get_env("ARANGO_PASSWORD", "")

  # VerisimDB: Level architect data (level hexads, version history, similarity)
  config :idaptik_sync_server, IDApixiTIK.SyncServer.VerisimClient,
    url: System.get_env("VERISIM_URL", "http://localhost:8080/api/v1"),
    timeout: 30_000
end
