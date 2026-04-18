defmodule ShellState.MixProject do
  use Mix.Project

  def project do
    [
      app: :shellstate,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript_config()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:toml_elixir, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:ex_machina, "~> 2.4", only: :test},
      {:stream_data, "~> 0.5", only: :test}
    ]
  end

  defp escript_config do
    [
      main_module: ShellState.CLI
    ]
  end
end