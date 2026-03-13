-- SPDX-License-Identifier: MPL-2.0
-- Union Plugin for Kith
--
-- Generates .well-known files for labor unions and worker cooperatives:
-- - Union membership declarations
-- - Worker-owned business status
-- - Fair labor policies

package Union is

   -- Generate union membership .well-known file
   procedure Generate_Membership (Union_Name : String; Local_Number : String);

   -- Generate worker cooperative status
   procedure Generate_Coop_Status (Coop_Name : String);

   -- Generate fair labor policy declaration
   procedure Generate_Fair_Labor;

end Union;
