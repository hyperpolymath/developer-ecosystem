# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.Token do
  @moduledoc """
  Generic token representation for lexers.

  Used by: Lexer, Parser, LSP, Formatter

  ## Example

      token = ALib.Token.new(:identifier, "hello", 1, 5)
      %ALib.Token{type: :identifier, value: "hello", line: 1, column: 5}
  """

  @type t :: %__MODULE__{
          type: atom(),
          value: any(),
          line: pos_integer(),
          column: pos_integer()
        }

  defstruct [:type, :value, :line, :column]

  @doc """
  Create a new token.

  ## Parameters

  - `type` - Token type (atom, e.g., :identifier, :string, :integer)
  - `value` - Token value (any)
  - `line` - Line number (1-indexed)
  - `column` - Column number (1-indexed)
  """
  @spec new(atom(), any(), pos_integer(), pos_integer()) :: t()
  def new(type, value, line, column) do
    %__MODULE__{
      type: type,
      value: value,
      line: line,
      column: column
    }
  end

  @doc """
  Get source position of token.
  """
  @spec position(t()) :: ALib.Position.t()
  def position(%__MODULE__{line: line, column: column}) do
    ALib.Position.new(line, column)
  end
end
