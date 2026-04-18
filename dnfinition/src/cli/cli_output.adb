-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- CLI_Output - Implementation
pragma Ada_2022;

with Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;

package body CLI_Output is

   use Ada.Text_IO;
   use Ada.Strings.Fixed;

   ---------------------------------------------------------------------------
   --  Terminal Detection
   ---------------------------------------------------------------------------

   function Supports_Color return Boolean is
      Term : constant String := Ada.Environment_Variables.Value ("TERM", "");
      No_Color : constant Boolean :=
        Ada.Environment_Variables.Exists ("NO_COLOR");
   begin
      if No_Color then
         return False;
      end if;

      --  Check for common color-supporting terminals
      return Term /= ""
        and then Term /= "dumb"
        and then (Index (Term, "color") > 0
                  or else Index (Term, "xterm") > 0
                  or else Index (Term, "screen") > 0
                  or else Index (Term, "tmux") > 0
                  or else Index (Term, "vt100") > 0
                  or else Index (Term, "linux") > 0
                  or else Term = "alacritty"
                  or else Term = "kitty");
   end Supports_Color;

   function Supports_Unicode return Boolean is
      Lang : constant String := Ada.Environment_Variables.Value ("LANG", "");
   begin
      return Index (Lang, "UTF-8") > 0
        or else Index (Lang, "utf8") > 0
        or else Index (Lang, "UTF8") > 0;
   end Supports_Unicode;

   function Terminal_Width return Positive is
      Columns : constant String :=
        Ada.Environment_Variables.Value ("COLUMNS", "80");
   begin
      return Positive'Value (Columns);
   exception
      when others => return 80;
   end Terminal_Width;

   procedure Set_Color_Enabled (Enabled : Boolean) is
   begin
      Colors_Enabled := Enabled and then Supports_Color;
   end Set_Color_Enabled;

   function Color_Enabled return Boolean is
   begin
      return Colors_Enabled and then Supports_Color;
   end Color_Enabled;

   ---------------------------------------------------------------------------
   --  Basic Output
   ---------------------------------------------------------------------------

   procedure Print (Text : String; Color : String := "") is
   begin
      if Color_Enabled and then Color /= "" then
         Put (Color & Text & Reset);
      else
         Put (Text);
      end if;
   end Print;

   procedure Print_Line (Text : String; Color : String := "") is
   begin
      if Color_Enabled and then Color /= "" then
         Put_Line (Color & Text & Reset);
      else
         Put_Line (Text);
      end if;
   end Print_Line;

   procedure New_Line is
   begin
      Ada.Text_IO.New_Line;
   end New_Line;

   procedure Print_Error (Text : String) is
   begin
      Put (Standard_Error, Red & Bold & Symbol_Cross & " Error: " & Reset);
      Put_Line (Standard_Error, Red & Text & Reset);
   end Print_Error;

   procedure Print_Warning (Text : String) is
   begin
      Put (Standard_Error, Yellow & Bold & Symbol_Warning & " Warning: " & Reset);
      Put_Line (Standard_Error, Yellow & Text & Reset);
   end Print_Warning;

   procedure Print_Info (Text : String) is
   begin
      Put (Cyan & Bold & Symbol_Info & " " & Reset);
      Put_Line (Text);
   end Print_Info;

   procedure Print_Success (Text : String) is
   begin
      Put (Green & Bold & Symbol_Check & " " & Reset);
      Put_Line (Green & Text & Reset);
   end Print_Success;

   ---------------------------------------------------------------------------
   --  Formatted Output
   ---------------------------------------------------------------------------

   procedure Print_Header (Text : String) is
   begin
      New_Line;
      Print_Line (Bold & Underline & Text & Reset);
   end Print_Header;

   procedure Print_Subheader (Text : String) is
   begin
      Print_Line (Bold & Text & Reset);
   end Print_Subheader;

   procedure Print_Item (Text : String; Indent : Natural := 2) is
      Prefix : constant String (1 .. Indent) := (others => ' ');
   begin
      if Supports_Unicode then
         Print_Line (Prefix & Cyan & Symbol_Bullet & Reset & " " & Text);
      else
         Print_Line (Prefix & Cyan & "*" & Reset & " " & Text);
      end if;
   end Print_Item;

   procedure Print_Field (Key : String; Value : String; Width : Positive := 20) is
      Padded_Key : constant String := Head (Key & ":", Width);
   begin
      Print (Bright_Black & Padded_Key & Reset);
      Print_Line (" " & Value);
   end Print_Field;

   procedure Print_Separator (Char : Character := '-') is
      Width : constant Positive := Terminal_Width;
      Line  : constant String (1 .. Width) := (others => Char);
   begin
      Print_Line (Bright_Black & Line & Reset);
   end Print_Separator;

   ---------------------------------------------------------------------------
   --  Package Display
   ---------------------------------------------------------------------------

   procedure Print_Package
     (Name        : String;
      Old_Version : String := "";
      New_Version : String := "";
      Size        : String := "";
      Action      : Package_Action := Action_Install)
   is
      Action_Symbol : constant String :=
        (case Action is
            when Action_Install   => Green & Symbol_Plus,
            when Action_Remove    => Red & Symbol_Minus,
            when Action_Upgrade   => Blue & Symbol_Arrow,
            when Action_Downgrade => Yellow & Symbol_Arrow,
            when Action_Reinstall => Cyan & "~",
            when Action_Keep      => Bright_Black & "=",
            when Action_Purge     => Red & Bold & Symbol_Minus,
            when Action_Autoremove => Bright_Black & Symbol_Minus);
   begin
      Print (Action_Symbol & Reset & " ");
      Print (Bold & Name & Reset);

      if Old_Version /= "" and then New_Version /= "" then
         Print ("  " & Dim & Old_Version & Reset);
         Print (" " & Symbol_Arrow & " ");
         Print (Bright_Green & New_Version & Reset);
      elsif New_Version /= "" then
         Print ("  " & Bright_Green & New_Version & Reset);
      elsif Old_Version /= "" then
         Print ("  " & Dim & Old_Version & Reset);
      end if;

      if Size /= "" then
         Print ("  " & Bright_Black & "(" & Size & ")" & Reset);
      end if;

      New_Line;
   end Print_Package;

   procedure Print_Package_Info
     (Name        : String;
      Version     : String;
      Description : String;
      Size        : String;
      Repository  : String;
      License     : String := "";
      Homepage    : String := "";
      Depends     : String := "")
   is
   begin
      Print_Header (Symbol_Package & " " & Name);
      Print_Field ("Version", Version);
      Print_Field ("Size", Size);
      Print_Field ("Repository", Repository);
      if License /= "" then
         Print_Field ("License", License);
      end if;
      if Homepage /= "" then
         Print_Field ("Homepage", Cyan & Underline & Homepage & Reset);
      end if;
      New_Line;
      Print_Subheader ("Description:");
      Print_Line ("  " & Description);
      if Depends /= "" then
         New_Line;
         Print_Subheader ("Dependencies:");
         Print_Line ("  " & Depends);
      end if;
   end Print_Package_Info;

   ---------------------------------------------------------------------------
   --  Transaction Summary
   ---------------------------------------------------------------------------

   procedure Print_Transaction_Summary (Summary : Transaction_Summary) is
   begin
      Print_Header ("Transaction Summary");

      if Summary.Installing > 0 then
         Print (Green & "  " & Summary.Installing'Image & Reset);
         Print_Line (" package(s) will be " & Green & "installed" & Reset);
      end if;

      if Summary.Removing > 0 then
         Print (Red & "  " & Summary.Removing'Image & Reset);
         Print_Line (" package(s) will be " & Red & "removed" & Reset);
      end if;

      if Summary.Upgrading > 0 then
         Print (Blue & "  " & Summary.Upgrading'Image & Reset);
         Print_Line (" package(s) will be " & Blue & "upgraded" & Reset);
      end if;

      if Summary.Downgrading > 0 then
         Print (Yellow & "  " & Summary.Downgrading'Image & Reset);
         Print_Line (" package(s) will be " & Yellow & "downgraded" & Reset);
      end if;

      if Summary.Reinstalling > 0 then
         Print (Cyan & "  " & Summary.Reinstalling'Image & Reset);
         Print_Line (" package(s) will be " & Cyan & "reinstalled" & Reset);
      end if;

      if Summary.Autoremoving > 0 then
         Print (Bright_Black & "  " & Summary.Autoremoving'Image & Reset);
         Print_Line (" package(s) will be " & Bright_Black & "auto-removed" & Reset);
      end if;

      New_Line;
      if Length (Summary.Download_Size) > 0 then
         Print_Field ("Download size", To_String (Summary.Download_Size));
      end if;
      if Length (Summary.Install_Size) > 0 then
         Print_Field ("Installed size", To_String (Summary.Install_Size));
      end if;
      if Length (Summary.Free_Space) > 0 then
         Print_Field ("Free space after", To_String (Summary.Free_Space));
      end if;
   end Print_Transaction_Summary;

   function Confirm_Transaction
     (Prompt  : String := "Do you want to continue?";
      Default : Boolean := True)
      return Boolean
   is
      Default_Hint : constant String :=
        (if Default then "[Y/n]" else "[y/N]");
      Response : String (1 .. 10);
      Last     : Natural;
   begin
      New_Line;
      Print (Bold & Prompt & Reset & " " & Default_Hint & " ");
      Flush;

      Get_Line (Response, Last);

      if Last = 0 then
         return Default;
      end if;

      declare
         R : constant Character := Response (1);
      begin
         return R = 'y' or R = 'Y';
      end;
   end Confirm_Transaction;

   ---------------------------------------------------------------------------
   --  Progress Display
   ---------------------------------------------------------------------------

   procedure Print_Progress
     (Current    : Natural;
      Total      : Natural;
      Label      : String := "";
      Show_Speed : Boolean := False;
      Speed      : String := "")
   is
      Width      : constant Positive := 30;
      Percentage : constant Natural :=
        (if Total > 0 then (Current * 100) / Total else 0);
      Filled     : constant Natural := (Percentage * Width) / 100;
      Empty      : constant Natural := Width - Filled;
      Bar_Filled : constant String (1 .. Filled) := (others => '#');
      Bar_Empty  : constant String (1 .. Empty) := (others => '-');
   begin
      Clear_Line;
      Print ("[" & Green & Bar_Filled & Reset & Bright_Black & Bar_Empty & Reset & "] ");
      Print (Percentage'Image & "%");

      if Label /= "" then
         Print (" " & Label);
      end if;

      if Show_Speed and then Speed /= "" then
         Print (" (" & Cyan & Speed & Reset & ")");
      end if;

      Flush;
   end Print_Progress;

   procedure Print_Download_Progress
     (Package_Name : String;
      Current      : Natural;
      Total        : Natural;
      Speed        : String := "")
   is
   begin
      Clear_Line;
      Print (Cyan & Symbol_Download & Reset & " ");
      Print (Bold & Package_Name & Reset & " ");
      Print_Progress (Current, Total, "", True, Speed);
   end Print_Download_Progress;

   procedure Clear_Line is
   begin
      Put (ASCII.ESC & "[2K" & ASCII.CR);
   end Clear_Line;

   procedure Cursor_Up (N : Positive := 1) is
   begin
      Put (ASCII.ESC & "[" & Trim (N'Image, Ada.Strings.Left) & "A");
   end Cursor_Up;

   ---------------------------------------------------------------------------
   --  Table Output
   ---------------------------------------------------------------------------

   procedure Print_Table
     (Columns : Column_Array;
      Rows    : Row_Array;
      Border  : Boolean := False)
   is
      pragma Unreferenced (Border);
      Col_Widths : array (Columns'Range) of Natural := (others => 0);
   begin
      --  Calculate column widths
      for I in Columns'Range loop
         Col_Widths (I) := Length (Columns (I).Header);
      end loop;

      for R in Rows'Range (1) loop
         for C in Rows'Range (2) loop
            if C in Columns'Range then
               Col_Widths (C) := Natural'Max (Col_Widths (C), Length (Rows (R, C)));
            end if;
         end loop;
      end loop;

      --  Print header
      for I in Columns'Range loop
         Print (Bold & Head (To_String (Columns (I).Header), Col_Widths (I)) & Reset);
         if I < Columns'Last then
            Print ("  ");
         end if;
      end loop;
      New_Line;

      --  Print separator
      for I in Columns'Range loop
         declare
            Sep : constant String (1 .. Col_Widths (I)) := (others => '-');
         begin
            Print (Bright_Black & Sep & Reset);
         end;
         if I < Columns'Last then
            Print ("  ");
         end if;
      end loop;
      New_Line;

      --  Print rows
      for R in Rows'Range (1) loop
         for C in Rows'Range (2) loop
            if C in Columns'Range then
               Print (Head (To_String (Rows (R, C)), Col_Widths (C)));
               if C < Columns'Last then
                  Print ("  ");
               end if;
            end if;
         end loop;
         New_Line;
      end loop;
   end Print_Table;

   ---------------------------------------------------------------------------
   --  History Display
   ---------------------------------------------------------------------------

   procedure Print_History (Entries : History_Array) is
   begin
      Print_Header ("Transaction History");

      for E of Entries loop
         Print ("  ");
         Print (Bright_Black & "#" & E.ID'Image & Reset & "  ");
         Print (Dim & To_String (E.Date) & Reset & "  ");
         Print (Bold & To_String (E.Command) & Reset);
         Print ("  " & Cyan & E.Altered'Image & Reset & " altered  ");

         --  Status with color
         declare
            Status : constant String := To_String (E.Status);
         begin
            if Status = "Success" then
               Print (Green & Status & Reset);
            elsif Status = "Failed" then
               Print (Red & Status & Reset);
            else
               Print (Yellow & Status & Reset);
            end if;
         end;
         New_Line;
      end loop;
   end Print_History;

   ---------------------------------------------------------------------------
   --  Search Results
   ---------------------------------------------------------------------------

   procedure Print_Search_Results (Results : Search_Results) is
   begin
      for R of Results loop
         Print (Bold);
         if R.Installed then
            Print (Green & Symbol_Check & " ");
         else
            Print ("  ");
         end if;
         Print (To_String (R.Name) & Reset);
         Print (" " & Bright_Green & To_String (R.Version) & Reset);
         Print (" " & Bright_Black & "[" & To_String (R.Repository) & "]" & Reset);
         New_Line;
         Print_Line ("    " & Dim & To_String (R.Description) & Reset);
      end loop;
   end Print_Search_Results;

   ---------------------------------------------------------------------------
   --  Size Formatting
   ---------------------------------------------------------------------------

   function Format_Size (Bytes : Long_Long_Integer) return String is
      KB : constant Long_Long_Integer := 1024;
      MB : constant Long_Long_Integer := KB * 1024;
      GB : constant Long_Long_Integer := MB * 1024;
   begin
      if Bytes >= GB then
         return Trim ((Bytes / GB)'Image, Ada.Strings.Left) & "." &
                Trim (((Bytes mod GB) * 10 / GB)'Image, Ada.Strings.Left) & " GB";
      elsif Bytes >= MB then
         return Trim ((Bytes / MB)'Image, Ada.Strings.Left) & "." &
                Trim (((Bytes mod MB) * 10 / MB)'Image, Ada.Strings.Left) & " MB";
      elsif Bytes >= KB then
         return Trim ((Bytes / KB)'Image, Ada.Strings.Left) & " KB";
      else
         return Trim (Bytes'Image, Ada.Strings.Left) & " B";
      end if;
   end Format_Size;

   function Format_Duration (Seconds : Natural) return String is
      Hours   : constant Natural := Seconds / 3600;
      Minutes : constant Natural := (Seconds mod 3600) / 60;
      Secs    : constant Natural := Seconds mod 60;
   begin
      if Hours > 0 then
         return Trim (Hours'Image, Ada.Strings.Left) & "h " &
                Trim (Minutes'Image, Ada.Strings.Left) & "m";
      elsif Minutes > 0 then
         return Trim (Minutes'Image, Ada.Strings.Left) & "m " &
                Trim (Secs'Image, Ada.Strings.Left) & "s";
      else
         return Trim (Secs'Image, Ada.Strings.Left) & "s";
      end if;
   end Format_Duration;

end CLI_Output;
