-- SPDX-License-Identifier: MPL-2.0
-- security.txt Validation (RFC 9116)

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Security_Txt is

   -- Required field: Contact
   -- Recommended fields: Expires, Encryption, Acknowledgments, Preferred-Languages, Canonical, Policy, Hiring

   -- Check if file contains a Contact field
   function Has_Contact (Content : Unbounded_String) return Boolean is
   begin
      return Index (Content, "Contact:") > 0;
   end Has_Contact;

   -- Check if file contains an Expires field
   function Has_Expires (Content : Unbounded_String) return Boolean is
   begin
      return Index (Content, "Expires:") > 0;
   end Has_Expires;

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
         Append (Content, Line (1 .. Last) & ASCII.LF);
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

   -- Validate a security.txt file
   procedure Validate (File_Name : String) is
      Content : Unbounded_String;
   begin
      if not Exists (File_Name) then
         Put_Line ("security.txt: " & File_Name & " - FILE NOT FOUND");
         return;
      end if;

      Content := Read_File (File_Name);
      if Length (Content) = 0 then
         Put_Line ("security.txt: " & File_Name & " - EMPTY FILE");
         return;
      end if;

      -- RFC 9116 requires Contact field
      if not Has_Contact (Content) then
         Put_Line ("security.txt: " & File_Name & " - INVALID (missing Contact field)");
         return;
      end if;

      -- Warn if Expires is missing (recommended per RFC 9116)
      if not Has_Expires (Content) then
         Put_Line ("security.txt: " & File_Name & " - VALID (warning: missing Expires field)");
      else
         Put_Line ("security.txt: " & File_Name & " - VALID");
      end if;
   end Validate;

   -- Check if a security.txt file is valid
   function Is_Valid (File_Name : String) return Boolean is
      Content : Unbounded_String;
   begin
      if not Exists (File_Name) then
         return False;
      end if;

      Content := Read_File (File_Name);
      return Length (Content) > 0 and then Has_Contact (Content);
   end Is_Valid;

end Security_Txt;
