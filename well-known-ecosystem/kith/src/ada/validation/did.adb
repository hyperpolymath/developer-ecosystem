-- SPDX-License-Identifier: MPL-2.0
-- DID (Decentralized Identifiers) Validation

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body DID is

   -- Required fields: @context, id
   -- Optional fields: verificationMethod, authentication, service

   -- Read file content
   function Read_File (File_Name : String) return Unbounded_String is
      File    : File_Type;
      Content : Unbounded_String := Null_Unbounded_String;
      Line    : String (1 .. 1024);
      Last    : Natural;
   begin
      Open (File, In_File, File_Name);
      while not End_Of_File (File) loop
         Get_Line (File, Line, Last);
         Append (Content, Line (1 .. Last));
      end loop;
      Close (File);
      return Content;
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         return Null_Unbounded_String;
   end Read_File;

   -- Check for required JSON key
   function Has_Key (Content : Unbounded_String; Key : String) return Boolean is
      Pattern : constant String := """" & Key & """:";
   begin
      return Index (Content, Pattern) > 0;
   end Has_Key;

   -- Validate a DID document
   procedure Validate (File_Name : String) is
      Content : Unbounded_String;
   begin
      if not Exists (File_Name) then
         Put_Line ("DID: " & File_Name & " - FILE NOT FOUND");
         return;
      end if;

      Content := Read_File (File_Name);
      if Length (Content) = 0 then
         Put_Line ("DID: " & File_Name & " - EMPTY FILE");
         return;
      end if;

      -- Check required fields
      if not Has_Key (Content, "@context") then
         Put_Line ("DID: " & File_Name & " - INVALID (missing @context)");
         return;
      end if;

      if not Has_Key (Content, "id") then
         Put_Line ("DID: " & File_Name & " - INVALID (missing id)");
         return;
      end if;

      Put_Line ("DID: " & File_Name & " - VALID");
   end Validate;

   -- Check if a DID document is valid
   function Is_Valid (File_Name : String) return Boolean is
      Content : Unbounded_String;
   begin
      if not Exists (File_Name) then
         return False;
      end if;

      Content := Read_File (File_Name);
      return Length (Content) > 0
         and then Has_Key (Content, "@context")
         and then Has_Key (Content, "id");
   end Is_Valid;

end DID;
