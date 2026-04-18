# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.Store.PackageStore do
  @moduledoc """
  Package state storage using CubDB.

  Tracks:
  - Installed packages with versions
  - Package metadata (install reason, hold status)
  - Package history (version changes over time)
  - Cache for package info queries
  """

  @db Dnfinition.Store.Packages

  # Key prefixes
  @pkg_prefix "pkg:"
  @ver_prefix "ver:"
  @hist_prefix "hist:"
  @idx_status "idx:status:"
  @idx_repo "idx:repo:"

  @type install_reason :: :manual | :dependency | :group | :recommended | :suggested

  @type package_state :: %{
    name: String.t(),
    version: String.t(),
    arch: String.t() | nil,
    install_reason: install_reason(),
    installed_at: DateTime.t(),
    updated_at: DateTime.t() | nil,
    repository: String.t() | nil,
    size_bytes: non_neg_integer(),
    held: boolean(),
    pinned_version: String.t() | nil,
    files_count: non_neg_integer(),
    description: String.t() | nil
  }

  ## Package State Management

  @doc """
  Record a package as installed.
  """
  def record_installed(name, version, opts \\ []) do
    now = DateTime.utc_now()

    state = %{
      name: name,
      version: version,
      arch: opts[:arch],
      install_reason: opts[:reason] || :manual,
      installed_at: now,
      updated_at: nil,
      repository: opts[:repository],
      size_bytes: opts[:size_bytes] || 0,
      held: false,
      pinned_version: nil,
      files_count: opts[:files_count] || 0,
      description: opts[:description]
    }

    # Store package state
    CubDB.put(@db, pkg_key(name), state)

    # Store current version
    CubDB.put(@db, "#{@ver_prefix}#{name}", version)

    # Index by status
    CubDB.put(@db, "#{@idx_status}installed:#{name}", name)

    # Index by repository if known
    if opts[:repository] do
      CubDB.put(@db, "#{@idx_repo}#{opts[:repository]}:#{name}", name)
    end

    # Record history
    record_history(name, :install, nil, version)

    {:ok, state}
  end

  @doc """
  Record a package update.
  """
  def record_updated(name, old_version, new_version, opts \\ []) do
    case get_package(name) do
      {:ok, state} ->
        updated_state = %{state |
          version: new_version,
          updated_at: DateTime.utc_now(),
          size_bytes: opts[:size_bytes] || state.size_bytes
        }

        CubDB.put(@db, pkg_key(name), updated_state)
        CubDB.put(@db, "#{@ver_prefix}#{name}", new_version)

        # Record history
        record_history(name, :upgrade, old_version, new_version)

        {:ok, updated_state}

      {:error, :not_found} ->
        # Package wasn't tracked, record as new install
        record_installed(name, new_version, opts)
    end
  end

  @doc """
  Record a package removal.
  """
  def record_removed(name) do
    case get_package(name) do
      {:ok, state} ->
        # Record history before deletion
        record_history(name, :remove, state.version, nil)

        # Delete package state
        CubDB.delete(@db, pkg_key(name))
        CubDB.delete(@db, "#{@ver_prefix}#{name}")

        # Remove from indices
        CubDB.delete(@db, "#{@idx_status}installed:#{name}")
        if state.repository do
          CubDB.delete(@db, "#{@idx_repo}#{state.repository}:#{name}")
        end

        :ok

      error ->
        error
    end
  end

  @doc """
  Get package state.
  """
  def get_package(name) do
    case CubDB.get(@db, pkg_key(name)) do
      nil -> {:error, :not_found}
      state -> {:ok, state}
    end
  end

  @doc """
  Get package version.
  """
  def get_version(name) do
    case CubDB.get(@db, "#{@ver_prefix}#{name}") do
      nil -> {:error, :not_found}
      version -> {:ok, version}
    end
  end

  @doc """
  Check if package is installed.
  """
  def installed?(name) do
    CubDB.has_key?(@db, pkg_key(name))
  end

  @doc """
  Hold a package at current version.
  """
  def hold_package(name) do
    case get_package(name) do
      {:ok, state} ->
        updated = %{state | held: true, pinned_version: state.version}
        CubDB.put(@db, pkg_key(name), updated)
        CubDB.put(@db, "#{@idx_status}held:#{name}", name)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Remove hold from a package.
  """
  def unhold_package(name) do
    case get_package(name) do
      {:ok, state} ->
        updated = %{state | held: false, pinned_version: nil}
        CubDB.put(@db, pkg_key(name), updated)
        CubDB.delete(@db, "#{@idx_status}held:#{name}")
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Set install reason for a package.
  """
  def set_install_reason(name, reason) when reason in [:manual, :dependency, :group, :recommended, :suggested] do
    case get_package(name) do
      {:ok, state} ->
        updated = %{state | install_reason: reason}
        CubDB.put(@db, pkg_key(name), updated)
        {:ok, updated}

      error ->
        error
    end
  end

  ## Queries

  @doc """
  List all installed packages.
  """
  def list_installed(opts \\ []) do
    limit = opts[:limit] || :infinity

    @db
    |> CubDB.select(min_key: @pkg_prefix, max_key: "#{@pkg_prefix}\xFF")
    |> Stream.map(fn {_key, state} -> state end)
    |> maybe_take(limit)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  List packages by install reason.
  """
  def list_by_reason(reason) do
    list_installed()
    |> Enum.filter(&(&1.install_reason == reason))
  end

  @doc """
  List held packages.
  """
  def list_held do
    @db
    |> CubDB.select(
      min_key: "#{@idx_status}held:",
      max_key: "#{@idx_status}held:\xFF"
    )
    |> Stream.map(fn {_key, name} -> name end)
    |> Stream.map(&get_package/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, state} -> state end)
  end

  @doc """
  List manually installed packages.
  """
  def list_manual do
    list_by_reason(:manual)
  end

  @doc """
  List automatically installed packages (dependencies).
  """
  def list_auto do
    list_by_reason(:dependency)
  end

  @doc """
  Get packages from a specific repository.
  """
  def list_from_repo(repository) do
    @db
    |> CubDB.select(
      min_key: "#{@idx_repo}#{repository}:",
      max_key: "#{@idx_repo}#{repository}:\xFF"
    )
    |> Stream.map(fn {_key, name} -> name end)
    |> Stream.map(&get_package/1)
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, state} -> state end)
  end

  @doc """
  Search packages by name pattern.
  """
  def search(pattern) do
    regex = Regex.compile!(pattern, [:caseless])

    list_installed()
    |> Enum.filter(fn state ->
      Regex.match?(regex, state.name) or
      (state.description && Regex.match?(regex, state.description))
    end)
  end

  @doc """
  Get package manifest (all packages with versions).
  """
  def get_manifest do
    list_installed()
    |> Map.new(&{&1.name, &1.version})
  end

  @doc """
  Get count of installed packages.
  """
  def count do
    @db
    |> CubDB.select(min_key: @pkg_prefix, max_key: "#{@pkg_prefix}\xFF")
    |> Enum.count()
  end

  @doc """
  Get statistics about installed packages.
  """
  def stats do
    packages = list_installed()

    %{
      total_count: length(packages),
      manual_count: Enum.count(packages, &(&1.install_reason == :manual)),
      dependency_count: Enum.count(packages, &(&1.install_reason == :dependency)),
      held_count: Enum.count(packages, & &1.held),
      total_size: Enum.sum(Enum.map(packages, & &1.size_bytes)),
      repositories: packages
        |> Enum.map(& &1.repository)
        |> Enum.reject(&is_nil/1)
        |> Enum.frequencies()
    }
  end

  ## History

  @doc """
  Get version history for a package.
  """
  def get_history(name, opts \\ []) do
    limit = opts[:limit] || 50

    @db
    |> CubDB.select(
      min_key: "#{@hist_prefix}#{name}:",
      max_key: "#{@hist_prefix}#{name}:\xFF"
    )
    |> Stream.map(fn {_key, entry} -> entry end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Record a history entry for a package.
  """
  def record_history(name, action, old_version, new_version) do
    now = DateTime.utc_now()
    unix = DateTime.to_unix(now, :microsecond)

    entry = %{
      action: action,
      old_version: old_version,
      new_version: new_version,
      timestamp: now
    }

    CubDB.put(@db, "#{@hist_prefix}#{name}:#{unix}", entry)
    :ok
  end

  ## Sync with System

  @doc """
  Sync package database with actual system state.
  Takes a list of {name, version, reason} tuples from the system.
  """
  def sync_from_system(system_packages) when is_list(system_packages) do
    current = get_manifest()
    system_map = Map.new(system_packages, fn {name, ver, _} -> {name, ver} end)

    # Find removed packages
    removed = MapSet.difference(MapSet.new(Map.keys(current)), MapSet.new(Map.keys(system_map)))
    for name <- removed, do: record_removed(name)

    # Find new/updated packages
    for {name, version, reason} <- system_packages do
      case Map.get(current, name) do
        nil ->
          record_installed(name, version, reason: reason)

        ^version ->
          :ok  # Same version, no change

        old_version ->
          record_updated(name, old_version, version)
      end
    end

    {:ok, %{
      added: length(system_packages) - map_size(current) + MapSet.size(removed),
      removed: MapSet.size(removed),
      updated: 0  # Would need more complex tracking
    }}
  end

  ## Private Functions

  defp pkg_key(name), do: "#{@pkg_prefix}#{name}"

  defp maybe_take(enum, :infinity), do: Enum.to_list(enum)
  defp maybe_take(enum, limit), do: Enum.take(enum, limit)
end
