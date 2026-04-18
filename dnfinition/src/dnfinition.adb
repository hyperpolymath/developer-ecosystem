-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- DNFinition - Universal Package Manager with Reversibility
-- Main entry point
pragma Ada_2022;

with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Strings.Fixed;

with Detection;
with Snapshot_Manager;
with Transaction_Log;
with Rollback_Engine;
with Terminal_Interface;
with CLI_Commands;
with CLI_Output;

procedure DNFinition is

   use Ada.Text_IO;
   use Ada.Command_Line;

   procedure Print_Version is
   begin
      Put_Line ("DNFinition " & Standard.DNFinition.Version_String);
      Put_Line ("Universal Package Manager with Reversibility");
      Put_Line ("Copyright (C) 2025 Jonathan D.A. Jewell");
      Put_Line ("License: AGPL-3.0-or-later");
   end Print_Version;

   procedure Print_Help is
      use CLI_Output;
   begin
      Print_Version;
      New_Line;
      Print_Line (Bold & "Usage:" & Reset & " dnfinition [OPTIONS] COMMAND [ARGS]");
      New_Line;

      Print_Line (Bold & "Package Commands:" & Reset);
      Print_Line ("  install PKG...       Install package(s)");
      Print_Line ("  remove PKG...        Remove package(s)");
      Print_Line ("  purge PKG...         Remove package(s) and config files");
      Print_Line ("  update               Update package lists");
      Print_Line ("  upgrade [PKG...]     Upgrade all or specific packages");
      Print_Line ("  full-upgrade         Full system upgrade (may remove packages)");
      Print_Line ("  autoremove           Remove unused packages");
      New_Line;

      Print_Line (Bold & "Query Commands:" & Reset);
      Print_Line ("  search QUERY         Search for packages");
      Print_Line ("  show PKG             Show package information");
      Print_Line ("  list [--installed]   List packages");
      Print_Line ("  depends PKG          Show package dependencies");
      Print_Line ("  rdepends PKG         Show reverse dependencies");
      Print_Line ("  which FILE           Find package owning file");
      New_Line;

      Print_Line (Bold & "History Commands:" & Reset);
      Print_Line ("  history              Show transaction history");
      Print_Line ("  history info ID      Show transaction details");
      Print_Line ("  history undo ID      Undo a transaction");
      Print_Line ("  history redo ID      Redo a transaction");
      Print_Line ("  history clear        Clear transaction history");
      New_Line;

      Print_Line (Bold & "Snapshot Commands:" & Reset);
      Print_Line ("  snapshots            List all snapshots");
      Print_Line ("  snapshot create      Create new snapshot");
      Print_Line ("  snapshot rollback ID Rollback to snapshot");
      Print_Line ("  snapshot delete ID   Delete a snapshot");
      New_Line;

      Print_Line (Bold & "Maintenance Commands:" & Reset);
      Print_Line ("  clean                Clean package cache");
      Print_Line ("  fix                  Fix broken packages");
      Print_Line ("  fetch                Find fastest mirrors");
      Print_Line ("  mark PKG manual|auto Mark package install reason");
      Print_Line ("  hold PKG             Hold package at current version");
      Print_Line ("  unhold PKG           Remove hold on package");
      New_Line;

      Print_Line (Bold & "System Commands:" & Reset);
      Print_Line ("  system-info          Show system information");
      Print_Line ("  language-pms         Show available language PMs");
      Print_Line ("  (no command)         Launch interactive TUI");
      New_Line;

      Print_Line (Bold & "Options:" & Reset);
      Print_Line ("  -h, --help           Show this help message");
      Print_Line ("  -v, --version        Show version information");
      Print_Line ("  -y, --yes            Assume yes to prompts");
      Print_Line ("  -n, --no             Assume no to prompts");
      Print_Line ("  -d, --download-only  Download only, don't install");
      Print_Line ("  -q, --quiet          Quiet mode");
      Print_Line ("  --verbose            Verbose output");
      Print_Line ("  --dry-run            Show what would be done");
      Print_Line ("  --no-snapshot        Don't create pre-operation snapshot");
      Print_Line ("  --no-color           Disable colored output");
      Print_Line ("  --purge              Also remove config files");
      Print_Line ("  --autoremove         Also remove unused dependencies");
      New_Line;

      Print_Line (Bright_Black & "Detected system:" & Reset);
      Print_Line ("  OS:       " & Cyan &
                 Detection.OS_Family'Image (Detection.Detect_OS) & Reset);
      Print_Line ("  Backend:  " & Cyan &
                 Detection.PM_Name (Detection.Detect_Package_Manager) & Reset);
   end Print_Help;

   procedure Print_System_Info is
      Info : constant Detection.System_Info := Detection.Get_System_Info;
   begin
      Put_Line ("System Information:");
      Put_Line ("  OS:          " & Detection.OS_Family'Image (Info.OS));
      Put_Line ("  Distribution: " &
                Ada.Strings.Unbounded.To_String (Info.OS_Name));
      Put_Line ("  Version:     " &
                Ada.Strings.Unbounded.To_String (Info.OS_Version));
      Put_Line ("  Architecture: " &
                Ada.Strings.Unbounded.To_String (Info.Arch));
      Put_Line ("  Package Manager: " &
                Detection.PM_Name (Info.PM));
      Put_Line ("  Atomic:      " & Boolean'Image (Info.Is_Atomic));
      Put_Line ("  Container:   " & Boolean'Image (Info.Is_Container));
   end Print_System_Info;

   procedure Initialize_Subsystems is
   begin
      Snapshot_Manager.Initialize;
      Transaction_Log.Initialize;
      Rollback_Engine.Initialize;
   end Initialize_Subsystems;

   procedure Run_TUI is
   begin
      Terminal_Interface.Initialize;
      Terminal_Interface.Run;
   exception
      when E : others =>
         Terminal_Interface.Finalize;
         Put_Line (Standard_Error,
           "TUI Error: " & Ada.Exceptions.Exception_Message (E));
         Set_Exit_Status (Failure);
   end Run_TUI;

   --  Get arguments after command as space-separated string
   function Get_Args_After (Start_Index : Positive) return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      for I in Start_Index .. Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            --  Skip options
            if Arg'Length > 0 and then Arg (Arg'First) /= '-' then
               if Length (Result) > 0 then
                  Append (Result, " ");
               end if;
               Append (Result, Arg);
            end if;
         end;
      end loop;
      return To_String (Result);
   end Get_Args_After;

   --  Get next argument (for commands needing single arg)
   function Get_Next_Arg (After_Index : Positive) return String is
   begin
      for I in After_Index + 1 .. Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            if Arg'Length > 0 and then Arg (Arg'First) /= '-' then
               return Arg;
            end if;
         end;
      end loop;
      return "";
   end Get_Next_Arg;

   --  Get numeric ID argument
   function Get_ID_Arg (After_Index : Positive) return Natural is
      Arg : constant String := Get_Next_Arg (After_Index);
   begin
      if Arg = "" then
         return 0;
      end if;
      return Natural'Value (Arg);
   exception
      when others => return 0;
   end Get_ID_Arg;

   procedure Process_Command (Cmd : String) is
      use CLI_Commands;
      use CLI_Output;
      Options : constant Command_Options := Parse_Options;
      Args : constant String := Get_Args_After (2);
   begin
      --  Package commands
      if Cmd = "install" then
         if Args = "" then
            Print_Error ("No packages specified");
            return;
         end if;
         Cmd_Install (Args, Options);

      elsif Cmd = "remove" then
         if Args = "" then
            Print_Error ("No packages specified");
            return;
         end if;
         Cmd_Remove (Args, Options);

      elsif Cmd = "purge" then
         if Args = "" then
            Print_Error ("No packages specified");
            return;
         end if;
         Cmd_Purge (Args, Options);

      elsif Cmd = "update" then
         Cmd_Update (Options);

      elsif Cmd = "upgrade" then
         Cmd_Upgrade (Args, Options);

      elsif Cmd = "full-upgrade" then
         Cmd_Full_Upgrade (Options);

      elsif Cmd = "autoremove" then
         Cmd_Autoremove (Options.Purge, Options);

      --  Query commands
      elsif Cmd = "search" then
         if Args = "" then
            Print_Error ("No search query specified");
            return;
         end if;
         Cmd_Search (Args, Options);

      elsif Cmd = "show" then
         if Args = "" then
            Print_Error ("No package specified");
            return;
         end if;
         Cmd_Show (Args, Options);

      elsif Cmd = "list" then
         Cmd_List (Installed_Only, Args, Options);

      elsif Cmd = "depends" then
         if Args = "" then
            Print_Error ("No package specified");
            return;
         end if;
         Cmd_Depends (Args, False, Options);

      elsif Cmd = "rdepends" then
         if Args = "" then
            Print_Error ("No package specified");
            return;
         end if;
         Cmd_Depends (Args, True, Options);

      elsif Cmd = "which" then
         if Args = "" then
            Print_Error ("No file path specified");
            return;
         end if;
         Cmd_Which (Args, Options);

      --  History commands
      elsif Cmd = "history" then
         declare
            Subcmd : constant String := Get_Next_Arg (1);
         begin
            if Subcmd = "" then
               Cmd_History (20, Options);
            elsif Subcmd = "info" then
               declare
                  ID : constant Natural := Get_ID_Arg (2);
               begin
                  if ID = 0 then
                     Print_Error ("Transaction ID required");
                     return;
                  end if;
                  Cmd_History_Info (ID, Options);
               end;
            elsif Subcmd = "undo" then
               declare
                  ID : constant Natural := Get_ID_Arg (2);
               begin
                  if ID = 0 then
                     Print_Error ("Transaction ID required");
                     return;
                  end if;
                  Cmd_History_Undo (ID, Options);
               end;
            elsif Subcmd = "redo" then
               declare
                  ID : constant Natural := Get_ID_Arg (2);
               begin
                  if ID = 0 then
                     Print_Error ("Transaction ID required");
                     return;
                  end if;
                  Cmd_History_Redo (ID, Options);
               end;
            elsif Subcmd = "clear" then
               Cmd_History_Clear (Options);
            else
               Print_Error ("Unknown history subcommand: " & Subcmd);
            end if;
         end;

      --  Snapshot commands
      elsif Cmd = "snapshots" then
         Cmd_Snapshots (Options);

      elsif Cmd = "snapshot" then
         declare
            Subcmd : constant String := Get_Next_Arg (1);
         begin
            if Subcmd = "create" then
               Cmd_Snapshot_Create (Get_Args_After (3), Options);
            elsif Subcmd = "rollback" then
               declare
                  ID : constant Natural := Get_ID_Arg (2);
               begin
                  if ID = 0 then
                     Print_Error ("Snapshot ID required");
                     return;
                  end if;
                  Cmd_Snapshot_Rollback (ID, Options);
               end;
            elsif Subcmd = "delete" then
               declare
                  ID : constant Natural := Get_ID_Arg (2);
               begin
                  if ID = 0 then
                     Print_Error ("Snapshot ID required");
                     return;
                  end if;
                  Cmd_Snapshot_Delete (ID, Options);
               end;
            else
               Print_Error ("Unknown snapshot subcommand: " & Subcmd);
            end if;
         end;

      --  Maintenance commands
      elsif Cmd = "clean" then
         Cmd_Clean (False, Options);

      elsif Cmd = "fix" then
         Cmd_Fix (Options);

      elsif Cmd = "fetch" then
         Cmd_Fetch ("", True, 5, Options);

      elsif Cmd = "mark" then
         declare
            Pkg : constant String := Get_Next_Arg (1);
            Mark_Str : constant String := Get_Next_Arg (2);
         begin
            if Pkg = "" then
               Print_Error ("Package name required");
               return;
            end if;
            if Mark_Str = "manual" then
               Cmd_Mark (Pkg, Manual, Options);
            elsif Mark_Str = "auto" or Mark_Str = "automatic" then
               Cmd_Mark (Pkg, Automatic, Options);
            else
               Print_Error ("Invalid mark type: " & Mark_Str);
               Print_Info ("Use 'manual' or 'auto'");
            end if;
         end;

      elsif Cmd = "hold" then
         if Args = "" then
            Print_Error ("Package name required");
            return;
         end if;
         Cmd_Mark (Args, Hold, Options);

      elsif Cmd = "unhold" then
         if Args = "" then
            Print_Error ("Package name required");
            return;
         end if;
         Cmd_Mark (Args, Unhold, Options);

      --  System info commands
      elsif Cmd = "system-info" or Cmd = "info" or Cmd = "system" then
         Cmd_System_Info (Options);

      elsif Cmd = "language-pms" then
         Cmd_Language_Pms (Options);

      --  Legacy rollback command
      elsif Cmd = "rollback" then
         declare
            ID : constant Natural := Get_ID_Arg (1);
         begin
            if ID > 0 then
               Cmd_Snapshot_Rollback (ID, Options);
            else
               --  Rollback last transaction
               declare
                  Result : constant Rollback_Engine.Rollback_Result :=
                    Rollback_Engine.Rollback_Last_Transaction;
               begin
                  case Result.Status is
                     when Rollback_Engine.Success =>
                        Print_Success ("Rollback successful");
                     when Rollback_Engine.Requires_Reboot =>
                        Print_Warning ("Rollback requires reboot to complete");
                     when Rollback_Engine.Not_Needed =>
                        Print_Info ("No rollback needed");
                     when others =>
                        Print_Error ("Rollback failed: " &
                                    Ada.Strings.Unbounded.To_String (Result.Message));
                        Set_Exit_Status (Failure);
                  end case;
               end;
            end if;
         end;

      else
         Print_Error ("Unknown command: " & Cmd);
         Print_Info ("Run 'dnfinition --help' for usage information.");
         Set_Exit_Status (Failure);
      end if;
   end Process_Command;

begin
   --  Handle command line arguments
   if Argument_Count = 0 then
      --  No arguments: launch TUI
      Initialize_Subsystems;
      Run_TUI;

   elsif Argument_Count >= 1 then
      declare
         Arg : constant String := Argument (1);
      begin
         if Arg = "-h" or Arg = "--help" then
            Print_Help;

         elsif Arg = "-v" or Arg = "--version" then
            Print_Version;

         else
            Initialize_Subsystems;
            Process_Command (Arg);
         end if;
      end;
   end if;

exception
   when E : others =>
      Put_Line (Standard_Error,
        "Error: " & Ada.Exceptions.Exception_Message (E));
      Set_Exit_Status (Failure);
end DNFinition;
