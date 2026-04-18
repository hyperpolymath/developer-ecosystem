-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Package_Types - Implementation
pragma Ada_2022;

with Ada.Characters.Handling; use Ada.Characters.Handling;

package body Package_Types is

   ----------------
   -- Make_Package
   ----------------

   function Make_Package
     (Name    : String;
      Version : String := "";
      Arch    : String := "")
      return Package_Info
   is
   begin
      return (
         Name         => +Name,
         Version      => +Version,
         Release      => Null_Unbounded_String,
         Epoch        => 0,
         Architecture => +Arch,
         Summary      => Null_Unbounded_String,
         Description  => Null_Unbounded_String,
         URL          => Null_Unbounded_String,
         License      => Null_Unbounded_String,
         Repository   => Null_Unbounded_String,
         Size         => 0,
         Install_Size => 0,
         State        => Available,
         Priority     => Standard,
         Is_Automatic => False
      );
   end Make_Package;

   ----------------------
   -- Compare_Versions
   ----------------------

   function Compare_Versions
     (Left, Right : Version_String)
      return Integer
   is
      L : constant String := To_String (Left);
      R : constant String := To_String (Right);

      type Segment_Kind is (Numeric, Alpha, Other);

      function Get_Kind (C : Character) return Segment_Kind is
      begin
         if Is_Digit (C) then
            return Numeric;
         elsif Is_Letter (C) then
            return Alpha;
         else
            return Other;
         end if;
      end Get_Kind;

      L_Pos : Positive := 1;
      R_Pos : Positive := 1;
   begin
      --  Empty version handling
      if L = "" and R = "" then
         return 0;
      elsif L = "" then
         return -1;
      elsif R = "" then
         return 1;
      end if;

      --  RPM-style version comparison (simplified)
      while L_Pos <= L'Last and R_Pos <= R'Last loop
         --  Skip separators
         while L_Pos <= L'Last and then Get_Kind (L (L_Pos)) = Other loop
            L_Pos := L_Pos + 1;
         end loop;
         while R_Pos <= R'Last and then Get_Kind (R (R_Pos)) = Other loop
            R_Pos := R_Pos + 1;
         end loop;

         --  Check if we've exhausted either string
         if L_Pos > L'Last or R_Pos > R'Last then
            exit;
         end if;

         --  Extract segments
         declare
            L_Start : constant Positive := L_Pos;
            R_Start : constant Positive := R_Pos;
            L_Kind  : constant Segment_Kind := Get_Kind (L (L_Pos));
            R_Kind  : constant Segment_Kind := Get_Kind (R (R_Pos));
         begin
            --  Numeric segments beat alpha segments
            if L_Kind = Numeric and R_Kind = Alpha then
               return 1;
            elsif L_Kind = Alpha and R_Kind = Numeric then
               return -1;
            end if;

            --  Find segment end
            while L_Pos <= L'Last and then Get_Kind (L (L_Pos)) = L_Kind loop
               L_Pos := L_Pos + 1;
            end loop;
            while R_Pos <= R'Last and then Get_Kind (R (R_Pos)) = R_Kind loop
               R_Pos := R_Pos + 1;
            end loop;

            declare
               L_Seg : constant String := L (L_Start .. L_Pos - 1);
               R_Seg : constant String := R (R_Start .. R_Pos - 1);
            begin
               if L_Kind = Numeric then
                  --  Numeric comparison
                  declare
                     L_Num : constant Natural := Natural'Value (L_Seg);
                     R_Num : constant Natural := Natural'Value (R_Seg);
                  begin
                     if L_Num < R_Num then
                        return -1;
                     elsif L_Num > R_Num then
                        return 1;
                     end if;
                  end;
               else
                  --  Lexicographic comparison
                  if L_Seg < R_Seg then
                     return -1;
                  elsif L_Seg > R_Seg then
                     return 1;
                  end if;
               end if;
            end;
         end;
      end loop;

      --  If one string has more segments, it's "greater"
      if L_Pos <= L'Last then
         return 1;
      elsif R_Pos <= R'Last then
         return -1;
      else
         return 0;
      end if;
   end Compare_Versions;

   ----------------------
   -- Version_Satisfies
   ----------------------

   function Version_Satisfies
     (Version  : Version_String;
      Operator : Version_Operator;
      Target   : Version_String)
      return Boolean
   is
      Cmp : constant Integer := Compare_Versions (Version, Target);
   begin
      case Operator is
         when Equal =>
            return Cmp = 0;
         when Less_Than =>
            return Cmp < 0;
         when Greater_Than =>
            return Cmp > 0;
         when Less_Equal =>
            return Cmp <= 0;
         when Greater_Equal =>
            return Cmp >= 0;
         when Any_Version =>
            return True;
      end case;
   end Version_Satisfies;

end Package_Types;
