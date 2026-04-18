-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Shell_Escape - Implementation
pragma Ada_2022;
pragma SPARK_Mode (On);

package body Shell_Escape
  with SPARK_Mode
is

   --  Shell metacharacters that need escaping
   function Is_Shell_Metachar (C : Character) return Boolean is
   begin
      case C is
         when ' ' | Character'Val (9) | Character'Val (10) |  -- space, tab, newline
              Character'Val (13) |                            -- carriage return
              '!' | '"' | '#' | '$' | '&' | ''' |
              '(' | ')' | '*' | ';' | '<' | '>' |
              '?' | '[' | '\' | ']' | '^' | '`' |
              '{' | '|' | '}' | '~' =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Shell_Metachar;

   function Contains_Shell_Metachar (S : String) return Boolean is
   begin
      for C of S loop
         if Is_Shell_Metachar (C) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Shell_Metachar;

   function Is_Valid_Path (Path : String) return Boolean is
   begin
      for C of Path loop
         --  Reject null bytes and most control characters
         if Character'Pos (C) < 32 and then C /= Character'Val (9) then
            --  Allow tab but reject other control chars including null
            return False;
         end if;
         if Character'Pos (C) = 127 then
            --  Reject DEL
            return False;
         end if;
      end loop;
      return True;
   end Is_Valid_Path;

   function Count_Single_Quotes (S : String) return Natural is
      Count : Natural := 0;
   begin
      for C of S loop
         if C = ''' then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Single_Quotes;

   --  Escape using single quotes
   --  Single quotes protect everything except single quotes themselves
   --  To include a single quote: end quote, add escaped quote, restart quote
   --  Example: "don't" becomes 'don'"'"'t' or 'don'\''t'
   function Escape_Path (Path : String) return Escape_Result is
      Quote_Count   : constant Natural := Count_Single_Quotes (Path);
      --  Each quote needs: close(1) + backslash(1) + quote(1) + open(1) = 4 chars
      --  Plus opening and closing quotes = 2
      Needed_Length : constant Natural := Path'Length + (Quote_Count * 3) + 2;
      Result_Str    : String (1 .. Max_Escaped_Length) := (others => ' ');
      Pos           : Natural := 1;
   begin
      --  Validate path first
      if not Is_Valid_Path (Path) then
         return (Success   => False,
                 Error_Msg => "Path contains invalid characters (null or control)" &
                              (1 .. 256 - 48 => ' '),
                 Msg_Len   => 48);
      end if;

      --  Check length
      if Needed_Length > Max_Escaped_Length then
         return (Success   => False,
                 Error_Msg => "Escaped path would exceed maximum length" &
                              (1 .. 256 - 43 => ' '),
                 Msg_Len   => 43);
      end if;

      --  Start with opening quote
      Result_Str (Pos) := ''';
      Pos := Pos + 1;

      --  Copy path, escaping single quotes
      for C of Path loop
         if C = ''' then
            --  End current quote, add escaped quote, restart quote
            --  'foo'bar' becomes 'foo'\''bar'
            Result_Str (Pos) := ''';      -- close quote
            Pos := Pos + 1;
            Result_Str (Pos) := '\';      -- backslash
            Pos := Pos + 1;
            Result_Str (Pos) := ''';      -- the literal quote
            Pos := Pos + 1;
            Result_Str (Pos) := ''';      -- reopen quote
            Pos := Pos + 1;
         else
            Result_Str (Pos) := C;
            Pos := Pos + 1;
         end if;
      end loop;

      --  Add closing quote
      Result_Str (Pos) := ''';
      Pos := Pos + 1;

      return (Success => True,
              Value   => Result_Str,
              Length  => Pos - 1);
   end Escape_Path;

   function Escape_Argument (Arg : String) return Escape_Result is
   begin
      --  Use the same escaping logic as paths
      return Escape_Path (Arg);
   end Escape_Argument;

end Shell_Escape;
