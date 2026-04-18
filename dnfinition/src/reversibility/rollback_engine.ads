-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Rollback_Engine - Coordinate rollback operations with safety guarantees
pragma Ada_2022;
pragma SPARK_Mode (On);

with Snapshot_Types;    use Snapshot_Types;
with Transaction_Types; use Transaction_Types;

package Rollback_Engine
  with SPARK_Mode
is

   --  Rollback result status
   type Rollback_Status is (
      Success,            --  Rollback completed successfully
      Partial,            --  Some operations rolled back
      Failed,             --  Rollback failed
      Requires_Reboot,    --  Rollback requires reboot to complete
      Not_Needed          --  No rollback necessary
   );

   --  Rollback result record
   type Rollback_Result is record
      Status       : Rollback_Status := Failed;
      Message      : Ada.Strings.Unbounded.Unbounded_String;
      Snapshot_ID  : Snapshot_ID := Invalid_Snapshot_ID;
      Trans_ID     : Transaction_ID := Invalid_Transaction_ID;
      Ops_Reversed : Natural := 0;
      Ops_Total    : Natural := 0;
   end record;

   --  Initialize the rollback engine
   procedure Initialize
     with Global => null;

   --  Rollback to a specific snapshot
   function Rollback_To_Snapshot
     (ID         : Snapshot_ID;
      Verify     : Boolean := True;
      Force      : Boolean := False)
      return Rollback_Result
     with Global => null,
          Pre    => Snapshot_Manager.Snapshot_Exists (ID);

   --  Rollback the last transaction
   function Rollback_Last_Transaction
     return Rollback_Result
     with Global => null;

   --  Rollback a specific transaction
   function Rollback_Transaction
     (Trans_ID : Transaction_ID;
      Verify   : Boolean := True)
      return Rollback_Result
     with Global => null,
          Pre    => Transaction_Log.Transaction_Exists (Trans_ID);

   --  Rollback to a specific point in time
   function Rollback_To_Time
     (Target_Time : Ada.Calendar.Time;
      Verify      : Boolean := True)
      return Rollback_Result
     with Global => null;

   --  Verify current system state matches expected
   function Verify_System_State return Boolean
     with Global => null;

   --  Verify a rollback can be safely performed
   function Can_Safely_Rollback
     (ID : Snapshot_ID)
      return Boolean
     with Global => null;

   --  Get the best rollback target for recovery
   function Get_Best_Rollback_Target return Snapshot_ID
     with Global => null;

   --  Estimate space required for rollback
   function Estimate_Rollback_Space
     (ID : Snapshot_ID)
      return Natural
     with Global => null;

   --  Check if reboot is required after rollback
   function Requires_Reboot
     (ID : Snapshot_ID)
      return Boolean
     with Global => null;

   --  Create recovery snapshot before risky operation
   function Create_Recovery_Point
     (Description : String)
      return Snapshot_ID
     with Global => null,
          Post   => Snapshot_Manager.Snapshot_Exists
                      (Create_Recovery_Point'Result);

   --  Emergency rollback (minimal verification)
   function Emergency_Rollback return Rollback_Result
     with Global => null;

private

   --  Track current rollback state
   type Rollback_State is (
      Idle,
      Preparing,
      In_Progress,
      Verifying,
      Completing
   );

   Current_State : Rollback_State := Idle
     with Part_Of => Rollback_Engine;

   --  Helper to use Unbounded_String in SPARK context
   use Ada.Strings.Unbounded;

   function "+" (S : String) return Unbounded_String
     renames To_Unbounded_String;

end Rollback_Engine;
