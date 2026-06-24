# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Models.Snapshot do
  @moduledoc """
  Snapshot model representing a point-in-time system state.

  Snapshots capture:
  - Complete package list with versions
  - Repository configuration
  - Optional btrfs/ostree snapshot references
  - Creation metadata
  """

  @type snapshot_type :: :manual | :auto | :pre_transaction | :post_transaction | :system

  @type t :: %__MODULE__{
    id: pos_integer(),
    name: String.t(),
    description: String.t() | nil,
    created_at: DateTime.t(),
    snapshot_type: snapshot_type(),
    user: String.t(),
    package_count: non_neg_integer(),
    package_manifest: map(),
    repo_config: map(),
    btrfs_snapshot: String.t() | nil,
    ostree_commit: String.t() | nil,
    transaction_id: pos_integer() | nil,
    size_estimate_bytes: non_neg_integer(),
    tags: [String.t()],
    protected: boolean()
  }

  defstruct [
    :id,
    :name,
    :description,
    :created_at,
    :snapshot_type,
    :user,
    :btrfs_snapshot,
    :ostree_commit,
    :transaction_id,
    package_count: 0,
    package_manifest: %{},
    repo_config: %{},
    size_estimate_bytes: 0,
    tags: [],
    protected: false
  ]

  @doc """
  Create a new snapshot.
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      id: opts[:id],
      name: name,
      description: opts[:description],
      created_at: DateTime.utc_now(),
      snapshot_type: opts[:type] || :manual,
      user: opts[:user] || System.get_env("USER", "unknown"),
      package_count: opts[:package_count] || 0,
      package_manifest: opts[:package_manifest] || %{},
      repo_config: opts[:repo_config] || %{},
      btrfs_snapshot: opts[:btrfs_snapshot],
      ostree_commit: opts[:ostree_commit],
      transaction_id: opts[:transaction_id],
      tags: opts[:tags] || [],
      protected: opts[:protected] || false
    }
  end

  @doc """
  Check if snapshot is restorable.
  """
  def restorable?(%__MODULE__{package_manifest: manifest}) when map_size(manifest) > 0, do: true
  def restorable?(%__MODULE__{btrfs_snapshot: snap}) when not is_nil(snap), do: true
  def restorable?(%__MODULE__{ostree_commit: commit}) when not is_nil(commit), do: true
  def restorable?(_), do: false

  @doc """
  Check if snapshot is atomic (btrfs/ostree).
  """
  def atomic?(%__MODULE__{btrfs_snapshot: snap}) when not is_nil(snap), do: true
  def atomic?(%__MODULE__{ostree_commit: commit}) when not is_nil(commit), do: true
  def atomic?(_), do: false

  @doc """
  Get the age of the snapshot.
  """
  def age(%__MODULE__{created_at: created}) do
    DateTime.diff(DateTime.utc_now(), created, :second)
  end

  @doc """
  Format age as human-readable string.
  """
  def age_string(%__MODULE__{} = snap) do
    seconds = age(snap)
    cond do
      seconds < 60 -> "#{seconds}s ago"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds < 604800 -> "#{div(seconds, 86400)}d ago"
      seconds < 2592000 -> "#{div(seconds, 604800)}w ago"
      true -> "#{div(seconds, 2592000)}mo ago"
    end
  end

  @doc """
  Get packages that differ between this snapshot and current state.
  """
  def diff_packages(%__MODULE__{package_manifest: manifest}, current_packages)
      when is_map(current_packages) do
    manifest_set = MapSet.new(Map.keys(manifest))
    current_set = MapSet.new(Map.keys(current_packages))

    added = MapSet.difference(current_set, manifest_set) |> MapSet.to_list()
    removed = MapSet.difference(manifest_set, current_set) |> MapSet.to_list()

    changed = manifest
      |> Enum.filter(fn {pkg, ver} ->
        current_ver = Map.get(current_packages, pkg)
        current_ver && current_ver != ver
      end)
      |> Enum.map(fn {pkg, old_ver} -> {pkg, old_ver, Map.get(current_packages, pkg)} end)

    %{added: added, removed: removed, changed: changed}
  end

  @doc """
  Get a human-readable summary.
  """
  def summary(%__MODULE__{} = snap) do
    type_str = case snap.snapshot_type do
      :manual -> "Manual"
      :auto -> "Auto"
      :pre_transaction -> "Pre-transaction"
      :post_transaction -> "Post-transaction"
      :system -> "System"
    end

    atomic_str = if atomic?(snap), do: " [atomic]", else: ""
    protected_str = if snap.protected, do: " [protected]", else: ""

    "#{type_str} snapshot ##{snap.id}: #{snap.name} (#{snap.package_count} packages)#{atomic_str}#{protected_str}"
  end

  @doc """
  Convert to JSON-serializable map.
  """
  def to_map(%__MODULE__{} = snap) do
    %{
      id: snap.id,
      name: snap.name,
      description: snap.description,
      created_at: DateTime.to_iso8601(snap.created_at),
      snapshot_type: Atom.to_string(snap.snapshot_type),
      user: snap.user,
      package_count: snap.package_count,
      package_manifest: snap.package_manifest,
      repo_config: snap.repo_config,
      btrfs_snapshot: snap.btrfs_snapshot,
      ostree_commit: snap.ostree_commit,
      transaction_id: snap.transaction_id,
      size_estimate_bytes: snap.size_estimate_bytes,
      tags: snap.tags,
      protected: snap.protected
    }
  end

  @doc """
  Create from map (JSON deserialization).
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"] || map[:id],
      name: map["name"] || map[:name],
      description: map["description"] || map[:description],
      created_at: parse_datetime(map["created_at"] || map[:created_at]),
      snapshot_type: parse_type(map["snapshot_type"] || map[:snapshot_type]),
      user: map["user"] || map[:user],
      package_count: map["package_count"] || map[:package_count] || 0,
      package_manifest: map["package_manifest"] || map[:package_manifest] || %{},
      repo_config: map["repo_config"] || map[:repo_config] || %{},
      btrfs_snapshot: map["btrfs_snapshot"] || map[:btrfs_snapshot],
      ostree_commit: map["ostree_commit"] || map[:ostree_commit],
      transaction_id: map["transaction_id"] || map[:transaction_id],
      size_estimate_bytes: map["size_estimate_bytes"] || map[:size_estimate_bytes] || 0,
      tags: map["tags"] || map[:tags] || [],
      protected: map["protected"] || map[:protected] || false
    }
  end

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_type(nil), do: :manual
  defp parse_type(type) when is_atom(type), do: type
  defp parse_type(str) when is_binary(str), do: String.to_existing_atom(str)
end
