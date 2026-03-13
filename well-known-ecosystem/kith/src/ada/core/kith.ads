-- SPDX-License-Identifier: MPL-2.0
-- Kith: Ethical .well-known Management
--
-- Main package specification for Kith TUI application.

package Kith is

   -- Application version
   Version : constant String := "0.1.0";

   -- Application name
   Name : constant String := "Kith";

   -- Default well-known directory path
   Well_Known_Path : constant String := ".well-known";

   -- Initialize the Kith application
   procedure Initialize;

   -- Run the main application loop
   procedure Run;

   -- Cleanup and shutdown
   procedure Shutdown;

end Kith;
