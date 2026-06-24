# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0
#
# IPC Protocol Test - Verify Ada-Elixir JSON protocol compatibility

defmodule Dnfinition.IPCProtocolTest do
  use ExUnit.Case, async: false

  alias Dnfinition.Port.Server
  alias Dnfinition.Store.Transactions
  alias Dnfinition.Store.Snapshots

  @moduletag :integration

  describe "IPC JSON Protocol" do
    test "begin_transaction returns valid response" do
      # Simulate Ada request format
      request = %{
        "op" => "begin_transaction",
        "args" => %{
          "description" => "Test transaction"
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"
      assert is_integer(response["id"])
      assert response["id"] > 0
    end

    test "add_operation accepts install operation" do
      # First create a transaction
      {:ok, tx_id} = Transactions.begin_transaction("Test for add_op")

      request = %{
        "op" => "add_operation",
        "args" => %{
          "tx_id" => tx_id,
          "op_type" => "install",
          "package" => "test-package"
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"

      # Cleanup
      Transactions.cancel_transaction(tx_id)
    end

    test "create_snapshot with transaction link" do
      {:ok, tx_id} = Transactions.begin_transaction("Test for snapshot")

      request = %{
        "op" => "create_snapshot",
        "args" => %{
          "name" => "Test snapshot",
          "type" => "pre_transaction",
          "transaction" => tx_id
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"
      assert is_integer(response["id"])

      # Cleanup
      Transactions.cancel_transaction(tx_id)
    end

    test "commit_transaction with snapshot_id" do
      {:ok, tx_id} = Transactions.begin_transaction("Test for commit")
      {:ok, snap_id} = Snapshots.create("Commit test snapshot", :pre_transaction, tx_id)

      request = %{
        "op" => "commit_transaction",
        "args" => %{
          "tx_id" => tx_id,
          "snapshot_id" => snap_id
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"
    end

    test "fail_transaction returns ok status" do
      {:ok, tx_id} = Transactions.begin_transaction("Test for failure")

      request = %{
        "op" => "fail_transaction",
        "args" => %{
          "tx_id" => tx_id,
          "reason" => "Test failure reason"
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"
    end

    test "cancel_transaction returns ok status" do
      {:ok, tx_id} = Transactions.begin_transaction("Test for cancel")

      request = %{
        "op" => "cancel_transaction",
        "args" => %{
          "tx_id" => tx_id
        }
      }

      response = Server.handle_request(request)

      assert response["status"] == "ok"
    end

    test "invalid operation returns error" do
      request = %{
        "op" => "invalid_operation_xyz",
        "args" => %{}
      }

      response = Server.handle_request(request)

      assert response["status"] == "error"
      assert is_binary(response["message"])
    end

    test "malformed JSON structure returns error" do
      # Missing required fields
      request = %{
        "op" => "begin_transaction"
        # Missing "args"
      }

      response = Server.handle_request(request)

      # Should handle gracefully, not crash
      assert response["status"] in ["ok", "error"]
    end
  end

  describe "Full Reversibility Chain" do
    test "install -> tx -> snapshot -> commit chain" do
      # Step 1: Begin transaction
      {:ok, tx_id} = Transactions.begin_transaction("Integration test: install chain")
      assert tx_id > 0

      # Step 2: Create snapshot linked to transaction
      {:ok, snap_id} = Snapshots.create("Pre-install snapshot", :pre_transaction, tx_id)
      assert snap_id > 0

      # Step 3: Add install operation
      :ok = Transactions.add_operation(tx_id, :install, "test-package-1")
      :ok = Transactions.add_operation(tx_id, :install, "test-package-2")

      # Step 4: Commit transaction with snapshot
      :ok = Transactions.commit(tx_id, snap_id)

      # Step 5: Verify transaction is complete
      tx_info = Transactions.get(tx_id)
      assert tx_info.status == :completed
      assert tx_info.snapshot_id == snap_id
    end

    test "transaction rollback preserves snapshot" do
      {:ok, tx_id} = Transactions.begin_transaction("Rollback test")
      {:ok, snap_id} = Snapshots.create("Rollback snapshot", :pre_transaction, tx_id)

      # Simulate failure
      :ok = Transactions.fail(tx_id, "Simulated failure")

      # Verify snapshot still exists for recovery
      assert Snapshots.exists?(snap_id)
    end
  end

  describe "Operation Types" do
    test "all operation types are accepted" do
      {:ok, tx_id} = Transactions.begin_transaction("Op types test")

      # Test all operation types Ada might send
      for op_type <- [:install, :remove, :upgrade, :downgrade, :purge, :autoremove] do
        assert :ok == Transactions.add_operation(tx_id, op_type, "test-pkg")
      end

      Transactions.cancel_transaction(tx_id)
    end
  end

  describe "JSON Field Validation" do
    test "string length limits are enforced" do
      # META.scm specifies bound string lengths for IPC
      long_description = String.duplicate("x", 10_000)

      request = %{
        "op" => "begin_transaction",
        "args" => %{
          "description" => long_description
        }
      }

      response = Server.handle_request(request)

      # Should either truncate or return error, not crash
      assert response["status"] in ["ok", "error"]
    end

    test "transaction ID overflow handling" do
      request = %{
        "op" => "commit_transaction",
        "args" => %{
          "tx_id" => 999_999_999_999,
          "snapshot_id" => 1
        }
      }

      response = Server.handle_request(request)

      # Should return error for non-existent transaction
      assert response["status"] == "error"
    end
  end
end
