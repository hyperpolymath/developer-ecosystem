-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Config_Parser - Configuration file parsing (TOML format)
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Snapshot_Types; use Snapshot_Types;

package Config_Parser is

   --  Configuration error
   Config_Error : exception;

   --  UI Configuration
   type UI_Config is record
      Theme                    : Unbounded_String := To_Unbounded_String
                                   ("default");
      Show_Package_Descriptions : Boolean := True;
      Show_Dependencies        : Boolean := True;
      Show_Reverse_Dependencies : Boolean := False;
      Highlight_Color          : Unbounded_String := To_Unbounded_String
                                   ("cyan");
      Page_Size                : Positive := 20;
   end record;

   Default_UI_Config : constant UI_Config := (others => <>);

   --  Keybinding configuration
   type Keybinding_Config is record
      Navigate_Up      : Character := 'k';
      Navigate_Down    : Character := 'j';
      Page_Up          : Character := 'u';
      Page_Down        : Character := 'd';
      Mark_Install     : Character := '+';
      Mark_Remove      : Character := '-';
      Mark_Upgrade     : Character := 'u';
      Apply_Transaction : Character := 'g';
      Cancel           : Character := 'q';
      Search           : Character := '/';
      Help             : Character := '?';
   end record;

   Default_Keybinding_Config : constant Keybinding_Config := (others => <>);

   --  General configuration
   type General_Config is record
      Default_Backend          : Unbounded_String := To_Unbounded_String
                                   ("auto");
      Confirm_Before_Install   : Boolean := True;
      Confirm_Before_Upgrade   : Boolean := True;
      Confirm_Before_Removal   : Boolean := True;
   end record;

   Default_General_Config : constant General_Config := (others => <>);

   --  Complete application configuration
   type App_Config is record
      General       : General_Config := Default_General_Config;
      Reversibility : Snapshot_Config := Default_Snapshot_Config;
      UI            : UI_Config := Default_UI_Config;
      Keybindings   : Keybinding_Config := Default_Keybinding_Config;
   end record;

   Default_App_Config : constant App_Config := (others => <>);

   --  Current configuration (global)
   Current_Config : App_Config := Default_App_Config;

   --  Load configuration from file
   procedure Load_Config (Path : String := "");

   --  Save configuration to file
   procedure Save_Config (Path : String := "");

   --  Get default configuration path
   function Get_Default_Config_Path return String;

   --  Get user configuration directory
   function Get_Config_Dir return String;

   --  Ensure configuration directory exists
   procedure Ensure_Config_Dir;

   --  Reset to defaults
   procedure Reset_Config;

   --  Individual setting getters/setters
   function Get_Theme return String;
   procedure Set_Theme (Theme : String);

   function Get_Confirm_Install return Boolean;
   procedure Set_Confirm_Install (Value : Boolean);

   function Get_Snapshot_Before_Install return Boolean;
   procedure Set_Snapshot_Before_Install (Value : Boolean);

   function Get_Keep_Snapshots return Positive;
   procedure Set_Keep_Snapshots (Value : Positive);

end Config_Parser;
