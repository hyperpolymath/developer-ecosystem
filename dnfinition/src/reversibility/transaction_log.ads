-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Transaction_Log - Log and manage package transactions
pragma Ada_2022;
pragma SPARK_Mode (On);

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Transaction_Types; use Transaction_Types;
with Snapshot_Types;    use Snapshot_Types;

package Transaction_Log
  with SPARK_Mode
is

   --  Exception for transaction errors
   Transaction_Error : exception;

   --  Initialize the transaction log
   procedure Initialize (Log_Path : String := "");

   --  Begin a new transaction
   function Begin_Transaction
     (Description : String := "")
      return Transaction_ID;

   --  Add an operation to the current transaction
   procedure Add_Operation
     (Trans_ID : Transaction_ID;
      Op       : Operation_Entry);

   --  Mark transaction as in progress
   procedure Start_Transaction (Trans_ID : Transaction_ID);

   --  Commit a successful transaction
   procedure Commit_Transaction
     (Trans_ID    : Transaction_ID;
      Snapshot_ID : Snapshot_Types.Snapshot_ID := Invalid_Snapshot_ID);

   --  Mark transaction as failed
   procedure Fail_Transaction
     (Trans_ID  : Transaction_ID;
      Error_Msg : String := "");

   --  Cancel/abort a transaction
   procedure Cancel_Transaction (Trans_ID : Transaction_ID);

   --  Log an individual operation
   procedure Log_Operation (Entry : Log_Entry);

   --  Get transaction by ID
   function Get_Transaction (Trans_ID : Transaction_ID)
     return Transaction_Info;

   --  Get all transactions
   function Get_Transaction_History return Transaction_Array;

   --  Get transactions for a specific time range
   function Get_Transactions_Since
     (Since : Ada.Calendar.Time)
      return Transaction_Array;

   --  Reverse a completed transaction (undo all operations)
   procedure Reverse_Transaction (Trans_ID : Transaction_ID)
     with Pre => Transaction_Exists (Trans_ID)
                 and then Can_Reverse (Trans_ID);

   --  Replay a transaction (redo)
   procedure Replay_Transaction (Trans_ID : Transaction_ID)
     with Pre => Transaction_Exists (Trans_ID);

   --  Check if a transaction exists
   function Transaction_Exists (Trans_ID : Transaction_ID) return Boolean;

   --  Check if a transaction can be reversed
   function Can_Reverse (Trans_ID : Transaction_ID) return Boolean;

   --  Get the current active transaction (if any)
   function Current_Transaction return Transaction_ID;

   --  Check if there's an active transaction
   function Has_Active_Transaction return Boolean;

   --  Get log file path
   function Get_Log_Path return String;

   --  Flush log to disk
   procedure Flush_Log;

   --  Cleanup old log entries
   procedure Cleanup_Old_Entries (Keep_Last : Positive := 100);

   --  Export transaction history
   procedure Export_History
     (Path   : String;
      Format : String := "json");

   --  Import transaction history
   procedure Import_History (Path : String);

private

   --  Log file path
   Log_File_Path : Unbounded_String :=
     To_Unbounded_String ("/var/lib/dnfinition/transactions.log");

   --  Current active transaction
   Active_Trans_ID : Transaction_ID := Invalid_Transaction_ID;

   --  Transaction storage
   Max_Transactions : constant := 10_000;
   Transaction_Count : Natural := 0;
   Next_Trans_ID : Transaction_ID := 1;

   type Transaction_DB_Entry is record
      Trans  : Transaction_Info;
      Active : Boolean := False;
   end record;

   type Transaction_DB_Array is
     array (1 .. Max_Transactions) of Transaction_DB_Entry;

   Transaction_DB : Transaction_DB_Array;

end Transaction_Log;
