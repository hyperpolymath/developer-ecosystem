# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Store.PackageStoreTest do
  use ExUnit.Case, async: false

  alias Dnfinition.Store.PackageStore

  setup do
    # Clean up test packages
    case PackageStore.get_package("test-package") do
      {:ok, _} -> PackageStore.record_removed("test-package")
      _ -> :ok
    end
    :ok
  end

  describe "record_installed/3" do
    test "records a new package installation" do
      {:ok, state} = PackageStore.record_installed("test-package", "1.0.0", reason: :manual)
      
      assert state.name == "test-package"
      assert state.version == "1.0.0"
      assert state.install_reason == :manual
    end

    test "sets default install reason to manual" do
      {:ok, state} = PackageStore.record_installed("test-package", "1.0.0")
      assert state.install_reason == :manual
    end
  end

  describe "get_package/1" do
    test "returns installed package" do
      PackageStore.record_installed("test-package", "1.0.0")
      {:ok, state} = PackageStore.get_package("test-package")
      
      assert state.name == "test-package"
      assert state.version == "1.0.0"
    end

    test "returns error for unknown package" do
      assert {:error, :not_found} = PackageStore.get_package("nonexistent-package")
    end
  end

  describe "installed?/1" do
    test "returns true for installed package" do
      PackageStore.record_installed("test-package", "1.0.0")
      assert PackageStore.installed?("test-package")
    end

    test "returns false for unknown package" do
      refute PackageStore.installed?("nonexistent-package")
    end
  end

  describe "record_updated/4" do
    test "updates package version" do
      PackageStore.record_installed("test-package", "1.0.0")
      {:ok, state} = PackageStore.record_updated("test-package", "1.0.0", "2.0.0")
      
      assert state.version == "2.0.0"
      assert state.updated_at != nil
    end
  end

  describe "record_removed/1" do
    test "removes package from store" do
      PackageStore.record_installed("test-package", "1.0.0")
      assert :ok = PackageStore.record_removed("test-package")
      refute PackageStore.installed?("test-package")
    end
  end

  describe "hold_package/1" do
    test "marks package as held" do
      PackageStore.record_installed("test-package", "1.0.0")
      {:ok, state} = PackageStore.hold_package("test-package")
      
      assert state.held == true
      assert state.pinned_version == "1.0.0"
    end
  end

  describe "unhold_package/1" do
    test "removes hold from package" do
      PackageStore.record_installed("test-package", "1.0.0")
      PackageStore.hold_package("test-package")
      {:ok, state} = PackageStore.unhold_package("test-package")
      
      assert state.held == false
      assert state.pinned_version == nil
    end
  end

  describe "list_installed/1" do
    test "returns list of installed packages" do
      PackageStore.record_installed("test-package", "1.0.0")
      packages = PackageStore.list_installed()
      
      assert Enum.any?(packages, fn p -> p.name == "test-package" end)
    end
  end

  describe "search/1" do
    test "finds packages by name pattern" do
      PackageStore.record_installed("test-package", "1.0.0")
      results = PackageStore.search("test")
      
      assert Enum.any?(results, fn p -> p.name == "test-package" end)
    end
  end
end
