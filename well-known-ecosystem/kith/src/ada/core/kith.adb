-- SPDX-License-Identifier: MPL-2.0
-- Kith: Ethical .well-known Management
--
-- Main package body for Kith TUI application.

with Ada.Text_IO; use Ada.Text_IO;
with TUI;

package body Kith is

   Initialized : Boolean := False;

   -- Initialize the Kith application
   procedure Initialize is
   begin
      if not Initialized then
         Put_Line("Kith v" & Version & " - Ethical .well-known Management");
         Put_Line("");
         Initialized := True;
      end if;
   end Initialize;

   -- Run the main application loop
   procedure Run is
   begin
      if not Initialized then
         Initialize;
      end if;
      TUI.Show_Menu;
   end Run;

   -- Cleanup and shutdown
   procedure Shutdown is
   begin
      Put_Line("Goodbye from Kith!");
      Initialized := False;
   end Shutdown;

end Kith;
