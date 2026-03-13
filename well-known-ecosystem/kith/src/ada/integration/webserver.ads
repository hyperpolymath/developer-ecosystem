-- SPDX-License-Identifier: MPL-2.0
-- Webserver Integration for Kith
--
-- Provides webserver configuration generation for .well-known serving.

package Webserver is

   type Server_Type is (Nginx, Apache, Caddy);

   -- Generate webserver config for .well-known
   procedure Generate_Config (Server : Server_Type);

   -- Test .well-known accessibility
   procedure Test_Endpoint (URL : String);

end Webserver;
