# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Models.Operation do
  @moduledoc """
  Operation model representing a single package operation within a transaction.

  Operations can be:
  - :install - Installing a new package
  - :remove - Removing a package
  - :upgrade - Upgrading to a newer version
  - :downgrade - Reverting to an older version
  - :reinstall - Reinstalling at same version
  - :purge - Removing package and config files
  """

  @type operation_type ::
    :install | :remove | :upgrade | :downgrade | :reinstall | :purge | :autoremove

  @type status :: :pending | :in_progress | :completed | :failed | :skipped

  @type t :: %__MODULE__{
    sequence: pos_integer(),
    operation: operation_type(),
    package_name: String.t(),
    old_version: String.t() | nil,
    new_version: String.t() | nil,
    status: status(),
    timestamp: DateTime.t(),
    size_bytes: non_neg_integer(),
    download_url: String.t() | nil,
    checksum: String.t() | nil,
    dependencies: [String.t()],
    error_message: String.t() | nil
  }

  defstruct [
    :sequence,
    :operation,
    :package_name,
    :old_version,
    :new_version,
    :status,
    :timestamp,
    :download_url,
    :checksum,
    :error_message,
    size_bytes: 0,
    dependencies: []
  ]

  @doc """
  Create a new operation.
  """
  def new(operation_type, package_name, opts \\ []) do
    %__MODULE__{
      sequence: opts[:sequence] || 1,
      operation: operation_type,
      package_name: package_name,
      old_version: opts[:old_version],
      new_version: opts[:new_version],
      status: :pending,
      timestamp: DateTime.utc_now(),
      size_bytes: opts[:size_bytes] || 0,
      download_url: opts[:download_url],
      checksum: opts[:checksum],
      dependencies: opts[:dependencies] || []
    }
  end

  @doc """
  Generate the reverse operation for undo functionality.
  """
  def reverse(%__MODULE__{operation: :install} = op) do
    %{op | operation: :remove, old_version: op.new_version, new_version: nil}
  end

  def reverse(%__MODULE__{operation: :remove} = op) do
    %{op | operation: :install, new_version: op.old_version, old_version: nil}
  end

  def reverse(%__MODULE__{operation: :upgrade} = op) do
    %{op | operation: :downgrade, old_version: op.new_version, new_version: op.old_version}
  end

  def reverse(%__MODULE__{operation: :downgrade} = op) do
    %{op | operation: :upgrade, old_version: op.new_version, new_version: op.old_version}
  end

  def reverse(%__MODULE__{operation: :reinstall} = op) do
    # Reinstall reverses to itself
    op
  end

  def reverse(%__MODULE__{operation: :purge} = op) do
    # Purge cannot be fully reversed (config files lost)
    %{op | operation: :install, new_version: op.old_version, old_version: nil}
  end

  def reverse(%__MODULE__{operation: :autoremove} = op) do
    %{op | operation: :install, new_version: op.old_version, old_version: nil}
  end

  @doc """
  Check if operation can be reversed.
  """
  def reversible?(%__MODULE__{operation: :purge}), do: false
  def reversible?(%__MODULE__{status: :completed}), do: true
  def reversible?(_), do: false

  @doc """
  Get a human-readable description of the operation.
  """
  def describe(%__MODULE__{operation: :install, package_name: pkg, new_version: ver}) do
    "Install #{pkg}" <> if(ver, do: " (#{ver})", else: "")
  end

  def describe(%__MODULE__{operation: :remove, package_name: pkg, old_version: ver}) do
    "Remove #{pkg}" <> if(ver, do: " (#{ver})", else: "")
  end

  def describe(%__MODULE__{operation: :upgrade, package_name: pkg, old_version: old, new_version: new}) do
    "Upgrade #{pkg} from #{old || "?"} to #{new || "?"}"
  end

  def describe(%__MODULE__{operation: :downgrade, package_name: pkg, old_version: old, new_version: new}) do
    "Downgrade #{pkg} from #{old || "?"} to #{new || "?"}"
  end

  def describe(%__MODULE__{operation: :reinstall, package_name: pkg, new_version: ver}) do
    "Reinstall #{pkg}" <> if(ver, do: " (#{ver})", else: "")
  end

  def describe(%__MODULE__{operation: :purge, package_name: pkg}) do
    "Purge #{pkg} (including config files)"
  end

  def describe(%__MODULE__{operation: :autoremove, package_name: pkg}) do
    "Auto-remove #{pkg}"
  end

  @doc """
  Get operation symbol for display.
  """
  def symbol(%__MODULE__{operation: :install}), do: "+"
  def symbol(%__MODULE__{operation: :remove}), do: "-"
  def symbol(%__MODULE__{operation: :upgrade}), do: "↑"
  def symbol(%__MODULE__{operation: :downgrade}), do: "↓"
  def symbol(%__MODULE__{operation: :reinstall}), do: "~"
  def symbol(%__MODULE__{operation: :purge}), do: "×"
  def symbol(%__MODULE__{operation: :autoremove}), do: "○"

  @doc """
  Convert to JSON-serializable map.
  """
  def to_map(%__MODULE__{} = op) do
    %{
      sequence: op.sequence,
      operation: Atom.to_string(op.operation),
      package_name: op.package_name,
      old_version: op.old_version,
      new_version: op.new_version,
      status: Atom.to_string(op.status),
      timestamp: DateTime.to_iso8601(op.timestamp),
      size_bytes: op.size_bytes,
      download_url: op.download_url,
      checksum: op.checksum,
      dependencies: op.dependencies,
      error_message: op.error_message
    }
  end

  @doc """
  Create from map (JSON deserialization).
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      sequence: map["sequence"] || map[:sequence],
      operation: parse_operation(map["operation"] || map[:operation]),
      package_name: map["package_name"] || map[:package_name],
      old_version: map["old_version"] || map[:old_version],
      new_version: map["new_version"] || map[:new_version],
      status: parse_status(map["status"] || map[:status]),
      timestamp: parse_datetime(map["timestamp"] || map[:timestamp]),
      size_bytes: map["size_bytes"] || map[:size_bytes] || 0,
      download_url: map["download_url"] || map[:download_url],
      checksum: map["checksum"] || map[:checksum],
      dependencies: map["dependencies"] || map[:dependencies] || [],
      error_message: map["error_message"] || map[:error_message]
    }
  end

  defp parse_operation(op) when is_atom(op), do: op
  defp parse_operation(str) when is_binary(str), do: String.to_existing_atom(str)

  defp parse_status(nil), do: :pending
  defp parse_status(status) when is_atom(status), do: status
  defp parse_status(str) when is_binary(str), do: String.to_existing_atom(str)

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end
end
