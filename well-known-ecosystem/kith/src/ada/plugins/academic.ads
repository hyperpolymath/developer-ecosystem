-- SPDX-License-Identifier: MPL-2.0
-- Academic Plugin for Kith
--
-- Generates .well-known files for academic institutions:
-- - ORCID integration
-- - DOI resolution
-- - Academic identity

package Academic is

   -- Generate ORCID .well-known file
   procedure Generate_ORCID (ORCID_ID : String);

   -- Generate academic identity file
   procedure Generate_Identity (Institution : String; Department : String);

end Academic;
