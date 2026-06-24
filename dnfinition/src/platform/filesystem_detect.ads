-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Filesystem_Detect - Detect filesystem types and snapshot capabilities
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Snapshot_Types; use Snapshot_Types;

package Filesystem_Detect is

   --  Mount point information
   type Mount_Info is record
      Mount_Point : Unbounded_String;
      Device      : Unbounded_String;
      FS_Type     : Filesystem_Type := Unknown;
      Options     : Unbounded_String;
      Can_Snapshot : Boolean := False;
   end record;

   --  Detect filesystem type for a path
   function Detect_Filesystem (Path : String) return Filesystem_Type;

   --  Detect filesystem for root
   function Detect_Root_Filesystem return Filesystem_Type;

   --  Check if a filesystem supports snapshots
   function Supports_Snapshots (FS : Filesystem_Type) return Boolean is
     (FS in Btrfs | ZFS | LVM);

   --  Get mount info for a path
   function Get_Mount_Info (Path : String) return Mount_Info;

   --  Get the btrfs subvolume for a path
   function Get_Btrfs_Subvolume (Path : String) return String;

   --  Get the ZFS dataset for a path
   function Get_ZFS_Dataset (Path : String) return String;

   --  Get the LVM logical volume for a path
   function Get_LVM_Volume (Path : String) return String;

   --  Check if btrfs tools are available
   function Btrfs_Tools_Available return Boolean;

   --  Check if ZFS tools are available
   function ZFS_Tools_Available return Boolean;

   --  Check if LVM tools are available
   function LVM_Tools_Available return Boolean;

   --  Get the best available snapshot strategy
   function Get_Best_Snapshot_Strategy return Snapshot_Strategy;

   --  Helper
   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

end Filesystem_Detect;
