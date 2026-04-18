-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Snapshot_Types - Types for system snapshot management
pragma Ada_2022;
pragma SPARK_Mode (On);

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar;
with Ada.Containers.Vectors;

package Snapshot_Types is

   --  Snapshot strategy enumeration
   type Snapshot_Strategy is (
      Native,           --  Use package manager's built-in (rpm-ostree, zypper)
      Filesystem,       --  Use filesystem snapshots (btrfs, ZFS, LVM)
      Transaction_Log,  --  Log operations for replay/reverse
      Container_Image   --  Save entire system as container
   );

   --  Filesystem type for filesystem-based snapshots
   type Filesystem_Type is (
      Unknown,
      Btrfs,
      ZFS,
      LVM,
      Ext4,
      XFS,
      APFS,        --  macOS
      NTFS         --  Windows
   );

   --  Snapshot status
   type Snapshot_Status is (
      Creating,     --  Snapshot in progress
      Valid,        --  Snapshot complete and verified
      Invalid,      --  Snapshot failed verification
      Restoring,    --  Rollback in progress
      Expired,      --  Marked for cleanup
      Pinned        --  Protected from cleanup
   );

   --  Snapshot identifier
   subtype Snapshot_ID is Natural;

   --  Invalid snapshot ID constant
   Invalid_Snapshot_ID : constant Snapshot_ID := 0;

   --  Snapshot information record
   type Snapshot_Info is record
      ID          : Snapshot_ID := Invalid_Snapshot_ID;
      Description : Unbounded_String;
      Path        : Unbounded_String;
      Timestamp   : Ada.Calendar.Time;
      Strategy    : Snapshot_Strategy := Filesystem;
      FS_Type     : Filesystem_Type := Unknown;
      Status      : Snapshot_Status := Creating;
      Size_Bytes  : Natural := 0;
      Is_Pinned   : Boolean := False;
   end record
     with Dynamic_Predicate =>
       (if Snapshot_Info.Strategy = Filesystem then
          Snapshot_Info.FS_Type /= Unknown);

   --  Null snapshot constant
   Null_Snapshot : constant Snapshot_Info := (
      ID          => Invalid_Snapshot_ID,
      Description => Null_Unbounded_String,
      Path        => Null_Unbounded_String,
      Timestamp   => Ada.Calendar.Time_Of (1970, 1, 1),
      Strategy    => Transaction_Log,
      FS_Type     => Unknown,
      Status      => Invalid,
      Size_Bytes  => 0,
      Is_Pinned   => False
   );

   --  Snapshot vector
   package Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Snapshot_Info);

   subtype Snapshot_Array is Snapshot_Vectors.Vector;

   --  Snapshot configuration
   type Snapshot_Config is record
      --  Strategy priority (try in order)
      Primary_Strategy   : Snapshot_Strategy := Native;
      Fallback_Strategy  : Snapshot_Strategy := Filesystem;
      Last_Resort        : Snapshot_Strategy := Transaction_Log;

      --  Retention settings
      Keep_Count         : Positive := 10;
      Keep_Days          : Natural := 30;
      Auto_Cleanup       : Boolean := True;

      --  Paths
      Snapshot_Base_Path : Unbounded_String;
      Metadata_DB_Path   : Unbounded_String;
      Transaction_Log_Path : Unbounded_String;

      --  Pre-operation snapshots
      Snapshot_Before_Install    : Boolean := True;
      Snapshot_Before_Upgrade    : Boolean := True;
      Snapshot_Before_Remove     : Boolean := False;
      Snapshot_Before_OS_Upgrade : Boolean := True;  --  Always recommended
   end record;

   --  Default configuration
   Default_Snapshot_Config : constant Snapshot_Config := (
      Primary_Strategy   => Native,
      Fallback_Strategy  => Filesystem,
      Last_Resort        => Transaction_Log,
      Keep_Count         => 10,
      Keep_Days          => 30,
      Auto_Cleanup       => True,
      Snapshot_Base_Path => To_Unbounded_String ("/.snapshots/dnfinition"),
      Metadata_DB_Path   => To_Unbounded_String
                              ("/var/lib/dnfinition/snapshots.db"),
      Transaction_Log_Path => To_Unbounded_String
                                ("/var/lib/dnfinition/transactions.log"),
      Snapshot_Before_Install    => True,
      Snapshot_Before_Upgrade    => True,
      Snapshot_Before_Remove     => False,
      Snapshot_Before_OS_Upgrade => True
   );

   --  Helper functions
   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function Is_Valid (Snap : Snapshot_Info) return Boolean is
     (Snap.ID /= Invalid_Snapshot_ID and Snap.Status = Valid);

   function Strategy_Name (S : Snapshot_Strategy) return String is
     (case S is
         when Native          => "native",
         when Filesystem      => "filesystem",
         when Transaction_Log => "transaction-log",
         when Container_Image => "container");

   function Filesystem_Name (F : Filesystem_Type) return String is
     (case F is
         when Unknown => "unknown",
         when Btrfs   => "btrfs",
         when ZFS     => "zfs",
         when LVM     => "lvm",
         when Ext4    => "ext4",
         when XFS     => "xfs",
         when APFS    => "apfs",
         when NTFS    => "ntfs");

end Snapshot_Types;
