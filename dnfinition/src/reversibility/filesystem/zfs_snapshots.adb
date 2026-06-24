-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- ZFS_Snapshots - Implementation
pragma Ada_2022;

with Ada.Calendar;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Filesystem_Detect;
with Shell_Escape;

package body ZFS_Snapshots is

   ------------------
   -- Is_Available
   ------------------

   function Is_Available return Boolean is
   begin
      return Filesystem_Detect.ZFS_Tools_Available
        and then Filesystem_Detect.Detect_Root_Filesystem = ZFS;
   end Is_Available;

   ----------------------
   -- Get_Root_Dataset
   ----------------------

   function Get_Root_Dataset return String is
   begin
      --  Would execute: zfs list -o name,mountpoint | grep " /$"
      --  Or parse /proc/mounts for ZFS
      return Filesystem_Detect.Get_ZFS_Dataset ("/");
   end Get_Root_Dataset;

   ----------------------
   -- Create_Snapshot
   ----------------------

   procedure Create_Snapshot
     (Dataset       : String;
      Snapshot_Name : String;
      Recursive     : Boolean := False)
   is
      use Shell_Escape;
      Full_Name    : constant String := Dataset & "@" & Snapshot_Name;
      Escaped_Name : constant Escape_Result := Escape_Argument (Full_Name);
   begin
      if not Is_Available then
         raise ZFS_Error with "ZFS not available";
      end if;

      if not Escaped_Name.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Name.Error_Msg (1 .. Escaped_Name.Msg_Len);
      end if;

      Run_ZFS_Command_Checked
        ("snapshot " &
         (if Recursive then "-r " else "") &
         Escaped_Name.Value (1 .. Escaped_Name.Length));
   end Create_Snapshot;

   ----------------------
   -- Delete_Snapshot
   ----------------------

   procedure Delete_Snapshot
     (Snapshot  : String;
      Recursive : Boolean := False)
   is
      use Shell_Escape;
      Escaped_Snap : constant Escape_Result := Escape_Argument (Snapshot);
   begin
      if not Is_Snapshot (Snapshot) then
         raise ZFS_Error with "Not a valid ZFS snapshot";
      end if;

      if not Escaped_Snap.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      Run_ZFS_Command_Checked
        ("destroy " &
         (if Recursive then "-r " else "") &
         Escaped_Snap.Value (1 .. Escaped_Snap.Length));
   end Delete_Snapshot;

   ---------------------
   -- List_Snapshots
   ---------------------

   function List_Snapshots (Dataset : String) return Snapshot_Array is
      Result : Snapshot_Array;
      pragma Unreferenced (Dataset);
   begin
      --  Would execute: zfs list -t snapshot -o name,creation,used -H
      --  and parse output
      return Result;
   end List_Snapshots;

   -----------------------
   -- Get_Snapshot_Info
   -----------------------

   function Get_Snapshot_Info (Snapshot : String) return Snapshot_Info is
      Info : Snapshot_Info;
   begin
      Info.Path := To_Unbounded_String (Snapshot);
      Info.Strategy := Filesystem;
      Info.FS_Type := ZFS;
      Info.Status := Valid;
      Info.Size_Bytes := Get_Snapshot_Size (Snapshot);

      --  Extract snapshot name from full path (dataset@snapname)
      declare
         use Ada.Strings.Fixed;
         At_Pos : constant Natural := Index (Snapshot, "@");
      begin
         if At_Pos > 0 then
            Info.Description := To_Unbounded_String
              (Snapshot (At_Pos + 1 .. Snapshot'Last));
         else
            Info.Description := To_Unbounded_String (Snapshot);
         end if;
      end;

      --  Would parse zfs get creation <snapshot> for actual timestamp
      Info.Timestamp := Ada.Calendar.Clock;

      return Info;
   end Get_Snapshot_Info;

   ---------------------------
   -- Rollback_To_Snapshot
   ---------------------------

   procedure Rollback_To_Snapshot
     (Snapshot      : String;
      Destroy_Later : Boolean := True;
      Force         : Boolean := False)
   is
      use Shell_Escape;
      Escaped_Snap : constant Escape_Result := Escape_Argument (Snapshot);
      Options      : constant String :=
        (if Destroy_Later then "-r " else "") &
        (if Force then "-f " else "");
   begin
      if not Is_Snapshot (Snapshot) then
         raise ZFS_Error with "Not a valid ZFS snapshot";
      end if;

      if not Escaped_Snap.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      --  ZFS rollback is atomic and instant
      Run_ZFS_Command_Checked
        ("rollback " & Options & Escaped_Snap.Value (1 .. Escaped_Snap.Length));
   end Rollback_To_Snapshot;

   ---------------------
   -- Clone_Snapshot
   ---------------------

   procedure Clone_Snapshot
     (Snapshot    : String;
      New_Dataset : String)
   is
      use Shell_Escape;
      Escaped_Snap    : constant Escape_Result := Escape_Argument (Snapshot);
      Escaped_Dataset : constant Escape_Result := Escape_Argument (New_Dataset);
   begin
      if not Is_Snapshot (Snapshot) then
         raise ZFS_Error with "Not a valid ZFS snapshot";
      end if;

      if not Escaped_Snap.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      if not Escaped_Dataset.Success then
         raise ZFS_Error with "Invalid dataset name: " &
           Escaped_Dataset.Error_Msg (1 .. Escaped_Dataset.Msg_Len);
      end if;

      Run_ZFS_Command_Checked
        ("clone " &
         Escaped_Snap.Value (1 .. Escaped_Snap.Length) & " " &
         Escaped_Dataset.Value (1 .. Escaped_Dataset.Length));
   end Clone_Snapshot;

   ----------------------
   -- Verify_Snapshot
   ----------------------

   function Verify_Snapshot (Snapshot : String) return Boolean is
   begin
      --  Check if snapshot exists
      --  Would execute: zfs list -t snapshot <snapshot>
      return Is_Snapshot (Snapshot);
   end Verify_Snapshot;

   ------------------------
   -- Get_Snapshot_Size
   ------------------------

   function Get_Snapshot_Size (Snapshot : String) return Natural is
      pragma Unreferenced (Snapshot);
   begin
      --  Would execute: zfs get -H -o value used <snapshot>
      --  and parse the output
      return 0;
   end Get_Snapshot_Size;

   -----------------
   -- Is_Snapshot
   -----------------

   function Is_Snapshot (Name : String) return Boolean is
      use Ada.Strings.Fixed;
   begin
      --  ZFS snapshots have the format: dataset@snapname
      return Index (Name, "@") > 0;
   end Is_Snapshot;

   ----------------------
   -- Get_Pool_Health
   ----------------------

   function Get_Pool_Health (Pool_Name : String) return String is
      pragma Unreferenced (Pool_Name);
   begin
      --  Would execute: zpool status -x <pool>
      return "ONLINE";
   end Get_Pool_Health;

   --------------------
   -- Hold_Snapshot
   --------------------

   procedure Hold_Snapshot
     (Snapshot : String;
      Tag      : String := "dnfinition")
   is
      use Shell_Escape;
      Escaped_Snap : constant Escape_Result := Escape_Argument (Snapshot);
      Escaped_Tag  : constant Escape_Result := Escape_Argument (Tag);
   begin
      if not Escaped_Snap.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      if not Escaped_Tag.Success then
         raise ZFS_Error with "Invalid tag: " &
           Escaped_Tag.Error_Msg (1 .. Escaped_Tag.Msg_Len);
      end if;

      Run_ZFS_Command_Checked
        ("hold " &
         Escaped_Tag.Value (1 .. Escaped_Tag.Length) & " " &
         Escaped_Snap.Value (1 .. Escaped_Snap.Length));
   end Hold_Snapshot;

   -----------------------
   -- Release_Snapshot
   -----------------------

   procedure Release_Snapshot
     (Snapshot : String;
      Tag      : String := "dnfinition")
   is
      use Shell_Escape;
      Escaped_Snap : constant Escape_Result := Escape_Argument (Snapshot);
      Escaped_Tag  : constant Escape_Result := Escape_Argument (Tag);
   begin
      if not Escaped_Snap.Success then
         raise ZFS_Error with "Invalid snapshot name: " &
           Escaped_Snap.Error_Msg (1 .. Escaped_Snap.Msg_Len);
      end if;

      if not Escaped_Tag.Success then
         raise ZFS_Error with "Invalid tag: " &
           Escaped_Tag.Error_Msg (1 .. Escaped_Tag.Msg_Len);
      end if;

      Run_ZFS_Command_Checked
        ("release " &
         Escaped_Tag.Value (1 .. Escaped_Tag.Length) & " " &
         Escaped_Snap.Value (1 .. Escaped_Snap.Length));
   end Release_Snapshot;

   ----------------------
   -- Run_ZFS_Command
   ----------------------

   function Run_ZFS_Command (Args : String) return String is
      pragma Unreferenced (Args);
   begin
      --  Would execute zfs command and capture output
      return "";
   end Run_ZFS_Command;

   ------------------------------
   -- Run_ZFS_Command_Checked
   ------------------------------

   procedure Run_ZFS_Command_Checked (Args : String) is
      Cmd : constant String := "zfs " & Args;
      pragma Unreferenced (Cmd);
   begin
      --  Would execute command and check exit code
      --  Raise ZFS_Error on failure
      null;
   end Run_ZFS_Command_Checked;

end ZFS_Snapshots;
