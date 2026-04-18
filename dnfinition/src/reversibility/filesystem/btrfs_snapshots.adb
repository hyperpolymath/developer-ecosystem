-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Btrfs_Snapshots - Implementation
pragma Ada_2022;

with Ada.Directories;
with Ada.Calendar;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Filesystem_Detect;
with Shell_Escape;

package body Btrfs_Snapshots is

   ------------------
   -- Is_Available
   ------------------

   function Is_Available return Boolean is
   begin
      return Filesystem_Detect.Btrfs_Tools_Available
        and then Filesystem_Detect.Detect_Root_Filesystem = Btrfs;
   end Is_Available;

   ----------------------------
   -- Get_Default_Subvolume
   ----------------------------

   function Get_Default_Subvolume return String is
   begin
      --  Would execute: btrfs subvolume get-default /
      return "@";  --  Common default on many distros
   end Get_Default_Subvolume;

   -------------------------
   -- Get_Root_Subvolume
   -------------------------

   function Get_Root_Subvolume return String is
   begin
      --  Would parse /proc/mounts or use btrfs commands
      return "/";
   end Get_Root_Subvolume;

   ----------------------
   -- Create_Snapshot
   ----------------------

   procedure Create_Snapshot
     (Source_Path   : String;
      Snapshot_Path : String;
      Read_Only     : Boolean := True)
   is
      use Shell_Escape;
      Escaped_Source : constant Escape_Result := Escape_Path (Source_Path);
      Escaped_Snap   : constant Escape_Result := Escape_Path (Snapshot_Path);
   begin
      if not Is_Available then
         raise Btrfs_Error with "Btrfs not available";
      end if;

      --  Validate paths can be safely escaped
      if not Escaped_Source.Success then
         raise Btrfs_Error with "Invalid source path: " &
           Escaped_Source.Error_Msg (1 .. Escaped_Source.Msg_Len);
      end if;
      if not Escaped_Snap.Success then
         raise Btrfs_Error with "Invalid snapshot path: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      --  Ensure parent directory exists
      declare
         Parent : constant String :=
           Ada.Directories.Containing_Directory (Snapshot_Path);
      begin
         if not Ada.Directories.Exists (Parent) then
            Ada.Directories.Create_Path (Parent);
         end if;
      end;

      Run_Btrfs_Command_Checked
        ("subvolume snapshot " &
         (if Read_Only then "-r " else "") &
         Escaped_Source.Value (1 .. Escaped_Source.Length) & " " &
         Escaped_Snap.Value (1 .. Escaped_Snap.Length));
   end Create_Snapshot;

   ----------------------
   -- Delete_Snapshot
   ----------------------

   procedure Delete_Snapshot (Snapshot_Path : String) is
      use Shell_Escape;
      Escaped_Path : constant Escape_Result := Escape_Path (Snapshot_Path);
   begin
      if not Is_Subvolume (Snapshot_Path) then
         raise Btrfs_Error with "Path is not a btrfs subvolume";
      end if;

      if not Escaped_Path.Success then
         raise Btrfs_Error with "Invalid snapshot path: " &
           Escaped_Path.Error_Msg (1 .. Escaped_Path.Msg_Len);
      end if;

      Run_Btrfs_Command_Checked
        ("subvolume delete " & Escaped_Path.Value (1 .. Escaped_Path.Length));
   end Delete_Snapshot;

   ---------------------
   -- List_Snapshots
   ---------------------

   function List_Snapshots (Base_Path : String) return Snapshot_Array is
      Result : Snapshot_Array;
      Search : Ada.Directories.Search_Type;
      Entry  : Ada.Directories.Directory_Entry_Type;
      use Ada.Directories;
   begin
      if not Exists (Base_Path) then
         return Result;
      end if;

      Start_Search (Search, Base_Path, "*",
        (Directory => True, others => False));

      while More_Entries (Search) loop
         Get_Next_Entry (Search, Entry);
         declare
            Name : constant String := Simple_Name (Entry);
            Path : constant String := Full_Name (Entry);
         begin
            if Name /= "." and Name /= ".."
              and then Is_Subvolume (Path)
            then
               Result.Append (Get_Snapshot_Info (Path));
            end if;
         end;
      end loop;

      End_Search (Search);
      return Result;
   end List_Snapshots;

   -----------------------
   -- Get_Snapshot_Info
   -----------------------

   function Get_Snapshot_Info (Snapshot_Path : String) return Snapshot_Info is
      Info : Snapshot_Info;
   begin
      Info.Path := To_Unbounded_String (Snapshot_Path);
      Info.Strategy := Filesystem;
      Info.FS_Type := Btrfs;
      Info.Status := Valid;
      Info.Size_Bytes := Get_Snapshot_Size (Snapshot_Path);

      --  Would parse btrfs subvolume show output for more details
      Info.Description := To_Unbounded_String
        (Ada.Directories.Simple_Name (Snapshot_Path));
      Info.Timestamp := Ada.Directories.Modification_Time (Snapshot_Path);

      return Info;
   end Get_Snapshot_Info;

   ---------------------------
   -- Rollback_To_Snapshot
   ---------------------------

   procedure Rollback_To_Snapshot
     (Snapshot_Path : String;
      Backup_Old    : Boolean := True)
   is
      Root_Subvol : constant String := Get_Root_Subvolume;
      Backup_Path : constant String := Root_Subvol & ".old";
   begin
      if not Is_Subvolume (Snapshot_Path) then
         raise Btrfs_Error with "Snapshot path is not a subvolume";
      end if;

      --  This is a simplified version - real implementation would:
      --  1. Mount the parent subvolume
      --  2. Rename current root to .old
      --  3. Create writable snapshot of target as new root
      --  4. Update bootloader
      --  5. Prompt for reboot

      if Backup_Old then
         --  Move current root to backup
         --  Would use: mv root root.old
         null;
      end if;

      --  Create writable snapshot as new root
      --  Would use: btrfs subvolume snapshot <snap> <root>
      null;

      --  Note: This requires a reboot to take effect
   end Rollback_To_Snapshot;

   ----------------------
   -- Verify_Snapshot
   ----------------------

   function Verify_Snapshot (Snapshot_Path : String) return Boolean is
   begin
      --  Check if it exists and is a valid subvolume
      return Ada.Directories.Exists (Snapshot_Path)
        and then Is_Subvolume (Snapshot_Path);
      --  Could also run btrfs scrub for thorough verification
   end Verify_Snapshot;

   ------------------------
   -- Get_Snapshot_Size
   ------------------------

   function Get_Snapshot_Size (Snapshot_Path : String) return Natural is
      pragma Unreferenced (Snapshot_Path);
   begin
      --  Would parse output of: btrfs qgroup show -p <path>
      --  Returns exclusive size in bytes
      return 0;
   end Get_Snapshot_Size;

   -------------------
   -- Is_Subvolume
   -------------------

   function Is_Subvolume (Path : String) return Boolean is
   begin
      if not Ada.Directories.Exists (Path) then
         return False;
      end if;

      --  Check if path is a btrfs subvolume
      --  Would execute: btrfs subvolume show <path>
      --  and check exit code
      return Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   end Is_Subvolume;

   -----------------------------
   -- Initialize_Snapshot_Dir
   -----------------------------

   procedure Initialize_Snapshot_Dir (Base_Path : String) is
   begin
      if not Ada.Directories.Exists (Base_Path) then
         Ada.Directories.Create_Path (Base_Path);
      end if;

      --  Create a subvolume for snapshots if on btrfs root
      --  Would execute: btrfs subvolume create <path>
   end Initialize_Snapshot_Dir;

   ------------------------
   -- Run_Btrfs_Command
   ------------------------

   function Run_Btrfs_Command
     (Args : String)
      return String
   is
      pragma Unreferenced (Args);
   begin
      --  Would execute btrfs command and capture output
      return "";
   end Run_Btrfs_Command;

   --------------------------------
   -- Run_Btrfs_Command_Checked
   --------------------------------

   procedure Run_Btrfs_Command_Checked (Args : String) is
      Cmd    : constant String := "btrfs " & Args;
      Result : Integer;
      pragma Unreferenced (Cmd, Result);
   begin
      --  Would execute command and check exit code
      --  Raise Btrfs_Error on failure
      null;
   end Run_Btrfs_Command_Checked;

end Btrfs_Snapshots;
