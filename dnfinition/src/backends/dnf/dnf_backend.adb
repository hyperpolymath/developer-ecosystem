-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- DNF_Backend - Implementation
pragma Ada_2022;

with GNAT.OS_Lib;
with Detection;
with Snapshot_Manager;
with Transaction_Log;

package body DNF_Backend is

   --  Helper to check if dnf/dnf5 is available
   function DNF_Available return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path ("dnf");
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
         return True;
      end if;
      return False;
   end DNF_Available;

   function DNF5_Available return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path ("dnf5");
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
         return True;
      end if;
      return False;
   end DNF5_Available;

   ----------
   -- Name
   ----------

   overriding function Name
     (Backend : DNF_Backend_Type)
      return String
   is
   begin
      return (if Backend.Use_DNF5 then "dnf5" else "dnf");
   end Name;

   ------------------
   -- Capabilities
   ------------------

   overriding function Capabilities
     (Backend : DNF_Backend_Type)
      return Capability_Set
   is
      pragma Unreferenced (Backend);
   begin
      return (
         Cap_Install         => True,
         Cap_Remove          => True,
         Cap_Upgrade         => True,
         Cap_Downgrade       => True,
         Cap_Search          => True,
         Cap_List_Installed  => True,
         Cap_Check_Updates   => True,
         Cap_Native_Snapshots => False,  --  Uses filesystem snapshots
         Cap_Transactions    => True,
         Cap_Dry_Run         => True,
         Cap_Hold_Packages   => True,
         Cap_Repository_Mgmt => True,
         Cap_File_Query      => True
      );
   end Capabilities;

   ------------------
   -- Is_Available
   ------------------

   overriding function Is_Available
     (Backend : DNF_Backend_Type)
      return Boolean
   is
      pragma Unreferenced (Backend);
   begin
      return DNF_Available or else DNF5_Available;
   end Is_Available;

   ----------------
   -- Initialize
   ----------------

   overriding procedure Initialize
     (Backend : in Out DNF_Backend_Type)
   is
   begin
      Backend.Use_DNF5 := DNF5_Available;
      Backend.Initialized := True;
   end Initialize;

   ----------------------
   -- Install_Package
   ----------------------

   overriding procedure Install_Package
     (Backend : in Out DNF_Backend_Type;
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
     (Backend  : in Out DNF_Backend_Type;
      Packages : Package_Array)
   is
      Snap_ID : Snapshot_Types.Snapshot_ID;
   begin
      --  Create snapshot before install
      Snapshot_Manager.Create_Snapshot
        ("Pre-install", Snap_ID);

      --  Build package list
      --  Would execute: dnf install -y pkg1 pkg2 ...

      --  Log the operation
      if Backend.In_Trans then
         for Pkg of Packages loop
            Transaction_Log.Add_Operation
              (Backend.Current_Trans,
               Make_Operation
                 (Install,
                  To_String (Pkg.Name),
                  New_Ver => To_String (Pkg.Version)));
         end loop;
      end if;
   end Install_Packages;

   ---------------------
   -- Remove_Package
   ---------------------

   overriding procedure Remove_Package
     (Backend : in Out DNF_Backend_Type;
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
     (Backend  : in Out DNF_Backend_Type;
      Packages : Package_Array)
   is
   begin
      --  Would execute: dnf remove -y pkg1 pkg2 ...
      if Backend.In_Trans then
         for Pkg of Packages loop
            Transaction_Log.Add_Operation
              (Backend.Current_Trans,
               Make_Operation
                 (Remove,
                  To_String (Pkg.Name),
                  Old_Ver => To_String (Pkg.Version)));
         end loop;
      end if;
   end Remove_Packages;

   ----------------------
   -- Upgrade_Package
   ----------------------

   overriding procedure Upgrade_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info)
   is
   begin
      --  Would execute: dnf upgrade -y <package>
      if Backend.In_Trans then
         Transaction_Log.Add_Operation
           (Backend.Current_Trans,
            Make_Operation
              (Upgrade,
               To_String (Package.Name)));
      end if;
   end Upgrade_Package;

   -----------------
   -- Upgrade_All
   -----------------

   overriding procedure Upgrade_All
     (Backend : in Out DNF_Backend_Type)
   is
      Snap_ID : Snapshot_Types.Snapshot_ID;
   begin
      --  Create snapshot before upgrade
      Snapshot_Manager.Create_Snapshot ("Pre-upgrade", Snap_ID);

      --  Would execute: dnf upgrade -y
      null;
   end Upgrade_All;

   ------------------------
   -- Downgrade_Package
   ------------------------

   overriding procedure Downgrade_Package
     (Backend    : in Out DNF_Backend_Type;
      Package    : Package_Info;
      To_Version : String)
   is
   begin
      --  Would execute: dnf downgrade -y <package>-<version>
      if Backend.In_Trans then
         Transaction_Log.Add_Operation
           (Backend.Current_Trans,
            Make_Operation
              (Downgrade,
               To_String (Package.Name),
               Old_Ver => To_String (Package.Version),
               New_Ver => To_Version));
      end if;
   end Downgrade_Package;

   ----------------------
   -- Search_Packages
   ----------------------

   overriding function Search_Packages
     (Backend : DNF_Backend_Type;
      Query   : String)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Query);
   begin
      --  Would execute: dnf search <query>
      --  Parse output and create Package_Info records
      return Result;
   end Search_Packages;

   ----------------------
   -- Get_Package_Info
   ----------------------

   overriding function Get_Package_Info
     (Backend : DNF_Backend_Type;
      Name    : String)
      return Package_Info
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf info <name>
      --  Parse output
      return Make_Package (Name);
   end Get_Package_Info;

   -----------------------------
   -- List_Installed_Packages
   -----------------------------

   overriding function List_Installed_Packages
     (Backend : DNF_Backend_Type)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf list installed
      return Result;
   end List_Installed_Packages;

   --------------------
   -- Check_Updates
   --------------------

   overriding function Check_Updates
     (Backend : DNF_Backend_Type)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf check-update
      return Result;
   end Check_Updates;

   ----------------------
   -- Get_Dependencies
   ----------------------

   overriding function Get_Dependencies
     (Backend : DNF_Backend_Type;
      Package : Package_Info)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Package);
   begin
      --  Would execute: dnf repoquery --requires <package>
      return Result;
   end Get_Dependencies;

   ------------------------------
   -- Get_Reverse_Dependencies
   ------------------------------

   overriding function Get_Reverse_Dependencies
     (Backend : DNF_Backend_Type;
      Package : Package_Info)
      return Package_Array
   is
      Result : Package_Array;
      pragma Unreferenced (Backend, Package);
   begin
      --  Would execute: dnf repoquery --whatrequires <package>
      return Result;
   end Get_Reverse_Dependencies;

   --------------------------
   -- Find_Package_By_File
   --------------------------

   overriding function Find_Package_By_File
     (Backend : DNF_Backend_Type;
      Path    : String)
      return Package_Info
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf provides <path>
      return Null_Package;
   end Find_Package_By_File;

   -----------------------
   -- Begin_Transaction
   -----------------------

   overriding procedure Begin_Transaction
     (Backend : in Out DNF_Backend_Type)
   is
   begin
      Backend.Current_Trans := Transaction_Log.Begin_Transaction
        ("DNF Transaction");
      Transaction_Log.Start_Transaction (Backend.Current_Trans);
      Backend.In_Trans := True;
   end Begin_Transaction;

   ------------------------
   -- Commit_Transaction
   ------------------------

   overriding procedure Commit_Transaction
     (Backend : in Out DNF_Backend_Type)
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
     (Backend : in Out DNF_Backend_Type)
   is
   begin
      if Backend.In_Trans then
         Transaction_Log.Cancel_Transaction (Backend.Current_Trans);
         Backend.In_Trans := False;
         Backend.Current_Trans := Invalid_Transaction_ID;
      end if;
   end Rollback_Transaction;

   --------------------
   -- In_Transaction
   --------------------

   overriding function In_Transaction
     (Backend : DNF_Backend_Type)
      return Boolean
   is
   begin
      return Backend.In_Trans;
   end In_Transaction;

   ----------------------
   -- Preview_Install
   ----------------------

   overriding function Preview_Install
     (Backend  : DNF_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend, Packages);
   begin
      --  Would execute: dnf install --assumeno <packages>
      --  Parse output for dependencies
      return Result;
   end Preview_Install;

   ---------------------
   -- Preview_Remove
   ---------------------

   overriding function Preview_Remove
     (Backend  : DNF_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend, Packages);
   begin
      --  Would execute: dnf remove --assumeno <packages>
      return Result;
   end Preview_Remove;

   ----------------------
   -- Preview_Upgrade
   ----------------------

   overriding function Preview_Upgrade
     (Backend : DNF_Backend_Type)
      return Transaction_Info
   is
      Result : Transaction_Info;
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf upgrade --assumeno
      return Result;
   end Preview_Upgrade;

   --------------------------------
   -- Supports_Native_Snapshots
   --------------------------------

   overriding function Supports_Native_Snapshots
     (Backend : DNF_Backend_Type)
      return Boolean
   is
      pragma Unreferenced (Backend);
   begin
      return False;  --  DNF uses filesystem snapshots
   end Supports_Native_Snapshots;

   ----------------------------
   -- Create_Native_Snapshot
   ----------------------------

   overriding procedure Create_Native_Snapshot
     (Backend     : in Out DNF_Backend_Type;
      Description : String;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID)
   is
      pragma Unreferenced (Backend);
   begin
      --  Use external snapshot manager
      Snapshot_Manager.Create_Snapshot (Description, Snapshot_ID);
   end Create_Native_Snapshot;

   ------------------------------
   -- Rollback_Native_Snapshot
   ------------------------------

   overriding procedure Rollback_Native_Snapshot
     (Backend     : in Out DNF_Backend_Type;
      Snapshot_ID : Snapshot_Types.Snapshot_ID)
   is
      pragma Unreferenced (Backend);
   begin
      Snapshot_Manager.Rollback_To_Snapshot (Snapshot_ID);
   end Rollback_Native_Snapshot;

   --------------------------
   -- Refresh_Repositories
   --------------------------

   overriding procedure Refresh_Repositories
     (Backend : in Out DNF_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf makecache
      null;
   end Refresh_Repositories;

   -----------------------
   -- List_Repositories
   -----------------------

   overriding function List_Repositories
     (Backend : DNF_Backend_Type)
      return Unbounded_String
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf repolist
      return Null_Unbounded_String;
   end List_Repositories;

   ------------------
   -- Hold_Package
   ------------------

   overriding procedure Hold_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info)
   is
      pragma Unreferenced (Backend, Package);
   begin
      --  Would use dnf versionlock
      null;
   end Hold_Package;

   --------------------
   -- Unhold_Package
   --------------------

   overriding procedure Unhold_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info)
   is
      pragma Unreferenced (Backend, Package);
   begin
      --  Would use dnf versionlock delete
      null;
   end Unhold_Package;

   ----------------
   -- Autoremove
   ----------------

   overriding procedure Autoremove
     (Backend : in Out DNF_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf autoremove -y
      null;
   end Autoremove;

   -----------------
   -- Clean_Cache
   -----------------

   overriding procedure Clean_Cache
     (Backend : in Out DNF_Backend_Type)
   is
      pragma Unreferenced (Backend);
   begin
      --  Would execute: dnf clean all
      null;
   end Clean_Cache;

end DNF_Backend;
