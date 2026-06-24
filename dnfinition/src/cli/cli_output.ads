-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- CLI_Output - Formatted terminal output (nala-style)
--
-- Provides colored, formatted output for the CLI similar to nala's
-- enhanced apt frontend. Supports ANSI colors, Unicode symbols,
-- progress bars, tables, and transaction summaries.
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package CLI_Output is

   ---------------------------------------------------------------------------
   --  ANSI Color Codes
   ---------------------------------------------------------------------------

   --  Reset
   Reset : constant String := ASCII.ESC & "[0m";

   --  Regular colors
   Black   : constant String := ASCII.ESC & "[30m";
   Red     : constant String := ASCII.ESC & "[31m";
   Green   : constant String := ASCII.ESC & "[32m";
   Yellow  : constant String := ASCII.ESC & "[33m";
   Blue    : constant String := ASCII.ESC & "[34m";
   Magenta : constant String := ASCII.ESC & "[35m";
   Cyan    : constant String := ASCII.ESC & "[36m";
   White   : constant String := ASCII.ESC & "[37m";

   --  Bright/bold colors
   Bold       : constant String := ASCII.ESC & "[1m";
   Dim        : constant String := ASCII.ESC & "[2m";
   Italic     : constant String := ASCII.ESC & "[3m";
   Underline  : constant String := ASCII.ESC & "[4m";

   Bright_Black   : constant String := ASCII.ESC & "[90m";
   Bright_Red     : constant String := ASCII.ESC & "[91m";
   Bright_Green   : constant String := ASCII.ESC & "[92m";
   Bright_Yellow  : constant String := ASCII.ESC & "[93m";
   Bright_Blue    : constant String := ASCII.ESC & "[94m";
   Bright_Magenta : constant String := ASCII.ESC & "[95m";
   Bright_Cyan    : constant String := ASCII.ESC & "[96m";
   Bright_White   : constant String := ASCII.ESC & "[97m";

   --  Background colors
   BG_Red     : constant String := ASCII.ESC & "[41m";
   BG_Green   : constant String := ASCII.ESC & "[42m";
   BG_Yellow  : constant String := ASCII.ESC & "[43m";
   BG_Blue    : constant String := ASCII.ESC & "[44m";

   ---------------------------------------------------------------------------
   --  Unicode Symbols (nala-style)
   ---------------------------------------------------------------------------

   Symbol_Check    : constant String := "✓";
   Symbol_Cross    : constant String := "✗";
   Symbol_Arrow    : constant String := "→";
   Symbol_Bullet   : constant String := "•";
   Symbol_Download : constant String := "↓";
   Symbol_Upload   : constant String := "↑";
   Symbol_Package  : constant String := "📦";
   Symbol_Warning  : constant String := "⚠";
   Symbol_Info     : constant String := "ℹ";
   Symbol_Plus     : constant String := "+";
   Symbol_Minus    : constant String := "-";
   Symbol_Block    : constant String := "█";
   Symbol_Light    : constant String := "░";

   ---------------------------------------------------------------------------
   --  Terminal State
   ---------------------------------------------------------------------------

   --  Check if terminal supports colors
   function Supports_Color return Boolean;

   --  Check if terminal supports Unicode
   function Supports_Unicode return Boolean;

   --  Get terminal width
   function Terminal_Width return Positive;

   --  Enable/disable colors globally
   procedure Set_Color_Enabled (Enabled : Boolean);
   function Color_Enabled return Boolean;

   ---------------------------------------------------------------------------
   --  Basic Output
   ---------------------------------------------------------------------------

   --  Print with color (respects color enabled setting)
   procedure Print (Text : String; Color : String := "");
   procedure Print_Line (Text : String; Color : String := "");
   procedure New_Line;

   --  Print to stderr
   procedure Print_Error (Text : String);
   procedure Print_Warning (Text : String);
   procedure Print_Info (Text : String);
   procedure Print_Success (Text : String);

   ---------------------------------------------------------------------------
   --  Formatted Output (nala-style)
   ---------------------------------------------------------------------------

   --  Section header (bold, underlined)
   procedure Print_Header (Text : String);

   --  Subsection
   procedure Print_Subheader (Text : String);

   --  Indented item with bullet
   procedure Print_Item (Text : String; Indent : Natural := 2);

   --  Key-value pair (aligned)
   procedure Print_Field (Key : String; Value : String; Width : Positive := 20);

   --  Separator line
   procedure Print_Separator (Char : Character := '-');

   ---------------------------------------------------------------------------
   --  Package Display (nala-style)
   ---------------------------------------------------------------------------

   type Package_Action is (
      Action_Install,
      Action_Remove,
      Action_Upgrade,
      Action_Downgrade,
      Action_Reinstall,
      Action_Keep,
      Action_Purge,
      Action_Autoremove
   );

   --  Display a package with action indicator
   --  Format: "+ package-name  1.0 → 2.0  (1.2 MB)"
   procedure Print_Package
     (Name        : String;
      Old_Version : String := "";
      New_Version : String := "";
      Size        : String := "";
      Action      : Package_Action := Action_Install);

   --  Display package info (like `nala show`)
   procedure Print_Package_Info
     (Name        : String;
      Version     : String;
      Description : String;
      Size        : String;
      Repository  : String;
      License     : String := "";
      Homepage    : String := "";
      Depends     : String := "");

   ---------------------------------------------------------------------------
   --  Transaction Summary (nala-style)
   ---------------------------------------------------------------------------

   type Transaction_Summary is record
      Installing    : Natural := 0;
      Removing      : Natural := 0;
      Upgrading     : Natural := 0;
      Downgrading   : Natural := 0;
      Reinstalling  : Natural := 0;
      Autoremoving  : Natural := 0;
      Download_Size : Unbounded_String;
      Install_Size  : Unbounded_String;
      Free_Space    : Unbounded_String;
   end record;

   --  Print transaction summary before confirmation
   procedure Print_Transaction_Summary (Summary : Transaction_Summary);

   --  Print confirmation prompt
   --  Returns True if user confirms
   function Confirm_Transaction
     (Prompt  : String := "Do you want to continue?";
      Default : Boolean := True)
      return Boolean;

   ---------------------------------------------------------------------------
   --  Progress Display
   ---------------------------------------------------------------------------

   --  Progress bar
   --  [████████████░░░░░░░░] 60% (1.2 MB/s)
   procedure Print_Progress
     (Current   : Natural;
      Total     : Natural;
      Label     : String := "";
      Show_Speed : Boolean := False;
      Speed     : String := "");

   --  Download progress (nala-style, shows multiple concurrent)
   procedure Print_Download_Progress
     (Package_Name : String;
      Current      : Natural;
      Total        : Natural;
      Speed        : String := "");

   --  Clear current line (for progress updates)
   procedure Clear_Line;

   --  Move cursor up N lines
   procedure Cursor_Up (N : Positive := 1);

   ---------------------------------------------------------------------------
   --  Table Output
   ---------------------------------------------------------------------------

   type Column_Alignment is (Left, Right, Center);

   type Column_Def is record
      Header : Unbounded_String;
      Width  : Natural := 0;  -- 0 = auto
      Align  : Column_Alignment := Left;
   end record;

   type Column_Array is array (Positive range <>) of Column_Def;
   type Row_Array is array (Positive range <>, Positive range <>) of Unbounded_String;

   --  Print a formatted table
   procedure Print_Table
     (Columns : Column_Array;
      Rows    : Row_Array;
      Border  : Boolean := False);

   ---------------------------------------------------------------------------
   --  History Display (nala-style)
   ---------------------------------------------------------------------------

   type History_Entry is record
      ID          : Natural;
      Date        : Unbounded_String;
      Command     : Unbounded_String;
      Altered     : Natural;
      Status      : Unbounded_String;
   end record;

   type History_Array is array (Positive range <>) of History_Entry;

   --  Print transaction history table
   procedure Print_History (Entries : History_Array);

   ---------------------------------------------------------------------------
   --  Search Results (nala-style)
   ---------------------------------------------------------------------------

   type Search_Result is record
      Name        : Unbounded_String;
      Version     : Unbounded_String;
      Repository  : Unbounded_String;
      Description : Unbounded_String;
      Installed   : Boolean := False;
   end record;

   type Search_Results is array (Positive range <>) of Search_Result;

   --  Print search results
   procedure Print_Search_Results (Results : Search_Results);

   ---------------------------------------------------------------------------
   --  Size Formatting
   ---------------------------------------------------------------------------

   --  Format bytes to human readable (1.2 MB, 500 KB, etc.)
   function Format_Size (Bytes : Long_Long_Integer) return String;

   --  Format duration (1m 30s, 2h 15m, etc.)
   function Format_Duration (Seconds : Natural) return String;

private

   Colors_Enabled : Boolean := True;
   Unicode_Enabled : Boolean := True;

end CLI_Output;
