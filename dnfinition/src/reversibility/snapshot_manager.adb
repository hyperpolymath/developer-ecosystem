-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Snapshot_Manager - Implementation
pragma Ada_2022;
pragma SPARK_Mode (Off);  --  Implementation uses I/O

with Ada.Calendar;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar.Formatting;
with Filesystem_Detect;
with Detection;

package body Snapshot_Manager is

   Initialized : Boolean := False;

   --  Format timestamp for snapshot names
   function Format_Timestamp (T : Ada.Calendar.Time) return String is
   begin
      return Ada.Calendar.Formatting.Image
        (Date                  => T,
         Include_Time_Fraction => False,
         Time_Zone             => 0);
   end Format_Timestamp;

   ----------------
   -- Initialize
   ----------------

   procedure Initialize (Config : Snapshot_Config := Default_Snapshot_Config)
   is
   begin
      Current_Config := Config;
      Snapshot_DB := (others => (Info => Null_Snapshot, Active => False));
      Next_ID := 1;
      Initialized := True;
   end Initialize;

   ---------------------------
   -- Detect_Best_Strategy
   ---------------------------

   function Detect_Best_Strategy return Snapshot_Strategy is
   begin
      return Filesystem_Detect.Get_Best_Snapshot_Strategy;
   end Detect_Best_Strategy;

   -------------------------
   -- Strategy_Supported
   -------------------------

   function Strategy_Supported (Strategy : Snapshot_Strategy) return Boolean
   is
      Root_FS : constant Filesystem_Type :=
        Filesystem_Detect.Detect_Root_Filesystem;
   begin
      case Strategy is
         when Native =>
            return Detection.PM_Has_Native_Snapshots
              (Detection.Detect_Package_Manager);

         when Filesystem =>
            case Root_FS is
               when Btrfs =>
                  return Filesystem_Detect.Btrfs_Tools_Available;
               when ZFS =>
                  return Filesystem_Detect.ZFS_Tools_Available;
               when LVM =>
                  return Filesystem_Detect.LVM_Tools_Available;
               when others =>
                  return False;
            end case;

         when Transaction_Log =>
            return True;  --  Always supported

         when Container_Image =>
            --  Check for podman/docker
            return Detection.PM_Available (Detection.Unknown_PM);
            --  Simplified: would check for container runtime
      end case;
   end Strategy_Supported;

   ---------------------
   -- Create_Snapshot
   ---------------------

   procedure Create_Snapshot
     (Description : String;
      Strategy    : Snapshot_Strategy;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID)
   is
      use Ada.Calendar;
      Info : Snapshot_Info;
   begin
      if not Initialized then
         Initialize;
      end if;

      if Next_ID > Snapshot_Types.Snapshot_ID (Max_Snapshots) then
         raise Snapshot_Error with "Maximum snapshot count reached";
      end if;

      --  Create snapshot info
      Info := (
         ID          => Next_ID,
         Description => To_Unbounded_String (Description),
         Path        => Null_Unbounded_String,
         Timestamp   => Clock,
         Strategy    => Strategy,
         FS_Type     => Filesystem_Detect.Detect_Root_Filesystem,
         Status      => Creating,
         Size_Bytes  => 0,
         Is_Pinned   => False
      );

      --  Create the actual snapshot based on strategy
      case Strategy is
         when Native =>
            Create_Native_Snapshot (Info);

         when Filesystem =>
            Create_Filesystem_Snapshot (Info);

         when Transaction_Log =>
            Create_Transaction_Snapshot (Info);

         when Container_Image =>
            Create_Container_Snapshot (Info);
      end case;

      --  Store in database
      Info.Status := Valid;
      Snapshot_DB (Positive (Next_ID)) := (Info => Info, Active => True);
      Snapshot_ID := Next_ID;
      Next_ID := Next_ID + 1;
   end Create_Snapshot;

   procedure Create_Snapshot
     (Description : String;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID)
   is
   begin
      Create_Snapshot (Description, Detect_Best_Strategy, Snapshot_ID);
   end Create_Snapshot;

   ----------------------------
   -- Create_Native_Snapshot
   ----------------------------

   procedure Create_Native_Snapshot (Info : in out Snapshot_Info) is
      PM : constant Detection.Package_Manager_Type :=
        Detection.Detect_Package_Manager;
   begin
      case PM is
         when Detection.RPM_Ostree =>
            --  rpm-ostree creates deployments automatically
            --  We just need to pin the current one
            Info.Path := To_Unbounded_String
              ("/ostree/deploy/" & Format_Timestamp (Info.Timestamp));

         when Detection.Zypper =>
            --  snapper integration
            Info.Path := To_Unbounded_String
              ("/.snapshots/" & Format_Timestamp (Info.Timestamp));

         when Detection.Nix | Detection.Guix =>
            --  These are inherently snapshot-based
            Info.Path := To_Unbounded_String
              ("/nix/var/nix/profiles/system-" &
               Format_Timestamp (Info.Timestamp));

         when others =>
            raise Snapshot_Error
              with "Native snapshots not supported for " &
                   Detection.PM_Name (PM);
      end case;
   end Create_Native_Snapshot;

   --------------------------------
   -- Create_Filesystem_Snapshot
   --------------------------------

   procedure Create_Filesystem_Snapshot (Info : in Out Snapshot_Info) is
      Root_FS : constant Filesystem_Type :=
        Filesystem_Detect.Detect_Root_Filesystem;
      Timestamp : constant String := Format_Timestamp (Info.Timestamp);
   begin
      Info.FS_Type := Root_FS;

      case Root_FS is
         when Btrfs =>
            Info.Path := To_Unbounded_String
              ("/.snapshots/dnfinition-" & Timestamp);
            --  Would execute: btrfs subvolume snapshot -r / <path>

         when ZFS =>
            declare
               Dataset : constant String :=
                 Filesystem_Detect.Get_ZFS_Dataset ("/");
            begin
               Info.Path := To_Unbounded_String
                 (Dataset & "@dnfinition-" & Timestamp);
               --  Would execute: zfs snapshot <dataset>@<name>
            end;

         when LVM =>
            declare
               Volume : constant String :=
                 Filesystem_Detect.Get_LVM_Volume ("/");
            begin
               Info.Path := To_Unbounded_String
                 (Volume & "-snap-" & Timestamp);
               --  Would execute: lvcreate -s -n <name> <volume>
            end;

         when others =>
            raise Snapshot_Error
              with "Filesystem snapshots not supported for " &
                   Filesystem_Name (Root_FS);
      end case;
   end Create_Filesystem_Snapshot;

   ---------------------------------
   -- Create_Transaction_Snapshot
   ---------------------------------

   procedure Create_Transaction_Snapshot (Info : in Out Snapshot_Info) is
   begin
      Info.Path := To_Unbounded_String
        (To_String (Current_Config.Transaction_Log_Path) & "/" &
         Format_Timestamp (Info.Timestamp) & ".txlog");
      --  Transaction log snapshots record the current package state
      --  and can replay/reverse operations
   end Create_Transaction_Snapshot;

   -------------------------------
   -- Create_Container_Snapshot
   -------------------------------

   procedure Create_Container_Snapshot (Info : in Out Snapshot_Info) is
   begin
      Info.Path := To_Unbounded_String
        ("dnfinition-snapshot:" & Format_Timestamp (Info.Timestamp));
      --  Would create a container image of the current system state
   end Create_Container_Snapshot;

   --------------------------
   -- Rollback_To_Snapshot
   --------------------------

   procedure Rollback_To_Snapshot (ID : Snapshot_Types.Snapshot_ID) is
      Info : constant Snapshot_Info :=
        Snapshot_DB (Positive (ID)).Info;
   begin
      case Info.Strategy is
         when Native =>
            Rollback_Native (Info);

         when Filesystem =>
            Rollback_Filesystem (Info);

         when Transaction_Log =>
            Rollback_Transaction_Log (Info);

         when Container_Image =>
            Rollback_Container (Info);
      end case;
   end Rollback_To_Snapshot;

   ----------------------
   -- Rollback_Native
   ----------------------

   procedure Rollback_Native (Info : Snapshot_Info) is
      PM : constant Detection.Package_Manager_Type :=
        Detection.Detect_Package_Manager;
   begin
      case PM is
         when Detection.RPM_Ostree =>
            --  rpm-ostree rollback
            null;  --  Would execute: rpm-ostree rollback

         when Detection.Zypper =>
            --  snapper rollback
            null;  --  Would execute: snapper rollback <num>

         when others =>
            raise Snapshot_Error
              with "Native rollback not supported for " &
                   Detection.PM_Name (PM);
      end case;
   end Rollback_Native;

   --------------------------
   -- Rollback_Filesystem
   --------------------------

   procedure Rollback_Filesystem (Info : Snapshot_Info) is
   begin
      case Info.FS_Type is
         when Btrfs =>
            --  Btrfs rollback involves replacing the root subvolume
            null;  --  Would execute btrfs commands

         when ZFS =>
            --  ZFS rollback
            null;  --  Would execute: zfs rollback -r <snapshot>

         when LVM =>
            --  LVM snapshot restore
            null;  --  Would use lvconvert --merge

         when others =>
            raise Snapshot_Error
              with "Cannot rollback filesystem " &
                   Filesystem_Name (Info.FS_Type);
      end case;
   end Rollback_Filesystem;

   ------------------------------
   -- Rollback_Transaction_Log
   ------------------------------

   procedure Rollback_Transaction_Log (Info : Snapshot_Info) is
      pragma Unreferenced (Info);
   begin
      --  Read the transaction log and reverse all operations
      null;  --  Would parse and execute reverse operations
   end Rollback_Transaction_Log;

   ------------------------
   -- Rollback_Container
   ------------------------

   procedure Rollback_Container (Info : Snapshot_Info) is
      pragma Unreferenced (Info);
   begin
      --  Restore from container image
      null;  --  Would use podman/docker to restore system state
   end Rollback_Container;

   ---------------------
   -- List_Snapshots
   ---------------------

   function List_Snapshots return Snapshot_Array is
      Result : Snapshot_Array;
   begin
      for I in 1 .. Positive (Next_ID) - 1 loop
         if Snapshot_DB (I).Active then
            Result.Append (Snapshot_DB (I).Info);
         end if;
      end loop;
      return Result;
   end List_Snapshots;

   -----------------------
   -- Get_Snapshot_Info
   -----------------------

   function Get_Snapshot_Info (ID : Snapshot_Types.Snapshot_ID)
     return Snapshot_Info
   is
   begin
      return Snapshot_DB (Positive (ID)).Info;
   end Get_Snapshot_Info;

   ----------------------
   -- Delete_Snapshot
   ----------------------

   procedure Delete_Snapshot (ID : Snapshot_Types.Snapshot_ID) is
   begin
      Snapshot_DB (Positive (ID)).Active := False;
      --  Would also delete the actual snapshot from storage
   end Delete_Snapshot;

   -------------------
   -- Pin_Snapshot
   -------------------

   procedure Pin_Snapshot (ID : Snapshot_Types.Snapshot_ID) is
   begin
      Snapshot_DB (Positive (ID)).Info.Is_Pinned := True;
   end Pin_Snapshot;

   ---------------------
   -- Unpin_Snapshot
   ---------------------

   procedure Unpin_Snapshot (ID : Snapshot_Types.Snapshot_ID) is
   begin
      Snapshot_DB (Positive (ID)).Info.Is_Pinned := False;
   end Unpin_Snapshot;

   ----------------------------
   -- Cleanup_Old_Snapshots
   ----------------------------

   procedure Cleanup_Old_Snapshots (Keep_Last : Positive := 10) is
      Count : Natural := 0;
   begin
      --  Count active, non-pinned snapshots
      for I in 1 .. Positive (Next_ID) - 1 loop
         if Snapshot_DB (I).Active
           and then not Snapshot_DB (I).Info.Is_Pinned
         then
            Count := Count + 1;
         end if;
      end loop;

      --  Delete oldest until we're at Keep_Last
      if Count > Keep_Last then
         for I in 1 .. Positive (Next_ID) - 1 loop
            if Snapshot_DB (I).Active
              and then not Snapshot_DB (I).Info.Is_Pinned
            then
               Delete_Snapshot (Snapshot_Types.Snapshot_ID (I));
               Count := Count - 1;
               exit when Count <= Keep_Last;
            end if;
         end loop;
      end if;
   end Cleanup_Old_Snapshots;

   ---------------------
   -- Cleanup_By_Age
   ---------------------

   procedure Cleanup_By_Age (Max_Age_Days : Positive := 30) is
      use Ada.Calendar;
      Cutoff : constant Time := Clock - Duration (Max_Age_Days * 86_400);
   begin
      for I in 1 .. Positive (Next_ID) - 1 loop
         if Snapshot_DB (I).Active
           and then not Snapshot_DB (I).Info.Is_Pinned
           and then Snapshot_DB (I).Info.Timestamp < Cutoff
         then
            Delete_Snapshot (Snapshot_Types.Snapshot_ID (I));
         end if;
      end loop;
   end Cleanup_By_Age;

   ----------------------
   -- Verify_Snapshot
   ----------------------

   function Verify_Snapshot (ID : Snapshot_Types.Snapshot_ID) return Boolean
   is
   begin
      return Snapshot_DB (Positive (ID)).Active
        and then Snapshot_DB (Positive (ID)).Info.Status = Valid;
      --  Would also verify the actual snapshot integrity
   end Verify_Snapshot;

   ---------------------
   -- Snapshot_Count
   ---------------------

   function Snapshot_Count return Natural is
      Count : Natural := 0;
   begin
      for I in 1 .. Positive (Next_ID) - 1 loop
         if Snapshot_DB (I).Active then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Snapshot_Count;

   --------------------------
   -- Total_Snapshot_Size
   --------------------------

   function Total_Snapshot_Size return Natural is
      Total : Natural := 0;
   begin
      for I in 1 .. Positive (Next_ID) - 1 loop
         if Snapshot_DB (I).Active then
            Total := Total + Snapshot_DB (I).Info.Size_Bytes;
         end if;
      end loop;
      return Total;
   end Total_Snapshot_Size;

end Snapshot_Manager;
