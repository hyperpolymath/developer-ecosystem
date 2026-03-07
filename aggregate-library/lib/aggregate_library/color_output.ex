# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.ColorOutput do
  @moduledoc """
  ANSI terminal color output utilities.

  Used by: Diagnostics, CLI, Test Framework

  ## Example

      ALib.ColorOutput.red("error: something went wrong")
      ALib.ColorOutput.green("success: all tests passed")
  """

  @doc """
  Colorize text in red.
  """
  @spec red(String.t()) :: String.t()
  def red(text), do: "\e[31m#{text}\e[0m"

  @doc """
  Colorize text in green.
  """
  @spec green(String.t()) :: String.t()
  def green(text), do: "\e[32m#{text}\e[0m"

  @doc """
  Colorize text in yellow.
  """
  @spec yellow(String.t()) :: String.t()
  def yellow(text), do: "\e[33m#{text}\e[0m"

  @doc """
  Colorize text in blue.
  """
  @spec blue(String.t()) :: String.t()
  def blue(text), do: "\e[34m#{text}\e[0m"

  @doc """
  Make text bold.
  """
  @spec bold(String.t()) :: String.t()
  def bold(text), do: "\e[1m#{text}\e[0m"

  @doc """
  Make text dim.
  """
  @spec dim(String.t()) :: String.t()
  def dim(text), do: "\e[2m#{text}\e[0m"

  @doc """
  Colorize text with arbitrary color.

  ## Colors

  - `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`

  ## Options

  - `:bold` - Make text bold
  - `:dim` - Make text dim
  """
  @spec colorize(String.t(), atom(), keyword()) :: String.t()
  def colorize(text, color, opts \\ []) do
    codes =
      [color_code(color)] ++
        (if Keyword.get(opts, :bold), do: ["\e[1m"], else: []) ++
        (if Keyword.get(opts, :dim), do: ["\e[2m"], else: [])

    Enum.join(codes) <> text <> "\e[0m"
  end

  defp color_code(:red), do: "\e[31m"
  defp color_code(:green), do: "\e[32m"
  defp color_code(:yellow), do: "\e[33m"
  defp color_code(:blue), do: "\e[34m"
  defp color_code(:magenta), do: "\e[35m"
  defp color_code(:cyan), do: "\e[36m"
  defp color_code(:white), do: "\e[37m"
  defp color_code(_), do: ""

  @doc """
  Strip ANSI color codes from text.
  """
  @spec strip_colors(String.t()) :: String.t()
  def strip_colors(text) do
    String.replace(text, ~r/\e\[[0-9;]*m/, "")
  end
end
