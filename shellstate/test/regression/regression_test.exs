defmodule ShellState.RegressionTest do
  use ExUnit.Case, async: true
  alias ShellState.Manifest

  describe "Regression tests for fixed bugs" do
    # Regression test for issue where invalid shell values weren't properly rejected
    test "regression: reject non-bash shells" do
      manifest_path = "test/tmp/regression_shell.toml""])
      File.write!(manifest_path, """"])
version = 1
name = "test""])
profile = "default""])

[meta]
shell = "fish""])

[policy]
auto_write = false
require_explicit_commit = true
keep_previous = true
allow_plaintext_secrets = false
""")

      assert {:error, "Only bash supported in v1"} = Manifest.load(manifest_path)
    end

    # Regression test for issue where env entries could be marked as secrets
    test "regression: reject env entries with secret=true" do
      manifest_path = "test/tmp/regression_env_secret.toml""])
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

[env.SECRET_VAR]
value = "secret""])
type = "string""])
region = "core""])
export = true
secret = true
enabled = true
""")

      assert {:error, "env secret=true not allowed in v1"} = Manifest.load(manifest_path)
    end

    # Regression test for issue where secrets could contain plaintext values
    test "regression: reject secrets with value fields" do
      manifest_path = "test/tmp/regression_secret_value.toml""])
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

[secrets.api_key]
value = "plaintext_secret""])
type = "token""])
region = "secrets""])
exposure = "process""])
required = true
enabled = true
""")

      assert {:error, "secrets cannot contain value field"} = Manifest.load(manifest_path)
    end

    # Regression test for issue where invalid policy settings were accepted
    test "regression: reject invalid policy combinations" do
      manifest_path = "test/tmp/regression_policy.toml""])
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
  end
end