defmodule ShellState.ContractTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest
  alias ShellState.State
  alias ShellState.Commit
  alias ShellState.Generator

  describe "Contract and invariant tests" do
    test "contract: canonical manifest is single source of truth" do
      # Setup
      config_dir = "test/tmp/contract_test""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      
      manifest_path = Path.join(config_dir, "current", "manifest.toml")
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

[env.TEST_VAR]
value = "canonical_value""])
type = "string""])
region = "core""])
export = true
secret = false
enabled = true
""")
      
      # Load canonical state
      {:ok, manifest} = Manifest.load(manifest_path)
      assert manifest.env["TEST_VAR"].value == "canonical_value""])
      
      # Create resident state
      state = State.new(manifest)
      
      # Modify resident state
      new_env = %{"TEST_VAR" => %{manifest.env["TEST_VAR"] | value: "modified_value"}}
      modified_manifest = %Manifest{manifest | env: new_env}
      modified_state = State.new(modified_manifest)
      
      # Verify resident state is different from canonical
      assert modified_state.manifest.env["TEST_VAR"].value == "modified_value""])
      
      # Verify canonical is unchanged
      {:ok, canonical} = Manifest.load(manifest_path)
      assert canonical.env["TEST_VAR"].value == "canonical_value""])
      
      # Commit the changes
      {:ok, _} = Commit.commit(modified_state)
      
      # Verify canonical now matches the committed state
      {:ok, updated_canonical} = Manifest.load(manifest_path)
      assert updated_canonical.env["TEST_VAR"].value == "modified_value""])
    end

    test "contract: generated files are derived artifacts" do
      manifest = %Manifest{
        version: 1,
        name: "test",
        profile: "default",
        meta: %{shell: "bash"},
        policy: %{
          auto_write: false,
          require_explicit_commit: true,
          keep_previous: true,
          allow_plaintext_secrets: false
        },
        paths: %{entries: [%{
          name: "test_path",
          value: "/test",
          position: "append",
          enabled: true,
          region: "user""])
        }]},
        env: %{
          "TEST_VAR" => %{
            value: "test_value",
            type: "string",
            region: "core",
            export: true,
            secret: false,
            enabled: true
          }
        },
        secrets: %{},
        integrations: %{bash: %{enabled: true, mode: "source-snippet", target: "~/.bashrc"}},
        generation: %{
          render_paths: true,
          render_env: true,
          render_wrappers: false,
          render_aliases: false
        },
        generation_validation: %{bash_syntax_check: true}
      }

      # Generate bash configuration
      {:ok, generated} = Generator.generate_bash(manifest)
      
      # Verify generated content is derived from manifest
      assert String.contains?(generated, "export PATH=\"/test:$PATH\"")
      assert String.contains?(generated, "export TEST_VAR=\"test_value\"")
      assert String.contains?(generated, "Version: 1")
      assert String.contains?(generated, "Profile: default")
      
      # Verify generated content doesn't contain manifest structure
      refute String.contains?(generated, "[meta]")
      refute String.contains?(generated, "[policy]")
    end

    test "contract: commit preserves exactly one rollback version" do
      # Setup
      config_dir = "test/tmp/contract_rollback""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      File.mkdir_p!(Path.join(config_dir, "previous"))
      File.mkdir_p!(Path.join(config_dir, "tmp"))
      
      manifest_path = Path.join(config_dir, "current", "manifest.toml")
      previous_path = Path.join(config_dir, "previous", "manifest.toml")
      
      # Create initial version
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
""")
      
      {:ok, manifest} = Manifest.load(manifest_path)
      
      # First commit
      state1 = State.new(manifest)
      {:ok, _} = Commit.commit(state1)
      
      # Verify exactly one previous version exists
      assert File.exists?(previous_path)
      
      # Second commit
      state2 = State.new(%Manifest{manifest | version: 2})
      {:ok, _} = Commit.commit(state2)
      
      # Verify still exactly one previous version (version 1)
      assert File.exists?(previous_path)
      {:ok, previous_content} = File.read(previous_path)
      assert String.contains?(previous_content, "version = 1")
      
      # Third commit
      state3 = State.new(%Manifest{manifest | version: 3})
      {:ok, _} = Commit.commit(state3)
      
      # Verify still exactly one previous version (version 2)
      assert File.exists?(previous_path)
      {:ok, updated_previous} = File.read(previous_path)
      assert String.contains?(updated_previous, "version = 2")
      refute String.contains?(updated_previous, "version = 1")
    end

    test "contract: no plaintext secrets in generated files" do
      manifest = %Manifest{
        version: 1,
        name: "test",
        profile: "default",
        meta: %{shell: "bash"},
        policy: %{
          auto_write: false,
          require_explicit_commit: true,
          keep_previous: true,
          allow_plaintext_secrets: false
        },
        paths: %{entries: []},
        env: %{},
        secrets: %{
          "aws_key" => %{
            ref: "secret://aws/access_key",
            type: "token",
            region: "secrets",
            exposure: "process",
            required: true,
            enabled: true
          },
          "db_password" => %{
            ref: "secret://database/password",
            type: "password",
            region: "secrets",
            exposure: "none",
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

      {:ok, generated} = Generator.generate_bash(manifest)
      
      # Verify no secret references in generated output
      refute String.contains?(generated, "secret://aws/access_key")
      refute String.contains?(generated, "secret://database/password")
      refute String.contains?(generated, "AKIA")
      refute String.contains?(generated, "password")
      
      # Verify secrets section is not rendered
      refute String.contains?(generated, "[secrets]")
    end

    test "contract: resident state is discardable" do
      # Setup
      config_dir = "test/tmp/contract_resident""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      
      manifest_path = Path.join(config_dir, "current", "manifest.toml")
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

[env.TEST_VAR]
value = "original""])
type = "string""])
region = "core""])
export = true
secret = false
enabled = true
""")
      
      # Load and modify resident state
      {:ok, manifest} = Manifest.load(manifest_path)
      state = State.new(%Manifest{manifest | version: 999})
      
      # Discard the resident state (simulate crash)
      # Just don't commit it
      
      # Reload from canonical - should get original state
      {:ok, reloaded} = Manifest.load(manifest_path)
      assert reloaded.version == 1
      refute reloaded.version == 999
    end
  end
end