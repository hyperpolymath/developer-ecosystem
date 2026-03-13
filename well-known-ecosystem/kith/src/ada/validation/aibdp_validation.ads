-- SPDX-License-Identifier: MPL-2.0
-- AIBDP (AI Bot Detection Protocol) Validation
--
-- Validates .well-known/aibdp files according to the AIBDP specification.
-- See: https://github.com/hyperpolymath/aibdp

package AIBDP_Validation is

   -- Validation result type
   type Validation_Result is (Valid, Invalid, File_Not_Found, Parse_Error);

   -- Validate an AIBDP file
   -- Returns the validation result status
   procedure Validate_AIBDP (File_Name : String);

   -- Validate an AIBDP file and return the result
   function Validate (File_Name : String) return Validation_Result;

   -- Check if a file exists
   function File_Exists (File_Name : String) return Boolean;

   -- Print validation summary
   procedure Print_Summary (File_Name : String; Result : Validation_Result);

end AIBDP_Validation;
