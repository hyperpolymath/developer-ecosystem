# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Download.Manager do
  @moduledoc """
  Parallel download manager for package files.

  Features:
  - Concurrent downloads with configurable parallelism
  - Progress tracking and reporting
  - Resume support for interrupted downloads
  - Checksum verification (SHA256)
  - Mirror failover
  - Rate limiting
  """

  use GenServer
  require Logger

  alias Dnfinition.Download.Worker

  @default_parallelism 4
  @default_timeout 300_000  # 5 minutes
  @chunk_size 65_536  # 64KB chunks

  @type download_status :: :pending | :downloading | :completed | :failed | :paused

  @type download_item :: %{
    id: String.t(),
    url: String.t(),
    mirrors: [String.t()],
    destination: String.t(),
    package_name: String.t(),
    version: String.t(),
    size_bytes: non_neg_integer(),
    checksum: String.t() | nil,
    checksum_type: :sha256 | :sha512 | :md5 | nil,
    status: download_status(),
    progress: non_neg_integer(),
    error: String.t() | nil,
    started_at: DateTime.t() | nil,
    completed_at: DateTime.t() | nil,
    worker_pid: pid() | nil,
    retries: non_neg_integer()
  }

  @type state :: %{
    queue: :queue.queue(download_item()),
    active: %{String.t() => download_item()},
    completed: [download_item()],
    failed: [download_item()],
    parallelism: pos_integer(),
    rate_limit: non_neg_integer() | nil,
    progress_callback: (download_item() -> any()) | nil,
    completion_callback: ([download_item()] -> any()) | nil
  }

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a package for download.
  """
  def queue_download(url, destination, opts \\ []) do
    GenServer.call(__MODULE__, {:queue, url, destination, opts})
  end

  @doc """
  Queue multiple packages for download.
  """
  def queue_downloads(items) when is_list(items) do
    GenServer.call(__MODULE__, {:queue_batch, items})
  end

  @doc """
  Start processing the download queue.
  """
  def start_downloads do
    GenServer.cast(__MODULE__, :start)
  end

  @doc """
  Pause all active downloads.
  """
  def pause_downloads do
    GenServer.cast(__MODULE__, :pause)
  end

  @doc """
  Resume paused downloads.
  """
  def resume_downloads do
    GenServer.cast(__MODULE__, :resume)
  end

  @doc """
  Cancel a specific download.
  """
  def cancel_download(id) do
    GenServer.call(__MODULE__, {:cancel, id})
  end

  @doc """
  Cancel all downloads and clear the queue.
  """
  def cancel_all do
    GenServer.call(__MODULE__, :cancel_all)
  end

  @doc """
  Get current download status.
  """
  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get progress for all downloads.
  """
  def get_progress do
    GenServer.call(__MODULE__, :progress)
  end

  @doc """
  Set the parallelism level (number of concurrent downloads).
  """
  def set_parallelism(n) when n > 0 do
    GenServer.call(__MODULE__, {:set_parallelism, n})
  end

  @doc """
  Set a progress callback function.
  """
  def set_progress_callback(callback) when is_function(callback, 1) do
    GenServer.call(__MODULE__, {:set_progress_callback, callback})
  end

  @doc """
  Set a completion callback function.
  """
  def set_completion_callback(callback) when is_function(callback, 1) do
    GenServer.call(__MODULE__, {:set_completion_callback, callback})
  end

  @doc """
  Wait for all downloads to complete.
  """
  def await_completion(timeout \\ :infinity) do
    GenServer.call(__MODULE__, :await_completion, timeout)
  end

  ## Callbacks

  @impl true
  def init(opts) do
    state = %{
      queue: :queue.new(),
      active: %{},
      completed: [],
      failed: [],
      parallelism: opts[:parallelism] || @default_parallelism,
      rate_limit: opts[:rate_limit],
      progress_callback: nil,
      completion_callback: nil,
      paused: false,
      awaiting: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:queue, url, destination, opts}, _from, state) do
    item = create_download_item(url, destination, opts)
    new_queue = :queue.in(item, state.queue)
    {:reply, {:ok, item.id}, %{state | queue: new_queue}}
  end

  @impl true
  def handle_call({:queue_batch, items}, _from, state) do
    {ids, new_queue} = Enum.reduce(items, {[], state.queue}, fn item_opts, {ids, queue} ->
      item = create_download_item(item_opts[:url], item_opts[:destination], item_opts)
      {[item.id | ids], :queue.in(item, queue)}
    end)

    {:reply, {:ok, Enum.reverse(ids)}, %{state | queue: new_queue}}
  end

  @impl true
  def handle_call({:cancel, id}, _from, state) do
    case Map.get(state.active, id) do
      nil ->
        # Check queue
        new_queue = :queue.filter(fn item -> item.id != id end, state.queue)
        {:reply, :ok, %{state | queue: new_queue}}

      item ->
        # Stop the worker
        if item.worker_pid, do: Worker.stop(item.worker_pid)
        new_active = Map.delete(state.active, id)
        {:reply, :ok, %{state | active: new_active}}
    end
  end

  @impl true
  def handle_call(:cancel_all, _from, state) do
    # Stop all workers
    for {_id, item} <- state.active do
      if item.worker_pid, do: Worker.stop(item.worker_pid)
    end

    new_state = %{state |
      queue: :queue.new(),
      active: %{},
      failed: state.failed ++ Map.values(state.active)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      queued: :queue.len(state.queue),
      active: map_size(state.active),
      completed: length(state.completed),
      failed: length(state.failed),
      paused: state.paused,
      parallelism: state.parallelism
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:progress, _from, state) do
    active_progress = Map.values(state.active)
      |> Enum.map(&%{
        id: &1.id,
        package: &1.package_name,
        progress: &1.progress,
        size: &1.size_bytes,
        status: &1.status
      })

    {:reply, active_progress, state}
  end

  @impl true
  def handle_call({:set_parallelism, n}, _from, state) do
    {:reply, :ok, %{state | parallelism: n}}
  end

  @impl true
  def handle_call({:set_progress_callback, callback}, _from, state) do
    {:reply, :ok, %{state | progress_callback: callback}}
  end

  @impl true
  def handle_call({:set_completion_callback, callback}, _from, state) do
    {:reply, :ok, %{state | completion_callback: callback}}
  end

  @impl true
  def handle_call(:await_completion, from, state) do
    if :queue.is_empty(state.queue) and map_size(state.active) == 0 do
      {:reply, {:ok, state.completed, state.failed}, state}
    else
      {:noreply, %{state | awaiting: [from | state.awaiting]}}
    end
  end

  @impl true
  def handle_cast(:start, state) do
    new_state = start_pending_downloads(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:pause, state) do
    # Pause all active downloads
    for {_id, item} <- state.active do
      if item.worker_pid, do: Worker.pause(item.worker_pid)
    end

    new_active = state.active
      |> Enum.map(fn {id, item} -> {id, %{item | status: :paused}} end)
      |> Map.new()

    {:noreply, %{state | active: new_active, paused: true}}
  end

  @impl true
  def handle_cast(:resume, state) do
    # Resume all paused downloads
    for {_id, item} <- state.active do
      if item.worker_pid and item.status == :paused do
        Worker.resume(item.worker_pid)
      end
    end

    new_active = state.active
      |> Enum.map(fn {id, item} ->
        if item.status == :paused do
          {id, %{item | status: :downloading}}
        else
          {id, item}
        end
      end)
      |> Map.new()

    {:noreply, %{state | active: new_active, paused: false}}
  end

  @impl true
  def handle_info({:download_progress, id, bytes_downloaded}, state) do
    case Map.get(state.active, id) do
      nil ->
        {:noreply, state}

      item ->
        updated_item = %{item | progress: bytes_downloaded}
        new_active = Map.put(state.active, id, updated_item)

        # Call progress callback if set
        if state.progress_callback do
          state.progress_callback.(updated_item)
        end

        {:noreply, %{state | active: new_active}}
    end
  end

  @impl true
  def handle_info({:download_complete, id, result}, state) do
    case Map.get(state.active, id) do
      nil ->
        {:noreply, state}

      item ->
        new_active = Map.delete(state.active, id)

        {new_completed, new_failed} = case result do
          :ok ->
            completed_item = %{item |
              status: :completed,
              completed_at: DateTime.utc_now()
            }
            {[completed_item | state.completed], state.failed}

          {:error, reason} ->
            # Check if we should retry
            if item.retries < 3 and length(item.mirrors) > 0 do
              # Retry with next mirror
              [_current | remaining_mirrors] = item.mirrors
              retry_item = %{item |
                mirrors: remaining_mirrors,
                url: hd(remaining_mirrors),
                retries: item.retries + 1,
                status: :pending,
                worker_pid: nil
              }
              new_queue = :queue.in(retry_item, state.queue)
              {state.completed, state.failed, %{state | queue: new_queue}}
            else
              failed_item = %{item |
                status: :failed,
                error: inspect(reason),
                completed_at: DateTime.utc_now()
              }
              {state.completed, [failed_item | state.failed]}
            end
        end

        new_state = %{state |
          active: new_active,
          completed: new_completed,
          failed: new_failed
        }

        # Start next download if available
        new_state = start_pending_downloads(new_state)

        # Check if all complete
        new_state = check_completion(new_state)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Worker crashed, mark download as failed
    {id, item} = Enum.find(state.active, fn {_id, item} -> item.worker_pid == pid end) || {nil, nil}

    if item do
      failed_item = %{item |
        status: :failed,
        error: "Worker crashed",
        completed_at: DateTime.utc_now()
      }

      new_state = %{state |
        active: Map.delete(state.active, id),
        failed: [failed_item | state.failed]
      }

      new_state = start_pending_downloads(new_state)
      {:noreply, check_completion(new_state)}
    else
      {:noreply, state}
    end
  end

  ## Private Functions

  defp create_download_item(url, destination, opts) do
    %{
      id: generate_id(),
      url: url,
      mirrors: opts[:mirrors] || [url],
      destination: destination,
      package_name: opts[:package_name] || Path.basename(destination),
      version: opts[:version] || "",
      size_bytes: opts[:size_bytes] || 0,
      checksum: opts[:checksum],
      checksum_type: opts[:checksum_type],
      status: :pending,
      progress: 0,
      error: nil,
      started_at: nil,
      completed_at: nil,
      worker_pid: nil,
      retries: 0
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  defp start_pending_downloads(state) do
    if state.paused do
      state
    else
      available_slots = state.parallelism - map_size(state.active)

      if available_slots > 0 and not :queue.is_empty(state.queue) do
        start_next_downloads(state, available_slots)
      else
        state
      end
    end
  end

  defp start_next_downloads(state, 0), do: state
  defp start_next_downloads(state, n) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        state

      {{:value, item}, new_queue} ->
        # Start worker for this download
        {:ok, worker_pid} = Worker.start_link(
          url: item.url,
          destination: item.destination,
          checksum: item.checksum,
          checksum_type: item.checksum_type,
          chunk_size: @chunk_size,
          timeout: @default_timeout,
          manager: self(),
          id: item.id
        )

        Process.monitor(worker_pid)
        Worker.start_download(worker_pid)

        updated_item = %{item |
          status: :downloading,
          started_at: DateTime.utc_now(),
          worker_pid: worker_pid
        }

        new_state = %{state |
          queue: new_queue,
          active: Map.put(state.active, item.id, updated_item)
        }

        start_next_downloads(new_state, n - 1)
    end
  end

  defp check_completion(state) do
    if :queue.is_empty(state.queue) and map_size(state.active) == 0 do
      # Call completion callback
      if state.completion_callback do
        state.completion_callback.(state.completed)
      end

      # Notify awaiting callers
      for from <- state.awaiting do
        GenServer.reply(from, {:ok, state.completed, state.failed})
      end

      %{state | awaiting: []}
    else
      state
    end
  end
end
