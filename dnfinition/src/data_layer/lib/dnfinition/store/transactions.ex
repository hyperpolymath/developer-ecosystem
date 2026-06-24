# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Store.TransactionStore do
  @moduledoc """
  Transaction history storage using CubDB.

  Provides:
  - Transaction creation and tracking
  - Undo/redo capability via CubDB snapshots
  - Operation journaling
  - Query by time range, status, package
  """

  alias Dnfinition.Models.Transaction
  alias Dnfinition.Models.Operation

  @db Dnfinition.Store.Transactions

  # Key prefixes for organization
  @tx_prefix "tx:"
  @op_prefix "op:"
  @idx_time "idx:time:"
  @idx_status "idx:status:"
  @idx_pkg "idx:pkg:"
  @meta_prefix "meta:"

  ## Transaction CRUD

  @doc """
  Begin a new transaction, returns transaction ID.
  """
  def begin_transaction(description, opts \\ []) do
    id = next_transaction_id()
    now = DateTime.utc_now()

    tx = %Transaction{
      id: id,
      description: description,
      started_at: now,
      status: :pending,
      user: opts[:user] || System.get_env("USER", "unknown"),
      operations: [],
      snapshot_id: nil
    }

    # Store transaction
    CubDB.put(@db, tx_key(id), tx)

    # Index by time
    CubDB.put(@db, "#{@idx_time}#{DateTime.to_unix(now)}:#{id}", id)

    # Index by status
    CubDB.put(@db, "#{@idx_status}pending:#{id}", id)

    # Create CubDB snapshot for rollback capability
    snapshot = CubDB.snapshot(@db)
    CubDB.put(@db, "#{@meta_prefix}snapshot:#{id}", snapshot)

    {:ok, id}
  end

  @doc """
  Add an operation to a transaction.
  """
  def add_operation(tx_id, operation) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        op = %Operation{
          sequence: length(tx.operations) + 1,
          operation: operation.type,
          package_name: operation.package,
          old_version: operation[:old_version],
          new_version: operation[:new_version],
          status: :pending,
          timestamp: DateTime.utc_now()
        }

        updated_tx = %{tx | operations: tx.operations ++ [op]}
        CubDB.put(@db, tx_key(tx_id), updated_tx)

        # Index by package
        CubDB.put(@db, "#{@idx_pkg}#{operation.package}:#{tx_id}", tx_id)

        # Store operation separately for querying
        CubDB.put(@db, "#{@op_prefix}#{tx_id}:#{op.sequence}", op)

        {:ok, op}

      error ->
        error
    end
  end

  @doc """
  Mark transaction as in progress.
  """
  def start_transaction(tx_id) do
    update_status(tx_id, :in_progress)
  end

  @doc """
  Commit a successful transaction.
  """
  def commit_transaction(tx_id, opts \\ []) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        now = DateTime.utc_now()

        updated_tx = %{tx |
          status: :completed,
          completed_at: now,
          snapshot_id: opts[:snapshot_id]
        }

        # Update main record
        CubDB.put(@db, tx_key(tx_id), updated_tx)

        # Update status index
        CubDB.delete(@db, "#{@idx_status}#{tx.status}:#{tx_id}")
        CubDB.put(@db, "#{@idx_status}completed:#{tx_id}", tx_id)

        # Mark all operations as completed
        for op <- tx.operations do
          updated_op = %{op | status: :completed}
          CubDB.put(@db, "#{@op_prefix}#{tx_id}:#{op.sequence}", updated_op)
        end

        {:ok, updated_tx}

      error ->
        error
    end
  end

  @doc """
  Mark transaction as failed.
  """
  def fail_transaction(tx_id, error_msg \\ nil) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        updated_tx = %{tx |
          status: :failed,
          completed_at: DateTime.utc_now(),
          error_message: error_msg
        }

        CubDB.put(@db, tx_key(tx_id), updated_tx)

        # Update status index
        CubDB.delete(@db, "#{@idx_status}#{tx.status}:#{tx_id}")
        CubDB.put(@db, "#{@idx_status}failed:#{tx_id}", tx_id)

        {:ok, updated_tx}

      error ->
        error
    end
  end

  @doc """
  Cancel/abort a transaction.
  """
  def cancel_transaction(tx_id) do
    update_status(tx_id, :cancelled)
  end

  ## Rollback/Undo

  @doc """
  Reverse a completed transaction (undo).
  Uses CubDB snapshot if available, otherwise generates reverse operations.
  """
  def reverse_transaction(tx_id) do
    case get_transaction(tx_id) do
      {:ok, %{status: :completed} = tx} ->
        # Check for CubDB snapshot
        case CubDB.get(@db, "#{@meta_prefix}snapshot:#{tx_id}") do
          nil ->
            # No snapshot, generate reverse operations
            reverse_ops = generate_reverse_operations(tx)
            {:ok, :operations, reverse_ops}

          _snapshot ->
            # CubDB snapshots are read-only views, not restorable state
            # For transaction reversal, we need to generate reverse operations
            reverse_ops = generate_reverse_operations(tx)
            {:ok, :operations, reverse_ops}
        end

      {:ok, %{status: status}} ->
        {:error, {:invalid_status, status}}

      error ->
        error
    end
  end

  @doc """
  Replay a transaction (redo).
  """
  def replay_transaction(tx_id) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        operations = Enum.map(tx.operations, fn op ->
          %{
            type: op.operation,
            package: op.package_name,
            version: op.new_version
          }
        end)
        {:ok, operations}

      error ->
        error
    end
  end

  ## Queries

  @doc """
  Get a transaction by ID.
  """
  def get_transaction(tx_id) do
    case CubDB.get(@db, tx_key(tx_id)) do
      nil -> {:error, :not_found}
      tx -> {:ok, tx}
    end
  end

  @doc """
  List all transactions, most recent first.
  """
  def list_transactions(opts \\ []) do
    limit = opts[:limit] || 100
    status_filter = opts[:status]

    @db
    |> CubDB.select(min_key: @tx_prefix, max_key: "#{@tx_prefix}\xFF")
    |> Stream.map(fn {_key, tx} -> tx end)
    |> maybe_filter_status(status_filter)
    |> Enum.sort_by(& &1.started_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Get transactions since a given time.
  """
  def transactions_since(datetime) do
    unix = DateTime.to_unix(datetime)

    @db
    |> CubDB.select(
      min_key: "#{@idx_time}#{unix}",
      max_key: "#{@idx_time}\xFF"
    )
    |> Stream.map(fn {_key, tx_id} -> tx_id end)
    |> Stream.map(&get_transaction/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, tx} -> tx end)
  end

  @doc """
  Get transactions affecting a specific package.
  """
  def transactions_for_package(package_name) do
    @db
    |> CubDB.select(
      min_key: "#{@idx_pkg}#{package_name}:",
      max_key: "#{@idx_pkg}#{package_name}:\xFF"
    )
    |> Stream.map(fn {_key, tx_id} -> tx_id end)
    |> Stream.uniq()
    |> Stream.map(&get_transaction/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, tx} -> tx end)
  end

  @doc """
  Check if a transaction can be reversed.
  """
  def can_reverse?(tx_id) do
    case get_transaction(tx_id) do
      {:ok, %{status: :completed} = tx} ->
        # Can reverse if we have a snapshot or operations to reverse
        has_snapshot = CubDB.has_key?(@db, "#{@meta_prefix}snapshot:#{tx_id}")
        has_operations = length(tx.operations) > 0
        has_snapshot or has_operations

      _ ->
        false
    end
  end

  @doc """
  Get the current active transaction (if any).
  """
  def current_transaction do
    case list_transactions(status: :in_progress, limit: 1) do
      [tx] -> {:ok, tx}
      [] -> {:error, :no_active_transaction}
    end
  end

  @doc """
  Clear old transactions, keeping the most recent N.
  """
  def cleanup(keep_last \\ 100) do
    transactions = list_transactions(limit: :infinity)
    to_delete = Enum.drop(transactions, keep_last)

    for tx <- to_delete do
      delete_transaction(tx.id)
    end

    {:ok, length(to_delete)}
  end

  ## Private Functions

  defp tx_key(id), do: "#{@tx_prefix}#{id}"

  defp next_transaction_id do
    current = CubDB.get(@db, "#{@meta_prefix}next_id", 1)
    CubDB.put(@db, "#{@meta_prefix}next_id", current + 1)
    current
  end

  defp update_status(tx_id, new_status) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        old_status = tx.status

        final_tx = if new_status in [:completed, :failed, :cancelled] do
          %{tx | status: new_status, completed_at: DateTime.utc_now()}
        else
          %{tx | status: new_status}
        end

        CubDB.put(@db, tx_key(tx_id), final_tx)

        # Update status indices
        CubDB.delete(@db, "#{@idx_status}#{old_status}:#{tx_id}")
        CubDB.put(@db, "#{@idx_status}#{new_status}:#{tx_id}", tx_id)

        {:ok, final_tx}

      error ->
        error
    end
  end

  defp generate_reverse_operations(tx) do
    tx.operations
    |> Enum.reverse()
    |> Enum.map(fn op ->
      case op.operation do
        :install ->
          %{type: :remove, package: op.package_name, version: op.new_version}

        :remove ->
          %{type: :install, package: op.package_name, version: op.old_version}

        :upgrade ->
          %{type: :downgrade, package: op.package_name,
            old_version: op.new_version, new_version: op.old_version}

        :downgrade ->
          %{type: :upgrade, package: op.package_name,
            old_version: op.new_version, new_version: op.old_version}

        :reinstall ->
          %{type: :reinstall, package: op.package_name, version: op.new_version}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp delete_transaction(tx_id) do
    case get_transaction(tx_id) do
      {:ok, tx} ->
        # Delete main record
        CubDB.delete(@db, tx_key(tx_id))

        # Delete operations
        for op <- tx.operations do
          CubDB.delete(@db, "#{@op_prefix}#{tx_id}:#{op.sequence}")
        end

        # Delete indices
        CubDB.delete(@db, "#{@idx_time}#{DateTime.to_unix(tx.started_at)}:#{tx_id}")
        CubDB.delete(@db, "#{@idx_status}#{tx.status}:#{tx_id}")

        # Delete snapshot
        CubDB.delete(@db, "#{@meta_prefix}snapshot:#{tx_id}")

        :ok

      _ ->
        :ok
    end
  end

  defp maybe_filter_status(stream, nil), do: stream
  defp maybe_filter_status(stream, status) do
    Stream.filter(stream, &(&1.status == status))
  end
end
