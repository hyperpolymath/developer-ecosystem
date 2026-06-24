# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
#
# Test configuration — disables the HTTP server so Plug.Test can call
# the endpoint pipeline directly without binding to a port.
import Config

config :idaptik_sync_server, IDApixiTIK.SyncServerWeb.Endpoint,
  server: false
