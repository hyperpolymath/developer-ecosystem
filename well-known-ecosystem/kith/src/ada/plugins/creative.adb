-- SPDX-License-Identifier: MPL-2.0
-- Creative Plugin for Kith

with Ada.Text_IO; use Ada.Text_IO;

package body Creative is

   -- Get SPDX identifier for license type
   function License_SPDX (License : License_Type) return String is
   begin
      case License is
         when CC_BY       => return "CC-BY-4.0";
         when CC_BY_SA    => return "CC-BY-SA-4.0";
         when CC_BY_NC    => return "CC-BY-NC-4.0";
         when CC_BY_NC_SA => return "CC-BY-NC-SA-4.0";
         when CC0         => return "CC0-1.0";
         when MIT         => return "MIT";
         when GPL         => return "GPL-3.0-or-later";
      end case;
   end License_SPDX;

   -- Generate license .well-known file
   procedure Generate_License (License : License_Type) is
   begin
      Put_Line ("{");
      Put_Line ("  ""license"": """ & License_SPDX (License) & """,");
      Put_Line ("  ""url"": ""https://spdx.org/licenses/" & License_SPDX (License) & ".html""");
      Put_Line ("}");
   end Generate_License;

   -- Generate attribution requirements
   procedure Generate_Attribution (Author : String; Work : String) is
   begin
      Put_Line ("{");
      Put_Line ("  ""author"": """ & Author & """,");
      Put_Line ("  ""work"": """ & Work & """,");
      Put_Line ("  ""attribution_required"": true");
      Put_Line ("}");
   end Generate_Attribution;

end Creative;
