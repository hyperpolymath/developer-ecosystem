-- SPDX-License-Identifier: MPL-2.0
-- Union Plugin for Kith

with Ada.Text_IO; use Ada.Text_IO;

package body Union is

   -- Generate union membership .well-known file
   procedure Generate_Membership (Union_Name : String; Local_Number : String) is
   begin
      Put_Line ("{");
      Put_Line ("  ""union"": """ & Union_Name & """,");
      Put_Line ("  ""local"": """ & Local_Number & """,");
      Put_Line ("  ""type"": ""membership""");
      Put_Line ("}");
   end Generate_Membership;

   -- Generate worker cooperative status
   procedure Generate_Coop_Status (Coop_Name : String) is
   begin
      Put_Line ("{");
      Put_Line ("  ""cooperative"": """ & Coop_Name & """,");
      Put_Line ("  ""worker_owned"": true,");
      Put_Line ("  ""democratic_governance"": true");
      Put_Line ("}");
   end Generate_Coop_Status;

   -- Generate fair labor policy declaration
   procedure Generate_Fair_Labor is
   begin
      Put_Line ("{");
      Put_Line ("  ""fair_labor"": true,");
      Put_Line ("  ""living_wage"": true,");
      Put_Line ("  ""collective_bargaining"": true,");
      Put_Line ("  ""worker_rights"": [""organize"", ""negotiate"", ""strike""]");
      Put_Line ("}");
   end Generate_Fair_Labor;

end Union;
