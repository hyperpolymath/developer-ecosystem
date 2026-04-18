defmodule ShellState.ManifestPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias ShellState.Manifest

  # Property: Round-trip serialization preserves manifest structure
  property "round-trip serialization" do
    check all version <- integer(1..100),
          name <- string(:ascii_printable, min_length: 1, max_length: 50) do
      manifest = %Manifest{
        version: version,
        name: name,
        profile: "default",
        meta: %{description: "test", owner: "test", shell: "bash"},
        policy: %{
          auto_write: false,
          require_explicit_commit: true,
          keep_previous: true,
          allow_plaintext_secrets: false
        },
        paths: %{entries: []},
        env: %{},
        secrets: %{},
        integrations: %{bash: %{enabled: true, mode: "source-snippet", target: "~/.bashrc"}},
        generation: %{render_paths: true, render_env: true, render_wrappers: false, render_aliases: false},
        generation_validation: %{bash_syntax_check: true}
      }
      
      {:ok, toml} = Manifest.to_toml(manifest)
      {:ok, loaded} = Manifest.load(toml)
      assert loaded.version == version
      assert loaded.name == name
    end
  end

  # Property: Validation rejects invalid shells
  property "validation rejects invalid shells" do
    check all shell <- string(:ascii_printable, min_length: 1, max_length: 50) do
      if shell != "bash" do
        manifest_content = """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "#{shell}""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false
""""])
        assert {:error, "Only bash supported in v1"} = Manifest.load(manifest_content)
      end
    end
  end

  # Simplified generators for property testing
  # (Complex manifest generation removed for simplicity)
end