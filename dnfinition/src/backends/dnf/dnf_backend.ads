-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- DNF_Backend - DNF package manager backend (Fedora, RHEL, etc.)
pragma Ada_2022;

with Backend_Interface; use Backend_Interface;
with Package_Types;     use Package_Types;
with Transaction_Types; use Transaction_Types;
with Snapshot_Types;    use Snapshot_Types;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package DNF_Backend is

   --  DNF backend implementation
   type DNF_Backend_Type is new Package_Manager_Backend with private;

   --  Backend interface implementation
   overriding function Name
     (Backend : DNF_Backend_Type)
      return String;

   overriding function Capabilities
     (Backend : DNF_Backend_Type)
      return Capability_Set;

   overriding function Is_Available
     (Backend : DNF_Backend_Type)
      return Boolean;

   overriding procedure Initialize
     (Backend : in Out DNF_Backend_Type);

   --  Package operations
   overriding procedure Install_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info);

   overriding procedure Install_Packages
     (Backend  : in Out DNF_Backend_Type;
      Packages : Package_Array);

   overriding procedure Remove_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info);

   overriding procedure Remove_Packages
     (Backend  : in Out DNF_Backend_Type;
      Packages : Package_Array);

   overriding procedure Upgrade_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info);

   overriding procedure Upgrade_All
     (Backend : in Out DNF_Backend_Type);

   overriding procedure Downgrade_Package
     (Backend    : in Out DNF_Backend_Type;
      Package    : Package_Info;
      To_Version : String);

   --  Query operations
   overriding function Search_Packages
     (Backend : DNF_Backend_Type;
      Query   : String)
      return Package_Array;

   overriding function Get_Package_Info
     (Backend : DNF_Backend_Type;
      Name    : String)
      return Package_Info;

   overriding function List_Installed_Packages
     (Backend : DNF_Backend_Type)
      return Package_Array;

   overriding function Check_Updates
     (Backend : DNF_Backend_Type)
      return Package_Array;

   overriding function Get_Dependencies
     (Backend : DNF_Backend_Type;
      Package : Package_Info)
      return Package_Array;

   overriding function Get_Reverse_Dependencies
     (Backend : DNF_Backend_Type;
      Package : Package_Info)
      return Package_Array;

   overriding function Find_Package_By_File
     (Backend : DNF_Backend_Type;
      Path    : String)
      return Package_Info;

   --  Transaction operations
   overriding procedure Begin_Transaction
     (Backend : in Out DNF_Backend_Type);

   overriding procedure Commit_Transaction
     (Backend : in Out DNF_Backend_Type);

   overriding procedure Rollback_Transaction
     (Backend : in Out DNF_Backend_Type);

   overriding function In_Transaction
     (Backend : DNF_Backend_Type)
      return Boolean;

   --  Preview operations
   overriding function Preview_Install
     (Backend  : DNF_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info;

   overriding function Preview_Remove
     (Backend  : DNF_Backend_Type;
      Packages : Package_Array)
      return Transaction_Info;

   overriding function Preview_Upgrade
     (Backend : DNF_Backend_Type)
      return Transaction_Info;

   --  Snapshot (uses external filesystem snapshots)
   overriding function Supports_Native_Snapshots
     (Backend : DNF_Backend_Type)
      return Boolean;

   overriding procedure Create_Native_Snapshot
     (Backend     : in Out DNF_Backend_Type;
      Description : String;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID);

   overriding procedure Rollback_Native_Snapshot
     (Backend     : in Out DNF_Backend_Type;
      Snapshot_ID : Snapshot_Types.Snapshot_ID);

   --  Repository management
   overriding procedure Refresh_Repositories
     (Backend : in Out DNF_Backend_Type);

   overriding function List_Repositories
     (Backend : DNF_Backend_Type)
      return Unbounded_String;

   --  Package hold
   overriding procedure Hold_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info);

   overriding procedure Unhold_Package
     (Backend : in Out DNF_Backend_Type;
      Package : Package_Info);

   --  Cleanup
   overriding procedure Autoremove
     (Backend : in Out DNF_Backend_Type);

   overriding procedure Clean_Cache
     (Backend : in Out DNF_Backend_Type);

private

   type DNF_Backend_Type is new Package_Manager_Backend with record
      Initialized     : Boolean := False;
      In_Trans        : Boolean := False;
      Use_DNF5        : Boolean := False;  --  Use dnf5 if available
      Current_Trans   : Transaction_ID := Invalid_Transaction_ID;
   end record;

end DNF_Backend;
