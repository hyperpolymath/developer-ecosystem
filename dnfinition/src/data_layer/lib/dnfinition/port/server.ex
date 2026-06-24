# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Port.Server do
  @moduledoc """
  Port server for Ada-Elixir IPC communication.

  Provides a JSON-based protocol for the Ada CLI to interact with
  the Elixir data layer. Uses stdin/stdout for communication.

  Protocol:
  - Messages are JSON objects terminated by newline
  - Request format: {"op": "operation", "args": {...}}
  - Response format: {"status": "ok"|"error", "data": ...}

  Operations:
  - tx:begin, tx:add_op, tx:commit, tx:fail, tx:get, tx:list
  - snap:create, snap:get, snap:delete, snap:list, snap:rollback
  - pkg:get, pkg:list, pkg:sync, pkg:hold, pkg:unhold
  - config:get, config:set
  - dl:queue, dl:queue_batch, dl:start, dl:pause, dl:status, dl:progress
  - mirror:fetch, mirror:test, mirror:best, mirror:ping, mirror:list
  """

  use GenServer
  require Logger

  alias Dnfinition.Store.{TransactionStore, SnapshotStore, PackageStore}
  alias Dnfinition.Models.{Transaction, Snapshot, Operation}

  @type state :: %{
    input_buffer: String.t()
  }

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    # Set up stdin reading if running as port
    if System.get_env("DNFINITION_PORT_MODE") == "1" do
      spawn_link(fn -> read_stdin_loop() end)
    end

    {:ok, %{input_buffer: ""}}
  end

  @impl true
  def handle_cast({:process_message, message}, state) do
    response = process_request(message)
    output_response(response)
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdin, line}, state) do
    case Jason.decode(String.trim(line)) do
      {:ok, request} ->
        response = process_request(request)
        output_response(response)

      {:error, _} ->
        output_response(%{status: "error", error: "invalid_json"})
    end

    {:noreply, state}
  end

  ## Request Processing

  @doc """
  Process a request and return a response.
  """
  def process_request(%{"op" => op} = request) do
    args = Map.get(request, "args", %{})

    try do
      case op do
        # Transaction operations
        "tx:begin" -> tx_begin(args)
        "tx:add_op" -> tx_add_operation(args)
        "tx:commit" -> tx_commit(args)
        "tx:fail" -> tx_fail(args)
        "tx:cancel" -> tx_cancel(args)
        "tx:get" -> tx_get(args)
        "tx:list" -> tx_list(args)
        "tx:reverse" -> tx_reverse(args)
        "tx:replay" -> tx_replay(args)
        "tx:current" -> tx_current(args)
        "tx:cleanup" -> tx_cleanup(args)

        # Snapshot operations
        "snap:create" -> snap_create(args)
        "snap:get" -> snap_get(args)
        "snap:delete" -> snap_delete(args)
        "snap:list" -> snap_list(args)
        "snap:protect" -> snap_protect(args)
        "snap:unprotect" -> snap_unprotect(args)
        "snap:latest" -> snap_latest(args)
        "snap:stats" -> snap_stats(args)
        "snap:cleanup" -> snap_cleanup(args)

        # Package operations
        "pkg:get" -> pkg_get(args)
        "pkg:version" -> pkg_version(args)
        "pkg:list" -> pkg_list(args)
        "pkg:search" -> pkg_search(args)
        "pkg:hold" -> pkg_hold(args)
        "pkg:unhold" -> pkg_unhold(args)
        "pkg:mark" -> pkg_mark(args)
        "pkg:sync" -> pkg_sync(args)
        "pkg:manifest" -> pkg_manifest(args)
        "pkg:stats" -> pkg_stats(args)
        "pkg:history" -> pkg_history(args)
        "pkg:record_install" -> pkg_record_install(args)
        "pkg:record_update" -> pkg_record_update(args)
        "pkg:record_remove" -> pkg_record_remove(args)

        # Config operations
        "config:get" -> config_get(args)
        "config:set" -> config_set(args)
        "config:list" -> config_list(args)

        # Download operations
        "dl:queue" -> dl_queue(args)
        "dl:queue_batch" -> dl_queue_batch(args)
        "dl:start" -> dl_start(args)
        "dl:pause" -> dl_pause(args)
        "dl:resume" -> dl_resume(args)
        "dl:cancel" -> dl_cancel(args)
        "dl:cancel_all" -> dl_cancel_all(args)
        "dl:status" -> dl_status(args)
        "dl:progress" -> dl_progress(args)
        "dl:await" -> dl_await(args)
        "dl:set_parallelism" -> dl_set_parallelism(args)

        # Mirror operations
        "mirror:fetch" -> mirror_fetch(args)
        "mirror:test" -> mirror_test(args)
        "mirror:best" -> mirror_best(args)
        "mirror:ping" -> mirror_ping(args)
        "mirror:cached" -> mirror_cached(args)
        "mirror:clear_cache" -> mirror_clear_cache(args)
        "mirror:list" -> mirror_list(args)

        # System operations
        "ping" -> %{status: "ok", data: "pong"}
        "version" -> %{status: "ok", data: %{version: "0.1.0", protocol: 1}}

        _ -> %{status: "error", error: "unknown_operation", op: op}
      end
    rescue
      e ->
        Logger.error("Port server error: #{Exception.message(e)}")
        %{status: "error", error: "internal_error", message: Exception.message(e)}
    end
  end

  def process_request(_), do: %{status: "error", error: "invalid_request"}

  ## Transaction Operations

  defp tx_begin(%{"description" => desc} = args) do
    opts = [user: args["user"]]

    case TransactionStore.begin_transaction(desc, opts) do
      {:ok, id} -> %{status: "ok", data: %{id: id}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_begin(_), do: %{status: "error", error: "missing_description"}

  defp tx_add_operation(%{"tx_id" => tx_id, "operation" => op}) do
    operation = %{
      type: String.to_existing_atom(op["type"]),
      package: op["package"],
      old_version: op["old_version"],
      new_version: op["new_version"]
    }

    case TransactionStore.add_operation(tx_id, operation) do
      {:ok, op} -> %{status: "ok", data: Operation.to_map(op)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_add_operation(_), do: %{status: "error", error: "missing_tx_id_or_operation"}

  defp tx_commit(%{"tx_id" => tx_id} = args) do
    opts = [snapshot_id: args["snapshot_id"]]

    case TransactionStore.commit_transaction(tx_id, opts) do
      {:ok, tx} -> %{status: "ok", data: Transaction.to_map(tx)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_commit(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_fail(%{"tx_id" => tx_id} = args) do
    case TransactionStore.fail_transaction(tx_id, args["message"]) do
      {:ok, tx} -> %{status: "ok", data: Transaction.to_map(tx)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_fail(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_cancel(%{"tx_id" => tx_id}) do
    case TransactionStore.cancel_transaction(tx_id) do
      {:ok, tx} -> %{status: "ok", data: Transaction.to_map(tx)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_cancel(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_get(%{"tx_id" => tx_id}) do
    case TransactionStore.get_transaction(tx_id) do
      {:ok, tx} -> %{status: "ok", data: Transaction.to_map(tx)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_get(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_list(args) do
    opts = [
      limit: args["limit"] || 100,
      status: args["status"] && String.to_existing_atom(args["status"])
    ]

    transactions = TransactionStore.list_transactions(opts)
    %{status: "ok", data: Enum.map(transactions, &Transaction.to_map/1)}
  end

  defp tx_reverse(%{"tx_id" => tx_id}) do
    case TransactionStore.reverse_transaction(tx_id) do
      {:ok, :snapshot_restored} ->
        %{status: "ok", data: %{method: "snapshot_restored"}}

      {:ok, :operations, ops} ->
        %{status: "ok", data: %{method: "operations", operations: ops}}

      {:error, reason} ->
        %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_reverse(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_replay(%{"tx_id" => tx_id}) do
    case TransactionStore.replay_transaction(tx_id) do
      {:ok, operations} -> %{status: "ok", data: operations}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp tx_replay(_), do: %{status: "error", error: "missing_tx_id"}

  defp tx_current(_args) do
    case TransactionStore.current_transaction() do
      {:ok, tx} -> %{status: "ok", data: Transaction.to_map(tx)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp tx_cleanup(args) do
    keep = args["keep_last"] || 100
    case TransactionStore.cleanup(keep) do
      {:ok, count} -> %{status: "ok", data: %{deleted: count}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  ## Snapshot Operations

  defp snap_create(%{"name" => name} = args) do
    opts = [
      description: args["description"],
      type: args["type"] && String.to_existing_atom(args["type"]),
      package_manifest: args["package_manifest"],
      btrfs_snapshot: args["btrfs_snapshot"],
      ostree_commit: args["ostree_commit"],
      transaction_id: args["transaction_id"],
      tags: args["tags"] || [],
      protected: args["protected"] || false
    ]

    case SnapshotStore.create_snapshot(name, opts) do
      {:ok, snap} -> %{status: "ok", data: Snapshot.to_map(snap)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp snap_create(_), do: %{status: "error", error: "missing_name"}

  defp snap_get(%{"id" => id}) do
    case SnapshotStore.get_snapshot(id) do
      {:ok, snap} -> %{status: "ok", data: Snapshot.to_map(snap)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp snap_get(_), do: %{status: "error", error: "missing_id"}

  defp snap_delete(%{"id" => id}) do
    case SnapshotStore.delete_snapshot(id) do
      :ok -> %{status: "ok", data: %{deleted: true}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp snap_delete(_), do: %{status: "error", error: "missing_id"}

  defp snap_list(args) do
    opts = [
      limit: args["limit"] || 100,
      type: args["type"] && String.to_existing_atom(args["type"])
    ]

    snapshots = SnapshotStore.list_snapshots(opts)
    %{status: "ok", data: Enum.map(snapshots, &Snapshot.to_map/1)}
  end

  defp snap_protect(%{"id" => id}) do
    case SnapshotStore.protect_snapshot(id) do
      {:ok, snap} -> %{status: "ok", data: Snapshot.to_map(snap)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp snap_protect(_), do: %{status: "error", error: "missing_id"}

  defp snap_unprotect(%{"id" => id}) do
    case SnapshotStore.unprotect_snapshot(id) do
      {:ok, snap} -> %{status: "ok", data: Snapshot.to_map(snap)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp snap_unprotect(_), do: %{status: "error", error: "missing_id"}

  defp snap_latest(_args) do
    case SnapshotStore.latest_snapshot() do
      {:ok, snap} -> %{status: "ok", data: Snapshot.to_map(snap)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp snap_stats(_args) do
    stats = SnapshotStore.stats()
    %{status: "ok", data: stats}
  end

  defp snap_cleanup(args) do
    keep = args["keep_last"] || 50
    case SnapshotStore.cleanup(keep) do
      {:ok, count} -> %{status: "ok", data: %{deleted: count}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  ## Package Operations

  defp pkg_get(%{"name" => name}) do
    case PackageStore.get_package(name) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_get(_), do: %{status: "error", error: "missing_name"}

  defp pkg_version(%{"name" => name}) do
    case PackageStore.get_version(name) do
      {:ok, version} -> %{status: "ok", data: %{version: version}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_version(_), do: %{status: "error", error: "missing_name"}

  defp pkg_list(args) do
    opts = [limit: args["limit"] || :infinity]

    packages = case args["filter"] do
      "manual" -> PackageStore.list_manual()
      "auto" -> PackageStore.list_auto()
      "held" -> PackageStore.list_held()
      _ -> PackageStore.list_installed(opts)
    end

    %{status: "ok", data: packages}
  end

  defp pkg_search(%{"pattern" => pattern}) do
    packages = PackageStore.search(pattern)
    %{status: "ok", data: packages}
  end
  defp pkg_search(_), do: %{status: "error", error: "missing_pattern"}

  defp pkg_hold(%{"name" => name}) do
    case PackageStore.hold_package(name) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_hold(_), do: %{status: "error", error: "missing_name"}

  defp pkg_unhold(%{"name" => name}) do
    case PackageStore.unhold_package(name) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_unhold(_), do: %{status: "error", error: "missing_name"}

  defp pkg_mark(%{"name" => name, "reason" => reason}) do
    reason_atom = String.to_existing_atom(reason)
    case PackageStore.set_install_reason(name, reason_atom) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_mark(_), do: %{status: "error", error: "missing_name_or_reason"}

  defp pkg_sync(%{"packages" => packages}) when is_list(packages) do
    parsed = Enum.map(packages, fn p ->
      {p["name"], p["version"], String.to_existing_atom(p["reason"] || "manual")}
    end)

    case PackageStore.sync_from_system(parsed) do
      {:ok, stats} -> %{status: "ok", data: stats}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_sync(_), do: %{status: "error", error: "missing_packages"}

  defp pkg_manifest(_args) do
    manifest = PackageStore.get_manifest()
    %{status: "ok", data: manifest}
  end

  defp pkg_stats(_args) do
    stats = PackageStore.stats()
    %{status: "ok", data: stats}
  end

  defp pkg_history(%{"name" => name} = args) do
    opts = [limit: args["limit"] || 50]
    history = PackageStore.get_history(name, opts)
    %{status: "ok", data: history}
  end
  defp pkg_history(_), do: %{status: "error", error: "missing_name"}

  defp pkg_record_install(%{"name" => name, "version" => version} = args) do
    opts = [
      reason: args["reason"] && String.to_existing_atom(args["reason"]),
      repository: args["repository"],
      size_bytes: args["size_bytes"]
    ]

    case PackageStore.record_installed(name, version, opts) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_record_install(_), do: %{status: "error", error: "missing_name_or_version"}

  defp pkg_record_update(%{"name" => name, "old_version" => old_ver, "new_version" => new_ver} = args) do
    opts = [size_bytes: args["size_bytes"]]

    case PackageStore.record_updated(name, old_ver, new_ver, opts) do
      {:ok, state} -> %{status: "ok", data: state}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_record_update(_), do: %{status: "error", error: "missing_name_or_versions"}

  defp pkg_record_remove(%{"name" => name}) do
    case PackageStore.record_removed(name) do
      :ok -> %{status: "ok", data: %{removed: true}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp pkg_record_remove(_), do: %{status: "error", error: "missing_name"}

  ## Config Operations

  defp config_get(%{"key" => key}) do
    case CubDB.get(Dnfinition.Store.Config, key) do
      nil -> %{status: "ok", data: nil}
      value -> %{status: "ok", data: value}
    end
  end
  defp config_get(_), do: %{status: "error", error: "missing_key"}

  defp config_set(%{"key" => key, "value" => value}) do
    CubDB.put(Dnfinition.Store.Config, key, value)
    %{status: "ok", data: %{key: key, value: value}}
  end
  defp config_set(_), do: %{status: "error", error: "missing_key_or_value"}

  defp config_list(_args) do
    config = CubDB.select(Dnfinition.Store.Config)
      |> Enum.into(%{})
    %{status: "ok", data: config}
  end

  ## Download Operations

  alias Dnfinition.Download.Manager, as: DownloadManager

  defp dl_queue(%{"url" => url, "destination" => dest} = args) do
    opts = [
      package_name: args["package_name"],
      version: args["version"],
      size_bytes: args["size_bytes"],
      checksum: args["checksum"],
      checksum_type: args["checksum_type"] && String.to_existing_atom(args["checksum_type"]),
      mirrors: args["mirrors"]
    ]

    case DownloadManager.queue_download(url, dest, opts) do
      {:ok, id} -> %{status: "ok", data: %{id: id}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp dl_queue(_), do: %{status: "error", error: "missing_url_or_destination"}

  defp dl_queue_batch(%{"items" => items}) when is_list(items) do
    parsed_items = Enum.map(items, fn item ->
      [
        url: item["url"],
        destination: item["destination"],
        package_name: item["package_name"],
        version: item["version"],
        size_bytes: item["size_bytes"],
        checksum: item["checksum"],
        checksum_type: item["checksum_type"] && String.to_existing_atom(item["checksum_type"]),
        mirrors: item["mirrors"]
      ]
    end)

    case DownloadManager.queue_downloads(parsed_items) do
      {:ok, ids} -> %{status: "ok", data: %{ids: ids}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp dl_queue_batch(_), do: %{status: "error", error: "missing_items"}

  defp dl_start(_args) do
    DownloadManager.start_downloads()
    %{status: "ok", data: %{started: true}}
  end

  defp dl_pause(_args) do
    DownloadManager.pause_downloads()
    %{status: "ok", data: %{paused: true}}
  end

  defp dl_resume(_args) do
    DownloadManager.resume_downloads()
    %{status: "ok", data: %{resumed: true}}
  end

  defp dl_cancel(%{"id" => id}) do
    case DownloadManager.cancel_download(id) do
      :ok -> %{status: "ok", data: %{cancelled: true}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp dl_cancel(_), do: %{status: "error", error: "missing_id"}

  defp dl_cancel_all(_args) do
    case DownloadManager.cancel_all() do
      :ok -> %{status: "ok", data: %{cancelled_all: true}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end

  defp dl_status(_args) do
    status = DownloadManager.get_status()
    %{status: "ok", data: status}
  end

  defp dl_progress(_args) do
    progress = DownloadManager.get_progress()
    %{status: "ok", data: progress}
  end

  defp dl_await(args) do
    timeout = args["timeout"] || :infinity
    case DownloadManager.await_completion(timeout) do
      {:ok, completed, failed} ->
        %{status: "ok", data: %{
          completed: length(completed),
          failed: length(failed),
          completed_items: Enum.map(completed, &Map.take(&1, [:id, :package_name, :destination])),
          failed_items: Enum.map(failed, &Map.take(&1, [:id, :package_name, :error]))
        }}

      {:error, reason} ->
        %{status: "error", error: inspect(reason)}
    end
  end

  defp dl_set_parallelism(%{"parallelism" => n}) when is_integer(n) and n > 0 do
    case DownloadManager.set_parallelism(n) do
      :ok -> %{status: "ok", data: %{parallelism: n}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp dl_set_parallelism(_), do: %{status: "error", error: "missing_or_invalid_parallelism"}

  ## Mirror Operations

  alias Dnfinition.Mirror.{Optimizer, ListManager}

  defp mirror_fetch(%{"mirrors" => mirrors} = args) when is_list(mirrors) do
    opts = [
      test_count: args["test_count"] || 5,
      test_file: args["test_file"]
    ]

    case Optimizer.fetch_mirrors(mirrors, opts) do
      {:ok, results} ->
        %{status: "ok", data: %{
          mirrors: Enum.map(results, &format_mirror_result/1),
          count: length(results)
        }}

      {:error, reason} ->
        %{status: "error", error: inspect(reason)}
    end
  end
  defp mirror_fetch(_), do: %{status: "error", error: "missing_mirrors"}

  defp mirror_test(%{"url" => url} = args) do
    opts = [
      test_count: args["test_count"] || 3,
      test_file: args["test_file"]
    ]

    case Optimizer.test_mirror(url, opts) do
      {:ok, result} -> %{status: "ok", data: format_mirror_result(result)}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp mirror_test(_), do: %{status: "error", error: "missing_url"}

  defp mirror_best(%{"mirrors" => mirrors} = args) when is_list(mirrors) do
    count = args["count"] || 5
    opts = [
      test_count: args["test_count"] || 5,
      test_file: args["test_file"]
    ]

    case Optimizer.get_best_mirrors(mirrors, count, opts) do
      {:ok, results} ->
        %{status: "ok", data: %{
          mirrors: Enum.map(results, &format_mirror_result/1),
          count: length(results)
        }}

      {:error, reason} ->
        %{status: "error", error: inspect(reason)}
    end
  end
  defp mirror_best(_), do: %{status: "error", error: "missing_mirrors"}

  defp mirror_ping(%{"url" => url}) do
    case Optimizer.ping_mirror(url) do
      {:ok, :reachable} -> %{status: "ok", data: %{reachable: true}}
      {:ok, {:unreachable, code}} -> %{status: "ok", data: %{reachable: false, http_status: code}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp mirror_ping(_), do: %{status: "error", error: "missing_url"}

  defp mirror_cached(_args) do
    case Optimizer.get_cached_rankings() do
      {:ok, rankings} ->
        %{status: "ok", data: %{
          mirrors: Enum.map(rankings, &format_mirror_result/1),
          count: length(rankings)
        }}

      {:error, :not_cached} ->
        %{status: "ok", data: %{mirrors: [], count: 0, cached: false}}

      {:error, reason} ->
        %{status: "error", error: inspect(reason)}
    end
  end

  defp mirror_clear_cache(_args) do
    Optimizer.clear_cache()
    %{status: "ok", data: %{cleared: true}}
  end

  defp mirror_list(%{"pm_type" => pm_type}) do
    type = String.to_existing_atom(pm_type)
    case ListManager.get_mirrors_for_pm(type) do
      {:ok, mirrors} -> %{status: "ok", data: %{mirrors: mirrors, count: length(mirrors)}}
      {:error, reason} -> %{status: "error", error: inspect(reason)}
    end
  end
  defp mirror_list(_), do: %{status: "error", error: "missing_pm_type"}

  defp format_mirror_result(result) do
    %{
      url: result.url,
      latency_ms: result.latency_ms,
      speed_kbps: result.speed_kbps,
      available: result.available,
      country: result.country,
      score: result.score,
      last_tested: if(result.last_tested, do: DateTime.to_iso8601(result.last_tested))
    }
  end

  ## Private Functions

  defp read_stdin_loop do
    case IO.gets("") do
      :eof ->
        :ok

      {:error, _} ->
        :ok

      line ->
        send(__MODULE__, {:stdin, line})
        read_stdin_loop()
    end
  end

  defp output_response(response) do
    json = Jason.encode!(response)
    IO.puts(json)
  end
end
