# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.DataLayer.Application do
  @moduledoc """
  OTP Application for dnfinition data layer.

  Manages CubDB storage, transaction history, and snapshot state.
  """
  use Application

  @impl true
  def start(_type, _args) do
    data_dir = System.get_env("DNFINITION_DATA_DIR", "/var/lib/dnfinition")

    children = [
      # Transaction store
      {CubDB, [
        data_dir: Path.join(data_dir, "transactions"),
        name: Dnfinition.Store.Transactions
      ]},

      # Snapshot metadata store
      {CubDB, [
        data_dir: Path.join(data_dir, "snapshots"),
        name: Dnfinition.Store.Snapshots
      ]},

      # Package state store
      {CubDB, [
        data_dir: Path.join(data_dir, "packages"),
        name: Dnfinition.Store.Packages
      ]},

      # Configuration store
      {CubDB, [
        data_dir: Path.join(data_dir, "config"),
        name: Dnfinition.Store.Config
      ]},

      # Cache store (for mirror info, metadata)
      {CubDB, [
        data_dir: Path.join(data_dir, "cache"),
        name: Dnfinition.Store.Cache
      ]},

      # Download manager for parallel package downloads
      {Dnfinition.Download.Manager, [parallelism: 4]},

      # Mirror optimizer for finding fastest mirrors
      {Dnfinition.Mirror.Optimizer, []},

      # Port server for Ada communication
      {Dnfinition.Port.Server, []},

      # Telemetry handler
      {Dnfinition.Telemetry, []}
    ]

    opts = [strategy: :one_for_one, name: Dnfinition.DataLayer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
