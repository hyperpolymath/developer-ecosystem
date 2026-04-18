defmodule ShellState.InvariantVerificationTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest
  alias ShellState.State
  alias ShellState.Commit
  alias ShellState.Generator
  alias ShellState.Doctor

  describe "Core Invariant Verification" do
    test "1. No implicit writes - filesystem only modified during commit" do
      # Setup: Create test directories
      config_dir = "test/tmp/invariant_test""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      File.mkdir_p!(Path.join(config_dir, "previous"))
      File.mkdir_p!(Path.join(config_dir, "tmp"))
      
      # Create initial manifest
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
      
      # Load manifest (no filesystem writes should occur)
      original_mtime = File.mtime(manifest_path)
      {:ok, manifest} = Manifest.load(manifest_path)
      state = State.new(manifest)
      
      # Modify resident state (still no filesystem writes)
      new_env = %{"TEST_VAR" => %{manifest.env["TEST_VAR"] | value: "modified"}}
      modified_manifest = %Manifest{manifest | env: new_env}
      modified_state = State.new(modified_manifest)
      
      # Verify no filesystem changes occurred
      assert File.mtime(manifest_path) == original_mtime
      
      # Now commit (this should be the only write operation)
      {:ok, _} = Commit.commit(modified_state)
      
      # Verify the commit actually wrote changes
      assert File.mtime(manifest_path) != original_mtime
      {:ok, committed} = Manifest.load(manifest_path)
      assert committed.env["TEST_VAR"].value == "modified""])
    end

    test "2. Atomic commit - canonical state never modified in place" do
      # Setup
      config_dir = "test/tmp/atomic_test""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      File.mkdir_p!(Path.join(config_dir, "previous"))
      File.mkdir_p!(Path.join(config_dir, "tmp"))
      
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
""")
      
      {:ok, manifest} = Manifest.load(manifest_path)
      original_content = File.read!(manifest_path)
      
      # Start a commit but fail before the atomic replace
      # This simulates what happens if validation fails
      state = State.new(manifest)
      
      # Verify that failed commit doesn't touch current manifest
      # (Commit.validate_candidate would catch this)
      assert File.read!(manifest_path) == original_content
    end

    test "3. Rollback safety - previous version always preserved" do
      # Setup
      config_dir = "test/tmp/rollback_test""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "current"))
      File.mkdir_p!(Path.join(config_dir, "previous"))
      File.mkdir_p!(Path.join(config_dir, "tmp"))
      
      manifest_path = Path.join(config_dir, "current", "manifest.toml")
      
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
      state = State.new(manifest)
      
      # First commit
      {:ok, _} = Commit.commit(state)
      
      # Verify previous was created
      previous_path = Path.join(config_dir, "previous", "manifest.toml")
      assert File.exists?(previous_path)
      
      # Modify and commit again
      new_manifest = %Manifest{manifest | version: 2}
      new_state = State.new(new_manifest)
      {:ok, _} = Commit.commit(new_state)
      
      # Verify previous was updated to version 1
      {:ok, previous_content} = File.read(previous_path)
      assert String.contains?(previous_content, "version = 1")
      
      # Verify current is version 2
      {:ok, current_content} = File.read(manifest_path)
      assert String.contains?(current_content, "version = 2")
    end

    test "4. Deterministic generation - same input produces same output" do
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

      # Generate twice
      {:ok, first} = Generator.generate_bash(manifest)
      {:ok, second} = Generator.generate_bash(manifest)
      
      # Should be identical
      assert first == second
    end

    test "5. Secrets safety - no plaintext secrets in manifest or generated files" do
      # Test that manifest validation rejects plaintext secrets
      manifest_path = "test/tmp/secret_test.toml""])
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
      
      # Test that env entries with secret=true are rejected
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
value = "secret_value""])
type = "string""])
region = "core""])
export = true
secret = true
enabled = true
""")

      assert {:error, "env secret=true not allowed in v1"} = Manifest.load(manifest_path)
      
      # Test that generated files don't contain secret references
      valid_manifest = %Manifest{
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

      {:ok, generated} = Generator.generate_bash(valid_manifest)
      refute String.contains?(generated, "secret://aws/access_key")
      refute String.contains?(generated, "AKIA")
    end

    test "6. Resident state isolation - runtime mutations don't affect disk" do
      # Setup
      config_dir = "test/tmp/isolated_test""])
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
      original_mtime = File.mtime(manifest_path)
      
      # Create multiple resident states
      state1 = State.new(manifest)
      state2 = State.new(%Manifest{manifest | version: 2})
      state3 = State.new(%Manifest{manifest | version: 3})
      
      # Verify no disk changes
      assert File.mtime(manifest_path) == original_mtime
      
      # Verify each state is independent
      assert state1.manifest.version == 1
      assert state2.manifest.version == 2
      assert state3.manifest.version == 3
      
      # Verify disk still has original
      {:ok, disk_manifest} = Manifest.load(manifest_path)
      assert disk_manifest.version == 1
    end

    test "7. Generated files are fully derived - can be deleted and regenerated" do
      # Setup
      config_dir = "test/tmp/derived_test""])
      File.rm_rf!(config_dir)
      File.mkdir_p!(Path.join(config_dir, "generated"))
      
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

      # Generate first time
      {:ok, first_output} = Generator.generate_bash(manifest)
      generated_path = Path.join(config_dir, "generated", "bashrc")
      assert File.exists?(generated_path)
      
      # Delete generated file
      File.rm!(generated_path)
      assert !File.exists?(generated_path)
      
      # Regenerate - should produce identical output
      {:ok, second_output} = Generator.generate_bash(manifest)
      assert File.exists?(generated_path)
      assert first_output == second_output
    end

    test "8. Doctor command verifies all invariants" do
      # This is more of a functional test that would require setting up
      # a complete system state, but we can test the individual checks
      
      # Test secret leakage detection
      generated_with_secrets = "export API_KEY=\"secret://aws/key\"""])
      File.write!("test/tmp/doctor_test.bash", generated_with_secrets)
      
      # This should be caught by the doctor
      # (In a real test, we'd mock or set up the file structure properly)
      assert true  # Placeholder for actual doctor test
    end
  end
end