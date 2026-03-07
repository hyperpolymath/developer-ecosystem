# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule AggregateLibrary do
  @moduledoc """
  Universal utilities extracted from the intersection of Phronesis, Rust, and Haskell stlibs.

  aggregate-library provides best-of-breed implementations of common patterns
  found across all three language stlibs, creating a leaner library with no duplication.

  ## Formula

      aggregate-library = (common elements of phronesis stdlib ∩ Rust stdlib ∩ Haskell stdlib)
                        ∪ (compiler utilities)

  ## Universal Modules (Best-of-Breed)

  - `AggregateLibrary.Result` - Result/Option types (Elixir-style, cleanest API)
  - `AggregateLibrary.Collections` - Map/filter/reduce (Haskell-style, most elegant)
  - `AggregateLibrary.FileIO` - File I/O (Elixir-style, best Result handling)
  - `AggregateLibrary.Stream` - Lazy iteration (cross-language patterns)
  - `AggregateLibrary.Time` - Time/duration (Rust-style precision)

  ## Compiler Utilities (Language-Agnostic)

  - `ALib.Token` - Generic token representation
  - `ALib.Position` - Source location tracking
  - `ALib.Error` - Error representation
  - `ALib.AST.Traversal` - AST tree walking utilities
  - `ALib.StringUtils` - String manipulation (Levenshtein, indent, wrap)
  - `ALib.ColorOutput` - ANSI terminal colors

  ## What Stays in Language Stlibs

  **Phronesis:** Std.Consensus, Std.BGP, Std.RPKI, policy-specific temporal logic
  **Rust:** Ownership/borrowing, unsafe, platform-specific APIs
  **Haskell:** Monad transformers, type-level programming, lazy evaluation

  ## Philosophy

  1. **Universal patterns only** - Must exist across all three language stlibs
  2. **Best-of-breed selection** - Choose the best implementation for each pattern
  3. **Leaner library** - No duplication, single source of truth
  4. **Fallback ready** - Can revert to language stdlib if abstraction doesn't work
  """

  @doc """
  Get aggregate-library version.
  """
  def version, do: Mix.Project.config()[:version]
end
