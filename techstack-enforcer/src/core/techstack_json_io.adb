-------------------------------------------------------------------------------
-- Techstack Enforcer - JSON Input/Output Implementation
-------------------------------------------------------------------------------

with Ada.Text_IO;       use Ada.Text_IO;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;

package body Techstack_JSON_IO is

   --  Helper to create bounded path string
   function To_Path (S : String) return Path_String is
      Result : Path_String := (others => ' ');
   begin
      if S'Length <= Max_Path_Length then
         Result (1 .. S'Length) := S;
      end if;
      return Result;
   end To_Path;

   function Level_To_String (L : Block_Level) return String is
   begin
      case L is
         when Allow => return "allow";
         when Warn  => return "warn";
         when Block => return "block";
         when Fatal => return "fatal";
      end case;
   end Level_To_String;

   function Decision_To_String (D : Decision_Kind) return String is
   begin
      case D is
         when Allow_Decision => return "allow";
         when Deny_Decision  => return "deny";
         when Warn_Decision  => return "warn";
      end case;
   end Decision_To_String;

   function Mode_To_String (M : Enforce_Mode) return String is
   begin
      case M is
         when Learning  => return "learning";
         when Warn_Only => return "warn";
         when Enforce   => return "enforce";
         when Lockdown  => return "lockdown";
      end case;
   end Mode_To_String;

   function Escape_JSON_String (S : String) return String is
      Result : String (1 .. S'Length * 2);  -- Worst case: every char needs escape
      J      : Natural := 0;
   begin
      for I in S'Range loop
         case S (I) is
            when '"' =>
               J := J + 1; Result (J) := '\';
               J := J + 1; Result (J) := '"';
            when '\' =>
               J := J + 1; Result (J) := '\';
               J := J + 1; Result (J) := '\';
            when ASCII.LF =>
               J := J + 1; Result (J) := '\';
               J := J + 1; Result (J) := 'n';
            when ASCII.CR =>
               J := J + 1; Result (J) := '\';
               J := J + 1; Result (J) := 'r';
            when ASCII.HT =>
               J := J + 1; Result (J) := '\';
               J := J + 1; Result (J) := 't';
            when others =>
               if S (I) >= ' ' and S (I) <= '~' then
                  J := J + 1; Result (J) := S (I);
               else
                  --  Skip non-printable characters for simplicity
                  null;
               end if;
         end case;
      end loop;
      return Result (1 .. J);
   end Escape_JSON_String;

   procedure Decide_File
     (File_Path : String;
      Result    : out File_Decision)
   is
      P          : Path_String := (others => ' ');
      P_Len      : constant Natural := Natural'Min (File_Path'Length, Max_Path_Length);
      Check_Res  : Techstack_Enforcer.Check_Result;
   begin
      Result := Null_Decision;
      Result.File_Path := To_Path (File_Path);
      Result.Path_Len := P_Len;

      P (1 .. P_Len) := File_Path (File_Path'First .. File_Path'First + P_Len - 1);
      Techstack_Enforcer.Check_File (P, P_Len, Check_Res);

      Result.Level := Check_Res.Level;
      Result.Pattern := Check_Res.Pattern;
      Result.Pattern_Len := Check_Res.Pattern_Len;
      Result.Reason := Check_Res.Reason;
      Result.Reason_Len := Check_Res.Reason_Len;

      --  Determine decision based on check result
      if Check_Res.Blocked then
         Result.Decision := Deny_Decision;
      elsif Check_Res.Level = Warn then
         Result.Decision := Warn_Decision;
      else
         Result.Decision := Allow_Decision;
      end if;
   end Decide_File;

   procedure Decide_Batch_From_Stdin
     (Result  : out Batch_Result;
      Success : out Boolean)
   is
      Line : String (1 .. Max_Path_Length);
      Last : Natural;
   begin
      Result.Count := 0;
      Result.Summary := (Total => 0, Allowed => 0, Denied => 0, Warnings => 0);
      Result.Mode := Techstack_Enforcer.Get_Mode;
      Success := True;

      while not End_Of_File loop
         Get_Line (Line, Last);

         --  Skip empty lines
         if Last > 0 then
            declare
               Path : constant String := Trim (Line (1 .. Last), Ada.Strings.Both);
            begin
               if Path'Length > 0 and Result.Count < Max_Batch_Size then
                  Result.Count := Result.Count + 1;
                  Decide_File (Path, Result.Decisions (Result.Count));

                  --  Update summary
                  Result.Summary.Total := Result.Summary.Total + 1;
                  case Result.Decisions (Result.Count).Decision is
                     when Allow_Decision =>
                        Result.Summary.Allowed := Result.Summary.Allowed + 1;
                     when Deny_Decision =>
                        Result.Summary.Denied := Result.Summary.Denied + 1;
                     when Warn_Decision =>
                        Result.Summary.Warnings := Result.Summary.Warnings + 1;
                  end case;
               end if;
            end;
         end if;
      end loop;

   exception
      when others =>
         Success := False;
   end Decide_Batch_From_Stdin;

   procedure Output_Decision_JSON (Dec : File_Decision) is
      File_Str    : constant String := Trim (Dec.File_Path (1 .. Dec.Path_Len), Ada.Strings.Both);
      Pattern_Str : constant String := Trim (Dec.Pattern (1 .. Dec.Pattern_Len), Ada.Strings.Both);
      Reason_Str  : constant String := Trim (Dec.Reason (1 .. Dec.Reason_Len), Ada.Strings.Both);
   begin
      Put_Line ("{");
      Put_Line ("  ""file"": """ & Escape_JSON_String (File_Str) & """,");
      Put_Line ("  ""decision"": """ & Decision_To_String (Dec.Decision) & """,");
      Put_Line ("  ""level"": """ & Level_To_String (Dec.Level) & """,");

      if Dec.Pattern_Len > 0 then
         Put_Line ("  ""pattern"": """ & Escape_JSON_String (Pattern_Str) & """,");
      else
         Put_Line ("  ""pattern"": null,");
      end if;

      if Dec.Reason_Len > 0 then
         Put_Line ("  ""reason"": """ & Escape_JSON_String (Reason_Str) & """");
      else
         Put_Line ("  ""reason"": null");
      end if;

      Put_Line ("}");
   end Output_Decision_JSON;

   procedure Output_Batch_JSON (Batch : Batch_Result) is
   begin
      Put_Line ("{");
      Put_Line ("  ""decisions"": [");

      for I in 1 .. Batch.Count loop
         declare
            Dec         : File_Decision renames Batch.Decisions (I);
            File_Str    : constant String := Trim (Dec.File_Path (1 .. Dec.Path_Len), Ada.Strings.Both);
            Pattern_Str : constant String := Trim (Dec.Pattern (1 .. Dec.Pattern_Len), Ada.Strings.Both);
            Reason_Str  : constant String := Trim (Dec.Reason (1 .. Dec.Reason_Len), Ada.Strings.Both);
            Comma       : constant String := (if I < Batch.Count then "," else "");
         begin
            Put_Line ("    {");
            Put_Line ("      ""file"": """ & Escape_JSON_String (File_Str) & """,");
            Put_Line ("      ""decision"": """ & Decision_To_String (Dec.Decision) & """,");
            Put_Line ("      ""level"": """ & Level_To_String (Dec.Level) & """,");

            if Dec.Pattern_Len > 0 then
               Put_Line ("      ""pattern"": """ & Escape_JSON_String (Pattern_Str) & """,");
            else
               Put_Line ("      ""pattern"": null,");
            end if;

            if Dec.Reason_Len > 0 then
               Put_Line ("      ""reason"": """ & Escape_JSON_String (Reason_Str) & """");
            else
               Put_Line ("      ""reason"": null");
            end if;

            Put_Line ("    }" & Comma);
         end;
      end loop;

      Put_Line ("  ],");
      Put_Line ("  ""summary"": {");
      Put_Line ("    ""total"": " & Natural'Image (Batch.Summary.Total) & ",");
      Put_Line ("    ""allowed"": " & Natural'Image (Batch.Summary.Allowed) & ",");
      Put_Line ("    ""denied"": " & Natural'Image (Batch.Summary.Denied) & ",");
      Put_Line ("    ""warnings"": " & Natural'Image (Batch.Summary.Warnings));
      Put_Line ("  },");
      Put_Line ("  ""mode"": """ & Mode_To_String (Batch.Mode) & """");
      Put_Line ("}");
   end Output_Batch_JSON;

end Techstack_JSON_IO;
