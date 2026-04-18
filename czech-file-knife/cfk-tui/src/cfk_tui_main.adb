--  Czech File Knife TUI Main
--  Ada terminal user interface for CFK

with Ada.Text_IO;
with Ada.Command_Line;
with CFK.TUI.Application;
with CFK.TUI.Config;

procedure CFK_TUI_Main is
   use Ada.Text_IO;
   use Ada.Command_Line;

   App    : CFK.TUI.Application.Application_Type;
   Config : CFK.TUI.Config.Config_Type;
begin
   --  Parse command line arguments
   if Argument_Count > 0 then
      Config := CFK.TUI.Config.Parse_Args;
   else
      Config := CFK.TUI.Config.Default_Config;
   end if;

   --  Initialize application
   CFK.TUI.Application.Initialize (App, Config);

   --  Run main loop
   CFK.TUI.Application.Run (App);

   --  Cleanup
   CFK.TUI.Application.Finalize (App);

exception
   when E : others =>
      Put_Line (Standard_Error, "Fatal error in CFK TUI");
      Set_Exit_Status (Failure);
end CFK_TUI_Main;
