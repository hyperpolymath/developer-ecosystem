-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Command_Executor - Execute shell commands with output capture
--
-- Provides process spawning with output capture for running package
-- manager commands and capturing their output for display.
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Command_Executor is

   ---------------------------------------------------------------------------
   --  Command Result
   ---------------------------------------------------------------------------

   type Exit_Status is new Integer range -1 .. 255;

   type Command_Result is record
      Success      : Boolean := False;
      Exit_Code    : Exit_Status := -1;
      Stdout       : Unbounded_String;
      Stderr       : Unbounded_String;
      Duration_Ms  : Natural := 0;
   end record;

   Null_Result : constant Command_Result := (
      Success     => False,
      Exit_Code   => -1,
      Stdout      => Null_Unbounded_String,
      Stderr      => Null_Unbounded_String,
      Duration_Ms => 0
   );

   ---------------------------------------------------------------------------
   --  Simple Command Execution
   ---------------------------------------------------------------------------

   --  Execute a command and capture output
   function Execute
     (Command    : String;
      Args       : String := "";
      Timeout_Ms : Natural := 0)  --  0 = no timeout
      return Command_Result;

   --  Execute and return stdout only (convenience)
   function Execute_Stdout
     (Command : String;
      Args    : String := "")
      return String;

   --  Execute and check if successful
   function Execute_Success
     (Command : String;
      Args    : String := "")
      return Boolean;

   ---------------------------------------------------------------------------
   --  Interactive Command Execution (for package managers)
   ---------------------------------------------------------------------------

   type Output_Callback is access procedure (Line : String);
   type Progress_Callback is access procedure (Percent : Natural);

   --  Execute with real-time output (for install/upgrade progress)
   procedure Execute_Interactive
     (Command      : String;
      Args         : String := "";
      On_Stdout    : Output_Callback := null;
      On_Stderr    : Output_Callback := null;
      On_Progress  : Progress_Callback := null;
      Result       : out Command_Result);

   ---------------------------------------------------------------------------
   --  Privileged Execution
   ---------------------------------------------------------------------------

   --  Execute with sudo if not root
   function Execute_Privileged
     (Command    : String;
      Args       : String := "";
      Timeout_Ms : Natural := 0)
      return Command_Result;

   --  Check if sudo is available
   function Sudo_Available return Boolean;

   --  Check if we're running as root
   function Running_As_Root return Boolean;

   ---------------------------------------------------------------------------
   --  Backend-Specific Commands
   ---------------------------------------------------------------------------

   --  Execute package manager command (auto-detects backend)
   function Execute_PM
     (Subcommand : String;
      Args       : String := "";
      Privileged : Boolean := True)
      return Command_Result;

   --  Execute apt/dnf/pacman/zypper specific
   function Execute_APT (Args : String) return Command_Result;
   function Execute_DNF (Args : String) return Command_Result;
   function Execute_Pacman (Args : String) return Command_Result;
   function Execute_Zypper (Args : String) return Command_Result;
   function Execute_RPM_Ostree (Args : String) return Command_Result;

   ---------------------------------------------------------------------------
   --  Output Parsing Helpers
   ---------------------------------------------------------------------------

   --  Parse output line by line
   type Line_Array is array (Positive range <>) of Unbounded_String;

   function Split_Lines (Text : String) return Line_Array;

   --  Check if command exists in PATH
   function Command_Exists (Command : String) return Boolean;

   --  Get command full path
   function Which (Command : String) return String;

private

   --  Internal sudo password handling (for non-interactive)
   Sudo_Password_Set : Boolean := False;

end Command_Executor;
