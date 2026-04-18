-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Command_Executor - Implementation
pragma Ada_2022;

with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNAT.Expect;
with Detection;

package body Command_Executor is

   use Ada.Calendar;

   ---------------------------------------------------------------------------
   --  Internal Helpers
   ---------------------------------------------------------------------------

   --  Build full command string
   function Build_Command (Command : String; Args : String) return String is
   begin
      if Args = "" then
         return Command;
      else
         return Command & " " & Args;
      end if;
   end Build_Command;

   --  Get environment PATH
   function Get_Path return String is
   begin
      return Ada.Environment_Variables.Value ("PATH", "/usr/bin:/bin");
   end Get_Path;

   ---------------------------------------------------------------------------
   --  Simple Command Execution
   ---------------------------------------------------------------------------

   function Execute
     (Command    : String;
      Args       : String := "";
      Timeout_Ms : Natural := 0)
      return Command_Result
   is
      pragma Unreferenced (Timeout_Ms);
      use GNAT.Expect;

      Result      : Command_Result := Null_Result;
      Full_Cmd    : constant String := Build_Command (Command, Args);
      Descriptor  : Process_Descriptor;
      Match       : Expect_Match;
      Start_Time  : constant Time := Clock;
      Output      : Unbounded_String;
   begin
      --  Spawn the process
      Non_Blocking_Spawn
        (Descriptor  => Descriptor,
         Command     => "/bin/sh",
         Args        => (1 => new String'("-c"),
                         2 => new String'(Full_Cmd)),
         Buffer_Size => 16_384,
         Err_To_Out  => False);

      --  Read output until process ends
      loop
         begin
            Expect (Descriptor, Match, ".+", 100);
            Append (Output, Expect_Out (Descriptor));
         exception
            when Process_Died =>
               --  Process finished
               exit;
         end;
      end loop;

      --  Get exit status
      declare
         Status : Integer;
      begin
         Close (Descriptor, Status);
         Result.Exit_Code := Exit_Status (Status);
         Result.Success := Status = 0;
      end;

      Result.Stdout := Output;
      Result.Duration_Ms := Natural ((Clock - Start_Time) * 1000.0);

      return Result;

   exception
      when others =>
         return Null_Result;
   end Execute;

   function Execute_Stdout
     (Command : String;
      Args    : String := "")
      return String
   is
      Result : constant Command_Result := Execute (Command, Args);
   begin
      return To_String (Result.Stdout);
   end Execute_Stdout;

   function Execute_Success
     (Command : String;
      Args    : String := "")
      return Boolean
   is
      Result : constant Command_Result := Execute (Command, Args);
   begin
      return Result.Success;
   end Execute_Success;

   ---------------------------------------------------------------------------
   --  Interactive Command Execution
   ---------------------------------------------------------------------------

   procedure Execute_Interactive
     (Command      : String;
      Args         : String := "";
      On_Stdout    : Output_Callback := null;
      On_Stderr    : Output_Callback := null;
      On_Progress  : Progress_Callback := null;
      Result       : out Command_Result)
   is
      pragma Unreferenced (On_Stderr, On_Progress);
      use GNAT.Expect;

      Full_Cmd    : constant String := Build_Command (Command, Args);
      Descriptor  : Process_Descriptor;
      Match       : Expect_Match;
      Start_Time  : constant Time := Clock;
      Output      : Unbounded_String;
   begin
      Result := Null_Result;

      --  Spawn the process
      Non_Blocking_Spawn
        (Descriptor  => Descriptor,
         Command     => "/bin/sh",
         Args        => (1 => new String'("-c"),
                         2 => new String'(Full_Cmd)),
         Buffer_Size => 4_096,
         Err_To_Out  => True);

      --  Read output line by line
      loop
         begin
            Expect (Descriptor, Match, "[^\n]*\n", 100);
            declare
               Line : constant String := Expect_Out (Descriptor);
            begin
               Append (Output, Line);
               if On_Stdout /= null then
                  On_Stdout (Line);
               end if;
            end;
         exception
            when Process_Died =>
               exit;
         end;
      end loop;

      --  Get exit status
      declare
         Status : Integer;
      begin
         Close (Descriptor, Status);
         Result.Exit_Code := Exit_Status (Status);
         Result.Success := Status = 0;
      end;

      Result.Stdout := Output;
      Result.Duration_Ms := Natural ((Clock - Start_Time) * 1000.0);
   end Execute_Interactive;

   ---------------------------------------------------------------------------
   --  Privileged Execution
   ---------------------------------------------------------------------------

   function Running_As_Root return Boolean is
      Euid : constant String :=
        Ada.Environment_Variables.Value ("EUID", "1000");
   begin
      return Euid = "0";
   exception
      when others =>
         --  Fallback: try to access /root
         return Ada.Directories.Exists ("/root/.bashrc");
   end Running_As_Root;

   function Sudo_Available return Boolean is
   begin
      return Command_Exists ("sudo");
   end Sudo_Available;

   function Execute_Privileged
     (Command    : String;
      Args       : String := "";
      Timeout_Ms : Natural := 0)
      return Command_Result
   is
   begin
      if Running_As_Root then
         return Execute (Command, Args, Timeout_Ms);
      elsif Sudo_Available then
         return Execute ("sudo", Command & " " & Args, Timeout_Ms);
      else
         --  No sudo available
         declare
            Result : Command_Result := Null_Result;
         begin
            Result.Stderr := To_Unbounded_String
              ("Root privileges required but sudo not available");
            return Result;
         end;
      end if;
   end Execute_Privileged;

   ---------------------------------------------------------------------------
   --  Backend-Specific Commands
   ---------------------------------------------------------------------------

   function Execute_PM
     (Subcommand : String;
      Args       : String := "";
      Privileged : Boolean := True)
      return Command_Result
   is
      PM      : constant Detection.System_Package_Manager :=
        Detection.Detect_Package_Manager;
      PM_Name : constant String := Detection.PM_Name (PM);
      Full_Args : constant String :=
        (if Args = "" then Subcommand else Subcommand & " " & Args);
   begin
      if Privileged then
         return Execute_Privileged (PM_Name, Full_Args);
      else
         return Execute (PM_Name, Full_Args);
      end if;
   end Execute_PM;

   function Execute_APT (Args : String) return Command_Result is
   begin
      return Execute_Privileged ("apt-get", Args);
   end Execute_APT;

   function Execute_DNF (Args : String) return Command_Result is
   begin
      return Execute_Privileged ("dnf", Args);
   end Execute_DNF;

   function Execute_Pacman (Args : String) return Command_Result is
   begin
      return Execute_Privileged ("pacman", Args);
   end Execute_Pacman;

   function Execute_Zypper (Args : String) return Command_Result is
   begin
      return Execute_Privileged ("zypper", Args);
   end Execute_Zypper;

   function Execute_RPM_Ostree (Args : String) return Command_Result is
   begin
      return Execute_Privileged ("rpm-ostree", Args);
   end Execute_RPM_Ostree;

   ---------------------------------------------------------------------------
   --  Output Parsing Helpers
   ---------------------------------------------------------------------------

   function Split_Lines (Text : String) return Line_Array is
      Count : Natural := 0;
      Pos   : Natural := Text'First;
   begin
      --  Count lines
      for C of Text loop
         if C = ASCII.LF then
            Count := Count + 1;
         end if;
      end loop;
      if Text'Length > 0 and then Text (Text'Last) /= ASCII.LF then
         Count := Count + 1;
      end if;

      if Count = 0 then
         return (1 .. 0 => <>);
      end if;

      --  Extract lines
      declare
         Result : Line_Array (1 .. Count);
         Idx    : Positive := 1;
         Start  : Natural := Text'First;
      begin
         Pos := Text'First;
         while Pos <= Text'Last loop
            if Text (Pos) = ASCII.LF then
               Result (Idx) := To_Unbounded_String (Text (Start .. Pos - 1));
               Idx := Idx + 1;
               Start := Pos + 1;
            end if;
            Pos := Pos + 1;
         end loop;

         --  Handle last line without newline
         if Start <= Text'Last then
            Result (Idx) := To_Unbounded_String (Text (Start .. Text'Last));
         end if;

         return Result;
      end;
   end Split_Lines;

   function Command_Exists (Command : String) return Boolean is
      Result : constant Command_Result := Execute ("which", Command);
   begin
      return Result.Success;
   end Command_Exists;

   function Which (Command : String) return String is
      Result : constant Command_Result := Execute ("which", Command);
   begin
      if Result.Success then
         declare
            Path : constant String := To_String (Result.Stdout);
         begin
            --  Remove trailing newline
            if Path'Length > 0 and then Path (Path'Last) = ASCII.LF then
               return Path (Path'First .. Path'Last - 1);
            else
               return Path;
            end if;
         end;
      else
         return "";
      end if;
   end Which;

end Command_Executor;
