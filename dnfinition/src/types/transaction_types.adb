-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Transaction_Types - Implementation
pragma Ada_2022;

package body Transaction_Types is

   --------------------
   -- Make_Operation
   --------------------

   function Make_Operation
     (Op      : Operation_Kind;
      Name    : String;
      Old_Ver : String := "";
      New_Ver : String := "")
      return Operation_Entry
   is
   begin
      return (
         Sequence     => 1,
         Operation    => Op,
         Package_Name => +Name,
         Old_Version  => +Old_Ver,
         New_Version  => +New_Ver,
         Status       => Pending,
         Error_Msg    => Null_Unbounded_String
      );
   end Make_Operation;

   ---------------------
   -- Calculate_Sizes
   ---------------------

   procedure Calculate_Sizes
     (Trans : in Out Transaction_Info)
   is
      Download : Package_Size := 0;
      Install  : Package_Size := 0;
      Remove_S : Package_Size := 0;
   begin
      --  Sum up sizes from packages being added
      for Pkg of Trans.Packages_Add loop
         Download := Download + Pkg.Size;
         Install := Install + Pkg.Install_Size;
      end loop;

      --  Sum up sizes from packages being upgraded
      for Pkg of Trans.Packages_Upg loop
         Download := Download + Pkg.Size;
         Install := Install + Pkg.Install_Size;
      end loop;

      --  Sum up sizes from packages being removed
      for Pkg of Trans.Packages_Del loop
         Remove_S := Remove_S + Pkg.Install_Size;
      end loop;

      Trans.Download_Size := Download;
      Trans.Install_Size := Install;
      Trans.Remove_Size := Remove_S;
   end Calculate_Sizes;

   ----------------------
   -- Count_Operations
   ----------------------

   function Count_Operations
     (Trans : Transaction_Info;
      Kind  : Operation_Kind)
      return Natural
   is
      Count : Natural := 0;
   begin
      for Op of Trans.Operations loop
         if Op.Operation = Kind then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Operations;

end Transaction_Types;
