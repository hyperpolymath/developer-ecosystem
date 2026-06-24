-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Filesystem_Detect - Implementation
pragma Ada_2022;

with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Detection;

package body Filesystem_Detect is

   --  Check if a command exists
   function Command_Exists (Cmd : String) return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path (Cmd);
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
         return True;
      end if;
      return False;
   end Command_Exists;

   -----------------------
   -- Detect_Filesystem
   -----------------------

   function Detect_Filesystem (Path : String) return Filesystem_Type is
      use Ada.Strings.Fixed;
      File : Ada.Text_IO.File_Type;
      Target_Path : constant String :=
        (if Path = "" then "/" else Path);
   begin
      --  Parse /proc/mounts to find the filesystem type
      if not Ada.Directories.Exists ("/proc/mounts") then
         --  Fallback for non-Linux systems
         if Ada.Directories.Exists ("/etc/fstab") then
            --  Try to parse fstab (simplified)
            return Unknown;
         end if;
         return Unknown;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");

      --  Find the mount point that best matches our path
      declare
         Best_Match    : Unbounded_String := Null_Unbounded_String;
         Best_FS_Type  : Filesystem_Type := Unknown;
         Best_Length   : Natural := 0;
      begin
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line        : constant String := Ada.Text_IO.Get_Line (File);
               Space1      : constant Natural := Index (Line, " ");
               Rest        : constant String :=
                 (if Space1 > 0
                  then Line (Space1 + 1 .. Line'Last)
                  else "");
               Space2      : constant Natural := Index (Rest, " ");
               Mount_Point : constant String :=
                 (if Space2 > 0
                  then Rest (Rest'First .. Space2 - 1)
                  else "");
               Rest2       : constant String :=
                 (if Space2 > 0
                  then Rest (Space2 + 1 .. Rest'Last)
                  else "");
               Space3      : constant Natural := Index (Rest2, " ");
               FS_Type_Str : constant String :=
                 (if Space3 > 0
                  then Rest2 (Rest2'First .. Space3 - 1)
                  else "");
            begin
               --  Check if this mount point is a prefix of our target
               if Mount_Point'Length > 0
                 and then Mount_Point'Length <= Target_Path'Length
                 and then Target_Path (Target_Path'First ..
                            Target_Path'First + Mount_Point'Length - 1)
                          = Mount_Point
                 and then Mount_Point'Length > Best_Length
               then
                  Best_Length := Mount_Point'Length;
                  Best_Match := +Mount_Point;

                  --  Parse filesystem type
                  if FS_Type_Str = "btrfs" then
                     Best_FS_Type := Btrfs;
                  elsif FS_Type_Str = "zfs" then
                     Best_FS_Type := ZFS;
                  elsif Index (FS_Type_Str, "lvm") > 0 then
                     Best_FS_Type := LVM;
                  elsif FS_Type_Str = "ext4" then
                     Best_FS_Type := Ext4;
                  elsif FS_Type_Str = "xfs" then
                     Best_FS_Type := XFS;
                  elsif FS_Type_Str = "apfs" then
                     Best_FS_Type := APFS;
                  elsif FS_Type_Str = "ntfs" or FS_Type_Str = "ntfs3" then
                     Best_FS_Type := NTFS;
                  else
                     Best_FS_Type := Unknown;
                  end if;
               end if;
            end;
         end loop;

         Ada.Text_IO.Close (File);
         return Best_FS_Type;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return Unknown;
   end Detect_Filesystem;

   ----------------------------
   -- Detect_Root_Filesystem
   ----------------------------

   function Detect_Root_Filesystem return Filesystem_Type is
   begin
      return Detect_Filesystem ("/");
   end Detect_Root_Filesystem;

   --------------------
   -- Get_Mount_Info
   --------------------

   function Get_Mount_Info (Path : String) return Mount_Info is
      use Ada.Strings.Fixed;
      File   : Ada.Text_IO.File_Type;
      Result : Mount_Info := (
         Mount_Point  => Null_Unbounded_String,
         Device       => Null_Unbounded_String,
         FS_Type      => Unknown,
         Options      => Null_Unbounded_String,
         Can_Snapshot => False
      );
      Target_Path : constant String :=
        (if Path = "" then "/" else Path);
      Best_Length : Natural := 0;
   begin
      if not Ada.Directories.Exists ("/proc/mounts") then
         return Result;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line        : constant String := Ada.Text_IO.Get_Line (File);
            Space1      : constant Natural := Index (Line, " ");
            Device      : constant String :=
              (if Space1 > 0
               then Line (Line'First .. Space1 - 1)
               else "");
            Rest        : constant String :=
              (if Space1 > 0
               then Line (Space1 + 1 .. Line'Last)
               else "");
            Space2      : constant Natural := Index (Rest, " ");
            Mount_Point : constant String :=
              (if Space2 > 0
               then Rest (Rest'First .. Space2 - 1)
               else "");
            Rest2       : constant String :=
              (if Space2 > 0
               then Rest (Space2 + 1 .. Rest'Last)
               else "");
            Space3      : constant Natural := Index (Rest2, " ");
            FS_Type_Str : constant String :=
              (if Space3 > 0
               then Rest2 (Rest2'First .. Space3 - 1)
               else "");
            Rest3       : constant String :=
              (if Space3 > 0
               then Rest2 (Space3 + 1 .. Rest2'Last)
               else "");
            Space4      : constant Natural := Index (Rest3, " ");
            Options_Str : constant String :=
              (if Space4 > 0
               then Rest3 (Rest3'First .. Space4 - 1)
               else Rest3);
         begin
            --  Check if this mount point matches
            if Mount_Point'Length > 0
              and then Mount_Point'Length <= Target_Path'Length
              and then Target_Path (Target_Path'First ..
                         Target_Path'First + Mount_Point'Length - 1)
                       = Mount_Point
              and then Mount_Point'Length > Best_Length
            then
               Best_Length := Mount_Point'Length;
               Result.Mount_Point := +Mount_Point;
               Result.Device := +Device;
               Result.Options := +Options_Str;

               --  Parse filesystem type
               if FS_Type_Str = "btrfs" then
                  Result.FS_Type := Btrfs;
                  Result.Can_Snapshot := Btrfs_Tools_Available;
               elsif FS_Type_Str = "zfs" then
                  Result.FS_Type := ZFS;
                  Result.Can_Snapshot := ZFS_Tools_Available;
               elsif Index (Device, "/dev/mapper/") > 0
                 or else Index (Device, "/dev/dm-") > 0
               then
                  Result.FS_Type := LVM;
                  Result.Can_Snapshot := LVM_Tools_Available;
               elsif FS_Type_Str = "ext4" then
                  Result.FS_Type := Ext4;
               elsif FS_Type_Str = "xfs" then
                  Result.FS_Type := XFS;
               else
                  Result.FS_Type := Unknown;
               end if;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return Result;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return Result;
   end Get_Mount_Info;

   --------------------------
   -- Get_Btrfs_Subvolume
   --------------------------

   function Get_Btrfs_Subvolume (Path : String) return String is
      pragma Unreferenced (Path);
   begin
      --  Would need to run: btrfs subvolume show <path>
      --  For now, return default root subvolume indicator
      return "@";
   end Get_Btrfs_Subvolume;

   ----------------------
   -- Get_ZFS_Dataset
   ----------------------

   function Get_ZFS_Dataset (Path : String) return String is
      Info : constant Mount_Info := Get_Mount_Info (Path);
   begin
      --  For ZFS, the device field is typically the dataset name
      return To_String (Info.Device);
   end Get_ZFS_Dataset;

   ---------------------
   -- Get_LVM_Volume
   ---------------------

   function Get_LVM_Volume (Path : String) return String is
      Info : constant Mount_Info := Get_Mount_Info (Path);
   begin
      return To_String (Info.Device);
   end Get_LVM_Volume;

   ----------------------------
   -- Btrfs_Tools_Available
   ----------------------------

   function Btrfs_Tools_Available return Boolean is
   begin
      return Command_Exists ("btrfs");
   end Btrfs_Tools_Available;

   --------------------------
   -- ZFS_Tools_Available
   --------------------------

   function ZFS_Tools_Available return Boolean is
   begin
      return Command_Exists ("zfs") and then Command_Exists ("zpool");
   end ZFS_Tools_Available;

   --------------------------
   -- LVM_Tools_Available
   --------------------------

   function LVM_Tools_Available return Boolean is
   begin
      return Command_Exists ("lvcreate")
        and then Command_Exists ("lvremove")
        and then Command_Exists ("lvscan");
   end LVM_Tools_Available;

   ---------------------------------
   -- Get_Best_Snapshot_Strategy
   ---------------------------------

   function Get_Best_Snapshot_Strategy return Snapshot_Strategy is
      Root_FS : constant Filesystem_Type := Detect_Root_Filesystem;
   begin
      --  First, check if the package manager has native snapshots
      if Detection.PM_Has_Native_Snapshots (Detection.Detect_Package_Manager)
      then
         return Native;
      end if;

      --  Then check filesystem capabilities
      case Root_FS is
         when Btrfs =>
            if Btrfs_Tools_Available then
               return Filesystem;
            end if;

         when ZFS =>
            if ZFS_Tools_Available then
               return Filesystem;
            end if;

         when LVM =>
            if LVM_Tools_Available then
               return Filesystem;
            end if;

         when others =>
            null;
      end case;

      --  Fallback to transaction log
      return Transaction_Log;
   end Get_Best_Snapshot_Strategy;

end Filesystem_Detect;
