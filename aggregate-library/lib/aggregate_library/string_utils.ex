# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.StringUtils do
  @moduledoc """
  String manipulation utilities for compiler/toolchain components.

  Used by: Lexer, Formatter, Diagnostics

  Includes:
  - Levenshtein distance for "did you mean" suggestions
  - Text indentation and wrapping
  - Whitespace normalization
  """

  @doc """
  Calculate Levenshtein distance between two strings.

  Used for "did you mean" suggestions in error messages.

  ## Example

      iex> ALib.StringUtils.levenshtein_distance("kitten", "sitting")
      3
  """
  @spec levenshtein_distance(String.t(), String.t()) :: non_neg_integer()
  def levenshtein_distance(s1, s2) do
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)
    levenshtein_distance_impl(s1_chars, s2_chars)
  end

  defp levenshtein_distance_impl(s1, s2) when length(s1) == 0, do: length(s2)
  defp levenshtein_distance_impl(s1, s2) when length(s2) == 0, do: length(s1)

  defp levenshtein_distance_impl([h | t1], [h | t2]) do
    levenshtein_distance_impl(t1, t2)
  end

  defp levenshtein_distance_impl([_ | t1] = s1, [_ | t2] = s2) do
    1 +
      min(
        levenshtein_distance_impl(t1, s2),
        min(
          levenshtein_distance_impl(s1, t2),
          levenshtein_distance_impl(t1, t2)
        )
      )
  end

  @doc """
  Find closest match from a list of candidates.

  Returns `{:ok, match}` if a close match is found, `:error` otherwise.

  ## Example

      iex> ALib.StringUtils.closest_match("polixy", ["policy", "priority", "export"])
      {:ok, "policy"}
  """
  @spec closest_match(String.t(), [String.t()], non_neg_integer()) :: {:ok, String.t()} | :error
  def closest_match(target, candidates, max_distance \\ 3) do
    candidates
    |> Enum.map(&{&1, levenshtein_distance(target, &1)})
    |> Enum.filter(fn {_, dist} -> dist <= max_distance end)
    |> Enum.min_by(fn {_, dist} -> dist end, fn -> nil end)
    |> case do
      {match, _} -> {:ok, match}
      nil -> :error
    end
  end

  @doc """
  Indent each line of text by N spaces.

  ## Example

      iex> ALib.StringUtils.indent("hello\\nworld", 2)
      "  hello\\n  world"
  """
  @spec indent(String.t(), non_neg_integer()) :: String.t()
  def indent(text, spaces) do
    prefix = String.duplicate(" ", spaces)

    text
    |> String.split("\n")
    |> Enum.map(&(prefix <> &1))
    |> Enum.join("\n")
  end

  @doc """
  Wrap text at specified column width.

  ## Example

      iex> ALib.StringUtils.wrap_at("hello world foo bar", 10)
      "hello\\nworld foo\\nbar"
  """
  @spec wrap_at(String.t(), pos_integer()) :: String.t()
  def wrap_at(text, width) do
    words = String.split(text)
    wrap_words(words, width, "", [])
  end

  defp wrap_words([], _width, current_line, lines) do
    (lines ++ [current_line])
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp wrap_words([word | rest], width, "", lines) do
    wrap_words(rest, width, word, lines)
  end

  defp wrap_words([word | rest], width, current_line, lines) do
    if String.length(current_line) + 1 + String.length(word) <= width do
      wrap_words(rest, width, current_line <> " " <> word, lines)
    else
      wrap_words(rest, width, word, lines ++ [current_line])
    end
  end

  @doc """
  Remove trailing whitespace from each line.
  """
  @spec trim_trailing(String.t()) :: String.t()
  def trim_trailing(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
  end
end
