# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
defmodule IDApixiTIK.SyncServer.ApplicationTest do
  use ExUnit.Case
  
  test "application starts and core services are alive" do
    assert Process.whereis(IDApixiTIK.SyncServer.Registry) != nil
    assert Process.whereis(IDApixiTIK.SyncServer.DistributedSupervisor) != nil
    assert Process.whereis(IDApixiTIK.SyncServer.PubSub) != nil
  end
end
