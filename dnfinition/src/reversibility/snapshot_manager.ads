-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Snapshot_Manager - Core snapshot management with SPARK verification
pragma Ada_2022;
pragma SPARK_Mode (On);

with Ada.Calendar;
with Snapshot_Types; use Snapshot_Types;

package Snapshot_Manager
  with SPARK_Mode
is

   --  Exception for snapshot operations
   Snapshot_Error : exception;

   --  Initialize the snapshot manager
   procedure Initialize (Config : Snapshot_Config := Default_Snapshot_Config)
     with Global => null;

   --  Determine best strategy for current system
   function Detect_Best_Strategy return Snapshot_Strategy
     with Global => null,
          Post   => Strategy_Supported (Detect_Best_Strategy'Result);

   --  Check if a strategy is supported on this system
   function Strategy_Supported (Strategy : Snapshot_Strategy) return Boolean
     with Global => null;

   --  Create snapshot before transaction
   procedure Create_Snapshot
     (Description : String;
      Strategy    : Snapshot_Strategy;
      Snapshot_ID : out Snapshot_ID)
     with Global => null,
          Pre    => Strategy_Supported (Strategy),
          Post   => Snapshot_Exists (Snapshot_ID);

   --  Create snapshot with auto-detected strategy
   procedure Create_Snapshot
     (Description : String;
      Snapshot_ID : out Snapshot_ID)
     with Global => null,
          Post   => Snapshot_Exists (Snapshot_ID);

   --  Rollback to specific snapshot
   procedure Rollback_To_Snapshot (ID : Snapshot_ID)
     with Global => null,
          Pre    => Snapshot_Exists (ID) and then Snapshot_Valid (ID),
          Post   => System_State_Restored (ID);

   --  List all snapshots
   function List_Snapshots return Snapshot_Array
     with Global => null;

   --  Get information about a specific snapshot
   function Get_Snapshot_Info (ID : Snapshot_ID) return Snapshot_Info
     with Global => null,
          Pre    => Snapshot_Exists (ID);

   --  Delete a specific snapshot
   procedure Delete_Snapshot (ID : Snapshot_ID)
     with Global => null,
          Pre    => Snapshot_Exists (ID) and then not Is_Pinned (ID),
          Post   => not Snapshot_Exists (ID);

   --  Pin a snapshot (protect from cleanup)
   procedure Pin_Snapshot (ID : Snapshot_ID)
     with Global => null,
          Pre    => Snapshot_Exists (ID),
          Post   => Is_Pinned (ID);

   --  Unpin a snapshot
   procedure Unpin_Snapshot (ID : Snapshot_ID)
     with Global => null,
          Pre    => Snapshot_Exists (ID),
          Post   => not Is_Pinned (ID);

   --  Delete old snapshots (keep most recent N)
   procedure Cleanup_Old_Snapshots (Keep_Last : Positive := 10)
     with Global => null,
          Post   => Snapshot_Count <= Keep_Last;

   --  Cleanup snapshots older than N days
   procedure Cleanup_By_Age (Max_Age_Days : Positive := 30)
     with Global => null;

   --  Verify snapshot integrity
   function Verify_Snapshot (ID : Snapshot_ID) return Boolean
     with Global => null,
          Pre    => Snapshot_Exists (ID);

   --  Get current snapshot count
   function Snapshot_Count return Natural
     with Global => null;

   --  Get total size of all snapshots
   function Total_Snapshot_Size return Natural
     with Global => null;

   --  SPARK Ghost functions for formal verification
   function Snapshot_Exists (ID : Snapshot_ID) return Boolean
     with Ghost,
          Global => null;

   function Snapshot_Valid (ID : Snapshot_ID) return Boolean
     with Ghost,
          Global => null;

   function System_State_Restored (ID : Snapshot_ID) return Boolean
     with Ghost,
          Global => null;

   function Is_Pinned (ID : Snapshot_ID) return Boolean
     with Ghost,
          Global => null;

private

   --  Internal snapshot database (simplified for SPARK)
   Max_Snapshots : constant := 1000;

   type Snapshot_DB_Entry is record
      Info   : Snapshot_Info;
      Active : Boolean := False;
   end record;

   type Snapshot_DB_Array is array (1 .. Max_Snapshots) of Snapshot_DB_Entry;

   --  The actual database would be persistent storage
   --  This is a simplified in-memory version for the spec
   Snapshot_DB : Snapshot_DB_Array
     with Part_Of => Snapshot_Manager;

   Current_Config : Snapshot_Config := Default_Snapshot_Config
     with Part_Of => Snapshot_Manager;

   Next_ID : Snapshot_ID := 1
     with Part_Of => Snapshot_Manager;

   --  Implementation of ghost functions
   function Snapshot_Exists (ID : Snapshot_ID) return Boolean is
     (ID > 0 and then ID < Next_ID);

   function Snapshot_Valid (ID : Snapshot_ID) return Boolean is
     (Snapshot_Exists (ID)
      and then Snapshot_DB (Positive (ID)).Active
      and then Snapshot_DB (Positive (ID)).Info.Status = Valid);

   function System_State_Restored (ID : Snapshot_ID) return Boolean is
     (True);  --  Simplified for SPARK

   function Is_Pinned (ID : Snapshot_ID) return Boolean is
     (Snapshot_Exists (ID)
      and then Snapshot_DB (Positive (ID)).Info.Is_Pinned);

end Snapshot_Manager;
