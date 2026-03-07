# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.Error do
  @moduledoc """
  Generic error representation for compiler/toolchain components.

  Used by: Lexer, Parser, Compiler, Interpreter, Linter, Analyzer

  ## Example

      error = ALib.Error.new(
        :parse_error,
        "unexpected token",
        ALib.Position.new(5, 12),
        severity: :error,
        code: "E0042"
      )
  """

  @type severity :: :error | :warning | :info
  @type error_type :: :lexer_error | :parse_error | :runtime_error | :lint_error | :analysis_error

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          position: ALib.Position.t() | nil,
          severity: severity(),
          code: String.t() | nil
        }

  defstruct [:type, :message, :position, :severity, :code]

  @doc """
  Create a new error.

  ## Options

  - `:severity` - Error severity (default: :error)
  - `:code` - Error code for documentation lookup (e.g., "E0001")
  """
  @spec new(error_type(), String.t(), ALib.Position.t() | nil, keyword()) :: t()
  def new(type, message, position \\ nil, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      position: position,
      severity: Keyword.get(opts, :severity, :error),
      code: Keyword.get(opts, :code)
    }
  end

  @doc """
  Format error as human-readable string.

  ## Example

      "error[E0042]: unexpected token at 5:12"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = error) do
    severity_str = to_string(error.severity)
    code_str = if error.code, do: "[#{error.code}]", else: ""
    pos_str = if error.position, do: " at #{ALib.Position.format(error.position)}", else: ""

    "#{severity_str}#{code_str}: #{error.message}#{pos_str}"
  end
end
