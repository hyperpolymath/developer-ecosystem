-------------------------------------------------------------------------------
-- Techstack Enforcer - Terminal User Interface
-- Fast keyboard-driven TUI for managing the filter list
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_TUI is

   --  ANSI escape codes for styling
   ESC      : constant Character := Character'Val (27);
   Reset    : constant String := ESC & "[0m";
   Bold     : constant String := ESC & "[1m";
   Dim      : constant String := ESC & "[2m";
   Underline : constant String := ESC & "[4m";

   --  Colors
   Red      : constant String := ESC & "[31m";
   Green    : constant String := ESC & "[32m";
   Yellow   : constant String := ESC & "[33m";
   Blue     : constant String := ESC & "[34m";
   Magenta  : constant String := ESC & "[35m";
   Cyan     : constant String := ESC & "[36m";
   White    : constant String := ESC & "[37m";

   --  Background colors
   BG_Red   : constant String := ESC & "[41m";
   BG_Green : constant String := ESC & "[42m";
   BG_Blue  : constant String := ESC & "[44m";

   --  Screen control
   Clear_Screen    : constant String := ESC & "[2J" & ESC & "[H";
   Cursor_Home     : constant String := ESC & "[H";
   Hide_Cursor     : constant String := ESC & "[?25l";
   Show_Cursor     : constant String := ESC & "[?25h";

   --  UI State
   type View_Mode is (Filter_List, Add_Filter, Edit_Filter, Stats, Help, Scan_Repo);

   type TUI_State is record
      Current_View    : View_Mode;
      Selected_Index  : Natural;
      Scroll_Offset   : Natural;
      Screen_Height   : Positive;
      Screen_Width    : Positive;
      Running         : Boolean;
      Status_Message  : String (1 .. 80);
      Status_Len      : Natural;
      Status_Is_Error : Boolean;
   end record;

   --  Initialize TUI state
   procedure Initialize (State : out TUI_State);

   --  Main TUI loop
   procedure Run;

   --  Individual view renderers
   procedure Render_Header (State : TUI_State);
   procedure Render_Filter_List (State : TUI_State);
   procedure Render_Add_Filter (State : in out TUI_State);
   procedure Render_Stats (State : TUI_State);
   procedure Render_Help (State : TUI_State);
   procedure Render_Scan_Repo (State : in out TUI_State);
   procedure Render_Status_Bar (State : TUI_State);
   procedure Render_Mode_Indicator;

   --  Input handling
   procedure Handle_Key (State : in out TUI_State; Key : Character);
   procedure Handle_Filter_List_Key (State : in out TUI_State; Key : Character);

   --  Helper procedures
   procedure Set_Status (State : in out TUI_State; Msg : String; Is_Error : Boolean := False);
   procedure Move_Cursor (Row, Col : Positive);
   function Get_Level_Color (Level : Block_Level) return String;
   function Get_Level_Symbol (Level : Block_Level) return Character;

end Techstack_TUI;
