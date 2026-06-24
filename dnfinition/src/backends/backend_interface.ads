-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Backend_Interface - Abstract interface for all package manager backends
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Package_Types;     use Package_Types;
with Transaction_Types; use Transaction_Types;
with Snapshot_Types;    use Snapshot_Types;

package Backend_Interface is

   --  Common exceptions
   Backend_Error        : exception;
   Package_Not_Found    : exception;
   Dependency_Error     : exception;
   Permission_Denied    : exception;
   Transaction_Failed   : exception;

   --  Backend capabilities
   type Backend_Capability is (
      Cap_Install,           --  Can install packages
      Cap_Remove,            --  Can remove packages
      Cap_Upgrade,           --  Can upgrade packages
      Cap_Downgrade,         --  Can downgrade packages
      Cap_Search,            --  Can search repositories
      Cap_List_Installed,    --  Can list installed packages
      Cap_Check_Updates,     --  Can check for updates
      Cap_Native_Snapshots,  --  Has built-in snapshot support
      Cap_Transactions,      --  Supports transactional operations
      Cap_Dry_Run,           --  Can preview operations
      Cap_Hold_Packages,     --  Can pin/hold package versions
      Cap_Repository_Mgmt,   --  Can add/remove repositories
      Cap_File_Query         --  Can find which package owns a file
   );

   type Capability_Set is array (Backend_Capability) of Boolean;

   --  All capabilities
   All_Capabilities : constant Capability_Set := (others => True);

   --  Abstract backend interface
   type Package_Manager_Backend is interface;

   --  Get backend name
   function Name (Backend : Package_Manager_Backend) return String is abstract;

   --  Get backend capabilities
   function Capabilities
     (Backend : Package_Manager_Backend)
      return Capability_Set is abstract;

   --  Check if backend is available on this system
   function Is_Available
     (Backend : Package_Manager_Backend)
      return Boolean is abstract;

   --  Initialize the backend
   procedure Initialize
     (Backend : in out Package_Manager_Backend) is abstract;

   --  Package operations
   procedure Install_Package
     (Backend : in Out Package_Manager_Backend;
      Package : Package_Info) is abstract;

   procedure Install_Packages
     (Backend  : in Out Package_Manager_Backend;
      Packages : Package_Array) is abstract;

   procedure Remove_Package
     (Backend : in Out Package_Manager_Backend;
      Package : Package_Info) is abstract;

   procedure Remove_Packages
     (Backend  : in Out Package_Manager_Backend;
      Packages : Package_Array) is abstract;

   procedure Upgrade_Package
     (Backend : in Out Package_Manager_Backend;
      Package : Package_Info) is abstract;

   procedure Upgrade_All
     (Backend : in Out Package_Manager_Backend) is abstract;

   procedure Downgrade_Package
     (Backend     : in Out Package_Manager_Backend;
      Package     : Package_Info;
      To_Version  : String) is abstract;

   --  Query operations
   function Search_Packages
     (Backend : Package_Manager_Backend;
      Query   : String)
      return Package_Array is abstract;

   function Get_Package_Info
     (Backend : Package_Manager_Backend;
      Name    : String)
      return Package_Info is abstract;

   function List_Installed_Packages
     (Backend : Package_Manager_Backend)
      return Package_Array is abstract;

   function Check_Updates
     (Backend : Package_Manager_Backend)
      return Package_Array is abstract;

   function Get_Dependencies
     (Backend : Package_Manager_Backend;
      Package : Package_Info)
      return Package_Array is abstract;

   function Get_Reverse_Dependencies
     (Backend : Package_Manager_Backend;
      Package : Package_Info)
      return Package_Array is abstract;

   function Find_Package_By_File
     (Backend : Package_Manager_Backend;
      Path    : String)
      return Package_Info is abstract;

   --  Transaction operations
   procedure Begin_Transaction
     (Backend : in Out Package_Manager_Backend) is abstract;

   procedure Commit_Transaction
     (Backend : in Out Package_Manager_Backend) is abstract;

   procedure Rollback_Transaction
     (Backend : in Out Package_Manager_Backend) is abstract;

   function In_Transaction
     (Backend : Package_Manager_Backend)
      return Boolean is abstract;

   --  Dry run / preview
   function Preview_Install
     (Backend  : Package_Manager_Backend;
      Packages : Package_Array)
      return Transaction_Info is abstract;

   function Preview_Remove
     (Backend  : Package_Manager_Backend;
      Packages : Package_Array)
      return Transaction_Info is abstract;

   function Preview_Upgrade
     (Backend : Package_Manager_Backend)
      return Transaction_Info is abstract;

   --  Snapshot integration (for backends with native support)
   function Supports_Native_Snapshots
     (Backend : Package_Manager_Backend)
      return Boolean is abstract;

   procedure Create_Native_Snapshot
     (Backend     : in Out Package_Manager_Backend;
      Description : String;
      Snapshot_ID : out Snapshot_Types.Snapshot_ID) is abstract;

   procedure Rollback_Native_Snapshot
     (Backend     : in Out Package_Manager_Backend;
      Snapshot_ID : Snapshot_Types.Snapshot_ID) is abstract;

   --  Repository management
   procedure Refresh_Repositories
     (Backend : in Out Package_Manager_Backend) is abstract;

   function List_Repositories
     (Backend : Package_Manager_Backend)
      return Unbounded_String is abstract;

   --  Package hold/pin
   procedure Hold_Package
     (Backend : in Out Package_Manager_Backend;
      Package : Package_Info) is abstract;

   procedure Unhold_Package
     (Backend : in Out Package_Manager_Backend;
      Package : Package_Info) is abstract;

   --  Cleanup
   procedure Autoremove
     (Backend : in Out Package_Manager_Backend) is abstract;

   procedure Clean_Cache
     (Backend : in Out Package_Manager_Backend) is abstract;

   --  Helper to check capability
   function Has_Capability
     (Backend : Package_Manager_Backend'Class;
      Cap     : Backend_Capability)
      return Boolean;

   --  Get the appropriate backend for the current system
   function Get_Default_Backend
     return access Package_Manager_Backend'Class;

private

   function Has_Capability
     (Backend : Package_Manager_Backend'Class;
      Cap     : Backend_Capability)
      return Boolean
   is (Backend.Capabilities (Cap));

end Backend_Interface;
