# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
defmodule IDApixiTIK.SyncServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :idaptik_sync_server,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "IDApTIK multiplayer sync server — Phoenix Channels + OTP",
      package: [
        maintainers: ["Joshua B. Jewell", "Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>"],
        licenses: ["PMPL-1.0-or-later"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {IDApixiTIK.SyncServer.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.0"},
      {:phoenix, "~> 1.7.10"},
      {:phoenix_pubsub, "~> 2.1"},
      # Redix/Dragonfly removed — ETS handles caching in-process (zero deps)
      {:horde, "~> 0.9"},
      {:libcluster, "~> 3.3"},
      {:thousand_island, "~> 1.0"},  # Primary TCP Core
      {:req, "~> 0.5"},              # HTTP client for ArangoDB + VerisimDB federation
      {:stream_data, "~> 1.0", only: :test},   # Property-based testing
      {:plug_cowboy, "~> 2.5", only: :test},   # Cowboy adapter for Plug.Test
      {:plug, "~> 1.15"}           # Plug HTTP abstractions
    ]
  end
end
