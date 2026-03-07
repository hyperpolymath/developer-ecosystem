# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

defmodule ALib.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hyperpolymath/aggregate-library"

  def project do
    [
      app: :a_lib,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp description do
    """
    aLib: Common compiler utilities for hyperpolymath language toolchains.

    Provides generic data structures (Token, Position, Error) and utilities
    (AST traversal, string manipulation, color output) used across compiler
    pipelines.
    """
  end

  defp package do
    [
      name: "a_lib",
      licenses: ["PMPL-1.0-or-later"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "ALib",
      source_url: @source_url,
      extras: ["README.adoc"]
    ]
  end
end
