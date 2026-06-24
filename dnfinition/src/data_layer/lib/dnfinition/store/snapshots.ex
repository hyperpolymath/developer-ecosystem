# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Store.SnapshotStore do
  @moduledoc """
  Snapshot storage using CubDB.

  Provides:
  - Snapshot creation and management
  - Package manifest storage
  - Btrfs/ostree reference tracking
  - Query by type, date, tags
  """

  alias Dnfinition.Models.Snapshot

  @db Dnfinition.Store.Snapshots

  # Key prefixes for organization
  @snap_prefix "snap:"
  @idx_type "idx:type:"
  @idx_time "idx:time:"
  @idx_tag "idx:tag:"
  @idx_tx "idx:tx:"
  @meta_prefix "meta:"

  ## Snapshot CRUD

  @doc """
  Create a new snapshot.
  """
  def create_snapshot(name, opts \\ []) do
    id = next_snapshot_id()
    now = DateTime.utc_now()

    snap = %Snapshot{
      id: id,
      name: name,
      description: opts[:description],
      created_at: now,
      snapshot_type: opts[:type] || :manual,
      user: opts[:user] || System.get_env("USER", "unknown"),
      package_count: map_size(opts[:package_manifest] || %{}),
      package_manifest: opts[:package_manifest] || %{},
      repo_config: opts[:repo_config] || %{},
      btrfs_snapshot: opts[:btrfs_snapshot],
      ostree_commit: opts[:ostree_commit],
      transaction_id: opts[:transaction_id],
      tags: opts[:tags] || [],
      protected: opts[:protected] || false
    }

    # Store snapshot
    CubDB.put(@db, snap_key(id), snap)

    # Index by type
    CubDB.put(@db, "#{@idx_type}#{snap.snapshot_type}:#{id}", id)

    # Index by time
    CubDB.put(@db, "#{@idx_time}#{DateTime.to_unix(now)}:#{id}", id)

    # Index by tags
    for tag <- snap.tags do
      CubDB.put(@db, "#{@idx_tag}#{tag}:#{id}", id)
    end

    # Index by transaction if linked
    if snap.transaction_id do
      CubDB.put(@db, "#{@idx_tx}#{snap.transaction_id}", id)
    end

    {:ok, snap}
  end

  @doc """
  Get a snapshot by ID.
  """
  def get_snapshot(id) do
    case CubDB.get(@db, snap_key(id)) do
      nil -> {:error, :not_found}
      snap -> {:ok, snap}
    end
  end

  @doc """
  Update a snapshot's metadata (not the manifest).
  """
  def update_snapshot(id, updates) do
    case get_snapshot(id) do
      {:ok, snap} ->
        updated = struct(snap, updates)
        CubDB.put(@db, snap_key(id), updated)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Delete a snapshot.
  """
  def delete_snapshot(id) do
    case get_snapshot(id) do
      {:ok, snap} ->
        if snap.protected do
          {:error, :protected}
        else
          # Delete main record
          CubDB.delete(@db, snap_key(id))

          # Delete indices
          CubDB.delete(@db, "#{@idx_type}#{snap.snapshot_type}:#{id}")
          CubDB.delete(@db, "#{@idx_time}#{DateTime.to_unix(snap.created_at)}:#{id}")

          for tag <- snap.tags do
            CubDB.delete(@db, "#{@idx_tag}#{tag}:#{id}")
          end

          if snap.transaction_id do
            CubDB.delete(@db, "#{@idx_tx}#{snap.transaction_id}")
          end

          :ok
        end

      error ->
        error
    end
  end

  @doc """
  Mark a snapshot as protected (prevents deletion).
  """
  def protect_snapshot(id) do
    update_snapshot(id, protected: true)
  end

  @doc """
  Remove protection from a snapshot.
  """
  def unprotect_snapshot(id) do
    update_snapshot(id, protected: false)
  end

  @doc """
  Add tags to a snapshot.
  """
  def add_tags(id, tags) when is_list(tags) do
    case get_snapshot(id) do
      {:ok, snap} ->
        new_tags = Enum.uniq(snap.tags ++ tags)
        updated = %{snap | tags: new_tags}
        CubDB.put(@db, snap_key(id), updated)

        # Add new tag indices
        for tag <- tags, tag not in snap.tags do
          CubDB.put(@db, "#{@idx_tag}#{tag}:#{id}", id)
        end

        {:ok, updated}

      error ->
        error
    end
  end

  ## Queries

  @doc """
  List all snapshots, most recent first.
  """
  def list_snapshots(opts \\ []) do
    limit = opts[:limit] || 100
    type_filter = opts[:type]

    @db
    |> CubDB.select(min_key: @snap_prefix, max_key: "#{@snap_prefix}\xFF")
    |> Stream.map(fn {_key, snap} -> snap end)
    |> maybe_filter_type(type_filter)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Get snapshots by type.
  """
  def snapshots_by_type(type) do
    @db
    |> CubDB.select(
      min_key: "#{@idx_type}#{type}:",
      max_key: "#{@idx_type}#{type}:\xFF"
    )
    |> Stream.map(fn {_key, id} -> id end)
    |> Stream.map(&get_snapshot/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, snap} -> snap end)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
  end

  @doc """
  Get snapshots created since a given time.
  """
  def snapshots_since(datetime) do
    unix = DateTime.to_unix(datetime)

    @db
    |> CubDB.select(
      min_key: "#{@idx_time}#{unix}",
      max_key: "#{@idx_time}\xFF"
    )
    |> Stream.map(fn {_key, id} -> id end)
    |> Stream.map(&get_snapshot/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, snap} -> snap end)
  end

  @doc """
  Get snapshots with a specific tag.
  """
  def snapshots_by_tag(tag) do
    @db
    |> CubDB.select(
      min_key: "#{@idx_tag}#{tag}:",
      max_key: "#{@idx_tag}#{tag}:\xFF"
    )
    |> Stream.map(fn {_key, id} -> id end)
    |> Stream.map(&get_snapshot/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, snap} -> snap end)
  end

  @doc """
  Get snapshot linked to a transaction.
  """
  def snapshot_for_transaction(tx_id) do
    case CubDB.get(@db, "#{@idx_tx}#{tx_id}") do
      nil -> {:error, :not_found}
      snap_id -> get_snapshot(snap_id)
    end
  end

  @doc """
  Get the most recent snapshot.
  """
  def latest_snapshot do
    case list_snapshots(limit: 1) do
      [snap] -> {:ok, snap}
      [] -> {:error, :no_snapshots}
    end
  end

  @doc """
  Get the most recent restorable snapshot.
  """
  def latest_restorable_snapshot do
    list_snapshots()
    |> Enum.find(&Snapshot.restorable?/1)
    |> case do
      nil -> {:error, :no_restorable_snapshot}
      snap -> {:ok, snap}
    end
  end

  @doc """
  Count total snapshots.
  """
  def count do
    @db
    |> CubDB.select(min_key: @snap_prefix, max_key: "#{@snap_prefix}\xFF")
    |> Enum.count()
  end

  @doc """
  Get storage statistics.
  """
  def stats do
    snapshots = list_snapshots(limit: :infinity)

    %{
      total_count: length(snapshots),
      protected_count: Enum.count(snapshots, & &1.protected),
      manual_count: Enum.count(snapshots, &(&1.snapshot_type == :manual)),
      auto_count: Enum.count(snapshots, &(&1.snapshot_type == :auto)),
      pre_tx_count: Enum.count(snapshots, &(&1.snapshot_type == :pre_transaction)),
      atomic_count: Enum.count(snapshots, &Snapshot.atomic?/1),
      total_size_estimate: Enum.sum(Enum.map(snapshots, & &1.size_estimate_bytes))
    }
  end

  @doc """
  Cleanup old snapshots, keeping the most recent N.
  """
  def cleanup(keep_last \\ 50) do
    snapshots = list_snapshots(limit: :infinity)
      |> Enum.reject(& &1.protected)
      |> Enum.drop(keep_last)

    for snap <- snapshots do
      delete_snapshot(snap.id)
    end

    {:ok, length(snapshots)}
  end

  @doc """
  Cleanup old auto-snapshots, keeping the most recent N.
  """
  def cleanup_auto(keep_last \\ 20) do
    snapshots = snapshots_by_type(:auto)
      |> Enum.reject(& &1.protected)
      |> Enum.drop(keep_last)

    for snap <- snapshots do
      delete_snapshot(snap.id)
    end

    {:ok, length(snapshots)}
  end

  ## Private Functions

  defp snap_key(id), do: "#{@snap_prefix}#{id}"

  defp next_snapshot_id do
    current = CubDB.get(@db, "#{@meta_prefix}next_id", 1)
    CubDB.put(@db, "#{@meta_prefix}next_id", current + 1)
    current
  end

  defp maybe_filter_type(stream, nil), do: stream
  defp maybe_filter_type(stream, type) do
    Stream.filter(stream, &(&1.snapshot_type == type))
  end
end
