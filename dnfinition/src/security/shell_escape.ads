-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Shell_Escape - Prevent shell injection by escaping dangerous characters
pragma Ada_2022;
pragma SPARK_Mode (On);

package Shell_Escape
  with SPARK_Mode
is

   --  Maximum length for escaped strings (2x input + quotes)
   Max_Escaped_Length : constant := 8192;

   --  Result of escape operation
   type Escape_Result (Success : Boolean := False) is record
      case Success is
         when True =>
            Value  : String (1 .. Max_Escaped_Length);
            Length : Natural;
         when False =>
            Error_Msg : String (1 .. 256);
            Msg_Len   : Natural;
      end case;
   end record;

   --  Escape a path for safe use in shell commands
   --  Uses single quotes with proper escaping of embedded quotes
   function Escape_Path (Path : String) return Escape_Result
     with Global => null,
          Pre    => Path'Length <= Max_Escaped_Length / 2 - 2;

   --  Escape a generic shell argument
   function Escape_Argument (Arg : String) return Escape_Result
     with Global => null,
          Pre    => Arg'Length <= Max_Escaped_Length / 2 - 2;

   --  Check if a string contains any shell metacharacters
   function Contains_Shell_Metachar (S : String) return Boolean
     with Global => null;

   --  Validate a path contains no null bytes or control characters
   function Is_Valid_Path (Path : String) return Boolean
     with Global => null;

   --  Characters that are dangerous in shell context
   --  Space, Tab, Newline, !, ", #, $, &, ', (, ), *, ;, <, >, ?, [, \, ], ^, `, {, |, }, ~
   function Is_Shell_Metachar (C : Character) return Boolean
     with Global => null,
          Inline;

private

   --  Helper to count single quotes in a string
   function Count_Single_Quotes (S : String) return Natural
     with Global => null;

end Shell_Escape;
