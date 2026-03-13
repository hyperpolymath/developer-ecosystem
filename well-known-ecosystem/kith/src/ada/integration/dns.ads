-- SPDX-License-Identifier: MPL-2.0
-- DNS Integration for Kith
--
-- Provides DNS operations for WebFinger and DMARC validation.

package DNS is

   -- Query DNS TXT record
   function Query_TXT (Domain : String) return String;

   -- Validate DMARC record
   procedure Validate_DMARC (Domain : String);

   -- Check WebFinger DNS requirements
   procedure Check_WebFinger (Domain : String);

end DNS;
