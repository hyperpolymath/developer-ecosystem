# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.Models.Transaction do
  @moduledoc """
  Transaction model representing a package management operation.

  Transactions track:
  - What operations were performed
  - When they occurred
  - Success/failure status
  - Rollback capability
  """

  @type status :: :pending | :in_progress | :completed | :failed | :cancelled | :rolled_back

  @type t :: %__MODULE__{
    id: pos_integer(),
    description: String.t(),
    started_at: DateTime.t(),
    completed_at: DateTime.t() | nil,
    status: status(),
    user: String.t(),
    operations: [Dnfinition.Models.Operation.t()],
    snapshot_id: pos_integer() | nil,
    error_message: String.t() | nil,
    duration_ms: non_neg_integer() | nil,
    packages_affected: non_neg_integer(),
    total_size_bytes: non_neg_integer()
  }

  defstruct [
    :id,
    :description,
    :started_at,
    :completed_at,
    :status,
    :user,
    :operations,
    :snapshot_id,
    :error_message,
    :duration_ms,
    packages_affected: 0,
    total_size_bytes: 0
  ]

  @doc """
  Create a new transaction with defaults.
  """
  def new(description, opts \\ []) do
    %__MODULE__{
      id: opts[:id],
      description: description,
      started_at: opts[:started_at] || DateTime.utc_now(),
      status: :pending,
      user: opts[:user] || System.get_env("USER", "unknown"),
      operations: [],
      snapshot_id: nil
    }
  end

  @doc """
  Check if transaction can be reversed.
  """
  def reversible?(%__MODULE__{status: :completed}), do: true
  def reversible?(_), do: false

  @doc """
  Check if transaction is still active.
  """
  def active?(%__MODULE__{status: status}) when status in [:pending, :in_progress], do: true
  def active?(_), do: false

  @doc """
  Check if transaction has finished (success or failure).
  """
  def finished?(%__MODULE__{status: status})
      when status in [:completed, :failed, :cancelled, :rolled_back], do: true
  def finished?(_), do: false

  @doc """
  Calculate duration if completed.
  """
  def duration(%__MODULE__{started_at: started, completed_at: completed})
      when not is_nil(completed) do
    DateTime.diff(completed, started, :millisecond)
  end
  def duration(_), do: nil

  @doc """
  Get a human-readable summary of the transaction.
  """
  def summary(%__MODULE__{} = tx) do
    op_count = length(tx.operations)
    op_summary = if op_count == 1, do: "1 operation", else: "#{op_count} operations"

    status_str = case tx.status do
      :pending -> "pending"
      :in_progress -> "in progress"
      :completed -> "completed"
      :failed -> "failed"
      :cancelled -> "cancelled"
      :rolled_back -> "rolled back"
    end

    "Transaction ##{tx.id}: #{tx.description} (#{op_summary}, #{status_str})"
  end

  @doc """
  Convert to JSON-serializable map.
  """
  def to_map(%__MODULE__{} = tx) do
    %{
      id: tx.id,
      description: tx.description,
      started_at: DateTime.to_iso8601(tx.started_at),
      completed_at: if(tx.completed_at, do: DateTime.to_iso8601(tx.completed_at)),
      status: Atom.to_string(tx.status),
      user: tx.user,
      operations: Enum.map(tx.operations, &Dnfinition.Models.Operation.to_map/1),
      snapshot_id: tx.snapshot_id,
      error_message: tx.error_message,
      duration_ms: tx.duration_ms || duration(tx),
      packages_affected: tx.packages_affected,
      total_size_bytes: tx.total_size_bytes
    }
  end

  @doc """
  Create from map (JSON deserialization).
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"] || map[:id],
      description: map["description"] || map[:description],
      started_at: parse_datetime(map["started_at"] || map[:started_at]),
      completed_at: parse_datetime(map["completed_at"] || map[:completed_at]),
      status: parse_status(map["status"] || map[:status]),
      user: map["user"] || map[:user],
      operations: parse_operations(map["operations"] || map[:operations]),
      snapshot_id: map["snapshot_id"] || map[:snapshot_id],
      error_message: map["error_message"] || map[:error_message],
      duration_ms: map["duration_ms"] || map[:duration_ms],
      packages_affected: map["packages_affected"] || map[:packages_affected] || 0,
      total_size_bytes: map["total_size_bytes"] || map[:total_size_bytes] || 0
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_status(nil), do: :pending
  defp parse_status(status) when is_atom(status), do: status
  defp parse_status(str) when is_binary(str), do: String.to_existing_atom(str)

  defp parse_operations(nil), do: []
  defp parse_operations(ops) when is_list(ops) do
    Enum.map(ops, &Dnfinition.Models.Operation.from_map/1)
  end
end
