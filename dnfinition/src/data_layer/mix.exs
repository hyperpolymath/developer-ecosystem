# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule Dnfinition.DataLayer.MixProject do
  use Mix.Project

  def project do
    [
      app: :dnfinition_data,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Dnfinition.DataLayer.Application, []}
    ]
  end

  defp deps do
    [
      {:cubdb, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:erlexec, "~> 2.0"},  # For Ada process communication
      {:telemetry, "~> 1.2"},
      {:hackney, "~> 1.20"}  # HTTP client for parallel downloads
    ]
  end

  defp escript do
    [
      main_module: Dnfinition.DataLayer.CLI,
      name: "dnfinition_data"
    ]
  end

  defp releases do
    [
      dnfinition_data: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
