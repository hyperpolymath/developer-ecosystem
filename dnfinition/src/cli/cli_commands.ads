-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- CLI_Commands - Command implementations (nala-style)
--
-- Provides all CLI commands with nala-style output and functionality.
-- Commands work across all supported package manager backends.
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Detection;

package CLI_Commands is

   ---------------------------------------------------------------------------
   --  Command Options (shared across commands)
   ---------------------------------------------------------------------------

   type Command_Options is record
      --  Confirmation
      Assume_Yes      : Boolean := False;  -- -y, --yes
      Assume_No       : Boolean := False;  -- -n, --no

      --  Safety
      Dry_Run         : Boolean := False;  -- --dry-run
      No_Snapshot     : Boolean := False;  -- --no-snapshot

      --  Download
      Download_Only   : Boolean := False;  -- -d, --download-only
      Parallel        : Positive := 4;     -- --parallel=N

      --  Output
      Verbose         : Boolean := False;  -- -v, --verbose
      Quiet           : Boolean := False;  -- -q, --quiet
      No_Color        : Boolean := False;  -- --no-color
      Raw             : Boolean := False;  -- --raw (for scripting)

      --  Scope (for install/remove)
      Purge           : Boolean := False;  -- --purge
      Autoremove      : Boolean := False;  -- --autoremove
      No_Recommends   : Boolean := False;  -- --no-recommends
      No_Suggests     : Boolean := False;  -- --no-suggests

      --  Version pinning
      Allow_Downgrade : Boolean := False;  -- --allow-downgrade

      --  File install
      Install_File    : Boolean := False;  -- Installing .deb/.rpm directly
   end record;

   Default_Options : constant Command_Options := (others => <>);

   ---------------------------------------------------------------------------
   --  Core Package Commands (nala equivalents)
   ---------------------------------------------------------------------------

   --  Install packages
   --  nala install pkg1 pkg2 ...
   --  Supports:
   --    - Package names from repositories
   --    - .deb / .rpm file paths
   --    - URLs to packages
   --    - Version constraints (pkg=1.0, pkg>=1.0)
   procedure Cmd_Install
     (Packages : String;  -- Space-separated package specs
      Options  : Command_Options := Default_Options);

   --  Remove packages
   --  nala remove pkg1 pkg2 ...
   procedure Cmd_Remove
     (Packages : String;
      Options  : Command_Options := Default_Options);

   --  Purge packages (remove + config files)
   --  nala purge pkg1 pkg2 ...
   procedure Cmd_Purge
     (Packages : String;
      Options  : Command_Options := Default_Options);

   --  Update package lists
   --  nala update
   procedure Cmd_Update
     (Options : Command_Options := Default_Options);

   --  Upgrade packages
   --  nala upgrade [pkg1 pkg2 ...]
   procedure Cmd_Upgrade
     (Packages : String := "";  -- Empty = upgrade all
      Options  : Command_Options := Default_Options);

   --  Full system upgrade (like apt full-upgrade)
   --  Allows removing packages if needed
   procedure Cmd_Full_Upgrade
     (Options : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Query Commands
   ---------------------------------------------------------------------------

   --  Search for packages
   --  nala search query
   procedure Cmd_Search
     (Query   : String;
      Options : Command_Options := Default_Options);

   --  Show package information
   --  nala show pkg
   procedure Cmd_Show
     (Package_Name : String;
      Options      : Command_Options := Default_Options);

   --  List installed packages
   --  nala list [--installed] [--upgradable]
   type List_Filter is (All_Packages, Installed_Only, Upgradable_Only, Held_Only);

   procedure Cmd_List
     (Filter  : List_Filter := Installed_Only;
      Pattern : String := "";
      Options : Command_Options := Default_Options);

   --  Show package dependencies
   procedure Cmd_Depends
     (Package_Name : String;
      Reverse_Deps : Boolean := False;  -- Show what depends on this
      Options      : Command_Options := Default_Options);

   --  Find which package owns a file
   procedure Cmd_Which
     (File_Path : String;
      Options   : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  History & Rollback Commands (dnfinition unique feature)
   ---------------------------------------------------------------------------

   --  Show transaction history
   --  nala history
   procedure Cmd_History
     (Count   : Positive := 20;
      Options : Command_Options := Default_Options);

   --  Undo a transaction
   --  nala history undo ID
   procedure Cmd_History_Undo
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options);

   --  Redo a transaction
   --  nala history redo ID
   procedure Cmd_History_Redo
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options);

   --  Show transaction details
   --  nala history info ID
   procedure Cmd_History_Info
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options);

   --  Clear transaction history
   procedure Cmd_History_Clear
     (Options : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Snapshot Commands
   ---------------------------------------------------------------------------

   --  List snapshots
   procedure Cmd_Snapshots
     (Options : Command_Options := Default_Options);

   --  Create a snapshot
   procedure Cmd_Snapshot_Create
     (Description : String := "";
      Options     : Command_Options := Default_Options);

   --  Rollback to snapshot
   procedure Cmd_Snapshot_Rollback
     (Snapshot_ID : Natural;
      Options     : Command_Options := Default_Options);

   --  Delete a snapshot
   procedure Cmd_Snapshot_Delete
     (Snapshot_ID : Natural;
      Options     : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Mirror/Fetch Commands (nala fetch style)
   ---------------------------------------------------------------------------

   --  Find and configure fastest mirrors
   --  nala fetch
   procedure Cmd_Fetch
     (Country     : String := "";   -- Filter by country
      Https_Only  : Boolean := True;
      Test_Count  : Positive := 5;  -- Number of mirrors to test
      Options     : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Maintenance Commands
   ---------------------------------------------------------------------------

   --  Clean package cache
   --  nala clean
   procedure Cmd_Clean
     (All_Versions : Boolean := False;  -- Remove all cached packages
      Options      : Command_Options := Default_Options);

   --  Fix broken packages
   procedure Cmd_Fix
     (Options : Command_Options := Default_Options);

   --  Autoremove unused packages
   procedure Cmd_Autoremove
     (Purge   : Boolean := False;
      Options : Command_Options := Default_Options);

   --  Mark package as manually/automatically installed
   type Mark_Type is (Manual, Automatic, Hold, Unhold);

   procedure Cmd_Mark
     (Package_Name : String;
      Mark         : Mark_Type;
      Options      : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  System Information Commands
   ---------------------------------------------------------------------------

   --  Show system and backend info
   procedure Cmd_System_Info
     (Options : Command_Options := Default_Options);

   --  Show available language package managers
   procedure Cmd_Language_Pms
     (Options : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Direct File Install (deb/rpm)
   ---------------------------------------------------------------------------

   --  Install .deb file
   procedure Cmd_Install_Deb
     (File_Path : String;
      Options   : Command_Options := Default_Options);

   --  Install .rpm file
   procedure Cmd_Install_Rpm
     (File_Path : String;
      Options   : Command_Options := Default_Options);

   --  Generic file install (auto-detect type)
   procedure Cmd_Install_File
     (File_Path : String;
      Options   : Command_Options := Default_Options);

   ---------------------------------------------------------------------------
   --  Helpers
   ---------------------------------------------------------------------------

   --  Parse command line arguments into options
   function Parse_Options return Command_Options;

   --  Get remaining arguments (package names, etc.)
   function Get_Arguments return String;

   --  Check if running as root (for system PM operations)
   function Is_Root return Boolean;

   --  Request elevation if needed
   procedure Ensure_Root (Operation : String);

private

   --  Current detected backend
   Current_PM : Detection.System_Package_Manager := Detection.Unknown_System_PM;

   --  Initialize backend
   procedure Initialize_Backend;

end CLI_Commands;
