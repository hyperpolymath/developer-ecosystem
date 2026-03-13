-- SPDX-License-Identifier: MPL-2.0
-- DID (Decentralized Identifiers) Validation
--
-- Validates .well-known/did.json files according to W3C DID specification.

package DID is

   type Validation_Result is (Valid, Invalid, File_Not_Found, Parse_Error);

   -- Validate a DID document
   procedure Validate (File_Name : String);

   -- Check if a DID document is valid
   function Is_Valid (File_Name : String) return Boolean;

end DID;
