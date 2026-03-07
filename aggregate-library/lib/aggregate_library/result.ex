# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule AggregateLibrary.Result do
  @moduledoc """
  Universal Result/Option type based on Elixir's tuple pattern.

  Provides error handling with tagged unions across all languages.
  Based on Elixir's {:ok, value} | {:error, reason} pattern (cleanest API).

  Equivalent to:
  - Rust: Result<T, E>
  - Haskell: Either a b
  """

  @type t(value, error) :: {:ok, value} | {:error, error}
  @type t(value) :: {:ok, value} | {:error, any()}

  @doc """
  Wrap a value in an :ok tuple.
  """
  @spec ok(value) :: {:ok, value} when value: any()
  def ok(value), do: {:ok, value}

  @doc """
  Wrap an error in an :error tuple.
  """
  @spec error(reason) :: {:error, reason} when reason: any()
  def error(reason), do: {:error, reason}

  @doc """
  Map a function over the value inside a Result.
  Returns error unchanged if result is an error.

  ## Examples

      iex> AggregateLibrary.Result.map({:ok, 5}, fn x -> x * 2 end)
      {:ok, 10}

      iex> AggregateLibrary.Result.map({:error, "failed"}, fn x -> x * 2 end)
      {:error, "failed"}
  """
  @spec map(t(a, e), (a -> b)) :: t(b, e) when a: any(), b: any(), e: any()
  def map({:ok, value}, f), do: {:ok, f.(value)}
  def map({:error, _} = err, _), do: err

  @doc """
  Flat-map (bind/chain) a function that returns a Result.
  Also known as bind or and_then in other languages.

  ## Examples

      iex> AggregateLibrary.Result.bind({:ok, 5}, fn x -> {:ok, x * 2} end)
      {:ok, 10}

      iex> AggregateLibrary.Result.bind({:ok, 5}, fn _ -> {:error, "failed"} end)
      {:error, "failed"}
  """
  @spec bind(t(a, e), (a -> t(b, e))) :: t(b, e) when a: any(), b: any(), e: any()
  def bind({:ok, value}, f), do: f.(value)
  def bind({:error, _} = err, _), do: err

  @doc """
  Unwrap a Result, returning the value or raising an error.
  """
  @spec unwrap!(t(value, any())) :: value when value: any()
  def unwrap!({:ok, value}), do: value
  def unwrap!({:error, reason}), do: raise("Unwrap failed: #{inspect(reason)}")

  @doc """
  Unwrap a Result with a default value if it's an error.

  ## Examples

      iex> AggregateLibrary.Result.unwrap_or({:ok, 5}, 0)
      5

      iex> AggregateLibrary.Result.unwrap_or({:error, "failed"}, 0)
      0
  """
  @spec unwrap_or(t(value, any()), value) :: value when value: any()
  def unwrap_or({:ok, value}, _default), do: value
  def unwrap_or({:error, _}, default), do: default

  @doc """
  Check if a Result is :ok.
  """
  @spec ok?(t(any(), any())) :: boolean()
  def ok?({:ok, _}), do: true
  def ok?({:error, _}), do: false

  @doc """
  Check if a Result is :error.
  """
  @spec error?(t(any(), any())) :: boolean()
  def error?({:error, _}), do: true
  def error?({:ok, _}), do: false
end
