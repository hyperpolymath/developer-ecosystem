# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.Position do
  @moduledoc """
  Source location tracking for compiler errors and diagnostics.

  Used by: Lexer, Parser, Diagnostics, LSP

  ## Example

      pos = ALib.Position.new(10, 25)
      pos = ALib.Position.advance_col(pos, 5)  # {10, 30}
      pos = ALib.Position.advance_line(pos)     # {11, 1}
  """

  @type t :: %__MODULE__{
          line: pos_integer(),
          column: pos_integer()
        }

  defstruct [:line, :column]

  @doc """
  Create a new position.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(line, column) do
    %__MODULE__{line: line, column: column}
  end

  @doc """
  Advance to next line (reset column to 1).
  """
  @spec advance_line(t()) :: t()
  def advance_line(%__MODULE__{line: line}) do
    %__MODULE__{line: line + 1, column: 1}
  end

  @doc """
  Advance column by N characters.
  """
  @spec advance_col(t(), pos_integer()) :: t()
  def advance_col(%__MODULE__{line: line, column: col}, n) do
    %__MODULE__{line: line, column: col + n}
  end

  @doc """
  Format position as "line:column".
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{line: line, column: column}) do
    "#{line}:#{column}"
  end
end
