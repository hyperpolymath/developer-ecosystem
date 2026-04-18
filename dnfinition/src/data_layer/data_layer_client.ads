-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Data Layer Client - Ada interface to Elixir CubDB backend
-- Uses JSON-over-pipe protocol for IPC
pragma Ada_2022;
pragma SPARK_Mode (Off);  -- Uses Ada.Containers (non-SPARK)

with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Calendar;

package Data_Layer_Client is

   use Ada.Strings.Unbounded;

   ---------------------------------------------------------------------------
   -- Types
   ---------------------------------------------------------------------------

   type Transaction_ID is new Positive;
   type Snapshot_ID is new Positive;

   type Transaction_Status is
     (Pending, In_Progress, Completed, Failed, Cancelled, Rolled_Back);

   type Operation_Type is
     (Install, Remove, Upgrade, Downgrade, Reinstall, Purge, Autoremove);

   type Operation_Status is (Pending, In_Progress, Completed, Failed, Skipped);

   type Install_Reason is (Manual, Dependency, Group_Install, Recommended, Suggested);

   type Snapshot_Type is (Snapshot_Manual, Snapshot_Auto, Pre_Transaction,
                          Post_Transaction, System_Snapshot);

   --  Operation record
   type Operation_Record is record
      Sequence       : Positive := 1;
      Operation      : Operation_Type := Install;
      Package_Name   : Unbounded_String;
      Old_Version    : Unbounded_String;
      New_Version    : Unbounded_String;
      Status         : Operation_Status := Pending;
      Size_Bytes     : Natural := 0;
   end record;

   package Operation_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Operation_Record);

   --  Transaction record
   type Transaction_Record is record
      ID              : Transaction_ID := 1;
      Description     : Unbounded_String;
      Started_At      : Ada.Calendar.Time;
      Completed_At    : Ada.Calendar.Time;
      Status          : Transaction_Status := Pending;
      User_Name       : Unbounded_String;
      Operations      : Operation_Vectors.Vector;
      Snapshot_ID     : Natural := 0;  -- 0 = no snapshot
      Error_Message   : Unbounded_String;
      Duration_Ms     : Natural := 0;
   end record;

   --  Package state record
   type Package_State is record
      Name            : Unbounded_String;
      Version         : Unbounded_String;
      Arch            : Unbounded_String;
      Install_Reason  : Data_Layer_Client.Install_Reason := Manual;
      Repository      : Unbounded_String;
      Size_Bytes      : Natural := 0;
      Held            : Boolean := False;
      Pinned_Version  : Unbounded_String;
   end record;

   package Package_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Package_State);

   --  Snapshot record
   type Snapshot_Record is record
      ID              : Snapshot_ID := 1;
      Name            : Unbounded_String;
      Description     : Unbounded_String;
      Created_At      : Ada.Calendar.Time;
      Snapshot_Type   : Data_Layer_Client.Snapshot_Type := Snapshot_Manual;
      User_Name       : Unbounded_String;
      Package_Count   : Natural := 0;
      Protected       : Boolean := False;
      Btrfs_Snapshot  : Unbounded_String;
      Ostree_Commit   : Unbounded_String;
      Transaction_ID  : Natural := 0;  -- 0 = no linked transaction
   end record;

   package Snapshot_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Snapshot_Record);

   --  Result types
   type Call_Status is (Success, Error, Timeout, Connection_Failed);

   type Call_Result (Status : Call_Status := Success) is record
      case Status is
         when Success =>
            null;
         when Error =>
            Error_Code    : Unbounded_String;
            Error_Message : Unbounded_String;
         when Timeout =>
            null;
         when Connection_Failed =>
            null;
      end case;
   end record;

   ---------------------------------------------------------------------------
   -- Initialization
   ---------------------------------------------------------------------------

   --  Initialize the data layer connection
   procedure Initialize;

   --  Check if data layer is available
   function Is_Available return Boolean;

   --  Shutdown the data layer connection
   procedure Shutdown;

   ---------------------------------------------------------------------------
   -- Transaction Operations
   ---------------------------------------------------------------------------

   --  Begin a new transaction
   function Begin_Transaction
     (Description : String;
      User        : String := "") return Transaction_ID;

   --  Add an operation to a transaction
   procedure Add_Operation
     (TX_ID       : Transaction_ID;
      Op_Type     : Operation_Type;
      Package     : String;
      Old_Version : String := "";
      New_Version : String := "");

   --  Commit a transaction
   function Commit_Transaction
     (TX_ID       : Transaction_ID;
      Snapshot_ID : Natural := 0) return Call_Result;

   --  Fail a transaction
   function Fail_Transaction
     (TX_ID   : Transaction_ID;
      Message : String := "") return Call_Result;

   --  Cancel a transaction
   function Cancel_Transaction (TX_ID : Transaction_ID) return Call_Result;

   --  Get transaction by ID
   function Get_Transaction (TX_ID : Transaction_ID) return Transaction_Record;

   --  List recent transactions
   function List_Transactions
     (Limit  : Positive := 100;
      Status : Transaction_Status := Pending) return Operation_Vectors.Vector;
      --  Note: Returns empty if filtering by status not matching

   --  Reverse (undo) a transaction
   function Reverse_Transaction (TX_ID : Transaction_ID) return Call_Result;

   --  Replay (redo) a transaction
   function Replay_Transaction (TX_ID : Transaction_ID) return Call_Result;

   --  Get current active transaction
   function Current_Transaction return Transaction_Record;

   --  Check if a transaction can be reversed
   function Can_Reverse (TX_ID : Transaction_ID) return Boolean;

   ---------------------------------------------------------------------------
   -- Snapshot Operations
   ---------------------------------------------------------------------------

   --  Create a new snapshot
   function Create_Snapshot
     (Name          : String;
      Description   : String := "";
      Snap_Type     : Snapshot_Type := Snapshot_Manual;
      Transaction   : Natural := 0;
      Protected     : Boolean := False) return Snapshot_ID;

   --  Get snapshot by ID
   function Get_Snapshot (ID : Snapshot_ID) return Snapshot_Record;

   --  Delete a snapshot
   function Delete_Snapshot (ID : Snapshot_ID) return Call_Result;

   --  List snapshots
   function List_Snapshots
     (Limit     : Positive := 100;
      Snap_Type : Snapshot_Type := Snapshot_Manual) return Snapshot_Vectors.Vector;

   --  Protect a snapshot from deletion
   function Protect_Snapshot (ID : Snapshot_ID) return Call_Result;

   --  Unprotect a snapshot
   function Unprotect_Snapshot (ID : Snapshot_ID) return Call_Result;

   --  Get the most recent snapshot
   function Latest_Snapshot return Snapshot_Record;

   --  Get snapshot linked to a transaction
   function Snapshot_For_Transaction (TX_ID : Transaction_ID) return Snapshot_Record;

   ---------------------------------------------------------------------------
   -- Package Operations
   ---------------------------------------------------------------------------

   --  Get package state
   function Get_Package (Name : String) return Package_State;

   --  Get package version
   function Get_Version (Name : String) return String;

   --  Check if package is installed
   function Is_Installed (Name : String) return Boolean;

   --  List installed packages
   function List_Packages
     (Filter : String := "") return Package_Vectors.Vector;

   --  Search packages by pattern
   function Search_Packages (Pattern : String) return Package_Vectors.Vector;

   --  Hold a package
   function Hold_Package (Name : String) return Call_Result;

   --  Unhold a package
   function Unhold_Package (Name : String) return Call_Result;

   --  Set install reason
   function Mark_Package
     (Name   : String;
      Reason : Install_Reason) return Call_Result;

   --  Record a package installation
   procedure Record_Package_Install
     (Name       : String;
      Version    : String;
      Reason     : Install_Reason := Manual;
      Repository : String := "";
      Size_Bytes : Natural := 0);

   --  Record a package update
   procedure Record_Package_Update
     (Name        : String;
      Old_Version : String;
      New_Version : String;
      Size_Bytes  : Natural := 0);

   --  Record a package removal
   procedure Record_Package_Remove (Name : String);

   --  Get package manifest (all packages with versions)
   function Get_Package_Manifest return Package_Vectors.Vector;

   ---------------------------------------------------------------------------
   -- Configuration Operations
   ---------------------------------------------------------------------------

   --  Get configuration value
   function Get_Config (Key : String) return String;

   --  Set configuration value
   procedure Set_Config (Key : String; Value : String);

   --  Get boolean configuration value
   function Get_Config_Bool (Key : String; Default : Boolean := False) return Boolean;

   --  Get integer configuration value
   function Get_Config_Int (Key : String; Default : Integer := 0) return Integer;

   ---------------------------------------------------------------------------
   -- Utility Functions
   ---------------------------------------------------------------------------

   --  Ping the data layer to check connectivity
   function Ping return Boolean;

   --  Get data layer version
   function Get_Version return String;

   --  Cleanup old transactions
   function Cleanup_Transactions (Keep_Last : Positive := 100) return Natural;

   --  Cleanup old snapshots
   function Cleanup_Snapshots (Keep_Last : Positive := 50) return Natural;

private

   --  Internal state
   Data_Layer_Available : Boolean := False;
   Port_Handle          : Integer := -1;

   --  JSON communication helpers
   function Send_Request (Operation : String; Args : String := "{}") return String;
   function Parse_Response (Response : String) return Call_Result;

end Data_Layer_Client;
