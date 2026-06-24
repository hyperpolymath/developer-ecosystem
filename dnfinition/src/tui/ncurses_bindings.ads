-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- NCurses_Bindings - Thin Ada bindings to ncurses library
pragma Ada_2022;

with Interfaces.C;
with Interfaces.C.Strings;

package NCurses_Bindings is

   --  Window type (opaque pointer)
   type Window_Ptr is new System.Address;

   Null_Window : constant Window_Ptr :=
     Window_Ptr (System.Null_Address);

   --  Standard windows
   Std_Screen : Window_Ptr := Null_Window;

   --  Color pair type
   type Color_Pair is new Interfaces.C.short;

   --  Attribute type
   type Attr_Type is new Interfaces.C.unsigned_long;

   --  Key constants
   Key_Down      : constant := 258;
   Key_Up        : constant := 259;
   Key_Left      : constant := 260;
   Key_Right     : constant := 261;
   Key_Home      : constant := 262;
   Key_Backspace : constant := 263;
   Key_F0        : constant := 264;
   Key_F1        : constant := 265;
   Key_F2        : constant := 266;
   Key_F3        : constant := 267;
   Key_F4        : constant := 268;
   Key_F5        : constant := 269;
   Key_F6        : constant := 270;
   Key_F7        : constant := 271;
   Key_F8        : constant := 272;
   Key_F9        : constant := 273;
   Key_F10       : constant := 274;
   Key_F11       : constant := 275;
   Key_F12       : constant := 276;
   Key_Delete    : constant := 330;
   Key_Insert    : constant := 331;
   Key_Next_Page : constant := 338;
   Key_Prev_Page : constant := 339;
   Key_End       : constant := 360;
   Key_Enter     : constant := 10;
   Key_Escape    : constant := 27;
   Key_Tab       : constant := 9;

   --  Color constants
   Color_Black   : constant := 0;
   Color_Red     : constant := 1;
   Color_Green   : constant := 2;
   Color_Yellow  : constant := 3;
   Color_Blue    : constant := 4;
   Color_Magenta : constant := 5;
   Color_Cyan    : constant := 6;
   Color_White   : constant := 7;

   --  Attribute constants
   A_Normal    : constant Attr_Type := 0;
   A_Standout  : constant Attr_Type := 65536;
   A_Underline : constant Attr_Type := 131072;
   A_Reverse   : constant Attr_Type := 262144;
   A_Blink     : constant Attr_Type := 524288;
   A_Dim       : constant Attr_Type := 1048576;
   A_Bold      : constant Attr_Type := 2097152;

   --  Boolean result type
   subtype C_Bool is Interfaces.C.int;
   OK  : constant C_Bool := 0;
   ERR : constant C_Bool := -1;

   --  Screen initialization and cleanup
   function Init_Screen return Window_Ptr;
   procedure End_Win;
   function Has_Colors return Boolean;
   procedure Start_Color;
   function Can_Change_Color return Boolean;

   --  Window creation and management
   function New_Win
     (Lines, Cols, Begin_Y, Begin_X : Interfaces.C.int)
      return Window_Ptr;
   procedure Del_Win (Win : Window_Ptr);
   function Sub_Win
     (Parent : Window_Ptr;
      Lines, Cols, Begin_Y, Begin_X : Interfaces.C.int)
      return Window_Ptr;
   function Dup_Win (Win : Window_Ptr) return Window_Ptr;

   --  Window refresh
   procedure Refresh;
   procedure W_Refresh (Win : Window_Ptr);
   procedure W_Nout_Refresh (Win : Window_Ptr);
   procedure Do_Update;

   --  Window clear
   procedure Clear;
   procedure W_Clear (Win : Window_Ptr);
   procedure Clr_To_Eol;
   procedure W_Clr_To_Eol (Win : Window_Ptr);
   procedure Clr_To_Bot;
   procedure W_Clr_To_Bot (Win : Window_Ptr);

   --  Cursor movement
   procedure Move (Y, X : Interfaces.C.int);
   procedure W_Move (Win : Window_Ptr; Y, X : Interfaces.C.int);
   procedure Get_YX (Win : Window_Ptr; Y, X : out Interfaces.C.int);
   procedure Get_Max_YX (Win : Window_Ptr; Y, X : out Interfaces.C.int);
   procedure Get_Beg_YX (Win : Window_Ptr; Y, X : out Interfaces.C.int);

   --  Character output
   procedure Add_Ch (Ch : Interfaces.C.int);
   procedure W_Add_Ch (Win : Window_Ptr; Ch : Interfaces.C.int);
   procedure Mv_Add_Ch (Y, X : Interfaces.C.int; Ch : Interfaces.C.int);
   procedure Mv_W_Add_Ch
     (Win : Window_Ptr;
      Y, X : Interfaces.C.int;
      Ch : Interfaces.C.int);

   --  String output
   procedure Add_Str (Str : String);
   procedure W_Add_Str (Win : Window_Ptr; Str : String);
   procedure Mv_Add_Str (Y, X : Interfaces.C.int; Str : String);
   procedure Mv_W_Add_Str
     (Win : Window_Ptr;
      Y, X : Interfaces.C.int;
      Str : String);

   procedure Add_N_Str (Str : String; N : Interfaces.C.int);
   procedure W_Add_N_Str
     (Win : Window_Ptr;
      Str : String;
      N : Interfaces.C.int);

   --  Input
   function Get_Ch return Interfaces.C.int;
   function W_Get_Ch (Win : Window_Ptr) return Interfaces.C.int;
   procedure Ungetch (Ch : Interfaces.C.int);

   --  Input modes
   procedure Cbreak;
   procedure Nocbreak;
   procedure Echo;
   procedure Noecho;
   procedure Raw;
   procedure Noraw;
   procedure Keypad (Win : Window_Ptr; Enable : Boolean);
   procedure Nodelay (Win : Window_Ptr; Enable : Boolean);
   procedure Halfdelay (Tenths : Interfaces.C.int);
   procedure Timeout (Delay_MS : Interfaces.C.int);
   procedure W_Timeout (Win : Window_Ptr; Delay_MS : Interfaces.C.int);

   --  Cursor visibility
   procedure Curs_Set (Visibility : Interfaces.C.int);

   --  Attributes
   procedure Attr_On (Attr : Attr_Type);
   procedure Attr_Off (Attr : Attr_Type);
   procedure Attr_Set (Attr : Attr_Type; Pair : Color_Pair);
   procedure W_Attr_On (Win : Window_Ptr; Attr : Attr_Type);
   procedure W_Attr_Off (Win : Window_Ptr; Attr : Attr_Type);
   procedure W_Attr_Set
     (Win : Window_Ptr;
      Attr : Attr_Type;
      Pair : Color_Pair);

   --  Colors
   procedure Init_Pair
     (Pair : Color_Pair;
      Fg, Bg : Interfaces.C.short);
   function Color_Pair_Attr (Pair : Color_Pair) return Attr_Type;

   --  Box drawing
   procedure Box
     (Win : Window_Ptr;
      Vert_Ch, Horiz_Ch : Interfaces.C.int);
   procedure W_Border
     (Win : Window_Ptr;
      Ls, Rs, Ts, Bs, Tl, Tr, Bl, Br : Interfaces.C.int);
   procedure H_Line
     (Ch : Interfaces.C.int;
      N : Interfaces.C.int);
   procedure V_Line
     (Ch : Interfaces.C.int;
      N : Interfaces.C.int);
   procedure W_H_Line
     (Win : Window_Ptr;
      Ch : Interfaces.C.int;
      N : Interfaces.C.int);
   procedure W_V_Line
     (Win : Window_Ptr;
      Ch : Interfaces.C.int;
      N : Interfaces.C.int);

   --  Screen size
   function Lines return Interfaces.C.int;
   function Cols return Interfaces.C.int;

   --  Miscellaneous
   procedure Beep;
   procedure Flash;

   --  High-level Ada wrappers
   procedure Initialize;
   procedure Finalize;
   procedure Print (Y, X : Integer; Text : String);
   procedure Print_At_Window
     (Win  : Window_Ptr;
      Y, X : Integer;
      Text : String);
   function Get_Key return Integer;
   function Screen_Height return Integer;
   function Screen_Width return Integer;
   procedure Set_Color (Pair : Color_Pair);
   procedure Set_Bold (Enable : Boolean);
   procedure Set_Reverse (Enable : Boolean);
   procedure Draw_Box (Win : Window_Ptr);

private

   use Interfaces.C;
   use Interfaces.C.Strings;

   pragma Import (C, End_Win, "endwin");
   pragma Import (C, Refresh, "refresh");
   pragma Import (C, Clear, "clear");
   pragma Import (C, Cbreak, "cbreak");
   pragma Import (C, Nocbreak, "nocbreak");
   pragma Import (C, Echo, "echo");
   pragma Import (C, Noecho, "noecho");
   pragma Import (C, Raw, "raw");
   pragma Import (C, Noraw, "noraw");
   pragma Import (C, Beep, "beep");
   pragma Import (C, Flash, "flash");
   pragma Import (C, Start_Color, "start_color");
   pragma Import (C, Do_Update, "doupdate");
   pragma Import (C, Clr_To_Eol, "clrtoeol");
   pragma Import (C, Clr_To_Bot, "clrtobot");

end NCurses_Bindings;
