# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Download.Worker do
  @moduledoc """
  Download worker process for fetching a single file.

  Features:
  - Chunked download with progress reporting
  - Resume support via HTTP Range headers
  - Checksum verification
  - Timeout handling
  - Graceful pause/resume/cancel
  - OWASP-compliant HTTP security headers
  - VPN/SDP integration for secure downloads
  """

  use GenServer, restart: :temporary
  require Logger

  alias Dnfinition.Security.HttpConfig

  @type state :: %{
    url: String.t(),
    destination: String.t(),
    checksum: String.t() | nil,
    checksum_type: :sha256 | :sha512 | :md5 | nil,
    chunk_size: pos_integer(),
    timeout: pos_integer(),
    manager: pid(),
    id: String.t(),
    status: :idle | :downloading | :paused | :verifying | :complete | :failed,
    file_handle: File.io_device() | nil,
    bytes_downloaded: non_neg_integer(),
    content_length: non_neg_integer() | nil,
    request_ref: reference() | nil,
    hash_state: any()
  }

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start_download(pid) do
    GenServer.cast(pid, :start)
  end

  def pause(pid) do
    GenServer.cast(pid, :pause)
  end

  def resume(pid) do
    GenServer.cast(pid, :resume)
  end

  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  def get_progress(pid) do
    GenServer.call(pid, :progress)
  end

  ## Callbacks

  @impl true
  def init(opts) do
    state = %{
      url: opts[:url],
      destination: opts[:destination],
      checksum: opts[:checksum],
      checksum_type: opts[:checksum_type] || :sha256,
      chunk_size: opts[:chunk_size] || 65_536,
      timeout: opts[:timeout] || 300_000,
      manager: opts[:manager],
      id: opts[:id],
      status: :idle,
      file_handle: nil,
      bytes_downloaded: 0,
      content_length: nil,
      request_ref: nil,
      hash_state: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:start, state) do
    new_state = start_download_request(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:pause, %{status: :downloading} = state) do
    # Cancel current request
    if state.request_ref do
      :hackney.cancel_request(state.request_ref)
    end

    {:noreply, %{state | status: :paused, request_ref: nil}}
  end

  @impl true
  def handle_cast(:pause, state), do: {:noreply, state}

  @impl true
  def handle_cast(:resume, %{status: :paused} = state) do
    new_state = start_download_request(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:resume, state), do: {:noreply, state}

  @impl true
  def handle_call(:progress, _from, state) do
    progress = %{
      bytes_downloaded: state.bytes_downloaded,
      content_length: state.content_length,
      status: state.status,
      percentage: calculate_percentage(state)
    }

    {:reply, progress, state}
  end

  @impl true
  def handle_info({:hackney_response, ref, {:status, status_code, _reason}}, state)
      when ref == state.request_ref do
    if status_code in [200, 206] do
      {:noreply, state}
    else
      Logger.error("Download failed with status #{status_code}: #{state.url}")
      cleanup_and_fail(state, {:http_error, status_code})
    end
  end

  @impl true
  def handle_info({:hackney_response, ref, {:headers, headers}}, state)
      when ref == state.request_ref do
    content_length = get_content_length(headers)

    # Initialize hash if checksum verification is needed
    hash_state = if state.checksum do
      :crypto.hash_init(state.checksum_type)
    else
      nil
    end

    {:noreply, %{state |
      content_length: content_length,
      hash_state: hash_state
    }}
  end

  @impl true
  def handle_info({:hackney_response, ref, chunk}, state)
      when ref == state.request_ref and is_binary(chunk) do
    # Write chunk to file
    case IO.binwrite(state.file_handle, chunk) do
      :ok ->
        bytes_downloaded = state.bytes_downloaded + byte_size(chunk)

        # Update hash
        hash_state = if state.hash_state do
          :crypto.hash_update(state.hash_state, chunk)
        else
          nil
        end

        # Report progress to manager
        send(state.manager, {:download_progress, state.id, bytes_downloaded})

        {:noreply, %{state |
          bytes_downloaded: bytes_downloaded,
          hash_state: hash_state
        }}

      {:error, reason} ->
        Logger.error("Failed to write chunk: #{inspect(reason)}")
        cleanup_and_fail(state, {:write_error, reason})
    end
  end

  @impl true
  def handle_info({:hackney_response, ref, :done}, state)
      when ref == state.request_ref do
    # Download complete, verify checksum
    File.close(state.file_handle)

    result = if state.checksum && state.hash_state do
      computed = :crypto.hash_final(state.hash_state) |> Base.encode16(case: :lower)
      expected = String.downcase(state.checksum)

      if computed == expected do
        :ok
      else
        Logger.error("Checksum mismatch: expected #{expected}, got #{computed}")
        {:error, :checksum_mismatch}
      end
    else
      :ok
    end

    # Notify manager
    send(state.manager, {:download_complete, state.id, result})

    {:noreply, %{state |
      status: (if result == :ok, do: :complete, else: :failed),
      file_handle: nil,
      request_ref: nil
    }}
  end

  @impl true
  def handle_info({:hackney_response, ref, {:error, reason}}, state)
      when ref == state.request_ref do
    Logger.error("Download error: #{inspect(reason)}")
    cleanup_and_fail(state, reason)
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unexpected message in download worker: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.file_handle do
      File.close(state.file_handle)
    end
    :ok
  end

  ## Private Functions

  defp start_download_request(state) do
    # Verify VPN/SDP if required before downloading
    case HttpConfig.verify_vpn_active() do
      :ok ->
        do_start_download(state)

      {:error, :vpn_required_but_not_configured} ->
        Logger.error("VPN required but not configured - download blocked")
        send(state.manager, {:download_complete, state.id, {:error, :vpn_required}})
        %{state | status: :failed}

      {:error, {:vpn_unreachable, reason}} ->
        Logger.error("VPN unreachable: #{inspect(reason)} - download blocked")
        send(state.manager, {:download_complete, state.id, {:error, {:vpn_unreachable, reason}}})
        %{state | status: :failed}
    end
  end

  defp do_start_download(state) do
    # Validate and sanitize URL (OWASP compliance)
    case HttpConfig.sanitize_url(state.url) do
      {:ok, safe_url} ->
        do_start_download_with_url(state, safe_url)

      {:error, :https_required} ->
        Logger.error("HTTPS required - download blocked: #{state.url}")
        send(state.manager, {:download_complete, state.id, {:error, :https_required}})
        %{state | status: :failed}

      {:error, reason} ->
        Logger.error("URL validation failed: #{inspect(reason)}")
        send(state.manager, {:download_complete, state.id, {:error, {:url_invalid, reason}}})
        %{state | status: :failed}
    end
  end

  defp do_start_download_with_url(state, safe_url) do
    # Ensure destination directory exists
    destination_dir = Path.dirname(state.destination)
    File.mkdir_p!(destination_dir)

    # Open file for writing (append if resuming)
    file_opts = if state.bytes_downloaded > 0 do
      [:append, :binary]
    else
      [:write, :binary]
    end

    case File.open(state.destination, file_opts) do
      {:ok, file_handle} ->
        # Build headers with OWASP security headers + range request if resuming
        base_headers = HttpConfig.owasp_headers()

        range_headers = if state.bytes_downloaded > 0 do
          [{"Range", "bytes=#{state.bytes_downloaded}-"}]
        else
          []
        end

        # Override Accept-Encoding for downloads (need raw data for checksum)
        headers = base_headers
          |> Keyword.delete("Accept-Encoding")
          |> Kernel.++(range_headers)
          |> Kernel.++([{"Accept-Encoding", "identity"}])

        # Get OWASP security options with async mode
        options = HttpConfig.owasp_options([
          async: true,
          recv_timeout: state.timeout
        ])

        # Start async HTTP request with secure configuration
        case :hackney.request(:get, safe_url, headers, "", options) do
          {:ok, ref} ->
            %{state |
              status: :downloading,
              file_handle: file_handle,
              request_ref: ref
            }

          {:error, reason} ->
            File.close(file_handle)
            Logger.error("Failed to start download: #{inspect(reason)}")
            send(state.manager, {:download_complete, state.id, {:error, reason}})
            %{state | status: :failed}
        end

      {:error, reason} ->
        Logger.error("Failed to open file #{state.destination}: #{inspect(reason)}")
        send(state.manager, {:download_complete, state.id, {:error, {:file_error, reason}}})
        %{state | status: :failed}
    end
  end

  defp cleanup_and_fail(state, reason) do
    if state.file_handle do
      File.close(state.file_handle)
    end

    # Optionally delete partial file
    if state.bytes_downloaded > 0 and File.exists?(state.destination) do
      # Keep partial file for resume capability
      # File.rm(state.destination)
    end

    send(state.manager, {:download_complete, state.id, {:error, reason}})
    {:noreply, %{state | status: :failed, file_handle: nil, request_ref: nil}}
  end

  defp get_content_length(headers) do
    case List.keyfind(headers, "Content-Length", 0) do
      {"Content-Length", length} -> String.to_integer(length)
      _ -> nil
    end
  end

  defp calculate_percentage(%{content_length: nil}), do: nil
  defp calculate_percentage(%{content_length: 0}), do: 100.0
  defp calculate_percentage(%{bytes_downloaded: downloaded, content_length: total}) do
    Float.round(downloaded / total * 100, 1)
  end
end
