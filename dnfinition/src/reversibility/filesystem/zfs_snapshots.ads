-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- ZFS_Snapshots - ZFS filesystem snapshot operations
pragma Ada_2022;
pragma SPARK_Mode (On);

with Snapshot_Types; use Snapshot_Types;

package ZFS_Snapshots
  with SPARK_Mode
is

   --  Exception for ZFS operations
   ZFS_Error : exception;

   --  Check if ZFS tools are available and root is ZFS
   function Is_Available return Boolean;

   --  Get the root dataset name
   function Get_Root_Dataset return String;

   --  Create a snapshot of a dataset
   procedure Create_Snapshot
     (Dataset       : String;
      Snapshot_Name : String;
      Recursive     : Boolean := False);

   --  Delete a snapshot
   procedure Delete_Snapshot
     (Snapshot : String;
      Recursive : Boolean := False);

   --  List all snapshots for a dataset
   function List_Snapshots (Dataset : String) return Snapshot_Array;

   --  Get snapshot info
   function Get_Snapshot_Info (Snapshot : String) return Snapshot_Info;

   --  Rollback to a snapshot
   procedure Rollback_To_Snapshot
     (Snapshot          : String;
      Destroy_Later     : Boolean := True;
      Force             : Boolean := False);

   --  Clone a snapshot to a new dataset
   procedure Clone_Snapshot
     (Snapshot     : String;
      New_Dataset  : String);

   --  Verify snapshot integrity
   function Verify_Snapshot (Snapshot : String) return Boolean;

   --  Get snapshot size (referenced)
   function Get_Snapshot_Size (Snapshot : String) return Natural;

   --  Check if a name is a valid ZFS snapshot
   function Is_Snapshot (Name : String) return Boolean;

   --  Get ZFS pool health status
   function Get_Pool_Health (Pool_Name : String) return String;

   --  Hold a snapshot (prevent deletion)
   procedure Hold_Snapshot
     (Snapshot : String;
      Tag      : String := "dnfinition");

   --  Release a snapshot hold
   procedure Release_Snapshot
     (Snapshot : String;
      Tag      : String := "dnfinition");

private

   --  Execute a ZFS command and return output
   function Run_ZFS_Command (Args : String) return String;

   --  Execute a ZFS command, raise on failure
   procedure Run_ZFS_Command_Checked (Args : String);

end ZFS_Snapshots;
