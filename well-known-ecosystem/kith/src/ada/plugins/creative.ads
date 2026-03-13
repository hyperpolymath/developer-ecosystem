-- SPDX-License-Identifier: MPL-2.0
-- Creative Plugin for Kith
--
-- Generates .well-known files for creative works:
-- - License declarations
-- - Attribution requirements
-- - Creative Commons support

package Creative is

   type License_Type is (CC_BY, CC_BY_SA, CC_BY_NC, CC_BY_NC_SA, CC0, MIT, GPL);

   -- Generate license .well-known file
   procedure Generate_License (License : License_Type);

   -- Generate attribution requirements
   procedure Generate_Attribution (Author : String; Work : String);

end Creative;
