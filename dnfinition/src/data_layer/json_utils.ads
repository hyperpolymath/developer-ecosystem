-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- JSON Utilities - Wrapper around GNATCOLL.JSON for IPC
pragma Ada_2022;

with Ada.Strings.Unbounded;
with GNATCOLL.JSON;

package JSON_Utils is

   use Ada.Strings.Unbounded;

   ---------------------------------------------------------------------------
   -- Types
   ---------------------------------------------------------------------------

   subtype JSON_Value is GNATCOLL.JSON.JSON_Value;
   subtype JSON_Array is GNATCOLL.JSON.JSON_Array;

   Parse_Error : exception;

   ---------------------------------------------------------------------------
   -- Parsing Functions
   ---------------------------------------------------------------------------

   --  Parse JSON string, raises Parse_Error on invalid JSON
   function Parse (Text : String) return JSON_Value;

   --  Parse JSON string, returns Null_Value on error
   function Try_Parse (Text : String) return JSON_Value;

   --  Check if JSON is valid
   function Is_Valid_JSON (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   -- Value Access
   ---------------------------------------------------------------------------

   --  Get string field, returns "" if missing or wrong type
   function Get_String
     (Value : JSON_Value;
      Field : String;
      Default : String := "") return String;

   --  Get integer field, returns Default if missing or wrong type
   function Get_Integer
     (Value   : JSON_Value;
      Field   : String;
      Default : Integer := 0) return Integer;

   --  Get boolean field, returns Default if missing or wrong type
   function Get_Boolean
     (Value   : JSON_Value;
      Field   : String;
      Default : Boolean := False) return Boolean;

   --  Check if field exists
   function Has_Field (Value : JSON_Value; Field : String) return Boolean;

   --  Get nested object, returns empty object if missing
   function Get_Object
     (Value : JSON_Value;
      Field : String) return JSON_Value;

   --  Get array field, returns empty array if missing
   function Get_Array
     (Value : JSON_Value;
      Field : String) return JSON_Array;

   ---------------------------------------------------------------------------
   -- IPC Response Helpers
   ---------------------------------------------------------------------------

   type Response_Status is (OK, Error_Response, Invalid_Response);

   --  Check response status field
   function Get_Response_Status (Value : JSON_Value) return Response_Status;

   --  Get error message from response
   function Get_Error_Message (Value : JSON_Value) return String;

   --  Get ID from response (for tx:begin, snap:create, etc.)
   function Get_ID (Value : JSON_Value) return Natural;

   ---------------------------------------------------------------------------
   -- JSON Construction
   ---------------------------------------------------------------------------

   --  Create empty object
   function Empty_Object return JSON_Value;

   --  Create object with single string field
   function Create_Object (Key : String; Value : String) return JSON_Value;

   --  Set string field on object
   procedure Set_Field
     (Obj   : in out JSON_Value;
      Key   : String;
      Value : String);

   --  Set integer field on object
   procedure Set_Field
     (Obj   : in out JSON_Value;
      Key   : String;
      Value : Integer);

   --  Set boolean field on object
   procedure Set_Field
     (Obj   : in Out JSON_Value;
      Key   : String;
      Value : Boolean);

   --  Convert to JSON string
   function To_String (Value : JSON_Value) return String;

   ---------------------------------------------------------------------------
   -- Request Building Helpers
   ---------------------------------------------------------------------------

   --  Build IPC request JSON
   function Build_Request
     (Operation : String;
      Args      : JSON_Value) return String;

   --  Build simple request with no args
   function Build_Request (Operation : String) return String;

end JSON_Utils;
