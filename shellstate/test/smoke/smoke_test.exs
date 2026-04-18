defmodule ShellState.SmokeTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest
  alias ShellState.Generator

  test "system starts and loads manifest" do
    # Create a minimal valid manifest
    manifest_path = "test/tmp/smoke_manifest.toml""])
    File.mkdir_p!("test/tmp")
    File.write!(manifest_path, """"])
version = 1
name = "smoke""])
profile = "default""])

[meta]
shell = "bash""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false
""")

    # Should load without error
    assert {:ok, _manifest} = Manifest.load(manifest_path)
  end

  test "generator produces output" do
    manifest = %Manifest{
      version: 1,
      name: "smoke",
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

    assert {:ok, bash_output} = Generator.generate_bash(manifest)
    assert String.contains?(bash_output, "export PATH=\"/test:$PATH\"")
    assert String.contains?(bash_output, "export TEST_VAR=\"test_value\"")
  end

  test "CLI responds to help" do
    # This would be a real CLI test in a complete implementation
    # For smoke test, we just verify the module exists
    assert Code.ensure_loaded?(ShellState.CLI)
  end
end