# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule AggregateLibrary.Collections do
  @moduledoc """
  Universal collection operations based on Haskell's elegant composable API.

  Provides both point-free (functional composition) and direct (Elixir-style) APIs.

  Best implementation chosen: Haskell (cleanest API, most elegant composability)
  """

  @doc """
  Map a function over a collection (point-free style).
  Returns a function that takes a collection.

  ## Examples

      iex> double = AggregateLibrary.Collections.map(fn x -> x * 2 end)
      iex> double.([1, 2, 3])
      [2, 4, 6]
  """
  @spec map((a -> b)) :: ([a] -> [b]) when a: any(), b: any()
  def map(f), do: fn coll -> Enum.map(coll, f) end

  @doc """
  Map a function over a collection (direct style).

  ## Examples

      iex> AggregateLibrary.Collections.map([1, 2, 3], fn x -> x * 2 end)
      [2, 4, 6]
  """
  @spec map(Enum.t(), (a -> b)) :: [b] when a: any(), b: any()
  def map(coll, f), do: Enum.map(coll, f)

  @doc """
  Filter a collection by a predicate (point-free style).
  Returns a function that takes a collection.

  ## Examples

      iex> evens = AggregateLibrary.Collections.filter(fn x -> rem(x, 2) == 0 end)
      iex> evens.([1, 2, 3, 4])
      [2, 4]
  """
  @spec filter((a -> boolean())) :: ([a] -> [a]) when a: any()
  def filter(pred), do: fn coll -> Enum.filter(coll, pred) end

  @doc """
  Filter a collection by a predicate (direct style).

  ## Examples

      iex> AggregateLibrary.Collections.filter([1, 2, 3, 4], fn x -> rem(x, 2) == 0 end)
      [2, 4]
  """
  @spec filter(Enum.t(), (a -> boolean())) :: [a] when a: any()
  def filter(coll, pred), do: Enum.filter(coll, pred)

  @doc """
  Reduce a collection to a single value (point-free style).
  Returns a function that takes a collection.

  ## Examples

      iex> sum = AggregateLibrary.Collections.reduce(fn x, acc -> x + acc end, 0)
      iex> sum.([1, 2, 3, 4])
      10
  """
  @spec reduce((a, b -> b), b) :: ([a] -> b) when a: any(), b: any()
  def reduce(f, init), do: fn coll -> Enum.reduce(coll, init, f) end

  @doc """
  Reduce a collection to a single value (direct style).

  ## Examples

      iex> AggregateLibrary.Collections.reduce([1, 2, 3, 4], 0, fn x, acc -> x + acc end)
      10
  """
  @spec reduce(Enum.t(), acc, (element, acc -> acc)) :: acc
        when element: any(), acc: any()
  def reduce(coll, init, f), do: Enum.reduce(coll, init, f)

  @doc """
  Fold left (alias for reduce for Haskell compatibility).
  """
  @spec foldl(Enum.t(), acc, (element, acc -> acc)) :: acc
        when element: any(), acc: any()
  def foldl(coll, init, f), do: reduce(coll, init, f)

  @doc """
  Take the first n elements from a collection.

  ## Examples

      iex> AggregateLibrary.Collections.take([1, 2, 3, 4, 5], 3)
      [1, 2, 3]
  """
  @spec take(Enum.t(), non_neg_integer()) :: [any()]
  def take(coll, n), do: Enum.take(coll, n)

  @doc """
  Drop the first n elements from a collection.

  ## Examples

      iex> AggregateLibrary.Collections.drop([1, 2, 3, 4, 5], 2)
      [3, 4, 5]
  """
  @spec drop(Enum.t(), non_neg_integer()) :: [any()]
  def drop(coll, n), do: Enum.drop(coll, n)

  @doc """
  Concatenate two collections.

  ## Examples

      iex> AggregateLibrary.Collections.concat([1, 2], [3, 4])
      [1, 2, 3, 4]
  """
  @spec concat(Enum.t(), Enum.t()) :: [any()]
  def concat(coll1, coll2), do: Enum.concat(coll1, coll2)

  @doc """
  Reverse a collection.

  ## Examples

      iex> AggregateLibrary.Collections.reverse([1, 2, 3])
      [3, 2, 1]
  """
  @spec reverse(Enum.t()) :: [any()]
  def reverse(coll), do: Enum.reverse(coll)

  @doc """
  Get the length of a collection.

  ## Examples

      iex> AggregateLibrary.Collections.length([1, 2, 3])
      3
  """
  @spec length(Enum.t()) :: non_neg_integer()
  def length(coll), do: Enum.count(coll)

  @doc """
  Check if a collection is empty.

  ## Examples

      iex> AggregateLibrary.Collections.empty?([])
      true

      iex> AggregateLibrary.Collections.empty?([1, 2, 3])
      false
  """
  @spec empty?(Enum.t()) :: boolean()
  def empty?(coll), do: Enum.empty?(coll)

  @doc """
  Find the first element matching a predicate.

  ## Examples

      iex> AggregateLibrary.Collections.find([1, 2, 3, 4], fn x -> x > 2 end)
      {:ok, 3}

      iex> AggregateLibrary.Collections.find([1, 2], fn x -> x > 5 end)
      {:error, :not_found}
  """
  @spec find(Enum.t(), (any() -> boolean())) :: {:ok, any()} | {:error, :not_found}
  def find(coll, pred) do
    case Enum.find(coll, pred) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @doc """
  Check if all elements satisfy a predicate.

  ## Examples

      iex> AggregateLibrary.Collections.all?([2, 4, 6], fn x -> rem(x, 2) == 0 end)
      true

      iex> AggregateLibrary.Collections.all?([2, 3, 4], fn x -> rem(x, 2) == 0 end)
      false
  """
  @spec all?(Enum.t(), (any() -> boolean())) :: boolean()
  def all?(coll, pred), do: Enum.all?(coll, pred)

  @doc """
  Check if any element satisfies a predicate.

  ## Examples

      iex> AggregateLibrary.Collections.any?([1, 2, 3], fn x -> x > 2 end)
      true

      iex> AggregateLibrary.Collections.any?([1, 2], fn x -> x > 5 end)
      false
  """
  @spec any?(Enum.t(), (any() -> boolean())) :: boolean()
  def any?(coll, pred), do: Enum.any?(coll, pred)
end
