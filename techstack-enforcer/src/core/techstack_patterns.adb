-------------------------------------------------------------------------------
-- Techstack Enforcer - Pattern Matching Engine Implementation
-------------------------------------------------------------------------------

package body Techstack_Patterns with SPARK_Mode is

   function Match_Pattern
     (Pattern     : Pattern_String;
      Pattern_Len : Natural;
      Input       : Path_String;
      Input_Len   : Natural) return Boolean
   is
      P_Idx : Natural := 1;
      I_Idx : Natural := 1;
   begin
      if Pattern_Len = 0 then
         return Input_Len = 0;
      end if;

      while P_Idx <= Pattern_Len loop
         if Pattern (P_Idx) = '*' then
            --  Check for ** (recursive glob)
            if P_Idx < Pattern_Len and then Pattern (P_Idx + 1) = '*' then
               --  ** matches any path including /
               if P_Idx + 1 = Pattern_Len then
                  return True;  -- ** at end matches everything
               end if;
               --  Try matching rest of pattern at each position
               for Try_Pos in I_Idx .. Input_Len + 1 loop
                  pragma Loop_Invariant (P_Idx <= Pattern_Len);
                  pragma Loop_Invariant (Try_Pos >= I_Idx);
                  if Match_Pattern
                       (Pattern (P_Idx + 2 .. Max_Pattern_Length),
                        Pattern_Len - P_Idx - 1,
                        Input (Try_Pos .. Max_Path_Length),
                        (if Try_Pos > Input_Len then 0 else Input_Len - Try_Pos + 1))
                  then
                     return True;
                  end if;
               end loop;
               return False;
            else
               --  Single * matches any chars except /
               if P_Idx = Pattern_Len then
                  --  * at end - match if no more / in input
                  for Check_Idx in I_Idx .. Input_Len loop
                     pragma Loop_Invariant (Check_Idx >= I_Idx);
                     if Input (Check_Idx) = '/' then
                        return False;
                     end if;
                  end loop;
                  return True;
               end if;
               --  Try matching rest of pattern at each position
               for Try_Pos in I_Idx .. Input_Len + 1 loop
                  pragma Loop_Invariant (P_Idx <= Pattern_Len);
                  pragma Loop_Invariant (Try_Pos >= I_Idx);
                  --  Check for / which * doesn't cross
                  declare
                     Has_Slash : Boolean := False;
                  begin
                     for Check_Idx in I_Idx .. Try_Pos - 1 loop
                        pragma Loop_Invariant (Check_Idx >= I_Idx);
                        if Check_Idx <= Input_Len and then Input (Check_Idx) = '/' then
                           Has_Slash := True;
                        end if;
                     end loop;
                     if not Has_Slash then
                        if Match_Pattern
                             (Pattern (P_Idx + 1 .. Max_Pattern_Length),
                              Pattern_Len - P_Idx,
                              Input (Try_Pos .. Max_Path_Length),
                              (if Try_Pos > Input_Len then 0 else Input_Len - Try_Pos + 1))
                        then
                           return True;
                        end if;
                     end if;
                  end;
               end loop;
               return False;
            end if;

         elsif Pattern (P_Idx) = '?' then
            --  ? matches exactly one character (except /)
            if I_Idx > Input_Len or else Input (I_Idx) = '/' then
               return False;
            end if;
            P_Idx := P_Idx + 1;
            I_Idx := I_Idx + 1;

         else
            --  Literal character match
            if I_Idx > Input_Len or else Pattern (P_Idx) /= Input (I_Idx) then
               return False;
            end if;
            P_Idx := P_Idx + 1;
            I_Idx := I_Idx + 1;
         end if;
      end loop;

      --  Pattern exhausted - input must also be exhausted
      return I_Idx > Input_Len;
   end Match_Pattern;

   procedure Get_Extension
     (Path      : Path_String;
      Path_Len  : Natural;
      Ext       : out Pattern_String;
      Ext_Len   : out Natural)
   is
      Dot_Pos : Natural := 0;
   begin
      Ext := (others => ' ');
      Ext_Len := 0;

      --  Find last dot after last slash
      for I in reverse 1 .. Path_Len loop
         pragma Loop_Invariant (Dot_Pos <= Path_Len);
         if Path (I) = '/' then
            exit;  --  Stop at directory separator
         elsif Path (I) = '.' then
            Dot_Pos := I;
            exit;
         end if;
      end loop;

      if Dot_Pos > 0 and then Dot_Pos < Path_Len then
         Ext_Len := Path_Len - Dot_Pos;
         if Ext_Len <= Max_Pattern_Length then
            Ext (1 .. Ext_Len) := Path (Dot_Pos + 1 .. Path_Len);
         else
            Ext_Len := 0;
         end if;
      end if;
   end Get_Extension;

   procedure Get_Filename
     (Path      : Path_String;
      Path_Len  : Natural;
      Name      : out Pattern_String;
      Name_Len  : out Natural)
   is
      Slash_Pos : Natural := 0;
   begin
      Name := (others => ' ');
      Name_Len := 0;

      --  Find last slash
      for I in reverse 1 .. Path_Len loop
         pragma Loop_Invariant (Slash_Pos <= Path_Len);
         if Path (I) = '/' then
            Slash_Pos := I;
            exit;
         end if;
      end loop;

      if Slash_Pos < Path_Len then
         Name_Len := Path_Len - Slash_Pos;
         if Name_Len <= Max_Pattern_Length then
            Name (1 .. Name_Len) := Path (Slash_Pos + 1 .. Path_Len);
         else
            Name_Len := 0;
         end if;
      elsif Path_Len > 0 then
         --  No slash, entire path is filename
         Name_Len := (if Path_Len <= Max_Pattern_Length then Path_Len else 0);
         if Name_Len > 0 then
            Name (1 .. Name_Len) := Path (1 .. Path_Len);
         end if;
      end if;
   end Get_Filename;

   function Contains_Directory
     (Path      : Path_String;
      Path_Len  : Natural;
      Dir_Name  : Pattern_String;
      Dir_Len   : Natural) return Boolean
   is
   begin
      if Dir_Len = 0 or else Dir_Len > Path_Len then
         return False;
      end if;

      --  Search for /dirname/ pattern
      for I in 1 .. Path_Len - Dir_Len + 1 loop
         pragma Loop_Invariant (I <= Path_Len - Dir_Len + 1);
         declare
            Start_Ok : constant Boolean :=
              (I = 1 or else Path (I - 1) = '/');
            End_Ok : constant Boolean :=
              (I + Dir_Len - 1 = Path_Len or else
               (I + Dir_Len <= Path_Len and then Path (I + Dir_Len) = '/'));
            Match : Boolean := True;
         begin
            if Start_Ok and End_Ok then
               for J in 0 .. Dir_Len - 1 loop
                  pragma Loop_Invariant (J <= Dir_Len - 1);
                  if Path (I + J) /= Dir_Name (1 + J) then
                     Match := False;
                     exit;
                  end if;
               end loop;
               if Match then
                  return True;
               end if;
            end if;
         end;
      end loop;

      return False;
   end Contains_Directory;

end Techstack_Patterns;
