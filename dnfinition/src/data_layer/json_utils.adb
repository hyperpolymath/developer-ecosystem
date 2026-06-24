-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- JSON Utilities Implementation
pragma Ada_2022;

with GNATCOLL.JSON; use GNATCOLL.JSON;

package body JSON_Utils is

   ---------------------------------------------------------------------------
   -- Parsing Functions
   ---------------------------------------------------------------------------

   function Parse (Text : String) return JSON_Value is
   begin
      return Read (Text);
   exception
      when others =>
         raise Parse_Error with "Invalid JSON: " & Text (Text'First ..
            Natural'Min (Text'Last, Text'First + 50));
   end Parse;

   function Try_Parse (Text : String) return JSON_Value is
   begin
      return Read (Text);
   exception
      when others =>
         return Create_Object;
   end Try_Parse;

   function Is_Valid_JSON (Text : String) return Boolean is
      Dummy : JSON_Value;
   begin
      Dummy := Read (Text);
      return True;
   exception
      when others =>
         return False;
   end Is_Valid_JSON;

   ---------------------------------------------------------------------------
   -- Value Access
   ---------------------------------------------------------------------------

   function Get_String
     (Value   : JSON_Value;
      Field   : String;
      Default : String := "") return String
   is
   begin
      if Value.Has_Field (Field) then
         declare
            Field_Value : constant JSON_Value := Value.Get (Field);
         begin
            if Field_Value.Kind = JSON_String_Type then
               return Field_Value.Get;
            end if;
         end;
      end if;
      return Default;
   exception
      when others =>
         return Default;
   end Get_String;

   function Get_Integer
     (Value   : JSON_Value;
      Field   : String;
      Default : Integer := 0) return Integer
   is
   begin
      if Value.Has_Field (Field) then
         declare
            Field_Value : constant JSON_Value := Value.Get (Field);
         begin
            if Field_Value.Kind = JSON_Int_Type then
               return Integer (Long_Long_Integer'(Field_Value.Get));
            end if;
         end;
      end if;
      return Default;
   exception
      when others =>
         return Default;
   end Get_Integer;

   function Get_Boolean
     (Value   : JSON_Value;
      Field   : String;
      Default : Boolean := False) return Boolean
   is
   begin
      if Value.Has_Field (Field) then
         declare
            Field_Value : constant JSON_Value := Value.Get (Field);
         begin
            if Field_Value.Kind = JSON_Boolean_Type then
               return Field_Value.Get;
            end if;
         end;
      end if;
      return Default;
   exception
      when others =>
         return Default;
   end Get_Boolean;

   function Has_Field (Value : JSON_Value; Field : String) return Boolean is
   begin
      return Value.Has_Field (Field);
   exception
      when others =>
         return False;
   end Has_Field;

   function Get_Object
     (Value : JSON_Value;
      Field : String) return JSON_Value
   is
   begin
      if Value.Has_Field (Field) then
         declare
            Field_Value : constant JSON_Value := Value.Get (Field);
         begin
            if Field_Value.Kind = JSON_Object_Type then
               return Field_Value;
            end if;
         end;
      end if;
      return Create_Object;
   exception
      when others =>
         return Create_Object;
   end Get_Object;

   function Get_Array
     (Value : JSON_Value;
      Field : String) return JSON_Array
   is
   begin
      if Value.Has_Field (Field) then
         declare
            Field_Value : constant JSON_Value := Value.Get (Field);
         begin
            if Field_Value.Kind = JSON_Array_Type then
               return Field_Value.Get;
            end if;
         end;
      end if;
      return Empty_Array;
   exception
      when others =>
         return Empty_Array;
   end Get_Array;

   ---------------------------------------------------------------------------
   -- IPC Response Helpers
   ---------------------------------------------------------------------------

   function Get_Response_Status (Value : JSON_Value) return Response_Status is
      Status_Str : constant String := Get_String (Value, "status");
   begin
      if Status_Str = "ok" then
         return OK;
      elsif Status_Str = "error" then
         return Error_Response;
      else
         return Invalid_Response;
      end if;
   end Get_Response_Status;

   function Get_Error_Message (Value : JSON_Value) return String is
   begin
      return Get_String (Value, "error", "Unknown error");
   end Get_Error_Message;

   function Get_ID (Value : JSON_Value) return Natural is
   begin
      return Natural (Get_Integer (Value, "id", 0));
   end Get_ID;

   ---------------------------------------------------------------------------
   -- JSON Construction
   ---------------------------------------------------------------------------

   function Empty_Object return JSON_Value is
   begin
      return Create_Object;
   end Empty_Object;

   function Create_Object (Key : String; Value : String) return JSON_Value is
      Result : JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Result.Set_Field (Key, Value);
      return Result;
   end Create_Object;

   procedure Set_Field
     (Obj   : in out JSON_Value;
      Key   : String;
      Value : String)
   is
   begin
      Obj.Set_Field (Key, Value);
   end Set_Field;

   procedure Set_Field
     (Obj   : in Out JSON_Value;
      Key   : String;
      Value : Integer)
   is
   begin
      Obj.Set_Field (Key, Value);
   end Set_Field;

   procedure Set_Field
     (Obj   : in Out JSON_Value;
      Key   : String;
      Value : Boolean)
   is
   begin
      Obj.Set_Field (Key, Value);
   end Set_Field;

   function To_String (Value : JSON_Value) return String is
   begin
      return Value.Write;
   end To_String;

   ---------------------------------------------------------------------------
   -- Request Building Helpers
   ---------------------------------------------------------------------------

   function Build_Request
     (Operation : String;
      Args      : JSON_Value) return String
   is
      Request : JSON_Value := Create_Object;
   begin
      Request.Set_Field ("op", Operation);
      Request.Set_Field ("args", Args);
      return Request.Write & ASCII.LF;
   end Build_Request;

   function Build_Request (Operation : String) return String is
   begin
      return Build_Request (Operation, Create_Object);
   end Build_Request;

end JSON_Utils;
