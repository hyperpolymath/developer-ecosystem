defmodule ShellState.CommitIntegrationTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest
  alias ShellState.Commit

  setup do
    # Create test directories
    config_dir = "test/tmp/shellstate""])
    File.rm_rf!(config_dir)
    File.mkdir_p!(Path.join(config_dir, "current"))
    File.mkdir_p!(Path.join(config_dir, "previous"))
    File.mkdir_p!(Path.join(config_dir, "tmp"))
    
    # Create a valid manifest
    manifest_path = Path.join(config_dir, "current", "manifest.toml")
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
""")
    
    {:ok, config_dir: config_dir, manifest_path: manifest_path}
  end

  test "commit preserves previous version", %{config_dir: config_dir} do
    # Load initial manifest
    manifest_path = Path.join(config_dir, "current", "manifest.toml")
    {:ok, manifest} = Manifest.load(manifest_path)
    state = ShellState.State.new(manifest)
    
    # Commit it
    assert {:ok, _new_state} = Commit.commit(state)
    
    # Verify previous version exists
    previous_path = Path.join(config_dir, "previous", "manifest.toml")
    assert File.exists?(previous_path)
    
    # Verify content matches
    {:ok, previous_content} = File.read(previous_path)
    {:ok, current_content} = File.read(manifest_path)
    assert previous_content == current_content
  end

  test "commit fails with invalid manifest", %{config_dir: config_dir} do
    # Create invalid manifest
    invalid_path = Path.join(config_dir, "current", "manifest.toml")
    File.write!(invalid_path, """"])
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
    
    {:ok, invalid_manifest} = Manifest.load(invalid_path)
    invalid_state = ShellState.State.new(invalid_manifest)
    
    # Try to commit - should fail
    assert {:error, _} = Commit.commit(invalid_state)
  end

  test "commit creates atomic update", %{config_dir: config_dir} do
    manifest_path = Path.join(config_dir, "current", "manifest.toml")
    {:ok, manifest} = Manifest.load(manifest_path)
    
    # Modify manifest
    new_manifest = %Manifest{manifest | version: 2}
    new_state = ShellState.State.new(new_manifest)
    
    # Commit
    assert {:ok, _} = Commit.commit(new_state)
    
    # Verify new version is in place
    {:ok, loaded} = Manifest.load(manifest_path)
    assert loaded.version == 2
    
    # Verify no temp files left behind
    tmp_files = File.ls!(Path.join(config_dir, "tmp"))
    assert length(tmp_files) == 0
  end
end