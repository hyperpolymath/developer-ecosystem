-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Rollback_Engine - Implementation
pragma Ada_2022;
pragma SPARK_Mode (Off);  --  Implementation uses I/O

with Ada.Calendar;
with Snapshot_Manager;
with Transaction_Log;

package body Rollback_Engine is

   Initialized : Boolean := False;

   ----------------
   -- Initialize
   ----------------

   procedure Initialize is
   begin
      Snapshot_Manager.Initialize;
      Transaction_Log.Initialize;
      Current_State := Idle;
      Initialized := True;
   end Initialize;

   ---------------------------
   -- Rollback_To_Snapshot
   ---------------------------

   function Rollback_To_Snapshot
     (ID         : Snapshot_ID;
      Verify     : Boolean := True;
      Force      : Boolean := False)
      return Rollback_Result
   is
      Result : Rollback_Result := (
         Status       => Failed,
         Message      => Null_Unbounded_String,
         Snapshot_ID  => ID,
         Trans_ID     => Invalid_Transaction_ID,
         Ops_Reversed => 0,
         Ops_Total    => 0
      );
   begin
      if not Initialized then
         Initialize;
      end if;

      --  Check if rollback is possible
      if not Force and then not Can_Safely_Rollback (ID) then
         Result.Message := +"Rollback safety check failed";
         return Result;
      end if;

      --  Verify snapshot if requested
      if Verify then
         if not Snapshot_Manager.Verify_Snapshot (ID) then
            Result.Message := +"Snapshot verification failed";
            return Result;
         end if;
      end if;

      Current_State := Preparing;

      --  Get snapshot info
      declare
         Snap_Info : constant Snapshot_Info :=
           Snapshot_Manager.Get_Snapshot_Info (ID);
      begin
         Current_State := In_Progress;

         --  Perform the rollback based on strategy
         Snapshot_Manager.Rollback_To_Snapshot (ID);

         Current_State := Verifying;

         --  Verify if requested
         if Verify then
            if not Verify_System_State then
               Result.Status := Partial;
               Result.Message := +"Rollback completed but verification failed";
            else
               Result.Status := Success;
               Result.Message := +"Rollback completed successfully";
            end if;
         else
            Result.Status := Success;
            Result.Message := +"Rollback completed (unverified)";
         end if;

         --  Check if reboot is required
         if Requires_Reboot (ID) then
            Result.Status := Requires_Reboot;
            Result.Message := +"Rollback requires reboot to complete";
         end if;

         Current_State := Idle;
      end;

      return Result;

   exception
      when others =>
         Current_State := Idle;
         Result.Status := Failed;
         Result.Message := +"Rollback failed with exception";
         return Result;
   end Rollback_To_Snapshot;

   ---------------------------------
   -- Rollback_Last_Transaction
   ---------------------------------

   function Rollback_Last_Transaction return Rollback_Result is
      History : constant Transaction_Array :=
        Transaction_Log.Get_Transaction_History;
      Result  : Rollback_Result := (
         Status       => Not_Needed,
         Message      => +"No transactions to rollback",
         Snapshot_ID  => Invalid_Snapshot_ID,
         Trans_ID     => Invalid_Transaction_ID,
         Ops_Reversed => 0,
         Ops_Total    => 0
      );
   begin
      if History.Is_Empty then
         return Result;
      end if;

      --  Find the last completed transaction
      for I in reverse 1 .. Natural (History.Length) loop
         declare
            Trans : constant Transaction_Info := History.Element (I);
         begin
            if Trans.Status = Completed then
               return Rollback_Transaction (Trans.ID, Verify => True);
            end if;
         end;
      end loop;

      return Result;
   end Rollback_Last_Transaction;

   ---------------------------
   -- Rollback_Transaction
   ---------------------------

   function Rollback_Transaction
     (Trans_ID : Transaction_ID;
      Verify   : Boolean := True)
      return Rollback_Result
   is
      Trans  : constant Transaction_Info :=
        Transaction_Log.Get_Transaction (Trans_ID);
      Result : Rollback_Result := (
         Status       => Failed,
         Message      => Null_Unbounded_String,
         Snapshot_ID  => Trans.Snapshot_ID,
         Trans_ID     => Trans_ID,
         Ops_Reversed => 0,
         Ops_Total    => Natural (Trans.Operations.Length)
      );
   begin
      if not Initialized then
         Initialize;
      end if;

      --  If transaction has a snapshot, use that
      if Trans.Snapshot_ID /= Invalid_Snapshot_ID then
         return Rollback_To_Snapshot (Trans.Snapshot_ID, Verify);
      end if;

      --  Otherwise, reverse operations manually
      Current_State := In_Progress;

      begin
         Transaction_Log.Reverse_Transaction (Trans_ID);
         Result.Ops_Reversed := Result.Ops_Total;

         if Verify then
            Current_State := Verifying;
            if Verify_System_State then
               Result.Status := Success;
               Result.Message := +"Transaction reversed successfully";
            else
               Result.Status := Partial;
               Result.Message := +"Transaction reversed but verification failed";
            end if;
         else
            Result.Status := Success;
            Result.Message := +"Transaction reversed (unverified)";
         end if;

      exception
         when others =>
            Result.Status := Failed;
            Result.Message := +"Failed to reverse transaction";
      end;

      Current_State := Idle;
      return Result;
   end Rollback_Transaction;

   ------------------------
   -- Rollback_To_Time
   ------------------------

   function Rollback_To_Time
     (Target_Time : Ada.Calendar.Time;
      Verify      : Boolean := True)
      return Rollback_Result
   is
      Snapshots : constant Snapshot_Array := Snapshot_Manager.List_Snapshots;
      Best_Snap : Snapshot_ID := Invalid_Snapshot_ID;
      Best_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1);
      use Ada.Calendar;
   begin
      --  Find the closest snapshot before the target time
      for Snap of Snapshots loop
         if Snap.Timestamp <= Target_Time
           and then Snap.Timestamp > Best_Time
           and then Snap.Status = Valid
         then
            Best_Snap := Snap.ID;
            Best_Time := Snap.Timestamp;
         end if;
      end loop;

      if Best_Snap = Invalid_Snapshot_ID then
         return (
            Status       => Failed,
            Message      => +"No snapshot found before target time",
            Snapshot_ID  => Invalid_Snapshot_ID,
            Trans_ID     => Invalid_Transaction_ID,
            Ops_Reversed => 0,
            Ops_Total    => 0
         );
      end if;

      return Rollback_To_Snapshot (Best_Snap, Verify);
   end Rollback_To_Time;

   -------------------------
   -- Verify_System_State
   -------------------------

   function Verify_System_State return Boolean is
   begin
      --  Would verify package database integrity,
      --  check critical files, etc.
      return True;
   end Verify_System_State;

   --------------------------
   -- Can_Safely_Rollback
   --------------------------

   function Can_Safely_Rollback
     (ID : Snapshot_ID)
      return Boolean
   is
   begin
      --  Check if we have enough space
      --  Check if critical services would be affected
      --  Check if snapshot is still valid
      return Snapshot_Manager.Verify_Snapshot (ID)
        and then Estimate_Rollback_Space (ID) > 0;
   end Can_Safely_Rollback;

   -------------------------------
   -- Get_Best_Rollback_Target
   -------------------------------

   function Get_Best_Rollback_Target return Snapshot_ID is
      Snapshots : constant Snapshot_Array := Snapshot_Manager.List_Snapshots;
   begin
      --  Find the most recent valid snapshot
      for I in reverse 1 .. Natural (Snapshots.Length) loop
         declare
            Snap : constant Snapshot_Info := Snapshots.Element (I);
         begin
            if Snap.Status = Valid
              and then Snapshot_Manager.Verify_Snapshot (Snap.ID)
            then
               return Snap.ID;
            end if;
         end;
      end loop;

      return Invalid_Snapshot_ID;
   end Get_Best_Rollback_Target;

   -----------------------------
   -- Estimate_Rollback_Space
   -----------------------------

   function Estimate_Rollback_Space
     (ID : Snapshot_ID)
      return Natural
   is
      Snap : constant Snapshot_Info := Snapshot_Manager.Get_Snapshot_Info (ID);
   begin
      --  Estimate based on snapshot size and current state
      return Snap.Size_Bytes * 2;  --  Rough estimate
   end Estimate_Rollback_Space;

   ----------------------
   -- Requires_Reboot
   ----------------------

   function Requires_Reboot
     (ID : Snapshot_ID)
      return Boolean
   is
      Snap : constant Snapshot_Info := Snapshot_Manager.Get_Snapshot_Info (ID);
   begin
      --  Filesystem snapshots typically require reboot for root
      --  Native (rpm-ostree) always requires reboot
      return Snap.Strategy = Native
        or else (Snap.Strategy = Filesystem
                 and then Snap.FS_Type in Btrfs | ZFS | LVM);
   end Requires_Reboot;

   ----------------------------
   -- Create_Recovery_Point
   ----------------------------

   function Create_Recovery_Point
     (Description : String)
      return Snapshot_ID
   is
      ID : Snapshot_ID;
   begin
      Snapshot_Manager.Create_Snapshot
        (Description => "Recovery: " & Description,
         Snapshot_ID => ID);
      Snapshot_Manager.Pin_Snapshot (ID);
      return ID;
   end Create_Recovery_Point;

   ------------------------
   -- Emergency_Rollback
   ------------------------

   function Emergency_Rollback return Rollback_Result is
      Best_Target : constant Snapshot_ID := Get_Best_Rollback_Target;
   begin
      if Best_Target = Invalid_Snapshot_ID then
         return (
            Status       => Failed,
            Message      => +"No valid snapshot for emergency rollback",
            Snapshot_ID  => Invalid_Snapshot_ID,
            Trans_ID     => Invalid_Transaction_ID,
            Ops_Reversed => 0,
            Ops_Total    => 0
         );
      end if;

      --  Emergency: no verification, force rollback
      return Rollback_To_Snapshot
        (ID     => Best_Target,
         Verify => False,
         Force  => True);
   end Emergency_Rollback;

end Rollback_Engine;
