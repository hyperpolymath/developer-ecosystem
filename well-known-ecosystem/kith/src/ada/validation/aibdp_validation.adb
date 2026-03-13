-- SPDX-License-Identifier: MPL-2.0
-- AIBDP (AI Bot Detection Protocol) Validation
--
-- Validates .well-known/aibdp files according to the AIBDP specification.

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body AIBDP_Validation is

   -- Required fields in AIBDP JSON
   Required_Fields : constant array (1 .. 3) of String (1 .. 20) :=
     ("version             ",
      "policy              ",
      "contact             ");

   -- Check if a file exists
   function File_Exists (File_Name : String) return Boolean is
   begin
      return Exists (File_Name);
   end File_Exists;

   -- Simple JSON key presence check
   -- Looks for "key": pattern in file content
   function Has_Key (Content : Unbounded_String; Key : String) return Boolean is
      Pattern : constant String := """" & Key & """:";
   begin
      return Index (Content, Pattern) > 0;
   end Has_Key;

   -- Read entire file content
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

   -- Trim trailing spaces from a fixed-width string
   function Trim (S : String) return String is
   begin
      for I in reverse S'Range loop
         if S (I) /= ' ' then
            return S (S'First .. I);
         end if;
      end loop;
      return "";
   end Trim;

   -- Validate an AIBDP file and return the result
   function Validate (File_Name : String) return Validation_Result is
      Content : Unbounded_String;
   begin
      -- Check file existence
      if not File_Exists (File_Name) then
         return File_Not_Found;
      end if;

      -- Read file content
      Content := Read_File (File_Name);
      if Length (Content) = 0 then
         return Parse_Error;
      end if;

      -- Check for required fields (version, policy, contact)
      for I in Required_Fields'Range loop
         if not Has_Key (Content, Trim (Required_Fields (I))) then
            return Invalid;
         end if;
      end loop;

      return Valid;
   end Validate;

   -- Print validation summary
   procedure Print_Summary (File_Name : String; Result : Validation_Result) is
   begin
      Put ("AIBDP Validation: " & File_Name & " - ");
      case Result is
         when Valid =>
            Put_Line ("VALID");
         when Invalid =>
            Put_Line ("INVALID (missing required fields)");
         when File_Not_Found =>
            Put_Line ("FILE NOT FOUND");
         when Parse_Error =>
            Put_Line ("PARSE ERROR");
      end case;
   end Print_Summary;

   -- Validate an AIBDP file (procedure wrapper)
   procedure Validate_AIBDP (File_Name : String) is
      Result : constant Validation_Result := Validate (File_Name);
   begin
      Print_Summary (File_Name, Result);
   end Validate_AIBDP;

end AIBDP_Validation;
