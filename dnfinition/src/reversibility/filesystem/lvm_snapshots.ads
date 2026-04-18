-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- LVM_Snapshots - LVM logical volume snapshot operations
pragma Ada_2022;
pragma SPARK_Mode (On);

with Snapshot_Types; use Snapshot_Types;

package LVM_Snapshots
  with SPARK_Mode
is

   --  Exception for LVM operations
   LVM_Error : exception;

   --  Check if LVM tools are available and root is on LVM
   function Is_Available return Boolean;

   --  Get the root logical volume path
   function Get_Root_LV return String;

   --  Get the volume group containing root
   function Get_Root_VG return String;

   --  Create a snapshot of a logical volume
   procedure Create_Snapshot
     (Source_LV     : String;
      Snapshot_Name : String;
      Size_Percent  : Positive := 20);

   --  Delete a snapshot
   procedure Delete_Snapshot (Snapshot_LV : String);

   --  List all snapshots in a volume group
   function List_Snapshots (VG_Name : String) return Snapshot_Array;

   --  Get snapshot info
   function Get_Snapshot_Info (Snapshot_LV : String) return Snapshot_Info;

   --  Rollback to a snapshot (merge snapshot into origin)
   procedure Rollback_To_Snapshot (Snapshot_LV : String);

   --  Verify snapshot integrity
   function Verify_Snapshot (Snapshot_LV : String) return Boolean;

   --  Get snapshot usage percentage
   function Get_Snapshot_Usage (Snapshot_LV : String) return Natural;

   --  Extend a snapshot's COW space
   procedure Extend_Snapshot
     (Snapshot_LV  : String;
      Add_Size_MB  : Positive);

   --  Check if a path is an LVM logical volume
   function Is_LV (Path : String) return Boolean;

   --  Get free space in volume group
   function Get_VG_Free_Space (VG_Name : String) return Natural;

private

   --  Execute an LVM command and return output
   function Run_LVM_Command (Command : String) return String;

   --  Execute an LVM command, raise on failure
   procedure Run_LVM_Command_Checked (Command : String);

end LVM_Snapshots;
