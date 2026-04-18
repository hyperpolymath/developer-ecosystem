# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.Telemetry do
  @moduledoc """
  Telemetry handler for dnfinition data layer.

  Emits events for:
  - Transaction lifecycle (begin, commit, fail, rollback)
  - Snapshot operations (create, restore, delete)
  - Package operations (install, remove, update)
  - Store performance metrics
  """

  use GenServer
  require Logger

  @events [
    # Transaction events
    [:dnfinition, :transaction, :begin],
    [:dnfinition, :transaction, :commit],
    [:dnfinition, :transaction, :fail],
    [:dnfinition, :transaction, :rollback],

    # Snapshot events
    [:dnfinition, :snapshot, :create],
    [:dnfinition, :snapshot, :restore],
    [:dnfinition, :snapshot, :delete],

    # Package events
    [:dnfinition, :package, :install],
    [:dnfinition, :package, :remove],
    [:dnfinition, :package, :update],

    # Store events
    [:dnfinition, :store, :query],
    [:dnfinition, :store, :write]
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Emit a telemetry event.
  """
  def emit(event_suffix, measurements, metadata \\ %{}) do
    event_name = [:dnfinition | event_suffix]
    :telemetry.execute(event_name, measurements, metadata)
  end

  @doc """
  Emit a transaction begin event.
  """
  def tx_begin(tx_id, description) do
    emit([:transaction, :begin], %{count: 1}, %{
      tx_id: tx_id,
      description: description,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Emit a transaction commit event.
  """
  def tx_commit(tx_id, duration_ms, operation_count) do
    emit([:transaction, :commit], %{
      duration_ms: duration_ms,
      operation_count: operation_count
    }, %{
      tx_id: tx_id,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Emit a transaction fail event.
  """
  def tx_fail(tx_id, error_message) do
    emit([:transaction, :fail], %{count: 1}, %{
      tx_id: tx_id,
      error: error_message,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Emit a snapshot create event.
  """
  def snap_create(snap_id, package_count) do
    emit([:snapshot, :create], %{
      package_count: package_count
    }, %{
      snap_id: snap_id,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Emit a package operation event.
  """
  def pkg_operation(operation, package_name, version, size_bytes \\ 0) do
    emit([:package, operation], %{
      size_bytes: size_bytes
    }, %{
      package: package_name,
      version: version,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Measure and emit a store query event.
  """
  def measure_query(store, operation, fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    duration = System.monotonic_time(:microsecond) - start

    emit([:store, :query], %{
      duration_us: duration
    }, %{
      store: store,
      operation: operation
    })

    result
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    # Attach handlers for all events
    :telemetry.attach_many(
      "dnfinition-telemetry-handler",
      @events,
      &handle_event/4,
      nil
    )

    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach("dnfinition-telemetry-handler")
    :ok
  end

  ## Event Handlers

  defp handle_event([:dnfinition, :transaction, :begin], _measurements, metadata, _config) do
    Logger.debug("Transaction #{metadata.tx_id} started: #{metadata.description}")
    :ok
  end

  defp handle_event([:dnfinition, :transaction, :commit], measurements, metadata, _config) do
    Logger.info("Transaction #{metadata.tx_id} committed " <>
                "(#{measurements.operation_count} ops, #{measurements.duration_ms}ms)")
    :ok
  end

  defp handle_event([:dnfinition, :transaction, :fail], _measurements, metadata, _config) do
    Logger.warning("Transaction #{metadata.tx_id} failed: #{metadata.error}")
    :ok
  end

  defp handle_event([:dnfinition, :transaction, :rollback], _measurements, metadata, _config) do
    Logger.info("Transaction #{metadata.tx_id} rolled back")
    :ok
  end

  defp handle_event([:dnfinition, :snapshot, :create], measurements, metadata, _config) do
    Logger.info("Snapshot #{metadata.snap_id} created (#{measurements.package_count} packages)")
    :ok
  end

  defp handle_event([:dnfinition, :snapshot, :restore], _measurements, metadata, _config) do
    Logger.info("Snapshot #{metadata.snap_id} restored")
    :ok
  end

  defp handle_event([:dnfinition, :snapshot, :delete], _measurements, metadata, _config) do
    Logger.debug("Snapshot #{metadata.snap_id} deleted")
    :ok
  end

  defp handle_event([:dnfinition, :package, operation], measurements, metadata, _config) do
    size_str = if measurements.size_bytes > 0 do
      " (#{format_size(measurements.size_bytes)})"
    else
      ""
    end

    Logger.debug("Package #{operation}: #{metadata.package} #{metadata.version}#{size_str}")
    :ok
  end

  defp handle_event([:dnfinition, :store, :query], measurements, metadata, _config) do
    if measurements.duration_us > 10_000 do
      Logger.warning("Slow query on #{metadata.store}.#{metadata.operation}: #{measurements.duration_us}µs")
    end
    :ok
  end

  defp handle_event([:dnfinition, :store, :write], measurements, metadata, _config) do
    if measurements.duration_us > 50_000 do
      Logger.warning("Slow write on #{metadata.store}.#{metadata.operation}: #{measurements.duration_us}µs")
    end
    :ok
  end

  defp handle_event(_event, _measurements, _metadata, _config), do: :ok

  ## Helpers

  defp format_size(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)}KB"
  defp format_size(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)}MB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)}GB"
end
