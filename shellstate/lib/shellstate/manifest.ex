defmodule ShellState.Manifest do
  @moduledoc """
  TOML Manifest parsing, validation, and serialization for ShellState.
  
  This module implements the canonical manifest structure as specified in the
  ShellState design document, with strict validation and normalization.
  """
  
  @enforce_keys [:version, :name, :profile]
  # Validation constants (used in validation functions)
  @valid_shell "bash"
  @valid_bash_mode "source-snippet"

  defstruct [
    :version,
    :name,
    :profile,
    meta: %{},
    policy: %{},
    paths: %{entries: []},
    env: %{},
    secrets: %{},
    integrations: %{bash: %{}},
    generation: %{},
    generation_validation: %{}
  ]

  @type t :: %__MODULE__{}

  @spec load(String.t()) :: {:ok, t} | {:error, String.t()}
  def load(path) do
    with {:ok, parsed} <- TOML.parse_file(path),
         {:ok, validated} <- validate(parsed),
         {:ok, struct} <- struct(validated) do
      {:ok, struct}
    else
      error -> error
    end
  end

  @spec to_toml(t) :: {:ok, String.t()} | {:error, String.t()}
  def to_toml(manifest) do
    try do
      toml = """
version = #{manifest.version}
name = "#{manifest.name}"
profile = "#{manifest.profile}"

[meta]
description = "#{manifest.meta.description || ""}"
owner = "#{manifest.meta.owner || ""}"
shell = "#{manifest.meta.shell || @valid_shell}"

[policy]
auto_write = #{manifest.policy.auto_write || false}
require_explicit_commit = #{manifest.policy.require_explicit_commit || true}
keep_previous = #{manifest.policy.keep_previous || true}
allow_plaintext_secrets = #{manifest.policy.allow_plaintext_secrets || false}

[[paths.entries]]
"""
      <> Enum.map(manifest.paths.entries, fn entry ->
        """
name = "#{entry.name}"
value = "#{entry.value}"
position = "#{entry.position}"
enabled = #{entry.enabled}
region = "#{entry.region}"
"""
      end)
      |> Enum.join("
")
      
      env_toml = manifest.env
      |> Enum.map(fn {name, config} ->
        """
[env.\"#{name}\"]
value = "#{config.value}"
type = "#{config.type}"
region = "#{config.region}"
export = #{config.export}
secret = #{config.secret}
enabled = #{config.enabled}
"""
      end)
      |> Enum.join("
")

      secrets_toml = manifest.secrets
      |> Enum.map(fn {name, config} ->
        """
[secrets.\"#{name}\"]
ref = "#{config.ref}"
type = "#{config.type}"
region = "#{config.region}"
exposure = "#{config.exposure}"
required = #{config.required}
enabled = #{config.enabled}
"""
      end)
      |> Enum.join("
")

      bash_integration = manifest.integrations.bash
      bash_toml = """
[integrations.bash]
enabled = #{bash_integration.enabled || false}
mode = "#{bash_integration.mode || @valid_bash_mode}"
target = "#{bash_integration.target || "~/.bashrc"}"
"""

      generation_toml = """
[generation]
render_paths = #{manifest.generation.render_paths || true}
render_env = #{manifest.generation.render_env || true}
render_wrappers = #{manifest.generation.render_wrappers || false}
render_aliases = #{manifest.generation.render_aliases || false}

[generation.validation]
bash_syntax_check = #{manifest.generation_validation.bash_syntax_check || true}
"""

      {:ok, toml <> env_toml <> secrets_toml <> bash_toml <> generation_toml}
    rescue
      error -> {:error, "TOML serialization failed: #{inspect(error)}"}
    end
  end

  defp validate(%{
    version: version,
    name: name,
    profile: profile,
    meta: %{shell: shell},
    policy: policy,
    env: env,
    secrets: secrets
  }) when is_integer(version) and is_binary(name) and is_binary(profile) do
    with :ok <- validate_shell(shell),
         :ok <- validate_policy(policy),
         :ok <- validate_env(env),
         :ok <- validate_secrets(secrets) do
      :ok
    end
  end

  defp validate(_), do: {:error, "Invalid manifest structure"}

  defp validate_shell(@valid_shell), do: :ok
  defp validate_shell(_), do: {:error, "Only bash supported in v1"}

  defp validate_policy(%{
    auto_write: false,
    require_explicit_commit: true,
    keep_previous: true,
    allow_plaintext_secrets: false
  }), do: :ok
  defp validate_policy(_), do: {:error, "Invalid policy settings"}

  defp validate_env(env) do
    Enum.each(env, fn {_name, %{secret: secret}} ->
      if secret, do: {:error, "env secret=true not allowed in v1"}
    end)
    :ok
  end

  defp validate_secrets(secrets) do
    Enum.each(secrets, fn {_name, config} ->
      if Map.has_key?(config, :value), do: {:error, "secrets cannot contain value field"}
    end)
    :ok
  end
end