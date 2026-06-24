# SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
# SPDX-License-Identifier: MPL-2.0

defmodule Dnfinition.Store.TransactionStoreTest do
  use ExUnit.Case, async: false

  alias Dnfinition.Store.TransactionStore

  setup do
    # Clear test data before each test
    TransactionStore.cleanup(0)
    :ok
  end

  describe "begin_transaction/2" do
    test "creates a new transaction" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Test transaction")
      assert is_integer(tx_id)
      assert tx_id > 0
    end

    test "returns incrementing transaction IDs" do
      {:ok, id1} = TransactionStore.begin_transaction("Transaction 1")
      {:ok, id2} = TransactionStore.begin_transaction("Transaction 2")
      assert id2 > id1
    end
  end

  describe "get_transaction/1" do
    test "returns transaction by ID" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Test transaction")
      {:ok, tx} = TransactionStore.get_transaction(tx_id)
      
      assert tx.id == tx_id
      assert tx.description == "Test transaction"
      assert tx.status == :pending
    end

    test "returns error for unknown ID" do
      assert {:error, :not_found} = TransactionStore.get_transaction(999_999)
    end
  end

  describe "commit_transaction/2" do
    test "commits a pending transaction" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Test")
      {:ok, tx} = TransactionStore.commit_transaction(tx_id)
      
      assert tx.status == :completed
      assert tx.completed_at != nil
    end
  end

  describe "fail_transaction/2" do
    test "marks transaction as failed" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Test")
      {:ok, tx} = TransactionStore.fail_transaction(tx_id, "Something went wrong")
      
      assert tx.status == :failed
      assert tx.error_message == "Something went wrong"
    end
  end

  describe "add_operation/2" do
    test "adds operation to transaction" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Test")
      {:ok, op} = TransactionStore.add_operation(tx_id, %{
        type: :install,
        package: "test-package",
        new_version: "1.0.0"
      })
      
      assert op.package_name == "test-package"
      assert op.operation == :install
      
      {:ok, tx} = TransactionStore.get_transaction(tx_id)
      assert length(tx.operations) == 1
    end
  end

  describe "list_transactions/1" do
    test "returns list of transactions" do
      TransactionStore.begin_transaction("Transaction 1")
      TransactionStore.begin_transaction("Transaction 2")
      
      transactions = TransactionStore.list_transactions()
      assert length(transactions) >= 2
    end

    test "returns transactions sorted by date descending" do
      {:ok, _id1} = TransactionStore.begin_transaction("First")
      Process.sleep(10)  # Small delay to ensure different timestamps
      {:ok, _id2} = TransactionStore.begin_transaction("Second")
      
      [newest | _] = TransactionStore.list_transactions()
      assert newest.description == "Second"
    end
  end

  describe "reverse_transaction/1" do
    test "generates reverse operations for completed transaction" do
      {:ok, tx_id} = TransactionStore.begin_transaction("Install test")
      TransactionStore.add_operation(tx_id, %{
        type: :install,
        package: "test-pkg",
        new_version: "1.0"
      })
      TransactionStore.commit_transaction(tx_id)
      
      {:ok, :operations, reverse_ops} = TransactionStore.reverse_transaction(tx_id)
      
      [reverse_op | _] = reverse_ops
      assert reverse_op.type == :remove
      assert reverse_op.package == "test-pkg"
    end
  end
end
