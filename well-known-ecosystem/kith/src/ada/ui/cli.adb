-- SPDX-License-Identifier: MPL-2.0
-- CLI Interface for Kith

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Kith;
with AIBDP_Validation;
with Security_Txt;
with DID;

package body CLI is

   -- Print usage information
   procedure Print_Usage is
   begin
      Put_Line ("Kith - Ethical .well-known Management");
      Put_Line ("");
      Put_Line ("Usage: kith [command] [options]");
      Put_Line ("");
      Put_Line ("Commands:");
      Put_Line ("  validate <file>    Validate a .well-known file");
      Put_Line ("  generate <type>    Generate a .well-known file");
      Put_Line ("  status             Show .well-known directory status");
      Put_Line ("  tui                Launch interactive TUI");
      Put_Line ("  version            Show version information");
      Put_Line ("  help               Show this help message");
   end Print_Usage;

   -- Print version information
   procedure Print_Version is
   begin
      Put_Line ("Kith v" & Kith.Version);
      Put_Line ("Ethical .well-known Management");
   end Print_Version;

   -- Process command-line arguments
   procedure Process_Args is
   begin
      if Argument_Count = 0 then
         -- No arguments: launch TUI
         Kith.Run;
         return;
      end if;

      declare
         Cmd : constant String := Argument (1);
      begin
         if Cmd = "help" or Cmd = "-h" or Cmd = "--help" then
            Print_Usage;
         elsif Cmd = "version" or Cmd = "-v" or Cmd = "--version" then
            Print_Version;
         elsif Cmd = "validate" then
            if Argument_Count < 2 then
               Put_Line ("Error: validate requires a file argument");
               return;
            end if;
            declare
               File_Name : constant String := Argument (2);
            begin
               -- Detect file type and validate
               if Index (File_Name, "aibdp") > 0 then
                  AIBDP_Validation.Validate_AIBDP (File_Name);
               elsif Index (File_Name, "security") > 0 then
                  Security_Txt.Validate (File_Name);
               elsif Index (File_Name, "did") > 0 then
                  DID.Validate (File_Name);
               else
                  Put_Line ("Unknown file type: " & File_Name);
               end if;
            end;
         elsif Cmd = "status" then
            Put_Line ("Checking .well-known/ directory...");
         elsif Cmd = "tui" then
            Kith.Run;
         else
            Put_Line ("Unknown command: " & Cmd);
            Print_Usage;
         end if;
      end;
   end Process_Args;

end CLI;
