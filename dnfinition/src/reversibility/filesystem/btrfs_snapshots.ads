-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Btrfs_Snapshots - Btrfs filesystem snapshot operations
pragma Ada_2022;
pragma SPARK_Mode (On);

with Snapshot_Types; use Snapshot_Types;

package Btrfs_Snapshots
  with SPARK_Mode
is

   --  Exception for btrfs operations
   Btrfs_Error : exception;

   --  Check if btrfs tools are available and root is btrfs
   function Is_Available return Boolean;

   --  Get the default subvolume
   function Get_Default_Subvolume return String;

   --  Get the root subvolume path
   function Get_Root_Subvolume return String;

   --  Create a read-only snapshot
   procedure Create_Snapshot
     (Source_Path   : String;
      Snapshot_Path : String;
      Read_Only     : Boolean := True);

   --  Delete a snapshot
   procedure Delete_Snapshot (Snapshot_Path : String);

   --  List all snapshots in a directory
   function List_Snapshots (Base_Path : String) return Snapshot_Array;

   --  Get snapshot info
   function Get_Snapshot_Info (Snapshot_Path : String) return Snapshot_Info;

   --  Rollback to a snapshot (replaces root subvolume)
   procedure Rollback_To_Snapshot
     (Snapshot_Path : String;
      Backup_Old    : Boolean := True);

   --  Verify snapshot integrity
   function Verify_Snapshot (Snapshot_Path : String) return Boolean;

   --  Get snapshot size (exclusive data)
   function Get_Snapshot_Size (Snapshot_Path : String) return Natural;

   --  Check if a path is a btrfs subvolume
   function Is_Subvolume (Path : String) return Boolean;

   --  Create the snapshot directory structure
   procedure Initialize_Snapshot_Dir (Base_Path : String);

private

   --  Default snapshot base path
   Default_Snapshot_Path : constant String := "/.snapshots/dnfinition";

   --  Execute a btrfs command and return output
   function Run_Btrfs_Command
     (Args : String)
      return String;

   --  Execute a btrfs command, raise on failure
   procedure Run_Btrfs_Command_Checked (Args : String);

end Btrfs_Snapshots;
