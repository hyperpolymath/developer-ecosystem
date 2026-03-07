# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule AggregateLibrary.Stream do
  @moduledoc """
  Universal lazy iteration operations.

  Provides lazy (streaming) versions of collection operations.
  Based on Elixir's Stream module with influences from:
  - Rust: Iterator trait (lazy by default)
  - Haskell: Lists are lazy by default

  Streams are composable and only evaluate when consumed.
  """

  @doc """
  Map a function over a stream lazily.

  ## Examples

      iex> [1, 2, 3]
      ...> |> AggregateLibrary.Stream.map(fn x -> x * 2 end)
      ...> |> Enum.to_list()
      [2, 4, 6]
  """
  @spec map(Enumerable.t(), (a -> b)) :: Enumerable.t() when a: any(), b: any()
  defdelegate map(stream, f), to: Stream

  @doc """
  Filter a stream lazily by a predicate.

  ## Examples

      iex> [1, 2, 3, 4]
      ...> |> AggregateLibrary.Stream.filter(fn x -> rem(x, 2) == 0 end)
      ...> |> Enum.to_list()
      [2, 4]
  """
  @spec filter(Enumerable.t(), (any() -> boolean())) :: Enumerable.t()
  defdelegate filter(stream, pred), to: Stream

  @doc """
  Take the first n elements from a stream.

  ## Examples

      iex> Stream.cycle([1, 2, 3])
      ...> |> AggregateLibrary.Stream.take(5)
      ...> |> Enum.to_list()
      [1, 2, 3, 1, 2]
  """
  @spec take(Enumerable.t(), non_neg_integer()) :: Enumerable.t()
  defdelegate take(stream, n), to: Stream

  @doc """
  Drop the first n elements from a stream.

  ## Examples

      iex> [1, 2, 3, 4, 5]
      ...> |> AggregateLibrary.Stream.drop(2)
      ...> |> Enum.to_list()
      [3, 4, 5]
  """
  @spec drop(Enumerable.t(), non_neg_integer()) :: Enumerable.t()
  defdelegate drop(stream, n), to: Stream

  @doc """
  Take elements while a predicate is true.

  ## Examples

      iex> [1, 2, 3, 4, 1]
      ...> |> AggregateLibrary.Stream.take_while(fn x -> x < 4 end)
      ...> |> Enum.to_list()
      [1, 2, 3]
  """
  @spec take_while(Enumerable.t(), (any() -> boolean())) :: Enumerable.t()
  defdelegate take_while(stream, pred), to: Stream

  @doc """
  Drop elements while a predicate is true.

  ## Examples

      iex> [1, 2, 3, 4, 5]
      ...> |> AggregateLibrary.Stream.drop_while(fn x -> x < 3 end)
      ...> |> Enum.to_list()
      [3, 4, 5]
  """
  @spec drop_while(Enumerable.t(), (any() -> boolean())) :: Enumerable.t()
  defdelegate drop_while(stream, pred), to: Stream

  @doc """
  Concatenate two streams.

  ## Examples

      iex> AggregateLibrary.Stream.concat([1, 2], [3, 4])
      ...> |> Enum.to_list()
      [1, 2, 3, 4]
  """
  @spec concat(Enumerable.t(), Enumerable.t()) :: Enumerable.t()
  defdelegate concat(stream1, stream2), to: Stream

  @doc """
  Flat-map a function over a stream (map + flatten).

  ## Examples

      iex> [1, 2, 3]
      ...> |> AggregateLibrary.Stream.flat_map(fn x -> [x, x * 2] end)
      ...> |> Enum.to_list()
      [1, 2, 2, 4, 3, 6]
  """
  @spec flat_map(Enumerable.t(), (a -> Enumerable.t())) :: Enumerable.t() when a: any()
  defdelegate flat_map(stream, f), to: Stream

  @doc """
  Chunk a stream into groups of n elements.

  ## Examples

      iex> [1, 2, 3, 4, 5, 6]
      ...> |> AggregateLibrary.Stream.chunk_every(2)
      ...> |> Enum.to_list()
      [[1, 2], [3, 4], [5, 6]]
  """
  @spec chunk_every(Enumerable.t(), pos_integer()) :: Enumerable.t()
  defdelegate chunk_every(stream, n), to: Stream

  @doc """
  Create an infinite stream by repeatedly applying a function.

  ## Examples

      iex> AggregateLibrary.Stream.iterate(1, fn x -> x * 2 end)
      ...> |> AggregateLibrary.Stream.take(5)
      ...> |> Enum.to_list()
      [1, 2, 4, 8, 16]
  """
  @spec iterate(a, (a -> a)) :: Enumerable.t() when a: any()
  defdelegate iterate(start, f), to: Stream

  @doc """
  Create an infinite stream by cycling through a collection.

  ## Examples

      iex> AggregateLibrary.Stream.cycle([1, 2, 3])
      ...> |> AggregateLibrary.Stream.take(7)
      ...> |> Enum.to_list()
      [1, 2, 3, 1, 2, 3, 1]
  """
  @spec cycle(Enumerable.t()) :: Enumerable.t()
  defdelegate cycle(collection), to: Stream

  @doc """
  Create an infinite stream of repeated values.

  ## Examples

      iex> AggregateLibrary.Stream.repeatedly(fn -> :rand.uniform(10) end)
      ...> |> AggregateLibrary.Stream.take(3)
      ...> |> Enum.to_list()
      [7, 3, 9]  # Random values
  """
  @spec repeatedly((() -> any())) :: Enumerable.t()
  defdelegate repeatedly(f), to: Stream

  @doc """
  Reduce a stream to a single value.

  ## Examples

      iex> [1, 2, 3, 4]
      ...> |> AggregateLibrary.Stream.map(fn x -> x * 2 end)
      ...> |> AggregateLibrary.Stream.reduce(0, fn x, acc -> x + acc end)
      20
  """
  @spec reduce(Enumerable.t(), acc, (element, acc -> acc)) :: acc
        when element: any(), acc: any()
  def reduce(stream, init, f) do
    Enum.reduce(stream, init, f)
  end

  @doc """
  Convert a stream to a list (forces evaluation).

  ## Examples

      iex> Stream.cycle([1, 2])
      ...> |> AggregateLibrary.Stream.take(4)
      ...> |> AggregateLibrary.Stream.to_list()
      [1, 2, 1, 2]
  """
  @spec to_list(Enumerable.t()) :: [any()]
  def to_list(stream), do: Enum.to_list(stream)
end
