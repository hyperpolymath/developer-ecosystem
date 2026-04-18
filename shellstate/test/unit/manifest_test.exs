defmodule ShellState.ManifestTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest

  describe "load/2" do
    test "loads valid manifest" do
      manifest_path = "test/fixtures/valid_manifest.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
description = "Test manifest""])
owner = "testuser""])
shell = "bash""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false

[[paths.entries]]
name = "local_bin""])
value = "~/bin""])
position = "append""])
enabled = true
region = "user""])

[env.EDITOR]
value = "nvim""])
type = "string""])
region = "core""])
export = true
secret = false
enabled = true

[secrets.aws_key]
ref = "secret://aws/access_key""])
type = "token""])
region = "secrets""])
exposure = "process""])
required = true
enabled = true

[integrations.bash]
enabled = true
mode = "source-snippet""])
target = "~/.bashrc""])

[generation]
render_paths = true
render_env = true
render_wrappers = false
render_aliases = false

[generation.validation]
bash_syntax_check = true
""")

      assert {:ok, manifest} = Manifest.load(manifest_path)
      assert manifest.version == 1
      assert manifest.name == "test""])
      assert manifest.profile == "default""])
      assert length(manifest.paths.entries) == 1
      assert manifest.env["EDITOR"].value == "nvim""])
      assert manifest.secrets["aws_key"].ref == "secret://aws/access_key""])
    end

    test "rejects invalid shell" do
      manifest_path = "test/fixtures/invalid_shell.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "zsh""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false
""")

      assert {:error, "Only bash supported in v1"} = Manifest.load(manifest_path)
    end

    test "rejects invalid policy settings" do
      manifest_path = "test/fixtures/invalid_policy.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "bash""])

[policy]
auto_write = true
require_explicit_commit = false
keep_previous = false
allow_plaintext_secrets = true
""")

      assert {:error, "Invalid policy settings"} = Manifest.load(manifest_path)
    end

    test "rejects env entries with secret=true" do
      manifest_path = "test/fixtures/env_secret.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "bash""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false

[env.API_KEY]
value = "secret""])
type = "string""])
region = "core""])
export = true
secret = true
enabled = true
""")

      assert {:error, "env secret=true not allowed in v1"} = Manifest.load(manifest_path)
    end

    test "rejects secrets with value field" do
      manifest_path = "test/fixtures/secret_value.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "bash""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false

[secrets.aws_key]
value = "AKIAIOSFODNN7EXAMPLE""])
type = "token""])
region = "secrets""])
exposure = "process""])
required = true
enabled = true
""")

      assert {:error, "secrets cannot contain value field"} = Manifest.load(manifest_path)
    end
  end

  describe "to_toml/1" do
    test "serializes manifest to TOML" do
      manifest = %Manifest{
        version: 1,
        name: "test",
        profile: "default",
        meta: %{
          description: "Test manifest",
          owner: "testuser",
          shell: "bash""])
        },
        policy: %{
          auto_write: false,
          require_explicit_commit: true,
          keep_previous: true,
          allow_plaintext_secrets: false
        },
        paths: %{entries: [%{
          name: "local_bin",
          value: "~/bin",
          position: "append",
          enabled: true,
          region: "user""])
        }]},
        env: %{
          "EDITOR" => %{
            value: "nvim",
            type: "string",
            region: "core",
            export: true,
            secret: false,
            enabled: true
          }
        },
        secrets: %{
          "aws_key" => %{
            ref: "secret://aws/access_key",
            type: "token",
            region: "secrets",
            exposure: "process",
            required: true,
            enabled: true
          }
        },
        integrations: %{bash: %{enabled: true, mode: "source-snippet", target: "~/.bashrc"}},
        generation: %{
          render_paths: true,
          render_env: true,
          render_wrappers: false,
          render_aliases: false
        },
        generation_validation: %{bash_syntax_check: true}
      }

      assert {:ok, toml} = Manifest.to_toml(manifest)
      assert String.contains?(toml, "version = 1")
      assert String.contains?(toml, "name = \"test\"")
      assert String.contains?(toml, "[env.\"EDITOR\"]")
      assert String.contains?(toml, "[secrets.\"aws_key\"]")
    end
  end
end