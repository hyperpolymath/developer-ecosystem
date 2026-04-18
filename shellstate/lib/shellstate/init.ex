defmodule ShellState.Init do
  @moduledoc """
  Initialization module for ShellState.
  
  This module sets up the directory structure and example configuration
  for new ShellState installations.
  """
  
  def initialize do
    config_dir = "~/.config/shellstate"
    
    # Create directory structure
    File.mkdir_p!(Path.join([config_dir, "current"]))
    File.mkdir_p!(Path.join([config_dir, "previous"]))
    File.mkdir_p!(Path.join([config_dir, "tmp"]))
    File.mkdir_p!(Path.join([config_dir, "generated"]))
    
    # Create example manifest
    username = System.get_env("USER") || "user"
    example_manifest = """
version = 1
name = "default"
profile = "default"

[meta]
description = "Default shell configuration"
owner = "#{username}"
shell = "bash"

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false

[[paths.entries]]
name = "local_bin"
value = "~/bin"
position = "append"
enabled = true
region = "user"

[env.EDITOR]
value = "nvim"
type = "string"
region = "core"
export = true
secret = false
enabled = true

[integrations.bash]
enabled = true
mode = "source-snippet"
target = "~/.bashrc"

[generation]
render_paths = true
render_env = true
render_wrappers = false
render_aliases = false

[generation.validation]
bash_syntax_check = true
"""
    
    example_path = Path.join([config_dir, "current", "manifest.toml.example"])
    File.write!(example_path, example_manifest)
    
    IO.puts("""
ShellState initialized.

Next steps:
1. Copy the example manifest:
   cp ~/.config/shellstate/current/manifest.toml.example ~/.config/shellstate/current/manifest.toml

2. Edit the manifest to your needs

3. Generate bash configuration:
   shellstate generate

4. Source the generated file in your ~/.bashrc
""")
  end
end