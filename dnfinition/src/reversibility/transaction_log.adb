-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Transaction_Log - Implementation
pragma Ada_2022;

with Ada.Calendar;
with Ada.Directories;

package body Transaction_Log is

   Initialized : Boolean := False;

   ----------------
   -- Initialize
   ----------------

   procedure Initialize (Log_Path : String := "") is
   begin
      if Log_Path /= "" then
         Log_File_Path := To_Unbounded_String (Log_Path);
      end if;

      --  Ensure log directory exists
      declare
         Dir : constant String := Ada.Directories.Containing_Directory
           (To_String (Log_File_Path));
      begin
         if not Ada.Directories.Exists (Dir) then
            Ada.Directories.Create_Path (Dir);
         end if;
      end;

      Transaction_DB := (others => (Trans => Null_Transaction, Active => False));
      Next_Trans_ID := 1;
      Transaction_Count := 0;
      Active_Trans_ID := Invalid_Transaction_ID;
      Initialized := True;
   end Initialize;

   -----------------------
   -- Begin_Transaction
   -----------------------

   function Begin_Transaction
     (Description : String := "")
      return Transaction_ID
   is
      use Ada.Calendar;
      Trans : Transaction_Info;
   begin
      if not Initialized then
         Initialize;
      end if;

      if Next_Trans_ID > Transaction_ID (Max_Transactions) then
         raise Transaction_Error with "Maximum transaction count reached";
      end if;

      Trans := (
         ID           => Next_Trans_ID,
         Description  => To_Unbounded_String (Description),
         Started_At   => Clock,
         Completed_At => Clock,
         Status       => Pending,
         Operations   => Operation_Vectors.Empty_Vector,
         Snapshot_ID  => Invalid_Snapshot_ID,
         User         => To_Unbounded_String (""),  --  Would get current user
         Packages_Add => Package_Types.Package_Vectors.Empty_Vector,
         Packages_Del => Package_Types.Package_Vectors.Empty_Vector,
         Packages_Upg => Package_Types.Package_Vectors.Empty_Vector,
         Download_Size => 0,
         Install_Size  => 0,
         Remove_Size   => 0
      );

      Transaction_DB (Positive (Next_Trans_ID)) :=
        (Trans => Trans, Active => True);

      declare
         Result : constant Transaction_ID := Next_Trans_ID;
      begin
         Next_Trans_ID := Next_Trans_ID + 1;
         Transaction_Count := Transaction_Count + 1;
         return Result;
      end;
   end Begin_Transaction;

   -------------------
   -- Add_Operation
   -------------------

   procedure Add_Operation
     (Trans_ID : Transaction_ID;
      Op       : Operation_Entry)
   is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      declare
         Entry_Ref : Transaction_DB_Entry
           renames Transaction_DB (Positive (Trans_ID));
         New_Op : Operation_Entry := Op;
      begin
         New_Op.Sequence := Positive (Entry_Ref.Trans.Operations.Length + 1);
         Entry_Ref.Trans.Operations.Append (New_Op);
      end;
   end Add_Operation;

   -----------------------
   -- Start_Transaction
   -----------------------

   procedure Start_Transaction (Trans_ID : Transaction_ID) is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      Transaction_DB (Positive (Trans_ID)).Trans.Status := In_Progress;
      Transaction_DB (Positive (Trans_ID)).Trans.Started_At :=
        Ada.Calendar.Clock;
      Active_Trans_ID := Trans_ID;
   end Start_Transaction;

   ------------------------
   -- Commit_Transaction
   ------------------------

   procedure Commit_Transaction
     (Trans_ID    : Transaction_ID;
      Snapshot_ID : Snapshot_Types.Snapshot_ID := Invalid_Snapshot_ID)
   is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      declare
         Entry_Ref : Transaction_DB_Entry
           renames Transaction_DB (Positive (Trans_ID));
      begin
         Entry_Ref.Trans.Status := Completed;
         Entry_Ref.Trans.Completed_At := Ada.Calendar.Clock;
         Entry_Ref.Trans.Snapshot_ID := Snapshot_ID;

         --  Mark all operations as completed
         for Op of Entry_Ref.Trans.Operations loop
            Op.Status := Completed;
         end loop;
      end;

      if Active_Trans_ID = Trans_ID then
         Active_Trans_ID := Invalid_Transaction_ID;
      end if;

      Flush_Log;
   end Commit_Transaction;

   ----------------------
   -- Fail_Transaction
   ----------------------

   procedure Fail_Transaction
     (Trans_ID  : Transaction_ID;
      Error_Msg : String := "")
   is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      declare
         Entry_Ref : Transaction_DB_Entry
           renames Transaction_DB (Positive (Trans_ID));
      begin
         Entry_Ref.Trans.Status := Failed;
         Entry_Ref.Trans.Completed_At := Ada.Calendar.Clock;

         --  Mark current operation as failed
         for Op of Entry_Ref.Trans.Operations loop
            if Op.Status = In_Progress then
               Op.Status := Failed;
               Op.Error_Msg := To_Unbounded_String (Error_Msg);
               exit;
            end if;
         end loop;
      end;

      if Active_Trans_ID = Trans_ID then
         Active_Trans_ID := Invalid_Transaction_ID;
      end if;

      Flush_Log;
   end Fail_Transaction;

   ------------------------
   -- Cancel_Transaction
   ------------------------

   procedure Cancel_Transaction (Trans_ID : Transaction_ID) is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      Transaction_DB (Positive (Trans_ID)).Trans.Status := Cancelled;
      Transaction_DB (Positive (Trans_ID)).Trans.Completed_At :=
        Ada.Calendar.Clock;

      if Active_Trans_ID = Trans_ID then
         Active_Trans_ID := Invalid_Transaction_ID;
      end if;
   end Cancel_Transaction;

   -------------------
   -- Log_Operation
   -------------------

   procedure Log_Operation (Entry : Log_Entry) is
   begin
      --  For standalone logging outside of transactions
      if Has_Active_Transaction then
         declare
            Op : constant Operation_Entry := (
               Sequence     => 1,
               Operation    => Entry.Operation,
               Package_Name => Entry.Package_Name,
               Old_Version  => Entry.Old_Version,
               New_Version  => Entry.New_Version,
               Status       =>
                 (if Entry.Success then Completed else Failed),
               Error_Msg    => Entry.Error_Msg
            );
         begin
            Add_Operation (Active_Trans_ID, Op);
         end;
      end if;
   end Log_Operation;

   ---------------------
   -- Get_Transaction
   ---------------------

   function Get_Transaction (Trans_ID : Transaction_ID)
     return Transaction_Info
   is
   begin
      if not Transaction_Exists (Trans_ID) then
         raise Transaction_Error with "Transaction does not exist";
      end if;

      return Transaction_DB (Positive (Trans_ID)).Trans;
   end Get_Transaction;

   ------------------------------
   -- Get_Transaction_History
   ------------------------------

   function Get_Transaction_History return Transaction_Array is
      Result : Transaction_Array;
   begin
      for I in 1 .. Positive (Next_Trans_ID) - 1 loop
         if Transaction_DB (I).Active then
            Result.Append (Transaction_DB (I).Trans);
         end if;
      end loop;
      return Result;
   end Get_Transaction_History;

   ----------------------------
   -- Get_Transactions_Since
   ----------------------------

   function Get_Transactions_Since
     (Since : Ada.Calendar.Time)
      return Transaction_Array
   is
      use Ada.Calendar;
      Result : Transaction_Array;
   begin
      for I in 1 .. Positive (Next_Trans_ID) - 1 loop
         if Transaction_DB (I).Active
           and then Transaction_DB (I).Trans.Started_At >= Since
         then
            Result.Append (Transaction_DB (I).Trans);
         end if;
      end loop;
      return Result;
   end Get_Transactions_Since;

   --------------------------
   -- Reverse_Transaction
   --------------------------

   procedure Reverse_Transaction (Trans_ID : Transaction_ID) is
      Trans : constant Transaction_Info := Get_Transaction (Trans_ID);
   begin
      --  Process operations in reverse order
      for I in reverse 1 .. Natural (Trans.Operations.Length) loop
         declare
            Op : constant Operation_Entry :=
              Trans.Operations.Element (I);
         begin
            --  Create reverse operation
            case Op.Operation is
               when Install | Install_Deps =>
                  --  Reverse of install is remove
                  null;  --  Would execute remove

               when Remove | Remove_Deps | Autoremove =>
                  --  Reverse of remove is install (with old version)
                  null;  --  Would execute install

               when Upgrade =>
                  --  Reverse of upgrade is downgrade
                  null;  --  Would execute downgrade

               when Downgrade =>
                  --  Reverse of downgrade is upgrade
                  null;  --  Would execute upgrade

               when Reinstall =>
                  --  Nothing to reverse
                  null;
            end case;
         end;
      end loop;

      --  Mark as rolled back
      Transaction_DB (Positive (Trans_ID)).Trans.Status := Rolled_Back;
   end Reverse_Transaction;

   ------------------------
   -- Replay_Transaction
   ------------------------

   procedure Replay_Transaction (Trans_ID : Transaction_ID) is
      Trans : constant Transaction_Info := Get_Transaction (Trans_ID);
   begin
      --  Process operations in original order
      for Op of Trans.Operations loop
         --  Execute the operation again
         null;  --  Would execute the operation
      end loop;
   end Replay_Transaction;

   ------------------------
   -- Transaction_Exists
   ------------------------

   function Transaction_Exists (Trans_ID : Transaction_ID) return Boolean is
   begin
      return Trans_ID > 0
        and then Trans_ID < Next_Trans_ID
        and then Transaction_DB (Positive (Trans_ID)).Active;
   end Transaction_Exists;

   -------------------
   -- Can_Reverse
   -------------------

   function Can_Reverse (Trans_ID : Transaction_ID) return Boolean is
   begin
      if not Transaction_Exists (Trans_ID) then
         return False;
      end if;

      declare
         Trans : constant Transaction_Info :=
           Transaction_DB (Positive (Trans_ID)).Trans;
      begin
         return Trans.Status = Completed
           and then (Trans.Snapshot_ID /= Invalid_Snapshot_ID
                     or else not Trans.Operations.Is_Empty);
      end;
   end Can_Reverse;

   -------------------------
   -- Current_Transaction
   -------------------------

   function Current_Transaction return Transaction_ID is
   begin
      return Active_Trans_ID;
   end Current_Transaction;

   ----------------------------
   -- Has_Active_Transaction
   ----------------------------

   function Has_Active_Transaction return Boolean is
   begin
      return Active_Trans_ID /= Invalid_Transaction_ID;
   end Has_Active_Transaction;

   ------------------
   -- Get_Log_Path
   ------------------

   function Get_Log_Path return String is
   begin
      return To_String (Log_File_Path);
   end Get_Log_Path;

   ----------------
   -- Flush_Log
   ----------------

   procedure Flush_Log is
   begin
      --  Would write transaction history to disk
      null;
   end Flush_Log;

   --------------------------
   -- Cleanup_Old_Entries
   --------------------------

   procedure Cleanup_Old_Entries (Keep_Last : Positive := 100) is
      Count : Natural := 0;
   begin
      --  Count active transactions
      for I in 1 .. Positive (Next_Trans_ID) - 1 loop
         if Transaction_DB (I).Active then
            Count := Count + 1;
         end if;
      end loop;

      --  Delete oldest until we're at Keep_Last
      if Count > Keep_Last then
         for I in 1 .. Positive (Next_Trans_ID) - 1 loop
            if Transaction_DB (I).Active then
               Transaction_DB (I).Active := False;
               Count := Count - 1;
               exit when Count <= Keep_Last;
            end if;
         end loop;
      end if;
   end Cleanup_Old_Entries;

   ---------------------
   -- Export_History
   ---------------------

   procedure Export_History
     (Path   : String;
      Format : String := "json")
   is
      pragma Unreferenced (Path, Format);
   begin
      --  Would export to JSON, CSV, etc.
      null;
   end Export_History;

   ---------------------
   -- Import_History
   ---------------------

   procedure Import_History (Path : String) is
      pragma Unreferenced (Path);
   begin
      --  Would import from file
      null;
   end Import_History;

end Transaction_Log;
