-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- NCurses_Bindings - Implementation
pragma Ada_2022;

with System;

package body NCurses_Bindings is

   use Interfaces.C;
   use Interfaces.C.Strings;

   --  C function imports
   function C_Initscr return Window_Ptr;
   pragma Import (C, C_Initscr, "initscr");

   function C_Has_Colors return C_Bool;
   pragma Import (C, C_Has_Colors, "has_colors");

   function C_Can_Change_Color return C_Bool;
   pragma Import (C, C_Can_Change_Color, "can_change_color");

   function C_Newwin
     (Lines, Cols, Begin_Y, Begin_X : int)
      return Window_Ptr;
   pragma Import (C, C_Newwin, "newwin");

   procedure C_Delwin (Win : Window_Ptr);
   pragma Import (C, C_Delwin, "delwin");

   function C_Subwin
     (Parent : Window_Ptr;
      Lines, Cols, Begin_Y, Begin_X : int)
      return Window_Ptr;
   pragma Import (C, C_Subwin, "subwin");

   function C_Dupwin (Win : Window_Ptr) return Window_Ptr;
   pragma Import (C, C_Dupwin, "dupwin");

   procedure C_Wrefresh (Win : Window_Ptr);
   pragma Import (C, C_Wrefresh, "wrefresh");

   procedure C_Wnoutrefresh (Win : Window_Ptr);
   pragma Import (C, C_Wnoutrefresh, "wnoutrefresh");

   procedure C_Wclear (Win : Window_Ptr);
   pragma Import (C, C_Wclear, "wclear");

   procedure C_Wclrtoeol (Win : Window_Ptr);
   pragma Import (C, C_Wclrtoeol, "wclrtoeol");

   procedure C_Wclrtobot (Win : Window_Ptr);
   pragma Import (C, C_Wclrtobot, "wclrtobot");

   procedure C_Move (Y, X : int);
   pragma Import (C, C_Move, "move");

   procedure C_Wmove (Win : Window_Ptr; Y, X : int);
   pragma Import (C, C_Wmove, "wmove");

   function C_Getch return int;
   pragma Import (C, C_Getch, "getch");

   function C_Wgetch (Win : Window_Ptr) return int;
   pragma Import (C, C_Wgetch, "wgetch");

   procedure C_Ungetch (Ch : int);
   pragma Import (C, C_Ungetch, "ungetch");

   procedure C_Keypad (Win : Window_Ptr; Bf : C_Bool);
   pragma Import (C, C_Keypad, "keypad");

   procedure C_Nodelay (Win : Window_Ptr; Bf : C_Bool);
   pragma Import (C, C_Nodelay, "nodelay");

   procedure C_Halfdelay (Tenths : int);
   pragma Import (C, C_Halfdelay, "halfdelay");

   procedure C_Timeout (Delay_MS : int);
   pragma Import (C, C_Timeout, "timeout");

   procedure C_Wtimeout (Win : Window_Ptr; Delay_MS : int);
   pragma Import (C, C_Wtimeout, "wtimeout");

   procedure C_Curs_Set (Visibility : int);
   pragma Import (C, C_Curs_Set, "curs_set");

   procedure C_Attron (Attr : unsigned_long);
   pragma Import (C, C_Attron, "attron");

   procedure C_Attroff (Attr : unsigned_long);
   pragma Import (C, C_Attroff, "attroff");

   procedure C_Wattron (Win : Window_Ptr; Attr : unsigned_long);
   pragma Import (C, C_Wattron, "wattron");

   procedure C_Wattroff (Win : Window_Ptr; Attr : unsigned_long);
   pragma Import (C, C_Wattroff, "wattroff");

   procedure C_Init_Pair (Pair : short; Fg, Bg : short);
   pragma Import (C, C_Init_Pair, "init_pair");

   function C_Color_Pair (Pair : short) return unsigned_long;
   pragma Import (C, C_Color_Pair, "COLOR_PAIR");

   procedure C_Box (Win : Window_Ptr; Vert, Horiz : int);
   pragma Import (C, C_Box, "box");

   procedure C_Wborder
     (Win : Window_Ptr;
      Ls, Rs, Ts, Bs, Tl, Tr, Bl, Br : int);
   pragma Import (C, C_Wborder, "wborder");

   procedure C_Hline (Ch : int; N : int);
   pragma Import (C, C_Hline, "hline");

   procedure C_Vline (Ch : int; N : int);
   pragma Import (C, C_Vline, "vline");

   procedure C_Whline (Win : Window_Ptr; Ch : int; N : int);
   pragma Import (C, C_Whline, "whline");

   procedure C_Wvline (Win : Window_Ptr; Ch : int; N : int);
   pragma Import (C, C_Wvline, "wvline");

   procedure C_Addch (Ch : int);
   pragma Import (C, C_Addch, "addch");

   procedure C_Waddch (Win : Window_Ptr; Ch : int);
   pragma Import (C, C_Waddch, "waddch");

   procedure C_Mvaddch (Y, X : int; Ch : int);
   pragma Import (C, C_Mvaddch, "mvaddch");

   procedure C_Mvwaddch (Win : Window_Ptr; Y, X : int; Ch : int);
   pragma Import (C, C_Mvwaddch, "mvwaddch");

   procedure C_Addstr (Str : chars_ptr);
   pragma Import (C, C_Addstr, "addstr");

   procedure C_Waddstr (Win : Window_Ptr; Str : chars_ptr);
   pragma Import (C, C_Waddstr, "waddstr");

   procedure C_Mvaddstr (Y, X : int; Str : chars_ptr);
   pragma Import (C, C_Mvaddstr, "mvaddstr");

   procedure C_Mvwaddstr (Win : Window_Ptr; Y, X : int; Str : chars_ptr);
   pragma Import (C, C_Mvwaddstr, "mvwaddstr");

   procedure C_Addnstr (Str : chars_ptr; N : int);
   pragma Import (C, C_Addnstr, "addnstr");

   procedure C_Waddnstr (Win : Window_Ptr; Str : chars_ptr; N : int);
   pragma Import (C, C_Waddnstr, "waddnstr");

   function C_Lines return int;
   pragma Import (C, C_Lines, "LINES");

   function C_Cols return int;
   pragma Import (C, C_Cols, "COLS");

   --  Helper for null-terminated strings
   function To_C_String (S : String) return chars_ptr is
   begin
      return New_String (S);
   end To_C_String;

   -----------------
   -- Init_Screen
   -----------------

   function Init_Screen return Window_Ptr is
   begin
      Std_Screen := C_Initscr;
      return Std_Screen;
   end Init_Screen;

   ----------------
   -- Has_Colors
   ----------------

   function Has_Colors return Boolean is
   begin
      return C_Has_Colors = OK;
   end Has_Colors;

   ----------------------
   -- Can_Change_Color
   ----------------------

   function Can_Change_Color return Boolean is
   begin
      return C_Can_Change_Color = OK;
   end Can_Change_Color;

   -------------
   -- New_Win
   -------------

   function New_Win
     (Lines, Cols, Begin_Y, Begin_X : int)
      return Window_Ptr
   is
   begin
      return C_Newwin (Lines, Cols, Begin_Y, Begin_X);
   end New_Win;

   -------------
   -- Del_Win
   -------------

   procedure Del_Win (Win : Window_Ptr) is
   begin
      C_Delwin (Win);
   end Del_Win;

   -------------
   -- Sub_Win
   -------------

   function Sub_Win
     (Parent : Window_Ptr;
      Lines, Cols, Begin_Y, Begin_X : int)
      return Window_Ptr
   is
   begin
      return C_Subwin (Parent, Lines, Cols, Begin_Y, Begin_X);
   end Sub_Win;

   -------------
   -- Dup_Win
   -------------

   function Dup_Win (Win : Window_Ptr) return Window_Ptr is
   begin
      return C_Dupwin (Win);
   end Dup_Win;

   ---------------
   -- W_Refresh
   ---------------

   procedure W_Refresh (Win : Window_Ptr) is
   begin
      C_Wrefresh (Win);
   end W_Refresh;

   --------------------
   -- W_Nout_Refresh
   --------------------

   procedure W_Nout_Refresh (Win : Window_Ptr) is
   begin
      C_Wnoutrefresh (Win);
   end W_Nout_Refresh;

   -------------
   -- W_Clear
   -------------

   procedure W_Clear (Win : Window_Ptr) is
   begin
      C_Wclear (Win);
   end W_Clear;

   ------------------
   -- W_Clr_To_Eol
   ------------------

   procedure W_Clr_To_Eol (Win : Window_Ptr) is
   begin
      C_Wclrtoeol (Win);
   end W_Clr_To_Eol;

   ------------------
   -- W_Clr_To_Bot
   ------------------

   procedure W_Clr_To_Bot (Win : Window_Ptr) is
   begin
      C_Wclrtobot (Win);
   end W_Clr_To_Bot;

   ----------
   -- Move
   ----------

   procedure Move (Y, X : int) is
   begin
      C_Move (Y, X);
   end Move;

   ------------
   -- W_Move
   ------------

   procedure W_Move (Win : Window_Ptr; Y, X : int) is
   begin
      C_Wmove (Win, Y, X);
   end W_Move;

   ------------
   -- Get_YX
   ------------

   procedure Get_YX (Win : Window_Ptr; Y, X : out int) is
      pragma Unreferenced (Win);
   begin
      Y := 0;
      X := 0;
      --  Would use getyx macro
   end Get_YX;

   ----------------
   -- Get_Max_YX
   ----------------

   procedure Get_Max_YX (Win : Window_Ptr; Y, X : out int) is
      pragma Unreferenced (Win);
   begin
      Y := C_Lines;
      X := C_Cols;
   end Get_Max_YX;

   ----------------
   -- Get_Beg_YX
   ----------------

   procedure Get_Beg_YX (Win : Window_Ptr; Y, X : out int) is
      pragma Unreferenced (Win);
   begin
      Y := 0;
      X := 0;
   end Get_Beg_YX;

   ------------
   -- Add_Ch
   ------------

   procedure Add_Ch (Ch : int) is
   begin
      C_Addch (Ch);
   end Add_Ch;

   --------------
   -- W_Add_Ch
   --------------

   procedure W_Add_Ch (Win : Window_Ptr; Ch : int) is
   begin
      C_Waddch (Win, Ch);
   end W_Add_Ch;

   ---------------
   -- Mv_Add_Ch
   ---------------

   procedure Mv_Add_Ch (Y, X : int; Ch : int) is
   begin
      C_Mvaddch (Y, X, Ch);
   end Mv_Add_Ch;

   -----------------
   -- Mv_W_Add_Ch
   -----------------

   procedure Mv_W_Add_Ch
     (Win : Window_Ptr;
      Y, X : int;
      Ch : int)
   is
   begin
      C_Mvwaddch (Win, Y, X, Ch);
   end Mv_W_Add_Ch;

   -------------
   -- Add_Str
   -------------

   procedure Add_Str (Str : String) is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Addstr (C_Str);
      Free (C_Str);
   end Add_Str;

   ---------------
   -- W_Add_Str
   ---------------

   procedure W_Add_Str (Win : Window_Ptr; Str : String) is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Waddstr (Win, C_Str);
      Free (C_Str);
   end W_Add_Str;

   ----------------
   -- Mv_Add_Str
   ----------------

   procedure Mv_Add_Str (Y, X : int; Str : String) is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Mvaddstr (Y, X, C_Str);
      Free (C_Str);
   end Mv_Add_Str;

   ------------------
   -- Mv_W_Add_Str
   ------------------

   procedure Mv_W_Add_Str
     (Win : Window_Ptr;
      Y, X : int;
      Str : String)
   is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Mvwaddstr (Win, Y, X, C_Str);
      Free (C_Str);
   end Mv_W_Add_Str;

   ---------------
   -- Add_N_Str
   ---------------

   procedure Add_N_Str (Str : String; N : int) is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Addnstr (C_Str, N);
      Free (C_Str);
   end Add_N_Str;

   -----------------
   -- W_Add_N_Str
   -----------------

   procedure W_Add_N_Str
     (Win : Window_Ptr;
      Str : String;
      N : int)
   is
      C_Str : chars_ptr := To_C_String (Str);
   begin
      C_Waddnstr (Win, C_Str, N);
      Free (C_Str);
   end W_Add_N_Str;

   ------------
   -- Get_Ch
   ------------

   function Get_Ch return int is
   begin
      return C_Getch;
   end Get_Ch;

   --------------
   -- W_Get_Ch
   --------------

   function W_Get_Ch (Win : Window_Ptr) return int is
   begin
      return C_Wgetch (Win);
   end W_Get_Ch;

   -------------
   -- Ungetch
   -------------

   procedure Ungetch (Ch : int) is
   begin
      C_Ungetch (Ch);
   end Ungetch;

   ------------
   -- Keypad
   ------------

   procedure Keypad (Win : Window_Ptr; Enable : Boolean) is
   begin
      C_Keypad (Win, (if Enable then 1 else 0));
   end Keypad;

   -------------
   -- Nodelay
   -------------

   procedure Nodelay (Win : Window_Ptr; Enable : Boolean) is
   begin
      C_Nodelay (Win, (if Enable then 1 else 0));
   end Nodelay;

   ---------------
   -- Halfdelay
   ---------------

   procedure Halfdelay (Tenths : int) is
   begin
      C_Halfdelay (Tenths);
   end Halfdelay;

   -------------
   -- Timeout
   -------------

   procedure Timeout (Delay_MS : int) is
   begin
      C_Timeout (Delay_MS);
   end Timeout;

   ---------------
   -- W_Timeout
   ---------------

   procedure W_Timeout (Win : Window_Ptr; Delay_MS : int) is
   begin
      C_Wtimeout (Win, Delay_MS);
   end W_Timeout;

   --------------
   -- Curs_Set
   --------------

   procedure Curs_Set (Visibility : int) is
   begin
      C_Curs_Set (Visibility);
   end Curs_Set;

   -------------
   -- Attr_On
   -------------

   procedure Attr_On (Attr : Attr_Type) is
   begin
      C_Attron (unsigned_long (Attr));
   end Attr_On;

   --------------
   -- Attr_Off
   --------------

   procedure Attr_Off (Attr : Attr_Type) is
   begin
      C_Attroff (unsigned_long (Attr));
   end Attr_Off;

   --------------
   -- Attr_Set
   --------------

   procedure Attr_Set (Attr : Attr_Type; Pair : Color_Pair) is
      pragma Unreferenced (Pair);
   begin
      C_Attron (unsigned_long (Attr));
   end Attr_Set;

   ---------------
   -- W_Attr_On
   ---------------

   procedure W_Attr_On (Win : Window_Ptr; Attr : Attr_Type) is
   begin
      C_Wattron (Win, unsigned_long (Attr));
   end W_Attr_On;

   ----------------
   -- W_Attr_Off
   ----------------

   procedure W_Attr_Off (Win : Window_Ptr; Attr : Attr_Type) is
   begin
      C_Wattroff (Win, unsigned_long (Attr));
   end W_Attr_Off;

   ----------------
   -- W_Attr_Set
   ----------------

   procedure W_Attr_Set
     (Win : Window_Ptr;
      Attr : Attr_Type;
      Pair : Color_Pair)
   is
      pragma Unreferenced (Pair);
   begin
      C_Wattron (Win, unsigned_long (Attr));
   end W_Attr_Set;

   ---------------
   -- Init_Pair
   ---------------

   procedure Init_Pair
     (Pair : Color_Pair;
      Fg, Bg : short)
   is
   begin
      C_Init_Pair (short (Pair), Fg, Bg);
   end Init_Pair;

   ----------------------
   -- Color_Pair_Attr
   ----------------------

   function Color_Pair_Attr (Pair : Color_Pair) return Attr_Type is
   begin
      return Attr_Type (C_Color_Pair (short (Pair)));
   end Color_Pair_Attr;

   ---------
   -- Box
   ---------

   procedure Box
     (Win : Window_Ptr;
      Vert_Ch, Horiz_Ch : int)
   is
   begin
      C_Box (Win, Vert_Ch, Horiz_Ch);
   end Box;

   --------------
   -- W_Border
   --------------

   procedure W_Border
     (Win : Window_Ptr;
      Ls, Rs, Ts, Bs, Tl, Tr, Bl, Br : int)
   is
   begin
      C_Wborder (Win, Ls, Rs, Ts, Bs, Tl, Tr, Bl, Br);
   end W_Border;

   ------------
   -- H_Line
   ------------

   procedure H_Line (Ch : int; N : int) is
   begin
      C_Hline (Ch, N);
   end H_Line;

   ------------
   -- V_Line
   ------------

   procedure V_Line (Ch : int; N : int) is
   begin
      C_Vline (Ch, N);
   end V_Line;

   --------------
   -- W_H_Line
   --------------

   procedure W_H_Line
     (Win : Window_Ptr;
      Ch : int;
      N : int)
   is
   begin
      C_Whline (Win, Ch, N);
   end W_H_Line;

   --------------
   -- W_V_Line
   --------------

   procedure W_V_Line
     (Win : Window_Ptr;
      Ch : int;
      N : int)
   is
   begin
      C_Wvline (Win, Ch, N);
   end W_V_Line;

   -----------
   -- Lines
   -----------

   function Lines return int is
   begin
      return C_Lines;
   end Lines;

   ----------
   -- Cols
   ----------

   function Cols return int is
   begin
      return C_Cols;
   end Cols;

   --  High-level Ada wrappers

   ----------------
   -- Initialize
   ----------------

   procedure Initialize is
   begin
      Std_Screen := Init_Screen;
      Cbreak;
      Noecho;
      Keypad (Std_Screen, True);
      Curs_Set (0);  --  Hide cursor

      if Has_Colors then
         Start_Color;
         --  Initialize standard color pairs
         Init_Pair (1, Color_White, Color_Blue);    --  Normal
         Init_Pair (2, Color_Black, Color_Cyan);    --  Selected
         Init_Pair (3, Color_Yellow, Color_Blue);   --  Highlight
         Init_Pair (4, Color_Red, Color_Blue);      --  Error
         Init_Pair (5, Color_Green, Color_Blue);    --  Success
         Init_Pair (6, Color_White, Color_Black);   --  Default
      end if;
   end Initialize;

   --------------
   -- Finalize
   --------------

   procedure Finalize is
   begin
      End_Win;
   end Finalize;

   -----------
   -- Print
   -----------

   procedure Print (Y, X : Integer; Text : String) is
   begin
      Mv_Add_Str (int (Y), int (X), Text);
   end Print;

   ----------------------
   -- Print_At_Window
   ----------------------

   procedure Print_At_Window
     (Win  : Window_Ptr;
      Y, X : Integer;
      Text : String)
   is
   begin
      Mv_W_Add_Str (Win, int (Y), int (X), Text);
   end Print_At_Window;

   -------------
   -- Get_Key
   -------------

   function Get_Key return Integer is
   begin
      return Integer (Get_Ch);
   end Get_Key;

   -------------------
   -- Screen_Height
   -------------------

   function Screen_Height return Integer is
   begin
      return Integer (Lines);
   end Screen_Height;

   ------------------
   -- Screen_Width
   ------------------

   function Screen_Width return Integer is
   begin
      return Integer (Cols);
   end Screen_Width;

   ---------------
   -- Set_Color
   ---------------

   procedure Set_Color (Pair : Color_Pair) is
   begin
      Attr_On (Color_Pair_Attr (Pair));
   end Set_Color;

   --------------
   -- Set_Bold
   --------------

   procedure Set_Bold (Enable : Boolean) is
   begin
      if Enable then
         Attr_On (A_Bold);
      else
         Attr_Off (A_Bold);
      end if;
   end Set_Bold;

   -----------------
   -- Set_Reverse
   -----------------

   procedure Set_Reverse (Enable : Boolean) is
   begin
      if Enable then
         Attr_On (A_Reverse);
      else
         Attr_Off (A_Reverse);
      end if;
   end Set_Reverse;

   --------------
   -- Draw_Box
   --------------

   procedure Draw_Box (Win : Window_Ptr) is
   begin
      Box (Win, 0, 0);
   end Draw_Box;

end NCurses_Bindings;
