-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- RPM_Ostree_Backend - Implementation
pragma Ada_2022;

with Ada.Directories;
with GNAT.OS_Lib;
with Transaction_Log;

package body RPM_Ostree_Backend is

   function RPM_Ostree_Available return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path ("rpm-ostree");
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
         --  Also check if we're on an ostree system
         return Ada.Directories.Exists ("/ostree");
      end if;
      return False;
   end RPM_Ostree_Available;

   ----------
   -- Name
   ----------

   overriding function Name
     (Backend : RPM_Ostree_Backend_Type)
      return String
   is
      pragma Unreferenced (Backend);
   begin
      return "rpm-ostree";
   end Name;

   ------------------
   -- Capabilities
   ------------------

   overriding function Capabilities
     (Backend : RPM_Ostree_Backend_Type)
      return Capability_Set
   is
      pragma Unreferenced (Backend);
   begin
      return (
         Cap_Install          => True,
         Cap_Remove           => True,
         Cap_Upgrade          => True,
         Cap_Downgrade        => False,  --  Not directly supported
         Cap_Search           => True,   --  Via dnf backend
         Cap_List_Installed   => True,
         Cap_Check_Updates    => True,
         Cap_Native_Snapshots => True,   --  Via deployments
         Cap_Transactions     => True,   --  Atomic
         Cap_Dry_Run          => True,
         Cap_Hold_Packages    => False,  --  Not supported
         Cap_Repository_Mgmt  => True,
         Cap_File_Query       => True
      );
   end Capabilities;

   ------------------
   -- Is_Available
   ------------------

   overriding function Is_Available
     (Backend : RPM_Ostree_Backend_Type)
      return Boolean
   is
      pragma Unreferenced (Backend);
   begin
      return RPM_Ostree_Available;
   end Is_Available;

   ----------------
   -- Initialize
   ----------------

   overriding procedure Initialize
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
   begin
      Backend.Initialized := True;
   end Initialize;

   ----------------------
   -- Install_Package
   ----------------------

   overriding procedure Install_Package
     (Backend : in Out RPM_Ostree_Backend_Type;
      Package : Package_Info)
   is
      Pkgs : Package_Array;
   begin
      Pkgs.Append (Package);
      Install_Packages (Backend, Pkgs);
   end Install_Package;

   -----------------------
   -- Install_Packages
   -----------------------

   overriding procedure Install_Packages
     (Backend  : in Out RPM_Ostree_Backend_Type;
      Packages : Package_Array)
   is
   begin
      --  Would execute: rpm-ostree install pkg1 pkg2 ...
      --  This creates a new deployment automatically (native snapshot)
      if Backend.In_Trans then
         for Pkg of Packages loop
            Transaction_Log.Add_Operation
              (Backend.Current_Trans,
               Make_Operation
                 (Install,
                  To_String (Pkg.Name)));
         end loop;
      end if;
   end Install_Packages;

   ---------------------
   -- Remove_Package
   ---------------------

   overriding procedure Remove_Package
     (Backend : in Out RPM_Ostree_Backend_Type;
      Package : Package_Info)
   is
      Pkgs : Package_Array;
   begin
      Pkgs.Append (Package);
      Remove_Packages (Backend, Pkgs);
   end Remove_Package;

   ----------------------
   -- Remove_Packages
   ----------------------

   overriding procedure Remove_Packages
     (Backend  : in Out RPM_Ostree_Backend_Type;
      Packages : Package_Array)
   is
   begin
      --  Would execute: rpm-ostree uninstall pkg1 pkg2 ...
      if Backend.In_Trans then
         for Pkg of Packages loop
            Transaction_Log.Add_Operation
              (Backend.Current_Trans,
               Make_Operation
                 (Remove,
                  To_String (Pkg.Name)));
         end loop;
      end if;
   end Remove_Packages;

   ----------------------
   -- Upgrade_Package
   ----------------------

   overriding procedure Upgrade_Package
     (Backend : in Out RPM_Ostree_Backend_Type;
      Package : Package_Info)
   is
      pragma Unreferenced (Package);
   begin
      --  rpm-ostree upgrades all at once
      Upgrade_All (Backend);
   end Upgrade_Package;

   -----------------
   -- Upgrade_All
   -----------------

   overriding procedure Upgrade_All
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree upgrade
      null;
   end Upgrade_All;

   ------------------------
   -- Downgrade_Package
   ------------------------

   overriding procedure Downgrade_Package
     (Backend    : in Out RPM_Ostree_Backend_Type;
      Package    : Package_Info;
      To_Version : String)
   is
      pragma Unreferenced (Backend, Package, To_Version);
   begin
      --  rpm-ostree doesn't support direct downgrade
      --  Use rollback to previous deployment instead
      raise Backend_Error with
        "rpm-ostree doesn't support package downgrade. Use rollback instead.";
   end Downgrade_Package;

   ----------------------
   -- Search_Packages
   ----------------------

   overriding function Search_Packages
     (Backend : RPM_Ostree_Backend_Type;
      Query   : String)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Query);
   begin
      --  Would use dnf search (rpm-ostree uses dnf repos)
      return Result;
   end Search_Packages;

   ----------------------
   -- Get_Package_Info
   ----------------------

   overriding function Get_Package_Info
     (Backend : RPM_Ostree_Backend_Type;
      Name    : String)
      return Package_Info
   is
      pragma Unreferenced (Backend);
   begin
      return Make_Package (Name);
   end Get_Package_Info;

   -----------------------------
   -- List_Installed_Packages
   -----------------------------

   overriding function List_Installed_Packages
     (Backend : RPM_Ostree_Backend_Type)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree status
      --  and: rpm -qa (for base + layered)
      return Result;
   end List_Installed_Packages;

   --------------------
   -- Check_Updates
   --------------------

   overriding function Check_Updates
     (Backend : RPM_Ostree_Backend_Type)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree upgrade --check
      return Result;
   end Check_Updates;

   ----------------------
   -- Get_Dependencies
   ----------------------

   overriding function Get_Dependencies
     (Backend : RPM_Ostree_Backend_Type;
      Package : Package_Info)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Package);
   begin
      return Result;
   end Get_Dependencies;

   ------------------------------
   -- Get_Reverse_Dependencies
   ------------------------------

   overriding function Get_Reverse_Dependencies
     (Backend : RPM_Ostree_Backend_Type;
      Package : Package_Info)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Package);
   begin
      return Result;
   end Get_Reverse_Dependencies;

   --------------------------
   -- Find_Package_By_File
   --------------------------

   overriding function Find_Package_By_File
     (Backend : RPM_Ostree_Backend_Type;
      Path    : String)
      return Package_Info
   is
      pragma Unreferenced (Backend, Path);
   begin
      return Null_Package;
   end Find_Package_By_File;

   -----------------------
   -- Begin_Transaction
   -----------------------

   overriding procedure Begin_Transaction
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
   begin
      Backend.Current_Trans := Transaction_Log.Begin_Transaction
        ("rpm-ostree Transaction");
      Transaction_Log.Start_Transaction (Backend.Current_Trans);
      Backend.In_Trans := True;
   end Begin_Transaction;

   ------------------------
   -- Commit_Transaction
   ------------------------

   overriding procedure Commit_Transaction
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
   begin
      if Backend.In_Trans then
         Transaction_Log.Commit_Transaction (Backend.Current_Trans);
         Backend.In_Trans := False;
         Backend.Current_Trans := Invalid_Transaction_ID;
      end if;
   end Commit_Transaction;

   --------------------------
   -- Rollback_Transaction
   --------------------------

   overriding procedure Rollback_Transaction
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
   begin
      if Backend.In_Trans then
         --  rpm-ostree can rollback to previous deployment
         Rollback (Backend);
         Transaction_Log.Cancel_Transaction (Backend.Current_Trans);
         Backend.In_Trans := False;
         Backend.Current_Trans := Invalid_Transaction_ID;
      end if;
   end Rollback_Transaction;

   --------------------
   -- In_Transaction
   --------------------

   overriding function In_Transaction
     (Backend : RPM_Ostree_Backend_Type)
      return Boolean
   is
   begin
      return Backend.In_Trans;
   end In_Transaction;

   ----------------------
   -- Preview_Install
   ----------------------

   overriding function Preview_Install
     (Backend  : RPM_Ostree_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend, Packages);
   begin
      --  Would execute: rpm-ostree install --dry-run <packages>
      return Result;
   end Preview_Install;

   ---------------------
   -- Preview_Remove
   ---------------------

   overriding function Preview_Remove
     (Backend  : RPM_Ostree_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend, Packages);
   begin
      return Result;
   end Preview_Remove;

   ----------------------
   -- Preview_Upgrade
   ----------------------

   overriding function Preview_Upgrade
     (Backend : RPM_Ostree_Backend_Type)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree upgrade --check
      return Result;
   end Preview_Upgrade;

   --------------------------------
   -- Supports_Native_Snapshots
   --------------------------------

   overriding function Supports_Native_Snapshots
     (Backend : RPM_Ostree_Backend_Type)
      return Boolean
   is
      pragma Unreferenced (Backend);
   begin
      return True;  --  Deployments are native snapshots
   end Supports_Native_Snapshots;

   ----------------------------
   -- Create_Native_Snapshot
   ----------------------------

   overriding procedure Create_Native_Snapshot
     (Backend     : in Out RPM_Ostree_Backend_Type;
      Description : String;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID)
   is
      pragma Unreferenced (Description);
   begin
      --  Pin current deployment
      Pin_Deployment (Backend, Get_Current_Deployment (Backend));
      Snapshot_ID := 1;  --  Would get actual deployment index
   end Create_Native_Snapshot;

   ------------------------------
   -- Rollback_Native_Snapshot
   ------------------------------

   overriding procedure Rollback_Native_Snapshot
     (Backend     : in Out RPM_Ostree_Backend_Type;
      Snapshot_ID : Snapshot_Types.Snapshot_ID)
   is
      pragma Unreferenced (Snapshot_ID);
   begin
      --  Would rollback to specific deployment
      Rollback (Backend);
   end Rollback_Native_Snapshot;

   --------------------------
   -- Refresh_Repositories
   --------------------------

   overriding procedure Refresh_Repositories
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree refresh-md
      null;
   end Refresh_Repositories;

   -----------------------
   -- List_Repositories
   -----------------------

   overriding function List_Repositories
     (Backend : RPM_Ostree_Backend_Type)
      return Unbounded_String
   is
      pragma Unreferenced (Backend);
   begin
      return Null_Unbounded_String;
   end List_Repositories;

   ------------------
   -- Hold_Package
   ------------------

   overriding procedure Hold_Package
     (Backend : in Out RPM_Ostree_Backend_Type;
      Package : Package_Info)
   is
      pragma Unreferenced (Backend, Package);
   begin
      raise Backend_Error with "rpm-ostree doesn't support package hold";
   end Hold_Package;

   --------------------
   -- Unhold_Package
   --------------------

   overriding procedure Unhold_Package
     (Backend : in Out RPM_Ostree_Backend_Type;
      Package : Package_Info)
   is
      pragma Unreferenced (Backend, Package);
   begin
      raise Backend_Error with "rpm-ostree doesn't support package hold";
   end Unhold_Package;

   ----------------
   -- Autoremove
   ----------------

   overriding procedure Autoremove
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  rpm-ostree doesn't have autoremove
      --  Cleanup happens via deployment pruning
      null;
   end Autoremove;

   -----------------
   -- Clean_Cache
   -----------------

   overriding procedure Clean_Cache
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree cleanup -m
      null;
   end Clean_Cache;

   ------------
   -- Rebase
   ------------

   procedure Rebase
     (Backend : in Out RPM_Ostree_Backend_Type;
      Ref     : String)
   is
      pragma Unreferenced (Backend, Ref);
   begin
      --  Would execute: rpm-ostree rebase <ref>
      null;
   end Rebase;

   ----------------------------
   -- Get_Current_Deployment
   ----------------------------

   function Get_Current_Deployment
     (Backend : RPM_Ostree_Backend_Type)
      return String
   is
      pragma Unreferenced (Backend);
   begin
      --  Would parse: rpm-ostree status
      return "current";
   end Get_Current_Deployment;

   ----------------------
   -- List_Deployments
   ----------------------

   function List_Deployments
     (Backend : RPM_Ostree_Backend_Type)
      return Unbounded_String
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree status
      return Null_Unbounded_String;
   end List_Deployments;

   --------------
   -- Rollback
   --------------

   procedure Rollback
     (Backend : in Out RPM_Ostree_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: rpm-ostree rollback
      null;
   end Rollback;

   --------------------
   -- Pin_Deployment
   --------------------

   procedure Pin_Deployment
     (Backend    : in Out RPM_Ostree_Backend_Type;
      Deployment : String)
   is
      pragma Unreferenced (Backend, Deployment);
   begin
      --  Would execute: ostree admin pin <index>
      null;
   end Pin_Deployment;

   ----------------------
   -- Unpin_Deployment
   ----------------------

   procedure Unpin_Deployment
     (Backend    : in Out RPM_Ostree_Backend_Type;
      Deployment : String)
   is
      pragma Unreferenced (Backend, Deployment);
   begin
      --  Would execute: ostree admin unpin <index>
      null;
   end Unpin_Deployment;

end RPM_Ostree_Backend;
