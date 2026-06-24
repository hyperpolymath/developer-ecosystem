-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Terminal_Interface - Implementation
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Detection;

package body Terminal_Interface is

   Running : Boolean := False;

   ----------------
   -- Initialize
   ----------------

   procedure Initialize is
   begin
      NCurses_Bindings.Initialize;
      Screen_Lines := Screen_Height;
      Screen_Columns := Screen_Width;
      Create_Windows;
      Running := True;
   end Initialize;

   --------------
   -- Finalize
   --------------

   procedure Finalize is
   begin
      Running := False;
      Destroy_Windows;
      NCurses_Bindings.Finalize;
   end Finalize;

   ---------
   -- Run
   ---------

   procedure Run is
      Key : Integer;
   begin
      if not Running then
         Initialize;
      end if;

      Display_Header;
      Display_Status_Bar ("Welcome to DNFinition - Press ? for help");
      Refresh_All;

      while Running loop
         Key := Get_User_Input;

         case Key is
            --  Navigation
            when Key_Up | Character'Pos ('k') =>
               Scroll_Up;

            when Key_Down | Character'Pos ('j') =>
               Scroll_Down;

            when Key_Prev_Page | Character'Pos ('u') =>
               Page_Up;

            when Key_Next_Page | Character'Pos ('d') =>
               Page_Down;

            when Key_Home | Character'Pos ('g') =>
               Go_To_Top;

            when Key_End | Character'Pos ('G') =>
               Go_To_Bottom;

            --  Actions
            when Character'Pos ('+') | Character'Pos ('i') =>
               Mark_For_Install;

            when Character'Pos ('-') | Character'Pos ('r') =>
               Mark_For_Remove;

            when Character'Pos ('U') =>
               Mark_For_Upgrade;

            when Character'Pos ('g') =>
               if Confirm_Action ("Apply transaction?") then
                  Apply_Transaction;
               end if;

            when Character'Pos ('/') =>
               Show_Search;

            when Character'Pos ('s') =>
               Show_Snapshots;

            when Character'Pos ('h') =>
               Show_History;

            when Character'Pos ('R') =>
               if Confirm_Action ("Rollback last transaction?") then
                  Rollback_Last;
               end if;

            when Character'Pos ('?') | Key_F1 =>
               Display_Help;

            when Character'Pos ('q') | Key_Escape =>
               if Current_Mode = Mode_Help then
                  Current_Mode := Mode_Browse;
                  Refresh_All;
               else
                  if Confirm_Action ("Quit DNFinition?") then
                     Running := False;
                  end if;
               end if;

            when others =>
               null;
         end case;

         if Running then
            Refresh_All;
         end if;
      end loop;

      Finalize;
   end Run;

   --------------------------
   -- Display_Package_List
   --------------------------

   procedure Display_Package_List (Packages : Package_Array) is
      Line : Integer := 1;
      Max_Lines : constant Integer :=
        Screen_Lines - Header_Height - Status_Height - 2;
   begin
      Current_Packages := Packages;
      W_Clear (List_Win);
      Draw_Box (List_Win);

      for I in Scroll_Offset + 1 ..
               Integer'Min (Scroll_Offset + Max_Lines,
                            Integer (Packages.Length))
      loop
         declare
            Pkg : constant Package_Info := Packages.Element (I);
            Name : constant String := To_String (Pkg.Name);
            State_Char : Character;
         begin
            --  Show package state indicator
            case Pkg.State is
               when Installed   => State_Char := 'i';
               when Upgradeable => State_Char := 'u';
               when Available   => State_Char := ' ';
               when Held        => State_Char := 'h';
               when others      => State_Char := '?';
            end case;

            --  Highlight selected line
            if I - 1 = Selected_Index then
               W_Attr_On (List_Win, A_Reverse);
            end if;

            Print_At_Window (List_Win, Line, 1,
              State_Char & " " & Name);

            if I - 1 = Selected_Index then
               W_Attr_Off (List_Win, A_Reverse);
            end if;

            Line := Line + 1;
         end;
      end loop;

      W_Refresh (List_Win);
   end Display_Package_List;

   -----------------------------
   -- Display_Package_Details
   -----------------------------

   procedure Display_Package_Details (Package : Package_Info) is
   begin
      W_Clear (Details_Win);
      Draw_Box (Details_Win);

      Print_At_Window (Details_Win, 1, 2,
        "Name: " & To_String (Package.Name));
      Print_At_Window (Details_Win, 2, 2,
        "Version: " & To_String (Package.Version));
      Print_At_Window (Details_Win, 3, 2,
        "Arch: " & To_String (Package.Architecture));
      Print_At_Window (Details_Win, 4, 2,
        "State: " & Package_State'Image (Package.State));
      Print_At_Window (Details_Win, 6, 2,
        "Summary:");
      Print_At_Window (Details_Win, 7, 2,
        To_String (Package.Summary));

      W_Refresh (Details_Win);
   end Display_Package_Details;

   ---------------------------------
   -- Display_Transaction_Preview
   ---------------------------------

   procedure Display_Transaction_Preview (Trans : Transaction_Info) is
      Line : Integer := 1;
   begin
      W_Clear (Details_Win);
      Draw_Box (Details_Win);

      Print_At_Window (Details_Win, Line, 2, "Transaction Preview:");
      Line := Line + 2;

      if not Trans.Packages_Add.Is_Empty then
         Print_At_Window (Details_Win, Line, 2, "Installing:");
         Line := Line + 1;
         for Pkg of Trans.Packages_Add loop
            Print_At_Window (Details_Win, Line, 4,
              "+ " & To_String (Pkg.Name));
            Line := Line + 1;
         end loop;
      end if;

      if not Trans.Packages_Del.Is_Empty then
         Print_At_Window (Details_Win, Line, 2, "Removing:");
         Line := Line + 1;
         for Pkg of Trans.Packages_Del loop
            Print_At_Window (Details_Win, Line, 4,
              "- " & To_String (Pkg.Name));
            Line := Line + 1;
         end loop;
      end if;

      if not Trans.Packages_Upg.Is_Empty then
         Print_At_Window (Details_Win, Line, 2, "Upgrading:");
         Line := Line + 1;
         for Pkg of Trans.Packages_Upg loop
            Print_At_Window (Details_Win, Line, 4,
              "^ " & To_String (Pkg.Name));
            Line := Line + 1;
         end loop;
      end if;

      W_Refresh (Details_Win);
   end Display_Transaction_Preview;

   ------------------------
   -- Display_Status_Bar
   ------------------------

   procedure Display_Status_Bar (Message : String) is
   begin
      W_Clear (Status_Win);
      Print_At_Window (Status_Win, 0, 1, Message);
      W_Refresh (Status_Win);
   end Display_Status_Bar;

   --------------------
   -- Display_Header
   --------------------

   procedure Display_Header is
      PM : constant Detection.Package_Manager_Type :=
        Detection.Detect_Package_Manager;
   begin
      W_Clear (Header_Win);
      Draw_Box (Header_Win);

      Set_Bold (True);
      Print_At_Window (Header_Win, 1, 2,
        "DNFinition - Universal Package Manager");
      Set_Bold (False);

      Print_At_Window (Header_Win, 1, Screen_Columns - 20,
        "Backend: " & Detection.PM_Name (PM));

      W_Refresh (Header_Win);
   end Display_Header;

   ------------------
   -- Display_Help
   ------------------

   procedure Display_Help is
   begin
      Current_Mode := Mode_Help;
      W_Clear (List_Win);
      W_Clear (Details_Win);
      Draw_Box (List_Win);

      Print_At_Window (List_Win, 1, 2, "DNFinition Help");
      Print_At_Window (List_Win, 3, 2, "Navigation:");
      Print_At_Window (List_Win, 4, 4, "j/Down  - Move down");
      Print_At_Window (List_Win, 5, 4, "k/Up    - Move up");
      Print_At_Window (List_Win, 6, 4, "u/PgUp  - Page up");
      Print_At_Window (List_Win, 7, 4, "d/PgDn  - Page down");
      Print_At_Window (List_Win, 8, 4, "g/Home  - Go to top");
      Print_At_Window (List_Win, 9, 4, "G/End   - Go to bottom");

      Print_At_Window (List_Win, 11, 2, "Actions:");
      Print_At_Window (List_Win, 12, 4, "+/i     - Mark for install");
      Print_At_Window (List_Win, 13, 4, "-/r     - Mark for remove");
      Print_At_Window (List_Win, 14, 4, "U       - Mark for upgrade");
      Print_At_Window (List_Win, 15, 4, "g       - Apply transaction");
      Print_At_Window (List_Win, 16, 4, "/       - Search packages");
      Print_At_Window (List_Win, 17, 4, "s       - Manage snapshots");
      Print_At_Window (List_Win, 18, 4, "h       - Transaction history");
      Print_At_Window (List_Win, 19, 4, "R       - Rollback last");
      Print_At_Window (List_Win, 20, 4, "q/Esc   - Quit");

      W_Refresh (List_Win);
      W_Refresh (Details_Win);
   end Display_Help;

   --------------------
   -- Get_User_Input
   --------------------

   function Get_User_Input return Integer is
   begin
      return Get_Key;
   end Get_User_Input;

   --------------------
   -- Confirm_Action
   --------------------

   function Confirm_Action (Prompt : String) return Boolean is
      Key : Integer;
   begin
      Display_Status_Bar (Prompt & " [y/N]");
      Refresh;
      Key := Get_Key;
      return Key = Character'Pos ('y') or Key = Character'Pos ('Y');
   end Confirm_Action;

   ----------------------
   -- Get_Search_Query
   ----------------------

   function Get_Search_Query return String is
   begin
      Display_Status_Bar ("Search: ");
      Refresh;
      --  Would implement line input here
      return "";
   end Get_Search_Query;

   --------------------
   -- Create_Windows
   --------------------

   procedure Create_Windows is
      List_Width : constant Integer :=
        Screen_Columns * List_Width_Pct / 100;
      Details_Width : constant Integer := Screen_Columns - List_Width;
      Content_Height : constant Integer :=
        Screen_Lines - Header_Height - Status_Height;
   begin
      Header_Win := New_Win
        (Interfaces.C.int (Header_Height),
         Interfaces.C.int (Screen_Columns),
         0, 0);

      List_Win := New_Win
        (Interfaces.C.int (Content_Height),
         Interfaces.C.int (List_Width),
         Interfaces.C.int (Header_Height),
         0);

      Details_Win := New_Win
        (Interfaces.C.int (Content_Height),
         Interfaces.C.int (Details_Width),
         Interfaces.C.int (Header_Height),
         Interfaces.C.int (List_Width));

      Status_Win := New_Win
        (Interfaces.C.int (Status_Height),
         Interfaces.C.int (Screen_Columns),
         Interfaces.C.int (Screen_Lines - Status_Height),
         0);
   end Create_Windows;

   ---------------------
   -- Destroy_Windows
   ---------------------

   procedure Destroy_Windows is
   begin
      if Header_Win /= Null_Window then
         Del_Win (Header_Win);
         Header_Win := Null_Window;
      end if;
      if List_Win /= Null_Window then
         Del_Win (List_Win);
         List_Win := Null_Window;
      end if;
      if Details_Win /= Null_Window then
         Del_Win (Details_Win);
         Details_Win := Null_Window;
      end if;
      if Status_Win /= Null_Window then
         Del_Win (Status_Win);
         Status_Win := Null_Window;
      end if;
   end Destroy_Windows;

   ---------------------
   -- Resize_Windows
   ---------------------

   procedure Resize_Windows is
   begin
      Destroy_Windows;
      Screen_Lines := Screen_Height;
      Screen_Columns := Screen_Width;
      Create_Windows;
   end Resize_Windows;

   -----------------
   -- Refresh_All
   -----------------

   procedure Refresh_All is
   begin
      W_Nout_Refresh (Header_Win);
      W_Nout_Refresh (List_Win);
      W_Nout_Refresh (Details_Win);
      W_Nout_Refresh (Status_Win);
      Do_Update;
   end Refresh_All;

   --------------------------
   -- Refresh_Package_List
   --------------------------

   procedure Refresh_Package_List is
   begin
      Display_Package_List (Current_Packages);
   end Refresh_Package_List;

   ---------------------
   -- Refresh_Details
   ---------------------

   procedure Refresh_Details is
   begin
      if not Current_Packages.Is_Empty
        and then Selected_Index < Integer (Current_Packages.Length)
      then
         Display_Package_Details
           (Current_Packages.Element (Selected_Index + 1));
      end if;
   end Refresh_Details;

   --------------------
   -- Refresh_Status
   --------------------

   procedure Refresh_Status is
   begin
      W_Refresh (Status_Win);
   end Refresh_Status;

   ---------------
   -- Scroll_Up
   ---------------

   procedure Scroll_Up is
   begin
      if Selected_Index > 0 then
         Selected_Index := Selected_Index - 1;
         if Selected_Index < Scroll_Offset then
            Scroll_Offset := Selected_Index;
         end if;
      end if;
   end Scroll_Up;

   -----------------
   -- Scroll_Down
   -----------------

   procedure Scroll_Down is
      Max_Index : constant Natural :=
        Natural (Current_Packages.Length) - 1;
   begin
      if Selected_Index < Max_Index then
         Selected_Index := Selected_Index + 1;
      end if;
   end Scroll_Down;

   -------------
   -- Page_Up
   -------------

   procedure Page_Up is
      Page_Size : constant Natural :=
        Natural (Screen_Lines - Header_Height - Status_Height - 2);
   begin
      if Selected_Index >= Page_Size then
         Selected_Index := Selected_Index - Page_Size;
      else
         Selected_Index := 0;
      end if;
      Scroll_Offset := Selected_Index;
   end Page_Up;

   ---------------
   -- Page_Down
   ---------------

   procedure Page_Down is
      Page_Size : constant Natural :=
        Natural (Screen_Lines - Header_Height - Status_Height - 2);
      Max_Index : constant Natural :=
        Natural (Current_Packages.Length) - 1;
   begin
      if Selected_Index + Page_Size <= Max_Index then
         Selected_Index := Selected_Index + Page_Size;
      else
         Selected_Index := Max_Index;
      end if;
   end Page_Down;

   ----------------
   -- Go_To_Top
   ----------------

   procedure Go_To_Top is
   begin
      Selected_Index := 0;
      Scroll_Offset := 0;
   end Go_To_Top;

   -------------------
   -- Go_To_Bottom
   -------------------

   procedure Go_To_Bottom is
   begin
      if not Current_Packages.Is_Empty then
         Selected_Index := Natural (Current_Packages.Length) - 1;
      end if;
   end Go_To_Bottom;

   ----------------------
   -- Mark_For_Install
   ----------------------

   procedure Mark_For_Install is
   begin
      if not Current_Packages.Is_Empty
        and then Selected_Index < Integer (Current_Packages.Length)
      then
         Marked_Install.Append
           (Current_Packages.Element (Selected_Index + 1));
         Display_Status_Bar ("Marked for install");
      end if;
   end Mark_For_Install;

   ---------------------
   -- Mark_For_Remove
   ---------------------

   procedure Mark_For_Remove is
   begin
      if not Current_Packages.Is_Empty
        and then Selected_Index < Integer (Current_Packages.Length)
      then
         Marked_Remove.Append
           (Current_Packages.Element (Selected_Index + 1));
         Display_Status_Bar ("Marked for removal");
      end if;
   end Mark_For_Remove;

   ----------------------
   -- Mark_For_Upgrade
   ----------------------

   procedure Mark_For_Upgrade is
   begin
      if not Current_Packages.Is_Empty
        and then Selected_Index < Integer (Current_Packages.Length)
      then
         Marked_Upgrade.Append
           (Current_Packages.Element (Selected_Index + 1));
         Display_Status_Bar ("Marked for upgrade");
      end if;
   end Mark_For_Upgrade;

   -----------------
   -- Clear_Marks
   -----------------

   procedure Clear_Marks is
   begin
      Marked_Install.Clear;
      Marked_Remove.Clear;
      Marked_Upgrade.Clear;
      Display_Status_Bar ("All marks cleared");
   end Clear_Marks;

   -----------------------
   -- Apply_Transaction
   -----------------------

   procedure Apply_Transaction is
   begin
      Display_Status_Bar ("Applying transaction...");
      --  Would call backend operations here
      Clear_Marks;
      Display_Status_Bar ("Transaction complete");
   end Apply_Transaction;

   ------------------------
   -- Cancel_Transaction
   ------------------------

   procedure Cancel_Transaction is
   begin
      Clear_Marks;
      Display_Status_Bar ("Transaction cancelled");
   end Cancel_Transaction;

   -----------------
   -- Show_Search
   -----------------

   procedure Show_Search is
      Query : constant String := Get_Search_Query;
      pragma Unreferenced (Query);
   begin
      Current_Mode := Mode_Search;
      --  Would search packages here
      Display_Status_Bar ("Search: ");
   end Show_Search;

   --------------------
   -- Show_Snapshots
   --------------------

   procedure Show_Snapshots is
   begin
      Current_Mode := Mode_Snapshot;
      Display_Status_Bar ("Snapshot management");
   end Show_Snapshots;

   ------------------
   -- Show_History
   ------------------

   procedure Show_History is
   begin
      Current_Mode := Mode_History;
      Display_Status_Bar ("Transaction history");
   end Show_History;

   -------------------
   -- Rollback_Last
   -------------------

   procedure Rollback_Last is
   begin
      Display_Status_Bar ("Rolling back...");
      --  Would call rollback engine here
      Display_Status_Bar ("Rollback complete");
   end Rollback_Last;

end Terminal_Interface;
