-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Backend_Interface - Implementation
pragma Ada_2022;

with Detection;

package body Backend_Interface is

   --  Placeholder for backend instances
   --  Real implementation would have proper dispatching

   -------------------------
   -- Get_Default_Backend
   -------------------------

   function Get_Default_Backend
     return access Package_Manager_Backend'Class
   is
      PM : constant Detection.Package_Manager_Type :=
        Detection.Detect_Package_Manager;
      pragma Unreferenced (PM);
   begin
      --  Would return the appropriate backend based on detected PM
      --  For now, return null as we need concrete implementations
      return null;
   end Get_Default_Backend;

end Backend_Interface;
