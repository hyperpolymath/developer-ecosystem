# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.Mirror.Optimizer do
  @moduledoc """
  Mirror optimization for finding fastest package mirrors.

  Features:
  - Parallel mirror latency testing
  - Geographic proximity scoring
  - Bandwidth estimation
  - Mirror health tracking
  - Automatic mirror list generation
  - OWASP-compliant HTTP security headers
  - VPN/SDP integration for secure testing
  """

  use GenServer
  require Logger

  alias Dnfinition.Security.HttpConfig

  @default_test_count 5
  @default_test_file "/repodata/repomd.xml"
  @test_timeout 10_000  # 10 seconds
  @cache_ttl 86_400_000  # 24 hours in ms

  @type mirror_result :: %{
    url: String.t(),
    latency_ms: non_neg_integer() | nil,
    speed_kbps: float() | nil,
    available: boolean(),
    country: String.t() | nil,
    score: float(),
    last_tested: DateTime.t()
  }

  @type state :: %{
    testing: boolean(),
    results: [mirror_result()],
    test_tasks: [Task.t()]
  }

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Test all mirrors and return ranked results.
  """
  def fetch_mirrors(mirrors, opts \\ []) do
    GenServer.call(__MODULE__, {:fetch, mirrors, opts}, :infinity)
  end

  @doc """
  Get cached mirror rankings.
  """
  def get_cached_rankings do
    GenServer.call(__MODULE__, :get_cached)
  end

  @doc """
  Test a single mirror and return its score.
  """
  def test_mirror(url, opts \\ []) do
    GenServer.call(__MODULE__, {:test_one, url, opts}, @test_timeout + 5_000)
  end

  @doc """
  Get the best N mirrors from cache or by testing.
  """
  def get_best_mirrors(mirrors, count \\ 5, opts \\ []) do
    GenServer.call(__MODULE__, {:get_best, mirrors, count, opts}, :infinity)
  end

  @doc """
  Check if a mirror is currently reachable.
  """
  def ping_mirror(url) do
    GenServer.call(__MODULE__, {:ping, url}, @test_timeout)
  end

  @doc """
  Clear cached mirror rankings.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{testing: false, results: [], test_tasks: []}}
  end

  @impl true
  def handle_call({:fetch, mirrors, opts}, _from, state) do
    # Verify VPN/SDP if required before testing mirrors
    case HttpConfig.verify_vpn_active() do
      :ok ->
        test_count = opts[:test_count] || @default_test_count
        test_file = opts[:test_file] || @default_test_file

        # Start parallel testing
        results = test_mirrors_parallel(mirrors, test_file, test_count)

        # Sort by score
        ranked = Enum.sort_by(results, & &1.score, :desc)

        # Cache results
        cache_rankings(ranked)

        {:reply, {:ok, ranked}, %{state | results: ranked}}

      {:error, reason} ->
        Logger.error("VPN verification failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_cached, _from, state) do
    case get_cached_rankings_internal() do
      nil -> {:reply, {:error, :not_cached}, state}
      rankings -> {:reply, {:ok, rankings}, state}
    end
  end

  @impl true
  def handle_call({:test_one, url, opts}, _from, state) do
    test_file = opts[:test_file] || @default_test_file
    test_count = opts[:test_count] || 3

    result = test_single_mirror(url, test_file, test_count)
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:get_best, mirrors, count, opts}, _from, state) do
    # Check cache first
    case get_cached_rankings_internal() do
      nil ->
        # Need to test - verify VPN first if required
        case HttpConfig.verify_vpn_active() do
          :ok ->
            test_file = opts[:test_file] || @default_test_file
            test_count = opts[:test_count] || @default_test_count

            results = test_mirrors_parallel(mirrors, test_file, test_count)
            ranked = Enum.sort_by(results, & &1.score, :desc)
            cache_rankings(ranked)

            best = ranked
              |> Enum.filter(& &1.available)
              |> Enum.take(count)

            {:reply, {:ok, best}, %{state | results: ranked}}

          {:error, reason} ->
            Logger.error("VPN verification failed: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end

      rankings ->
        # Use cached results, filter to available mirrors
        best = rankings
          |> Enum.filter(& &1.available)
          |> Enum.take(count)

        {:reply, {:ok, best}, state}
    end
  end

  @impl true
  def handle_call({:ping, url}, _from, state) do
    result = ping_url(url)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    CubDB.delete(Dnfinition.Store.Cache, "mirror_rankings")
    {:reply, :ok, %{state | results: []}}
  end

  ## Private Functions

  defp test_mirrors_parallel(mirrors, test_file, test_count) do
    mirrors
    |> Task.async_stream(
      fn mirror_url -> test_single_mirror(mirror_url, test_file, test_count) end,
      max_concurrency: 10,
      timeout: @test_timeout * test_count,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, _reason} -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp test_single_mirror(base_url, test_file, test_count) do
    test_url = String.trim_trailing(base_url, "/") <> test_file

    latencies = for _ <- 1..test_count do
      case measure_latency(test_url) do
        {:ok, latency, _size} -> latency
        {:error, _} -> nil
      end
    end
    |> Enum.reject(&is_nil/1)

    if length(latencies) > 0 do
      avg_latency = Enum.sum(latencies) / length(latencies)
      min_latency = Enum.min(latencies)

      # Also measure download speed
      speed_kbps = case measure_speed(test_url) do
        {:ok, kbps} -> kbps
        {:error, _} -> 0.0
      end

      # Calculate score (higher is better)
      # Score = (1000 / latency_ms) * speed_factor
      speed_factor = :math.log(speed_kbps + 1) / 10 + 1
      score = (1000.0 / avg_latency) * speed_factor

      %{
        url: base_url,
        latency_ms: round(avg_latency),
        min_latency_ms: round(min_latency),
        speed_kbps: Float.round(speed_kbps, 1),
        available: true,
        country: extract_country(base_url),
        score: Float.round(score, 2),
        last_tested: DateTime.utc_now(),
        success_rate: length(latencies) / test_count
      }
    else
      %{
        url: base_url,
        latency_ms: nil,
        min_latency_ms: nil,
        speed_kbps: nil,
        available: false,
        country: extract_country(base_url),
        score: 0.0,
        last_tested: DateTime.utc_now(),
        success_rate: 0.0
      }
    end
  end

  defp measure_latency(url) do
    # Validate URL for OWASP compliance
    case HttpConfig.sanitize_url(url) do
      {:ok, safe_url} ->
        do_measure_latency(safe_url)

      {:error, reason} ->
        Logger.warning("URL validation failed for latency test: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_measure_latency(url) do
    start_time = System.monotonic_time(:millisecond)

    # Use OWASP-compliant options
    options = HttpConfig.owasp_options([
      recv_timeout: @test_timeout,
      connect_timeout: 5_000
    ])

    headers = HttpConfig.owasp_headers()

    case :hackney.request(:head, url, headers, "", options) do
      {:ok, status, _headers, _ref} when status in [200, 206, 301, 302] ->
        latency = System.monotonic_time(:millisecond) - start_time
        {:ok, latency, 0}

      {:ok, _status, _headers, _ref} ->
        {:error, :bad_status}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp measure_speed(url) do
    # Validate URL for OWASP compliance
    case HttpConfig.sanitize_url(url) do
      {:ok, safe_url} ->
        do_measure_speed(safe_url)

      {:error, reason} ->
        Logger.warning("URL validation failed for speed test: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_measure_speed(url) do
    start_time = System.monotonic_time(:millisecond)

    # Use OWASP-compliant options
    options = HttpConfig.owasp_options([
      recv_timeout: @test_timeout,
      connect_timeout: 5_000
    ])

    headers = HttpConfig.owasp_headers()

    case :hackney.request(:get, url, headers, "", options) do
      {:ok, status, response_headers, ref} when status in [200, 206] ->
        # Validate response headers for security issues
        HttpConfig.validate_response_headers(response_headers)

        case :hackney.body(ref) do
          {:ok, body} ->
            duration_ms = System.monotonic_time(:millisecond) - start_time
            size_kb = byte_size(body) / 1024

            if duration_ms > 0 do
              speed_kbps = size_kb / (duration_ms / 1000)
              {:ok, speed_kbps}
            else
              {:ok, 0.0}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, _status, _headers, ref} ->
        :hackney.skip_body(ref)
        {:error, :bad_status}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ping_url(url) do
    # Validate URL for OWASP compliance
    case HttpConfig.sanitize_url(url) do
      {:ok, safe_url} ->
        do_ping_url(safe_url)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_ping_url(url) do
    # Use OWASP-compliant options with shorter timeouts for ping
    options = HttpConfig.owasp_options([
      recv_timeout: 5_000,
      connect_timeout: 3_000
    ])

    headers = HttpConfig.owasp_headers()

    case :hackney.request(:head, url, headers, "", options) do
      {:ok, status, _headers, _ref} when status in [200, 206, 301, 302] ->
        {:ok, :reachable}

      {:ok, status, _headers, _ref} ->
        {:ok, {:unreachable, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_country(url) do
    # Try to extract country from URL patterns
    # Common patterns: .de., .us., .uk., etc.
    uri = URI.parse(url)

    cond do
      String.contains?(uri.host || "", ".de.") or String.ends_with?(uri.host || "", ".de") ->
        "DE"
      String.contains?(uri.host || "", ".us.") or String.ends_with?(uri.host || "", ".us") ->
        "US"
      String.contains?(uri.host || "", ".uk.") or String.ends_with?(uri.host || "", ".uk") ->
        "UK"
      String.contains?(uri.host || "", ".fr.") or String.ends_with?(uri.host || "", ".fr") ->
        "FR"
      String.contains?(uri.host || "", ".nl.") or String.ends_with?(uri.host || "", ".nl") ->
        "NL"
      String.contains?(uri.host || "", ".se.") or String.ends_with?(uri.host || "", ".se") ->
        "SE"
      String.contains?(uri.host || "", ".jp.") or String.ends_with?(uri.host || "", ".jp") ->
        "JP"
      String.contains?(uri.host || "", ".au.") or String.ends_with?(uri.host || "", ".au") ->
        "AU"
      String.contains?(uri.host || "", ".ca.") or String.ends_with?(uri.host || "", ".ca") ->
        "CA"
      true ->
        nil
    end
  end

  defp cache_rankings(rankings) do
    CubDB.put(Dnfinition.Store.Cache, "mirror_rankings", %{
      rankings: rankings,
      cached_at: DateTime.utc_now()
    })
  end

  defp get_cached_rankings_internal do
    case CubDB.get(Dnfinition.Store.Cache, "mirror_rankings") do
      nil ->
        nil

      %{rankings: rankings, cached_at: cached_at} ->
        age_ms = DateTime.diff(DateTime.utc_now(), cached_at, :millisecond)

        if age_ms < @cache_ttl do
          rankings
        else
          nil  # Cache expired
        end
    end
  end
end
