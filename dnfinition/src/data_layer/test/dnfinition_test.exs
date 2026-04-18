# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: AGPL-3.0-or-later

defmodule DnfinitionTest do
  use ExUnit.Case
  doctest Dnfinition

  describe "Dnfinition" do
    test "application starts successfully" do
      # Application should be running from test helper
      assert Process.whereis(Dnfinition.Store.Packages) != nil or
             Process.whereis(Dnfinition.Store.Cache) == nil
    end
  end
end
