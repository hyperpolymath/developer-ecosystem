-- SPDX-License-Identifier: MPL-2.0
-- Academic Plugin for Kith

with Ada.Text_IO; use Ada.Text_IO;

package body Academic is

   -- Generate ORCID .well-known file
   procedure Generate_ORCID (ORCID_ID : String) is
   begin
      Put_Line ("{");
      Put_Line ("  ""orcid"": """ & ORCID_ID & """,");
      Put_Line ("  ""profile"": ""https://orcid.org/" & ORCID_ID & """");
      Put_Line ("}");
   end Generate_ORCID;

   -- Generate academic identity file
   procedure Generate_Identity (Institution : String; Department : String) is
   begin
      Put_Line ("{");
      Put_Line ("  ""institution"": """ & Institution & """,");
      Put_Line ("  ""department"": """ & Department & """,");
      Put_Line ("  ""type"": ""academic""");
      Put_Line ("}");
   end Generate_Identity;

end Academic;
