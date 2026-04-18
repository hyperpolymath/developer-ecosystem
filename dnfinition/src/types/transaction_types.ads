-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Transaction_Types - Types for package transaction management
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar;
with Ada.Containers.Vectors;
with Package_Types;  use Package_Types;
with Snapshot_Types; use Snapshot_Types;

package Transaction_Types is

   --  Operation kind for individual package operations
   type Operation_Kind is (
      Install,          --  Install new package
      Remove,           --  Remove installed package
      Upgrade,          --  Upgrade to newer version
      Downgrade,        --  Revert to older version
      Reinstall,        --  Reinstall same version
      Install_Deps,     --  Install as dependency
      Remove_Deps,      --  Remove unused dependency
      Autoremove        --  Remove orphaned auto-deps
   );

   --  Transaction status
   type Transaction_Status is (
      Pending,          --  Not yet executed
      In_Progress,      --  Currently executing
      Completed,        --  Successfully finished
      Failed,           --  Execution failed
      Rolled_Back,      --  Reverted after failure
      Cancelled         --  Cancelled by user
   );

   --  Transaction identifier
   subtype Transaction_ID is Natural;

   --  Invalid transaction ID
   Invalid_Transaction_ID : constant Transaction_ID := 0;

   --  Single operation entry within a transaction
   type Operation_Entry is record
      Sequence     : Positive := 1;
      Operation    : Operation_Kind := Install;
      Package_Name : Package_Name_Type;
      Old_Version  : Version_String;
      New_Version  : Version_String;
      Status       : Transaction_Status := Pending;
      Error_Msg    : Unbounded_String;
   end record;

   --  Operation vector
   package Operation_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Operation_Entry);

   subtype Operation_Array is Operation_Vectors.Vector;

   --  Full transaction record
   type Transaction_Info is record
      ID           : Transaction_ID := Invalid_Transaction_ID;
      Description  : Unbounded_String;
      Started_At   : Ada.Calendar.Time;
      Completed_At : Ada.Calendar.Time;
      Status       : Transaction_Status := Pending;
      Operations   : Operation_Array;
      Snapshot_ID  : Snapshot_ID := Invalid_Snapshot_ID;
      User         : Unbounded_String;
      Packages_Add : Package_Array;
      Packages_Del : Package_Array;
      Packages_Upg : Package_Array;
      Download_Size : Package_Size := 0;
      Install_Size  : Package_Size := 0;
      Remove_Size   : Package_Size := 0;
   end record;

   --  Null transaction constant
   Null_Transaction : constant Transaction_Info := (
      ID           => Invalid_Transaction_ID,
      Description  => Null_Unbounded_String,
      Started_At   => Ada.Calendar.Time_Of (1970, 1, 1),
      Completed_At => Ada.Calendar.Time_Of (1970, 1, 1),
      Status       => Cancelled,
      Operations   => Operation_Vectors.Empty_Vector,
      Snapshot_ID  => Invalid_Snapshot_ID,
      User         => Null_Unbounded_String,
      Packages_Add => Package_Vectors.Empty_Vector,
      Packages_Del => Package_Vectors.Empty_Vector,
      Packages_Upg => Package_Vectors.Empty_Vector,
      Download_Size => 0,
      Install_Size  => 0,
      Remove_Size   => 0
   );

   --  Transaction vector for history
   package Transaction_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Transaction_Info);

   subtype Transaction_Array is Transaction_Vectors.Vector;

   --  Transaction log entry (lightweight for logging)
   type Log_Entry is record
      Timestamp    : Ada.Calendar.Time;
      Trans_ID     : Transaction_ID;
      Operation    : Operation_Kind;
      Package_Name : Package_Name_Type;
      Old_Version  : Version_String;
      New_Version  : Version_String;
      Success      : Boolean := True;
      Error_Msg    : Unbounded_String;
   end record;

   --  Log entry vector
   package Log_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Log_Entry);

   subtype Log_Array is Log_Entry_Vectors.Vector;

   --  Helper functions
   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function Operation_Name (Op : Operation_Kind) return String is
     (case Op is
         when Install      => "install",
         when Remove       => "remove",
         when Upgrade      => "upgrade",
         when Downgrade    => "downgrade",
         when Reinstall    => "reinstall",
         when Install_Deps => "install-deps",
         when Remove_Deps  => "remove-deps",
         when Autoremove   => "autoremove");

   function Status_Name (S : Transaction_Status) return String is
     (case S is
         when Pending     => "pending",
         when In_Progress => "in-progress",
         when Completed   => "completed",
         when Failed      => "failed",
         when Rolled_Back => "rolled-back",
         when Cancelled   => "cancelled");

   --  Create an operation entry
   function Make_Operation
     (Op      : Operation_Kind;
      Name    : String;
      Old_Ver : String := "";
      New_Ver : String := "")
      return Operation_Entry;

   --  Calculate transaction summary
   procedure Calculate_Sizes
     (Trans : in out Transaction_Info);

   --  Check if transaction can be rolled back
   function Can_Rollback (Trans : Transaction_Info) return Boolean is
     (Trans.Status = Completed and Trans.Snapshot_ID /= Invalid_Snapshot_ID);

   --  Count operations of a specific kind
   function Count_Operations
     (Trans : Transaction_Info;
      Kind  : Operation_Kind)
      return Natural;

end Transaction_Types;
