# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule AggregateLibrary.Time do
  @moduledoc """
  Universal time and duration operations.

  Best implementation chosen: Rust (best precision, no allocations)
  API design influenced by Rust's std::time (Duration, Instant)

  Provides basic time operations common across all languages:
  - Current timestamp
  - Duration creation and manipulation
  - Time arithmetic
  - Timestamp parsing and formatting
  - Unix timestamp conversion

  Policy-specific time logic (expiration checks, time windows) stays in
  language-specific stlibs (e.g., Phronesis.Stdlib.Temporal).
  """

  @type duration :: %{seconds: integer(), microseconds: integer()}

  @doc """
  Get the current UTC timestamp.

  ## Examples

      iex> AggregateLibrary.Time.now()
      ~U[2026-02-01 10:30:00.123456Z]
  """
  @spec now() :: DateTime.t()
  def now do
    DateTime.utc_now()
  end

  @doc """
  Create a duration from seconds.

  ## Examples

      iex> AggregateLibrary.Time.duration(60)
      %{seconds: 60, microseconds: 0}
  """
  @spec duration(integer()) :: duration()
  def duration(seconds) when is_integer(seconds) do
    %{seconds: seconds, microseconds: 0}
  end

  @doc """
  Create a duration from milliseconds.

  ## Examples

      iex> AggregateLibrary.Time.from_millis(1500)
      %{seconds: 1, microseconds: 500_000}
  """
  @spec from_millis(integer()) :: duration()
  def from_millis(millis) when is_integer(millis) do
    seconds = div(millis, 1000)
    microseconds = rem(millis, 1000) * 1000
    %{seconds: seconds, microseconds: microseconds}
  end

  @doc """
  Create a duration from microseconds.

  ## Examples

      iex> AggregateLibrary.Time.from_micros(1_500_000)
      %{seconds: 1, microseconds: 500_000}
  """
  @spec from_micros(integer()) :: duration()
  def from_micros(micros) when is_integer(micros) do
    seconds = div(micros, 1_000_000)
    microseconds = rem(micros, 1_000_000)
    %{seconds: seconds, microseconds: microseconds}
  end

  @doc """
  Add a duration to a datetime.

  ## Examples

      iex> dt = ~U[2026-02-01 10:00:00Z]
      iex> dur = AggregateLibrary.Time.duration(3600)
      iex> AggregateLibrary.Time.add(dt, dur)
      ~U[2026-02-01 11:00:00Z]
  """
  @spec add(DateTime.t(), duration()) :: DateTime.t()
  def add(%DateTime{} = time, %{seconds: seconds, microseconds: micros}) do
    time
    |> DateTime.add(seconds, :second)
    |> DateTime.add(micros, :microsecond)
  end

  @doc """
  Subtract a duration from a datetime.

  ## Examples

      iex> dt = ~U[2026-02-01 10:00:00Z]
      iex> dur = AggregateLibrary.Time.duration(3600)
      iex> AggregateLibrary.Time.subtract(dt, dur)
      ~U[2026-02-01 09:00:00Z]
  """
  @spec subtract(DateTime.t(), duration()) :: DateTime.t()
  def subtract(%DateTime{} = time, %{seconds: seconds, microseconds: micros}) do
    time
    |> DateTime.add(-seconds, :second)
    |> DateTime.add(-micros, :microsecond)
  end

  @doc """
  Calculate elapsed time between two datetimes.

  Returns a duration representing the difference (always positive).

  ## Examples

      iex> start = ~U[2026-02-01 10:00:00Z]
      iex> end_time = ~U[2026-02-01 11:30:00Z]
      iex> AggregateLibrary.Time.elapsed(start, end_time)
      %{seconds: 5400, microseconds: 0}
  """
  @spec elapsed(DateTime.t(), DateTime.t()) :: duration()
  def elapsed(%DateTime{} = start_time, %DateTime{} = end_time) do
    diff_micros = DateTime.diff(end_time, start_time, :microsecond)

    seconds = div(diff_micros, 1_000_000)
    microseconds = rem(diff_micros, 1_000_000)

    %{seconds: abs(seconds), microseconds: abs(microseconds)}
  end

  @doc """
  Calculate duration between two datetimes (signed).

  Returns negative duration if end_time is before start_time.

  ## Examples

      iex> start = ~U[2026-02-01 10:00:00Z]
      iex> end_time = ~U[2026-02-01 11:00:00Z]
      iex> AggregateLibrary.Time.duration_between(start, end_time)
      %{seconds: 3600, microseconds: 0}
  """
  @spec duration_between(DateTime.t(), DateTime.t()) :: duration()
  def duration_between(%DateTime{} = start_time, %DateTime{} = end_time) do
    diff_micros = DateTime.diff(end_time, start_time, :microsecond)

    seconds = div(diff_micros, 1_000_000)
    microseconds = rem(diff_micros, 1_000_000)

    %{seconds: seconds, microseconds: microseconds}
  end

  @doc """
  Parse an ISO8601 timestamp string to DateTime.

  ## Examples

      iex> AggregateLibrary.Time.parse("2026-02-01T10:00:00Z")
      {:ok, ~U[2026-02-01 10:00:00Z]}

      iex> AggregateLibrary.Time.parse("invalid")
      {:error, :invalid_format}
  """
  @spec parse(String.t()) :: {:ok, DateTime.t()} | {:error, atom()}
  def parse(timestamp_str) when is_binary(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Format a DateTime as an ISO8601 string.

  ## Examples

      iex> dt = ~U[2026-02-01 10:00:00Z]
      iex> AggregateLibrary.Time.format(dt)
      "2026-02-01T10:00:00Z"
  """
  @spec format(DateTime.t()) :: String.t()
  def format(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  @doc """
  Convert DateTime to Unix timestamp (seconds since epoch).

  ## Examples

      iex> dt = ~U[2026-02-01 10:00:00Z]
      iex> AggregateLibrary.Time.to_unix(dt)
      1738404000
  """
  @spec to_unix(DateTime.t()) :: integer()
  def to_unix(%DateTime{} = dt) do
    DateTime.to_unix(dt)
  end

  @doc """
  Convert Unix timestamp to DateTime.

  ## Examples

      iex> AggregateLibrary.Time.from_unix(1738404000)
      {:ok, ~U[2026-02-01 10:00:00Z]}
  """
  @spec from_unix(integer()) :: {:ok, DateTime.t()} | {:error, atom()}
  def from_unix(unix_timestamp) when is_integer(unix_timestamp) do
    DateTime.from_unix(unix_timestamp)
  end

  @doc """
  Convert duration to total seconds.

  ## Examples

      iex> dur = %{seconds: 90, microseconds: 500_000}
      iex> AggregateLibrary.Time.as_seconds(dur)
      90.5
  """
  @spec as_seconds(duration()) :: float()
  def as_seconds(%{seconds: seconds, microseconds: micros}) do
    seconds + micros / 1_000_000
  end

  @doc """
  Convert duration to total milliseconds.

  ## Examples

      iex> dur = %{seconds: 1, microseconds: 500_000}
      iex> AggregateLibrary.Time.as_millis(dur)
      1500
  """
  @spec as_millis(duration()) :: integer()
  def as_millis(%{seconds: seconds, microseconds: micros}) do
    seconds * 1000 + div(micros, 1000)
  end

  @doc """
  Convert duration to total microseconds.

  ## Examples

      iex> dur = %{seconds: 1, microseconds: 500_000}
      iex> AggregateLibrary.Time.as_micros(dur)
      1_500_000
  """
  @spec as_micros(duration()) :: integer()
  def as_micros(%{seconds: seconds, microseconds: micros}) do
    seconds * 1_000_000 + micros
  end

  @doc """
  Compare two datetimes.

  Returns:
  - `:lt` if time1 < time2
  - `:eq` if time1 == time2
  - `:gt` if time1 > time2

  ## Examples

      iex> dt1 = ~U[2026-02-01 10:00:00Z]
      iex> dt2 = ~U[2026-02-01 11:00:00Z]
      iex> AggregateLibrary.Time.compare(dt1, dt2)
      :lt
  """
  @spec compare(DateTime.t(), DateTime.t()) :: :lt | :eq | :gt
  def compare(%DateTime{} = time1, %DateTime{} = time2) do
    DateTime.compare(time1, time2)
  end
end
