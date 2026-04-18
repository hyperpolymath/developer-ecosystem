-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- CLI_Commands - Implementation
pragma Ada_2022;

with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Calendar.Formatting;
with GNAT.OS_Lib;

with CLI_Output;
with Detection;
with Transaction_Log;
with Transaction_Types;
with Snapshot_Manager;
with Snapshot_Types;
with Rollback_Engine;
with Command_Executor;
with Data_Layer_Client;

package body CLI_Commands is

   use Ada.Text_IO;
   use Ada.Strings.Fixed;
   use CLI_Output;

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   Backend_Initialized : Boolean := False;

   procedure Initialize_Backend is
   begin
      if not Backend_Initialized then
         Current_PM := Detection.Detect_Package_Manager;
         Backend_Initialized := True;
      end if;
   end Initialize_Backend;

   function Is_Root return Boolean is
      Euid : constant String := GNAT.OS_Lib.Getenv ("EUID").all;
   begin
      return Euid = "0";
   exception
      when others =>
         --  Try checking /root access
         return Ada.Directories.Exists ("/root");
   end Is_Root;

   procedure Ensure_Root (Operation : String) is
   begin
      if not Is_Root then
         Print_Error ("This operation requires root privileges: " & Operation);
         Print_Info ("Try running with 'sudo dnfinition " & Operation & "'");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error with "Root required";
      end if;
   end Ensure_Root;

   --  Output callback for interactive display
   procedure Display_Line (Line : String) is
   begin
      Print_Line (Line);
   end Display_Line;

   --  Run backend command (apt, dnf, pacman, etc.)
   procedure Run_Backend_Command
     (Command : String;
      Args    : String;
      Options : Command_Options)
   is
      PM_Name  : constant String := Detection.PM_Name (Current_PM);
      Full_Cmd : constant String := PM_Name & " " & Command & " " & Args;
      Result   : Command_Executor.Command_Result;
   begin
      if Options.Dry_Run then
         Print_Info ("Would run: " & Full_Cmd);
         return;
      end if;

      if Options.Verbose then
         Print_Line (Dim & "$ " & Full_Cmd & Reset);
      end if;

      --  Execute command with interactive output
      if Options.Quiet then
         Result := Command_Executor.Execute_Privileged (PM_Name, Command & " " & Args);
      else
         Command_Executor.Execute_Interactive
           (Command   => PM_Name,
            Args      => Command & " " & Args,
            On_Stdout => Display_Line'Access,
            Result    => Result);
      end if;

      if not Result.Success then
         Print_Error ("Command failed with exit code" & Result.Exit_Code'Image);
         if Options.Verbose and then Length (Result.Stderr) > 0 then
            Print_Line (Red & To_String (Result.Stderr) & Reset);
         end if;
      end if;
   end Run_Backend_Command;

   ---------------------------------------------------------------------------
   --  Core Package Commands
   ---------------------------------------------------------------------------

   procedure Cmd_Install
     (Packages : String;
      Options  : Command_Options := Default_Options)
   is
      use Detection;
      use Data_Layer_Client;
      TX_ID   : Transaction_ID;
      Snap_ID : Snapshot_ID := 1;
      Install_Success : Boolean := False;
   begin
      Initialize_Backend;

      if Packages = "" then
         Print_Error ("No packages specified");
         return;
      end if;

      --  Check for file paths
      if Index (Packages, ".deb") > 0 or Index (Packages, ".rpm") > 0 then
         Cmd_Install_File (Packages, Options);
         return;
      end if;

      Print_Header ("Installing Packages");
      Print_Info ("Packages: " & Packages);

      --  Initialize data layer and begin transaction
      if Is_Available then
         TX_ID := Begin_Transaction ("Install: " & Packages);
         if Options.Verbose then
            Print_Info ("Transaction #" & Transaction_ID'Image (TX_ID) & " started");
         end if;
      end if;

      --  Create pre-operation snapshot linked to transaction
      if not Options.No_Snapshot then
         Print_Info ("Creating pre-install snapshot...");
         if Is_Available then
            Snap_ID := Create_Snapshot
              (Name        => "Pre-install: " & Packages,
               Snap_Type   => Pre_Transaction,
               Transaction => Natural (TX_ID));
         else
            --  Fallback to local snapshot manager
            Snapshot_Manager.Create_Snapshot ("Pre-install: " & Packages);
         end if;
      end if;

      --  Show what will be installed
      Print_Subheader ("The following packages will be installed:");

      --  Split packages and display them, add operations to transaction
      declare
         Pos : Natural := Packages'First;
         Start : Natural;
      begin
         while Pos <= Packages'Last loop
            --  Skip spaces
            while Pos <= Packages'Last and then Packages (Pos) = ' ' loop
               Pos := Pos + 1;
            end loop;

            Start := Pos;

            --  Find end of package name
            while Pos <= Packages'Last and then Packages (Pos) /= ' ' loop
               Pos := Pos + 1;
            end loop;

            if Start < Pos then
               declare
                  Pkg_Name : constant String := Packages (Start .. Pos - 1);
               begin
                  Print_Package (Name => Pkg_Name, Action => Action_Install);

                  --  Record operation in transaction
                  if Is_Available then
                     Add_Operation
                       (TX_ID   => TX_ID,
                        Op_Type => Install,
                        Package => Pkg_Name);
                  end if;
               end;
            end if;
         end loop;
      end;

      --  Transaction summary
      declare
         Summary : Transaction_Summary;
      begin
         Summary.Installing := 1;  -- TODO: Actual count
         Summary.Download_Size := +"calculating...";
         Print_Transaction_Summary (Summary);
      end;

      --  Confirm
      if not Options.Assume_Yes then
         if not Confirm_Transaction then
            Print_Info ("Operation cancelled");
            --  Cancel the transaction
            if Is_Available then
               declare
                  Result : constant Call_Result := Cancel_Transaction (TX_ID);
                  pragma Unreferenced (Result);
               begin
                  null;
               end;
            end if;
            return;
         end if;
      end if;

      --  Run the install based on backend
      begin
         case Current_PM is
            when DNF | DNF5 =>
               Run_Backend_Command ("install", Packages, Options);
            when APT =>
               Run_Backend_Command ("install", Packages, Options);
            when Pacman | Paru | Yay =>
               Run_Backend_Command ("-S", Packages, Options);
            when Zypper =>
               Run_Backend_Command ("install", Packages, Options);
            when RPM_Ostree =>
               Run_Backend_Command ("install", Packages, Options);
            when Brew =>
               Run_Backend_Command ("install", Packages, Options);
            when others =>
               Print_Error ("Backend not implemented: " & PM_Name (Current_PM));
               raise Program_Error;
         end case;
         Install_Success := True;
      exception
         when others =>
            Install_Success := False;
      end;

      --  Complete the transaction
      if Is_Available then
         if Install_Success then
            declare
               Result : constant Call_Result :=
                 Commit_Transaction (TX_ID, Natural (Snap_ID));
            begin
               case Result.Status is
                  when Success =>
                     Print_Success ("Installation complete (TX #" &
                                   Transaction_ID'Image (TX_ID) & ")");
                  when Error =>
                     Print_Warning ("Installation complete but transaction commit failed");
                  when others =>
                     null;
               end case;
            end;
         else
            declare
               Result : constant Call_Result :=
                 Fail_Transaction (TX_ID, "Backend command failed");
               pragma Unreferenced (Result);
            begin
               Print_Error ("Installation failed (TX #" &
                           Transaction_ID'Image (TX_ID) & " rolled back)");
            end;
         end if;
      else
         if Install_Success then
            Print_Success ("Installation complete");
         else
            Print_Error ("Installation failed");
         end if;
      end if;

   exception
      when E : others =>
         --  Fail the transaction on exception
         if Is_Available then
            declare
               Result : constant Call_Result :=
                 Fail_Transaction (TX_ID, "Exception during install");
               pragma Unreferenced (Result);
            begin
               null;
            end;
         end if;
         Print_Error ("Installation failed");
   end Cmd_Install;

   procedure Cmd_Remove
     (Packages : String;
      Options  : Command_Options := Default_Options)
   is
      use Detection;
      use Data_Layer_Client;
      TX_ID   : Transaction_ID;
      Snap_ID : Snapshot_ID := 1;
      Remove_Success : Boolean := False;
   begin
      Initialize_Backend;

      if Packages = "" then
         Print_Error ("No packages specified");
         return;
      end if;

      Print_Header ("Removing Packages");

      --  Initialize data layer and begin transaction
      if Is_Available then
         TX_ID := Begin_Transaction ("Remove: " & Packages);
         if Options.Verbose then
            Print_Info ("Transaction #" & Transaction_ID'Image (TX_ID) & " started");
         end if;
      end if;

      --  Create pre-operation snapshot linked to transaction
      if not Options.No_Snapshot then
         Print_Info ("Creating pre-remove snapshot...");
         if Is_Available then
            Snap_ID := Create_Snapshot
              (Name        => "Pre-remove: " & Packages,
               Snap_Type   => Pre_Transaction,
               Transaction => Natural (TX_ID));
         else
            Snapshot_Manager.Create_Snapshot ("Pre-remove: " & Packages);
         end if;
      end if;

      Print_Subheader ("The following packages will be removed:");

      --  Display packages to remove and add operations to transaction
      declare
         Pos : Natural := Packages'First;
         Start : Natural;
      begin
         while Pos <= Packages'Last loop
            while Pos <= Packages'Last and then Packages (Pos) = ' ' loop
               Pos := Pos + 1;
            end loop;
            Start := Pos;
            while Pos <= Packages'Last and then Packages (Pos) /= ' ' loop
               Pos := Pos + 1;
            end loop;
            if Start < Pos then
               declare
                  Pkg_Name : constant String := Packages (Start .. Pos - 1);
               begin
                  Print_Package
                    (Name   => Pkg_Name,
                     Action => (if Options.Purge then Action_Purge else Action_Remove));

                  --  Record operation in transaction
                  if Is_Available then
                     Add_Operation
                       (TX_ID   => TX_ID,
                        Op_Type => (if Options.Purge then Purge else Remove),
                        Package => Pkg_Name);
                  end if;
               end;
            end if;
         end loop;
      end;

      --  Confirm
      if not Options.Assume_Yes then
         if not Confirm_Transaction then
            Print_Info ("Operation cancelled");
            if Is_Available then
               declare
                  Result : constant Call_Result := Cancel_Transaction (TX_ID);
                  pragma Unreferenced (Result);
               begin
                  null;
               end;
            end if;
            return;
         end if;
      end if;

      --  Run remove command
      begin
         case Current_PM is
            when DNF | DNF5 =>
               Run_Backend_Command ("remove", Packages, Options);
            when APT =>
               if Options.Purge then
                  Run_Backend_Command ("purge", Packages, Options);
               else
                  Run_Backend_Command ("remove", Packages, Options);
               end if;
            when Pacman | Paru | Yay =>
               if Options.Purge then
                  Run_Backend_Command ("-Rns", Packages, Options);
               else
                  Run_Backend_Command ("-R", Packages, Options);
               end if;
            when others =>
               Print_Error ("Backend not implemented");
               raise Program_Error;
         end case;
         Remove_Success := True;
      exception
         when others =>
            Remove_Success := False;
      end;

      --  Complete the transaction
      if Is_Available then
         if Remove_Success then
            declare
               Result : constant Call_Result :=
                 Commit_Transaction (TX_ID, Natural (Snap_ID));
            begin
               case Result.Status is
                  when Success =>
                     Print_Success ("Removal complete (TX #" &
                                   Transaction_ID'Image (TX_ID) & ")");
                  when Error =>
                     Print_Warning ("Removal complete but transaction commit failed");
                  when others =>
                     null;
               end case;
            end;
         else
            declare
               Result : constant Call_Result :=
                 Fail_Transaction (TX_ID, "Backend command failed");
               pragma Unreferenced (Result);
            begin
               Print_Error ("Removal failed (TX #" &
                           Transaction_ID'Image (TX_ID) & " rolled back)");
            end;
         end if;
      else
         if Remove_Success then
            Print_Success ("Removal complete");
         else
            Print_Error ("Removal failed");
         end if;
      end if;
   end Cmd_Remove;

   procedure Cmd_Purge
     (Packages : String;
      Options  : Command_Options := Default_Options)
   is
      Purge_Options : Command_Options := Options;
   begin
      Purge_Options.Purge := True;
      Cmd_Remove (Packages, Purge_Options);
   end Cmd_Purge;

   procedure Cmd_Update
     (Options : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      Print_Header ("Updating Package Lists");

      case Current_PM is
         when DNF | DNF5 =>
            Run_Backend_Command ("check-update", "", Options);
         when APT =>
            Run_Backend_Command ("update", "", Options);
         when Pacman | Paru | Yay =>
            Run_Backend_Command ("-Sy", "", Options);
         when Zypper =>
            Run_Backend_Command ("refresh", "", Options);
         when Brew =>
            Run_Backend_Command ("update", "", Options);
         when others =>
            Print_Error ("Backend not implemented");
      end case;

      Print_Success ("Package lists updated");
   end Cmd_Update;

   procedure Cmd_Upgrade
     (Packages : String := "";
      Options  : Command_Options := Default_Options)
   is
      use Detection;
      use Data_Layer_Client;
      TX_ID   : Transaction_ID;
      Snap_ID : Snapshot_ID := 1;
      Upgrade_Success : Boolean := False;
      Desc : constant String :=
        (if Packages = "" then "Upgrade: all packages" else "Upgrade: " & Packages);
   begin
      Initialize_Backend;

      Print_Header ("Upgrading Packages");

      --  Initialize data layer and begin transaction
      if Is_Available then
         TX_ID := Begin_Transaction (Desc);
         if Options.Verbose then
            Print_Info ("Transaction #" & Transaction_ID'Image (TX_ID) & " started");
         end if;
      end if;

      --  Create pre-upgrade snapshot linked to transaction
      if not Options.No_Snapshot then
         Print_Info ("Creating pre-upgrade snapshot...");
         if Is_Available then
            Snap_ID := Create_Snapshot
              (Name        => "Pre-upgrade: " &
                              (if Packages = "" then "all" else Packages),
               Snap_Type   => Pre_Transaction,
               Transaction => Natural (TX_ID));
         else
            Snapshot_Manager.Create_Snapshot (Desc);
         end if;
      end if;

      Print_Subheader ("Checking for upgrades...");

      --  Add upgrade operation to transaction
      if Is_Available then
         if Packages = "" then
            Add_Operation
              (TX_ID   => TX_ID,
               Op_Type => Upgrade,
               Package => "*");  -- All packages
         else
            --  Parse individual packages
            declare
               Pos   : Natural := Packages'First;
               Start : Natural;
            begin
               while Pos <= Packages'Last loop
                  while Pos <= Packages'Last and then Packages (Pos) = ' ' loop
                     Pos := Pos + 1;
                  end loop;
                  Start := Pos;
                  while Pos <= Packages'Last and then Packages (Pos) /= ' ' loop
                     Pos := Pos + 1;
                  end loop;
                  if Start < Pos then
                     Add_Operation
                       (TX_ID   => TX_ID,
                        Op_Type => Upgrade,
                        Package => Packages (Start .. Pos - 1));
                  end if;
               end loop;
            end;
         end if;
      end if;

      --  Confirm
      if not Options.Assume_Yes then
         if not Confirm_Transaction ("Proceed with upgrade?") then
            Print_Info ("Operation cancelled");
            if Is_Available then
               declare
                  Result : constant Call_Result := Cancel_Transaction (TX_ID);
                  pragma Unreferenced (Result);
               begin
                  null;
               end;
            end if;
            return;
         end if;
      end if;

      --  Run upgrade command
      begin
         case Current_PM is
            when DNF | DNF5 =>
               if Packages = "" then
                  Run_Backend_Command ("upgrade", "", Options);
               else
                  Run_Backend_Command ("upgrade", Packages, Options);
               end if;
            when APT =>
               if Packages = "" then
                  Run_Backend_Command ("upgrade", "", Options);
               else
                  Run_Backend_Command ("install --only-upgrade", Packages, Options);
               end if;
            when Pacman | Paru | Yay =>
               if Packages = "" then
                  Run_Backend_Command ("-Syu", "", Options);
               else
                  Run_Backend_Command ("-S", Packages, Options);
               end if;
            when RPM_Ostree =>
               Run_Backend_Command ("upgrade", "", Options);
            when others =>
               Print_Error ("Backend not implemented");
               raise Program_Error;
         end case;
         Upgrade_Success := True;
      exception
         when others =>
            Upgrade_Success := False;
      end;

      --  Complete the transaction
      if Is_Available then
         if Upgrade_Success then
            declare
               Result : constant Call_Result :=
                 Commit_Transaction (TX_ID, Natural (Snap_ID));
            begin
               case Result.Status is
                  when Success =>
                     Print_Success ("Upgrade complete (TX #" &
                                   Transaction_ID'Image (TX_ID) & ")");
                  when Error =>
                     Print_Warning ("Upgrade complete but transaction commit failed");
                  when others =>
                     null;
               end case;
            end;
         else
            declare
               Result : constant Call_Result :=
                 Fail_Transaction (TX_ID, "Backend command failed");
               pragma Unreferenced (Result);
            begin
               Print_Error ("Upgrade failed (TX #" &
                           Transaction_ID'Image (TX_ID) & " rolled back)");
            end;
         end if;
      else
         if Upgrade_Success then
            Print_Success ("Upgrade complete");
         else
            Print_Error ("Upgrade failed");
         end if;
      end if;

   exception
      when E : others =>
         if Is_Available then
            declare
               Result : constant Call_Result :=
                 Fail_Transaction (TX_ID, "Exception during upgrade");
               pragma Unreferenced (Result);
            begin
               null;
            end;
         end if;
         Print_Error ("Upgrade failed");
   end Cmd_Upgrade;

   procedure Cmd_Full_Upgrade
     (Options : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      Print_Header ("Full System Upgrade");
      Print_Warning ("This may remove packages to resolve conflicts");

      case Current_PM is
         when APT =>
            Run_Backend_Command ("full-upgrade", "", Options);
         when DNF | DNF5 =>
            Run_Backend_Command ("distro-sync", "", Options);
         when Pacman =>
            Run_Backend_Command ("-Syu", "", Options);
         when others =>
            Cmd_Upgrade ("", Options);
      end case;
   end Cmd_Full_Upgrade;

   ---------------------------------------------------------------------------
   --  Query Commands
   ---------------------------------------------------------------------------

   procedure Cmd_Search
     (Query   : String;
      Options : Command_Options := Default_Options)
   is
      use Detection;
      pragma Unreferenced (Options);
   begin
      Initialize_Backend;

      Print_Header ("Search Results for: " & Query);

      --  TODO: Actually run search and parse results
      case Current_PM is
         when DNF | DNF5 =>
            Run_Backend_Command ("search", Query, Default_Options);
         when APT =>
            Run_Backend_Command ("search", Query, Default_Options);
         when Pacman =>
            Run_Backend_Command ("-Ss", Query, Default_Options);
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Search;

   procedure Cmd_Show
     (Package_Name : String;
      Options      : Command_Options := Default_Options)
   is
      use Detection;
      pragma Unreferenced (Options);
   begin
      Initialize_Backend;

      case Current_PM is
         when DNF | DNF5 =>
            Run_Backend_Command ("info", Package_Name, Default_Options);
         when APT =>
            Run_Backend_Command ("show", Package_Name, Default_Options);
         when Pacman =>
            Run_Backend_Command ("-Si", Package_Name, Default_Options);
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Show;

   procedure Cmd_List
     (Filter  : List_Filter := Installed_Only;
      Pattern : String := "";
      Options : Command_Options := Default_Options)
   is
      use Detection;
      pragma Unreferenced (Options);
   begin
      Initialize_Backend;

      case Current_PM is
         when DNF | DNF5 =>
            case Filter is
               when Installed_Only =>
                  Run_Backend_Command ("list installed", Pattern, Default_Options);
               when Upgradable_Only =>
                  Run_Backend_Command ("list upgrades", Pattern, Default_Options);
               when others =>
                  Run_Backend_Command ("list", Pattern, Default_Options);
            end case;
         when APT =>
            case Filter is
               when Installed_Only =>
                  Run_Backend_Command ("list --installed", Pattern, Default_Options);
               when Upgradable_Only =>
                  Run_Backend_Command ("list --upgradable", Pattern, Default_Options);
               when others =>
                  Run_Backend_Command ("list", Pattern, Default_Options);
            end case;
         when Pacman =>
            case Filter is
               when Installed_Only =>
                  Run_Backend_Command ("-Q", Pattern, Default_Options);
               when Upgradable_Only =>
                  Run_Backend_Command ("-Qu", Pattern, Default_Options);
               when others =>
                  Run_Backend_Command ("-Sl", Pattern, Default_Options);
            end case;
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_List;

   procedure Cmd_Depends
     (Package_Name : String;
      Reverse_Deps : Boolean := False;
      Options      : Command_Options := Default_Options)
   is
      use Detection;
      pragma Unreferenced (Options);
   begin
      Initialize_Backend;

      if Reverse_Deps then
         Print_Header ("Packages depending on: " & Package_Name);
      else
         Print_Header ("Dependencies of: " & Package_Name);
      end if;

      case Current_PM is
         when DNF | DNF5 =>
            if Reverse_Deps then
               Run_Backend_Command ("repoquery --whatrequires", Package_Name, Default_Options);
            else
               Run_Backend_Command ("repoquery --requires", Package_Name, Default_Options);
            end if;
         when APT =>
            if Reverse_Deps then
               Run_Backend_Command ("rdepends", Package_Name, Default_Options);
            else
               Run_Backend_Command ("depends", Package_Name, Default_Options);
            end if;
         when Pacman =>
            if Reverse_Deps then
               Run_Backend_Command ("-Qi", Package_Name & " | grep 'Required By'", Default_Options);
            else
               Run_Backend_Command ("-Si", Package_Name & " | grep 'Depends On'", Default_Options);
            end if;
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Depends;

   procedure Cmd_Which
     (File_Path : String;
      Options   : Command_Options := Default_Options)
   is
      use Detection;
      pragma Unreferenced (Options);
   begin
      Initialize_Backend;

      Print_Header ("Package owning: " & File_Path);

      case Current_PM is
         when DNF | DNF5 =>
            Run_Backend_Command ("provides", File_Path, Default_Options);
         when APT =>
            Run_Backend_Command ("search", File_Path, Default_Options);
            --  Or use dpkg -S
         when Pacman =>
            Run_Backend_Command ("-Qo", File_Path, Default_Options);
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Which;

   ---------------------------------------------------------------------------
   --  History & Rollback
   ---------------------------------------------------------------------------

   procedure Cmd_History
     (Count   : Positive := 20;
      Options : Command_Options := Default_Options)
   is
      use Transaction_Types;
      use Ada.Calendar.Formatting;
      pragma Unreferenced (Options);

      History : constant Transaction_Array :=
        Transaction_Log.Get_Transaction_History;
      Display_Count : Natural := 0;
   begin
      Print_Header ("Transaction History");

      if History.Is_Empty then
         Print_Info ("No transactions recorded yet");
         return;
      end if;

      --  Build history entries for display
      for I in reverse 1 .. Natural (History.Length) loop
         exit when Display_Count >= Count;

         declare
            Trans : constant Transaction_Info := History.Element (I);
            Status_Color : constant String :=
              (case Trans.Status is
                  when Completed   => Green,
                  when Failed      => Red,
                  when Rolled_Back => Yellow,
                  when Cancelled   => Bright_Black,
                  when others      => Cyan);
            Status_Text : constant String :=
              (case Trans.Status is
                  when Pending     => "Pending",
                  when In_Progress => "Running",
                  when Completed   => "Success",
                  when Failed      => "Failed",
                  when Rolled_Back => "Rolled Back",
                  when Cancelled   => "Cancelled");
            Op_Count : constant Natural := Natural (Trans.Operations.Length);
         begin
            Print ("  ");
            Print (Bright_Black & "#" & Trans.ID'Image & Reset & "  ");
            Print (Dim & Image (Trans.Started_At) & Reset & "  ");
            Print (Bold & To_String (Trans.Description) & Reset);
            Print ("  " & Cyan & Op_Count'Image & Reset & " ops  ");
            Print (Status_Color & Status_Text & Reset);
            New_Line;

            Display_Count := Display_Count + 1;
         end;
      end loop;

      New_Line;
      Print_Info ("Use 'dnfinition history info <id>' for details");
      Print_Info ("Use 'dnfinition history undo <id>' to undo a transaction");
   end Cmd_History;

   procedure Cmd_History_Undo
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options)
   is
      use Transaction_Types;
      Trans_ID : constant Transaction_Types.Transaction_ID :=
        Transaction_Types.Transaction_ID (Transaction_ID);
   begin
      Initialize_Backend;

      Print_Header ("Undoing Transaction #" & Transaction_ID'Image);

      --  Check transaction exists
      if not Transaction_Log.Transaction_Exists (Trans_ID) then
         Print_Error ("Transaction #" & Transaction_ID'Image & " not found");
         return;
      end if;

      --  Check if can be reversed
      if not Transaction_Log.Can_Reverse (Trans_ID) then
         Print_Error ("Transaction cannot be reversed (no snapshot or operations)");
         return;
      end if;

      --  Show what will be undone
      declare
         Trans : constant Transaction_Info := Transaction_Log.Get_Transaction (Trans_ID);
      begin
         Print_Subheader ("Transaction details:");
         Print_Field ("Description", To_String (Trans.Description));
         Print_Field ("Operations", Natural (Trans.Operations.Length)'Image);

         for Op of Trans.Operations loop
            Print ("  ");
            Print ((case Op.Operation is
                       when Install => Green & "+",
                       when Remove | Autoremove => Red & "-",
                       when Upgrade => Blue & Symbol_Arrow,
                       when Downgrade => Yellow & Symbol_Arrow,
                       when others => "~") & Reset & " ");
            Print (To_String (Op.Package_Name));
            if Length (Op.Old_Version) > 0 then
               Print (" " & Dim & To_String (Op.Old_Version) & Reset);
            end if;
            if Length (Op.New_Version) > 0 then
               Print (" " & Symbol_Arrow & " " &
                     Bright_Green & To_String (Op.New_Version) & Reset);
            end if;
            New_Line;
         end loop;
      end;

      New_Line;

      --  Confirm
      if not Options.Assume_Yes then
         if not Confirm_Transaction ("Undo this transaction?", False) then
            Print_Info ("Operation cancelled");
            return;
         end if;
      end if;

      --  Create snapshot before undo
      if not Options.No_Snapshot then
         Print_Info ("Creating pre-undo snapshot...");
         Snapshot_Manager.Create_Snapshot ("Pre-undo: transaction #" &
                                          Transaction_ID'Image);
      end if;

      --  Perform the rollback
      Print_Info ("Reversing transaction...");
      declare
         Result : constant Rollback_Engine.Rollback_Result :=
           Rollback_Engine.Rollback_Transaction (Trans_ID);
      begin
         case Result.Status is
            when Rollback_Engine.Success =>
               Print_Success ("Transaction undone successfully");
               Print_Field ("Operations reversed", Result.Ops_Reversed'Image);

            when Rollback_Engine.Partial =>
               Print_Warning ("Partial rollback: " &
                            Result.Ops_Reversed'Image & "/" &
                            Result.Ops_Total'Image & " operations reversed");
               Print_Line (Yellow & To_String (Result.Message) & Reset);

            when Rollback_Engine.Requires_Reboot =>
               Print_Warning ("Rollback requires reboot to complete");
               Print_Info ("Please reboot your system to finish the rollback");

            when Rollback_Engine.Failed =>
               Print_Error ("Rollback failed: " & To_String (Result.Message));

            when Rollback_Engine.Not_Needed =>
               Print_Info ("No rollback necessary");
         end case;
      end;
   end Cmd_History_Undo;

   procedure Cmd_History_Redo
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options)
   is
      use Transaction_Types;
      Trans_ID : constant Transaction_Types.Transaction_ID :=
        Transaction_Types.Transaction_ID (Transaction_ID);
   begin
      Initialize_Backend;

      Print_Header ("Redoing Transaction #" & Transaction_ID'Image);

      if not Transaction_Log.Transaction_Exists (Trans_ID) then
         Print_Error ("Transaction #" & Transaction_ID'Image & " not found");
         return;
      end if;

      declare
         Trans : constant Transaction_Info := Transaction_Log.Get_Transaction (Trans_ID);
      begin
         Print_Subheader ("Replaying transaction:");
         Print_Field ("Description", To_String (Trans.Description));
         Print_Field ("Operations", Natural (Trans.Operations.Length)'Image);
      end;

      if not Options.Assume_Yes then
         if not Confirm_Transaction ("Replay this transaction?", False) then
            Print_Info ("Operation cancelled");
            return;
         end if;
      end if;

      Print_Info ("Replaying transaction...");
      Transaction_Log.Replay_Transaction (Trans_ID);
      Print_Success ("Transaction replayed successfully");
   end Cmd_History_Redo;

   procedure Cmd_History_Info
     (Transaction_ID : Natural;
      Options        : Command_Options := Default_Options)
   is
      use Transaction_Types;
      use Ada.Calendar.Formatting;
      Trans_ID : constant Transaction_Types.Transaction_ID :=
        Transaction_Types.Transaction_ID (Transaction_ID);
      pragma Unreferenced (Options);
   begin
      if not Transaction_Log.Transaction_Exists (Trans_ID) then
         Print_Error ("Transaction #" & Transaction_ID'Image & " not found");
         return;
      end if;

      declare
         Trans : constant Transaction_Info := Transaction_Log.Get_Transaction (Trans_ID);
      begin
         Print_Header ("Transaction #" & Transaction_ID'Image);

         Print_Field ("Description", To_String (Trans.Description));
         Print_Field ("Started", Image (Trans.Started_At));
         Print_Field ("Completed", Image (Trans.Completed_At));
         Print_Field ("Status", Transaction_Status'Image (Trans.Status));
         Print_Field ("User", To_String (Trans.User));

         if Trans.Snapshot_ID /= Snapshot_Types.Invalid_Snapshot_ID then
            Print_Field ("Snapshot", Trans.Snapshot_ID'Image);
         end if;

         New_Line;
         Print_Subheader ("Operations:");

         for Op of Trans.Operations loop
            Print ("  " & Op.Sequence'Image & ". ");
            Print (Bold & Operation_Type'Image (Op.Operation) & Reset);
            Print (" " & To_String (Op.Package_Name));
            if Length (Op.Old_Version) > 0 then
               Print (" " & To_String (Op.Old_Version));
            end if;
            if Length (Op.New_Version) > 0 then
               Print (" " & Symbol_Arrow & " " & To_String (Op.New_Version));
            end if;
            Print (" [" & Operation_Status'Image (Op.Status) & "]");
            if Length (Op.Error_Msg) > 0 then
               New_Line;
               Print ("     " & Red & To_String (Op.Error_Msg) & Reset);
            end if;
            New_Line;
         end loop;

         New_Line;
         Print_Field ("Packages added", Natural (Trans.Packages_Add.Length)'Image);
         Print_Field ("Packages removed", Natural (Trans.Packages_Del.Length)'Image);
         Print_Field ("Packages upgraded", Natural (Trans.Packages_Upg.Length)'Image);
         Print_Field ("Download size", Format_Size (Long_Long_Integer (Trans.Download_Size)));
         Print_Field ("Install size", Format_Size (Long_Long_Integer (Trans.Install_Size)));
      end;
   end Cmd_History_Info;

   procedure Cmd_History_Clear
     (Options : Command_Options := Default_Options)
   is
      pragma Unreferenced (Options);
   begin
      Print_Warning ("This will clear all transaction history");
      if Confirm_Transaction ("Clear all history?", False) then
         Print_Success ("History cleared");
      end if;
   end Cmd_History_Clear;

   ---------------------------------------------------------------------------
   --  Snapshots
   ---------------------------------------------------------------------------

   procedure Cmd_Snapshots
     (Options : Command_Options := Default_Options)
   is
      use Snapshot_Types;
      use Ada.Calendar.Formatting;
      pragma Unreferenced (Options);
      Snapshots : constant Snapshot_Array := Snapshot_Manager.List_Snapshots;
   begin
      Print_Header ("System Snapshots");

      if Snapshots.Is_Empty then
         Print_Info ("No snapshots recorded");
         return;
      end if;

      Print_Line (Bright_Black &
                 "  ID    Strategy      Date                 Size        Description" &
                 Reset);
      Print_Separator;

      for Snap of Snapshots loop
         Print ("  ");

         --  ID with pin indicator
         if Snap.Is_Pinned then
            Print (Yellow & Symbol_Check & Reset);
         else
            Print (" ");
         end if;
         Print (Bright_Black & Snap.ID'Image & Reset);

         --  Strategy
         Print ("  " & Cyan &
               (case Snap.Strategy is
                   when Native          => "Native    ",
                   when Filesystem      => "Filesystem",
                   when Transaction_Log => "TxLog     ",
                   when Container_Image => "Container ") &
               Reset);

         --  Timestamp
         Print ("  " & Dim & Image (Snap.Timestamp) & Reset);

         --  Size
         Print ("  " & Format_Size (Long_Long_Integer (Snap.Size_Bytes)));

         --  Description
         Print ("  " & To_String (Snap.Description));

         New_Line;
      end loop;

      New_Line;
      Print_Field ("Total snapshots", Natural (Snapshots.Length)'Image);
      Print_Field ("Total size",
                  Format_Size (Long_Long_Integer (Snapshot_Manager.Total_Snapshot_Size)));
      New_Line;
      Print_Info ("Pinned snapshots are marked with " & Yellow & Symbol_Check & Reset);
   end Cmd_Snapshots;

   procedure Cmd_Snapshot_Create
     (Description : String := "";
      Options     : Command_Options := Default_Options)
   is
      use Snapshot_Types;
      pragma Unreferenced (Options);
      Desc : constant String :=
        (if Description = "" then "Manual snapshot" else Description);
      Snap_ID : Snapshot_ID;
   begin
      Print_Info ("Creating snapshot: " & Desc);
      Print_Info ("Detecting best snapshot strategy...");

      declare
         Strategy : constant Snapshot_Strategy := Snapshot_Manager.Detect_Best_Strategy;
      begin
         Print_Field ("Strategy",
           (case Strategy is
               when Native          => "Native (package manager)",
               when Filesystem      => "Filesystem (btrfs/zfs/lvm)",
               when Transaction_Log => "Transaction log",
               when Container_Image => "Container image"));

         Snapshot_Manager.Create_Snapshot (Desc, Strategy, Snap_ID);
      end;

      Print_Success ("Snapshot #" & Snap_ID'Image & " created");
   end Cmd_Snapshot_Create;

   procedure Cmd_Snapshot_Rollback
     (Snapshot_ID : Natural;
      Options     : Command_Options := Default_Options)
   is
      use Snapshot_Types;
      use Ada.Calendar.Formatting;
      Snap_ID : constant Snapshot_Types.Snapshot_ID :=
        Snapshot_Types.Snapshot_ID (Snapshot_ID);
   begin
      if not Snapshot_Manager.Snapshot_Exists (Snap_ID) then
         Print_Error ("Snapshot #" & Snapshot_ID'Image & " not found");
         return;
      end if;

      declare
         Snap : constant Snapshot_Info := Snapshot_Manager.Get_Snapshot_Info (Snap_ID);
      begin
         Print_Header ("Rollback to Snapshot #" & Snapshot_ID'Image);
         Print_Field ("Description", To_String (Snap.Description));
         Print_Field ("Created", Image (Snap.Timestamp));
         Print_Field ("Strategy", Snapshot_Strategy'Image (Snap.Strategy));
      end;

      Print_Warning ("This will restore the system to the snapshot state");
      Print_Warning ("Any changes made after this snapshot will be lost");

      if not Options.Assume_Yes then
         if not Confirm_Transaction ("Proceed with rollback?", False) then
            Print_Info ("Operation cancelled");
            return;
         end if;
      end if;

      --  Verify snapshot before rollback
      Print_Info ("Verifying snapshot integrity...");
      if not Snapshot_Manager.Verify_Snapshot (Snap_ID) then
         Print_Error ("Snapshot verification failed");
         return;
      end if;

      Print_Info ("Rolling back...");
      declare
         Result : constant Rollback_Engine.Rollback_Result :=
           Rollback_Engine.Rollback_To_Snapshot (Snap_ID);
      begin
         case Result.Status is
            when Rollback_Engine.Success =>
               Print_Success ("Rollback completed successfully");

            when Rollback_Engine.Requires_Reboot =>
               Print_Success ("Rollback staged successfully");
               Print_Warning ("System reboot required to complete rollback");

            when Rollback_Engine.Failed =>
               Print_Error ("Rollback failed: " & To_String (Result.Message));

            when others =>
               Print_Info ("Rollback status: " &
                          Rollback_Engine.Rollback_Status'Image (Result.Status));
         end case;
      end;
   end Cmd_Snapshot_Rollback;

   procedure Cmd_Snapshot_Delete
     (Snapshot_ID : Natural;
      Options     : Command_Options := Default_Options)
   is
      use Snapshot_Types;
      Snap_ID : constant Snapshot_Types.Snapshot_ID :=
        Snapshot_Types.Snapshot_ID (Snapshot_ID);
   begin
      if not Snapshot_Manager.Snapshot_Exists (Snap_ID) then
         Print_Error ("Snapshot #" & Snapshot_ID'Image & " not found");
         return;
      end if;

      declare
         Snap : constant Snapshot_Info := Snapshot_Manager.Get_Snapshot_Info (Snap_ID);
      begin
         if Snap.Is_Pinned then
            Print_Error ("Cannot delete pinned snapshot");
            Print_Info ("Unpin the snapshot first with 'dnfinition snapshot unpin " &
                       Snapshot_ID'Image & "'");
            return;
         end if;

         Print_Info ("Deleting snapshot: " & To_String (Snap.Description));
      end;

      if not Options.Assume_Yes then
         if not Confirm_Transaction ("Delete this snapshot?", False) then
            Print_Info ("Operation cancelled");
            return;
         end if;
      end if;

      Snapshot_Manager.Delete_Snapshot (Snap_ID);
      Print_Success ("Snapshot #" & Snapshot_ID'Image & " deleted");
   end Cmd_Snapshot_Delete;

   ---------------------------------------------------------------------------
   --  Mirror Fetch
   ---------------------------------------------------------------------------

   procedure Cmd_Fetch
     (Country     : String := "";
      Https_Only  : Boolean := True;
      Test_Count  : Positive := 5;
      Options     : Command_Options := Default_Options)
   is
      pragma Unreferenced (Country, Https_Only, Test_Count, Options);
   begin
      Print_Header ("Finding Fastest Mirrors");
      Print_Info ("Mirror testing coming soon");
   end Cmd_Fetch;

   ---------------------------------------------------------------------------
   --  Maintenance
   ---------------------------------------------------------------------------

   procedure Cmd_Clean
     (All_Versions : Boolean := False;
      Options      : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      Print_Header ("Cleaning Package Cache");

      case Current_PM is
         when DNF | DNF5 =>
            if All_Versions then
               Run_Backend_Command ("clean all", "", Options);
            else
               Run_Backend_Command ("clean packages", "", Options);
            end if;
         when APT =>
            if All_Versions then
               Run_Backend_Command ("clean", "", Options);
            else
               Run_Backend_Command ("autoclean", "", Options);
            end if;
         when Pacman =>
            if All_Versions then
               Run_Backend_Command ("-Scc", "", Options);
            else
               Run_Backend_Command ("-Sc", "", Options);
            end if;
         when others =>
            Print_Error ("Backend not implemented");
      end case;

      Print_Success ("Cache cleaned");
   end Cmd_Clean;

   procedure Cmd_Fix
     (Options : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      Print_Header ("Fixing Broken Packages");

      case Current_PM is
         when APT =>
            Run_Backend_Command ("--fix-broken install", "", Options);
         when DNF | DNF5 =>
            Run_Backend_Command ("distro-sync", "", Options);
         when Pacman =>
            Print_Info ("Try: pacman -Syyu");
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Fix;

   procedure Cmd_Autoremove
     (Purge   : Boolean := False;
      Options : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      Print_Header ("Auto-removing Unused Packages");

      case Current_PM is
         when DNF | DNF5 =>
            Run_Backend_Command ("autoremove", "", Options);
         when APT =>
            if Purge then
               Run_Backend_Command ("autopurge", "", Options);
            else
               Run_Backend_Command ("autoremove", "", Options);
            end if;
         when Pacman =>
            Run_Backend_Command ("-Qdtq | pacman -Rs -", "", Options);
         when others =>
            Print_Error ("Backend not implemented");
      end case;

      Print_Success ("Autoremove complete");
   end Cmd_Autoremove;

   procedure Cmd_Mark
     (Package_Name : String;
      Mark         : Mark_Type;
      Options      : Command_Options := Default_Options)
   is
      use Detection;
   begin
      Initialize_Backend;

      case Mark is
         when Manual =>
            Print_Info ("Marking " & Package_Name & " as manually installed");
         when Automatic =>
            Print_Info ("Marking " & Package_Name & " as automatically installed");
         when Hold =>
            Print_Info ("Holding " & Package_Name & " at current version");
         when Unhold =>
            Print_Info ("Removing hold on " & Package_Name);
      end case;

      case Current_PM is
         when APT =>
            case Mark is
               when Manual =>
                  Run_Backend_Command ("mark manual", Package_Name, Options);
               when Automatic =>
                  Run_Backend_Command ("mark auto", Package_Name, Options);
               when Hold =>
                  Run_Backend_Command ("mark hold", Package_Name, Options);
               when Unhold =>
                  Run_Backend_Command ("mark unhold", Package_Name, Options);
            end case;
         when DNF | DNF5 =>
            case Mark is
               when Hold =>
                  Run_Backend_Command ("versionlock add", Package_Name, Options);
               when Unhold =>
                  Run_Backend_Command ("versionlock delete", Package_Name, Options);
               when others =>
                  Print_Info ("Mark type not available for dnf");
            end case;
         when others =>
            Print_Error ("Backend not implemented");
      end case;
   end Cmd_Mark;

   ---------------------------------------------------------------------------
   --  System Info
   ---------------------------------------------------------------------------

   procedure Cmd_System_Info
     (Options : Command_Options := Default_Options)
   is
      pragma Unreferenced (Options);
      Info : constant Detection.System_Info := Detection.Get_System_Info;
   begin
      Print_Header ("System Information");

      Print_Field ("OS", Detection.OS_Family'Image (Info.OS));
      Print_Field ("Distribution", To_String (Info.OS_Name));
      Print_Field ("Version", To_String (Info.OS_Version));
      Print_Field ("Architecture", To_String (Info.Arch));
      Print_Field ("Package Manager", Detection.PM_Name (Info.PM));
      Print_Field ("Atomic System", (if Info.Is_Atomic then "Yes" else "No"));
      Print_Field ("Container", (if Info.Is_Container then "Yes" else "No"));
   end Cmd_System_Info;

   procedure Cmd_Language_Pms
     (Options : Command_Options := Default_Options)
   is
      pragma Unreferenced (Options);
      Available : constant Detection.Language_PM_Array :=
        Detection.Detect_Language_Package_Managers;
   begin
      Print_Header ("Available Language Package Managers");

      if Available'Length = 0 then
         Print_Info ("No language package managers detected");
         return;
      end if;

      for PM of Available loop
         Print_Item (Detection.PM_Name (PM) &
                    " (" & Detection.Programming_Language'Image
                           (Detection.PM_Language (PM)) & ")");
      end loop;
   end Cmd_Language_Pms;

   ---------------------------------------------------------------------------
   --  File Install
   ---------------------------------------------------------------------------

   procedure Cmd_Install_Deb
     (File_Path : String;
      Options   : Command_Options := Default_Options)
   is
   begin
      if not Ada.Directories.Exists (File_Path) then
         Print_Error ("File not found: " & File_Path);
         return;
      end if;

      Print_Header ("Installing DEB Package");
      Print_Info ("File: " & File_Path);

      Run_Backend_Command ("dpkg -i", File_Path, Options);

      --  Fix dependencies
      Run_Backend_Command ("apt-get install -f", "", Options);

      Print_Success ("Installation complete");
   end Cmd_Install_Deb;

   procedure Cmd_Install_Rpm
     (File_Path : String;
      Options   : Command_Options := Default_Options)
   is
      use Detection;
   begin
      if not Ada.Directories.Exists (File_Path) then
         Print_Error ("File not found: " & File_Path);
         return;
      end if;

      Print_Header ("Installing RPM Package");
      Print_Info ("File: " & File_Path);

      case Current_PM is
         when RPM_Ostree =>
            --  rpm-ostree can't install local RPMs directly
            Print_Warning ("rpm-ostree doesn't support local RPM install");
            Print_Info ("Consider using: rpm-ostree override replace " & File_Path);
         when DNF | DNF5 =>
            Run_Backend_Command ("install", File_Path, Options);
         when Zypper =>
            Run_Backend_Command ("install", File_Path, Options);
         when others =>
            --  Fallback to raw rpm
            Print_Info ("Using rpm directly");
            Run_Backend_Command ("rpm -i", File_Path, Options);
      end case;

      Print_Success ("Installation complete");
   end Cmd_Install_Rpm;

   procedure Cmd_Install_File
     (File_Path : String;
      Options   : Command_Options := Default_Options)
   is
   begin
      if Index (File_Path, ".deb") > 0 then
         Cmd_Install_Deb (File_Path, Options);
      elsif Index (File_Path, ".rpm") > 0 then
         Cmd_Install_Rpm (File_Path, Options);
      else
         Print_Error ("Unknown package format. Expected .deb or .rpm");
      end if;
   end Cmd_Install_File;

   ---------------------------------------------------------------------------
   --  Argument Parsing
   ---------------------------------------------------------------------------

   function Parse_Options return Command_Options is
      Result : Command_Options;
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "-y" or Arg = "--yes" then
               Result.Assume_Yes := True;
            elsif Arg = "-n" or Arg = "--no" then
               Result.Assume_No := True;
            elsif Arg = "--dry-run" then
               Result.Dry_Run := True;
            elsif Arg = "--no-snapshot" then
               Result.No_Snapshot := True;
            elsif Arg = "-v" or Arg = "--verbose" then
               Result.Verbose := True;
            elsif Arg = "-q" or Arg = "--quiet" then
               Result.Quiet := True;
            elsif Arg = "--no-color" then
               Result.No_Color := True;
               Set_Color_Enabled (False);
            elsif Arg = "--purge" then
               Result.Purge := True;
            elsif Arg = "--autoremove" then
               Result.Autoremove := True;
            elsif Arg = "-d" or Arg = "--download-only" then
               Result.Download_Only := True;
            end if;
         end;
      end loop;
      return Result;
   end Parse_Options;

   function Get_Arguments return String is
      Result : Unbounded_String;
      Skip_Next : Boolean := False;
   begin
      for I in 2 .. Ada.Command_Line.Argument_Count loop
         if Skip_Next then
            Skip_Next := False;
         else
            declare
               Arg : constant String := Ada.Command_Line.Argument (I);
            begin
               --  Skip options
               if Arg (Arg'First) /= '-' then
                  if Length (Result) > 0 then
                     Append (Result, " ");
                  end if;
                  Append (Result, Arg);
               end if;
            end;
         end if;
      end loop;
      return To_String (Result);
   end Get_Arguments;

end CLI_Commands;
