-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Terminal_Interface - Main TUI framework for DNFinition
pragma Ada_2022;

with NCurses_Bindings; use NCurses_Bindings;
with Package_Types;    use Package_Types;
with Transaction_Types; use Transaction_Types;

package Terminal_Interface is

   --  UI Mode
   type UI_Mode is (
      Mode_Browse,        --  Browse packages
      Mode_Search,        --  Search for packages
      Mode_Transaction,   --  View transaction preview
      Mode_Snapshot,      --  Manage snapshots
      Mode_History,       --  View transaction history
      Mode_Help           --  Show help
   );

   --  Initialize the TUI
   procedure Initialize;

   --  Finalize the TUI
   procedure Finalize;

   --  Main event loop
   procedure Run;

   --  Display functions
   procedure Display_Package_List (Packages : Package_Array);
   procedure Display_Package_Details (Package : Package_Info);
   procedure Display_Transaction_Preview (Trans : Transaction_Info);
   procedure Display_Status_Bar (Message : String);
   procedure Display_Header;
   procedure Display_Help;

   --  Input handling
   function Get_User_Input return Integer;
   function Confirm_Action (Prompt : String) return Boolean;
   function Get_Search_Query return String;

   --  Window management
   procedure Create_Windows;
   procedure Destroy_Windows;
   procedure Resize_Windows;

   --  Refresh display
   procedure Refresh_All;
   procedure Refresh_Package_List;
   procedure Refresh_Details;
   procedure Refresh_Status;

   --  Navigation
   procedure Scroll_Up;
   procedure Scroll_Down;
   procedure Page_Up;
   procedure Page_Down;
   procedure Go_To_Top;
   procedure Go_To_Bottom;

   --  Package marking
   procedure Mark_For_Install;
   procedure Mark_For_Remove;
   procedure Mark_For_Upgrade;
   procedure Clear_Marks;

   --  Actions
   procedure Apply_Transaction;
   procedure Cancel_Transaction;
   procedure Show_Search;
   procedure Show_Snapshots;
   procedure Show_History;
   procedure Rollback_Last;

private

   --  Window handles
   Header_Win    : Window_Ptr := Null_Window;
   List_Win      : Window_Ptr := Null_Window;
   Details_Win   : Window_Ptr := Null_Window;
   Status_Win    : Window_Ptr := Null_Window;

   --  UI state
   Current_Mode    : UI_Mode := Mode_Browse;
   Selected_Index  : Natural := 0;
   Scroll_Offset   : Natural := 0;
   Current_Packages : Package_Array;
   Marked_Install  : Package_Array;
   Marked_Remove   : Package_Array;
   Marked_Upgrade  : Package_Array;

   --  Screen dimensions
   Screen_Lines : Integer := 24;
   Screen_Columns : Integer := 80;

   --  Layout constants
   Header_Height  : constant := 3;
   Status_Height  : constant := 2;
   List_Width_Pct : constant := 40;  --  40% of screen width

end Terminal_Interface;
