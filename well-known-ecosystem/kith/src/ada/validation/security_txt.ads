-- SPDX-License-Identifier: MPL-2.0
-- security.txt Validation (RFC 9116)
--
-- Validates .well-known/security.txt files according to RFC 9116.

package Security_Txt is

   type Validation_Result is (Valid, Invalid, File_Not_Found, Parse_Error);

   -- Validate a security.txt file
   procedure Validate (File_Name : String);

   -- Check if a security.txt file is valid
   function Is_Valid (File_Name : String) return Boolean;

end Security_Txt;
