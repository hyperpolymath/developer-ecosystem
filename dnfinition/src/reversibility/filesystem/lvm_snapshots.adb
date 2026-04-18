-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- LVM_Snapshots - Implementation
pragma Ada_2022;

with Ada.Calendar;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Filesystem_Detect;
with Shell_Escape;

package body LVM_Snapshots is

   ------------------
   -- Is_Available
   ------------------

   function Is_Available return Boolean is
   begin
      return Filesystem_Detect.LVM_Tools_Available
        and then Filesystem_Detect.Detect_Root_Filesystem = LVM;
   end Is_Available;

   ------------------
   -- Get_Root_LV
   ------------------

   function Get_Root_LV return String is
   begin
      return Filesystem_Detect.Get_LVM_Volume ("/");
   end Get_Root_LV;

   ------------------
   -- Get_Root_VG
   ------------------

   function Get_Root_VG return String is
      Root_LV : constant String := Get_Root_LV;
      use Ada.Strings.Fixed;
   begin
      --  LV path is typically /dev/vgname/lvname or /dev/mapper/vgname-lvname
      --  Extract VG name
      if Index (Root_LV, "/dev/mapper/") = 1 then
         --  Format: /dev/mapper/vgname-lvname
         declare
            Name   : constant String :=
              Root_LV (Root_LV'First + 12 .. Root_LV'Last);
            Dash   : constant Natural := Index (Name, "-");
         begin
            if Dash > 0 then
               return Name (Name'First .. Dash - 1);
            end if;
         end;
      elsif Index (Root_LV, "/dev/") = 1 then
         --  Format: /dev/vgname/lvname
         declare
            Path  : constant String :=
              Root_LV (Root_LV'First + 5 .. Root_LV'Last);
            Slash : constant Natural := Index (Path, "/");
         begin
            if Slash > 0 then
               return Path (Path'First .. Slash - 1);
            end if;
         end;
      end if;

      return "";
   end Get_Root_VG;

   ----------------------
   -- Create_Snapshot
   ----------------------

   procedure Create_Snapshot
     (Source_LV     : String;
      Snapshot_Name : String;
      Size_Percent  : Positive := 20)
   is
      use Shell_Escape;
      Escaped_Source : constant Escape_Result := Escape_Argument (Source_LV);
      Escaped_Name   : constant Escape_Result := Escape_Argument (Snapshot_Name);
      Size_Str       : constant String := Positive'Image (Size_Percent) & "%ORIGIN";
   begin
      if not Is_Available then
         raise LVM_Error with "LVM not available";
      end if;

      if not Escaped_Source.Success then
         raise LVM_Error with "Invalid source LV: " &
           Escaped_Source.Error_Msg (1 .. Escaped_Source.Msg_Len);
      end if;

      if not Escaped_Name.Success then
         raise LVM_Error with "Invalid snapshot name: " &
           Escaped_Name.Error_Msg (1 .. Escaped_Name.Msg_Len);
      end if;

      --  Create COW snapshot
      Run_LVM_Command_Checked
        ("lvcreate -s -n " &
         Escaped_Name.Value (1 .. Escaped_Name.Length) &
         " -l " & Size_Str & " " &
         Escaped_Source.Value (1 .. Escaped_Source.Length));
   end Create_Snapshot;

   ----------------------
   -- Delete_Snapshot
   ----------------------

   procedure Delete_Snapshot (Snapshot_LV : String) is
      use Shell_Escape;
      Escaped_LV : constant Escape_Result := Escape_Argument (Snapshot_LV);
   begin
      if not Is_LV (Snapshot_LV) then
         raise LVM_Error with "Not a valid logical volume";
      end if;

      if not Escaped_LV.Success then
         raise LVM_Error with "Invalid LV path: " &
           Escaped_LV.Error_Msg (1 .. Escaped_LV.Msg_Len);
      end if;

      Run_LVM_Command_Checked
        ("lvremove -f " & Escaped_LV.Value (1 .. Escaped_LV.Length));
   end Delete_Snapshot;

   ---------------------
   -- List_Snapshots
   ---------------------

   function List_Snapshots (VG_Name : String) return Snapshot_Array is
      Result : Snapshot_Array;
      pragma Unreferenced (VG_Name);
   begin
      --  Would execute: lvs -o lv_name,origin,snap_percent VG_Name
      --  and filter for snapshots (those with an origin)
      return Result;
   end List_Snapshots;

   -----------------------
   -- Get_Snapshot_Info
   -----------------------

   function Get_Snapshot_Info (Snapshot_LV : String) return Snapshot_Info is
      Info : Snapshot_Info;
   begin
      Info.Path := To_Unbounded_String (Snapshot_LV);
      Info.Strategy := Filesystem;
      Info.FS_Type := LVM;
      Info.Status := Valid;

      --  Extract snapshot name from path
      declare
         use Ada.Strings.Fixed;
         Last_Slash : constant Natural := Index (Snapshot_LV, "/", Going => Ada.Strings.Backward);
      begin
         if Last_Slash > 0 then
            Info.Description := To_Unbounded_String
              (Snapshot_LV (Last_Slash + 1 .. Snapshot_LV'Last));
         else
            Info.Description := To_Unbounded_String (Snapshot_LV);
         end if;
      end;

      Info.Timestamp := Ada.Calendar.Clock;  --  Would get from LV metadata

      return Info;
   end Get_Snapshot_Info;

   ---------------------------
   -- Rollback_To_Snapshot
   ---------------------------

   procedure Rollback_To_Snapshot (Snapshot_LV : String) is
      use Shell_Escape;
      Escaped_LV : constant Escape_Result := Escape_Argument (Snapshot_LV);
   begin
      if not Is_LV (Snapshot_LV) then
         raise LVM_Error with "Not a valid logical volume";
      end if;

      if not Escaped_LV.Success then
         raise LVM_Error with "Invalid LV path: " &
           Escaped_LV.Error_Msg (1 .. Escaped_LV.Msg_Len);
      end if;

      --  LVM snapshot merge happens on next activation (usually reboot)
      Run_LVM_Command_Checked
        ("lvconvert --merge " & Escaped_LV.Value (1 .. Escaped_LV.Length));

      --  Note: System needs to be rebooted for merge to complete
   end Rollback_To_Snapshot;

   ----------------------
   -- Verify_Snapshot
   ----------------------

   function Verify_Snapshot (Snapshot_LV : String) return Boolean is
   begin
      --  Check if LV exists and is a snapshot
      --  Would execute: lvs --noheadings -o origin <snapshot>
      return Is_LV (Snapshot_LV);
   end Verify_Snapshot;

   -------------------------
   -- Get_Snapshot_Usage
   -------------------------

   function Get_Snapshot_Usage (Snapshot_LV : String) return Natural is
      pragma Unreferenced (Snapshot_LV);
   begin
      --  Would execute: lvs --noheadings -o snap_percent <snapshot>
      return 0;
   end Get_Snapshot_Usage;

   ----------------------
   -- Extend_Snapshot
   ----------------------

   procedure Extend_Snapshot
     (Snapshot_LV : String;
      Add_Size_MB : Positive)
   is
      use Shell_Escape;
      Escaped_LV : constant Escape_Result := Escape_Argument (Snapshot_LV);
      Size_Str   : constant String := "+" & Positive'Image (Add_Size_MB) & "M";
   begin
      if not Escaped_LV.Success then
         raise LVM_Error with "Invalid LV path: " &
           Escaped_LV.Error_Msg (1 .. Escaped_LV.Msg_Len);
      end if;

      Run_LVM_Command_Checked
        ("lvextend -L " & Size_Str & " " &
         Escaped_LV.Value (1 .. Escaped_LV.Length));
   end Extend_Snapshot;

   -------------
   -- Is_LV
   -------------

   function Is_LV (Path : String) return Boolean is
      use Ada.Strings.Fixed;
   begin
      --  Check if path looks like an LVM path
      return Index (Path, "/dev/mapper/") = 1
        or else (Index (Path, "/dev/") = 1
                 and then Index (Path, "/", Going => Ada.Strings.Backward) > 5);
   end Is_LV;

   -------------------------
   -- Get_VG_Free_Space
   -------------------------

   function Get_VG_Free_Space (VG_Name : String) return Natural is
      pragma Unreferenced (VG_Name);
   begin
      --  Would execute: vgs --noheadings -o vg_free <vg> --units m
      return 0;
   end Get_VG_Free_Space;

   ----------------------
   -- Run_LVM_Command
   ----------------------

   function Run_LVM_Command (Command : String) return String is
      pragma Unreferenced (Command);
   begin
      --  Would execute LVM command and capture output
      return "";
   end Run_LVM_Command;

   ------------------------------
   -- Run_LVM_Command_Checked
   ------------------------------

   procedure Run_LVM_Command_Checked (Command : String) is
      pragma Unreferenced (Command);
   begin
      --  Would execute command and check exit code
      --  Raise LVM_Error on failure
      null;
   end Run_LVM_Command_Checked;

end LVM_Snapshots;
