-- SPDX-License-Identifier: MPL-2.0
-- Webserver Integration for Kith

with Ada.Text_IO; use Ada.Text_IO;

package body Webserver is

   -- Generate webserver config for .well-known
   procedure Generate_Config (Server : Server_Type) is
   begin
      case Server is
         when Nginx =>
            Put_Line ("# Nginx configuration for .well-known");
            Put_Line ("location /.well-known/ {");
            Put_Line ("    alias /var/www/.well-known/;");
            Put_Line ("    default_type application/json;");
            Put_Line ("}");
         when Apache =>
            Put_Line ("# Apache configuration for .well-known");
            Put_Line ("Alias /.well-known /var/www/.well-known");
            Put_Line ("<Directory /var/www/.well-known>");
            Put_Line ("    Options Indexes FollowSymLinks");
            Put_Line ("    AllowOverride None");
            Put_Line ("    Require all granted");
            Put_Line ("</Directory>");
         when Caddy =>
            Put_Line ("# Caddy configuration for .well-known");
            Put_Line ("handle /.well-known/* {");
            Put_Line ("    root * /var/www");
            Put_Line ("    file_server");
            Put_Line ("}");
      end case;
   end Generate_Config;

   -- Test .well-known accessibility
   procedure Test_Endpoint (URL : String) is
   begin
      Put_Line ("Testing endpoint: " & URL);
      Put_Line ("Run: curl -I " & URL);
   end Test_Endpoint;

end Webserver;
