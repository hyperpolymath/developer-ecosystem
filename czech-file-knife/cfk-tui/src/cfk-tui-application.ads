--  CFK TUI Application Package
--  Main application state and lifecycle

with CFK.TUI.Config;
with CFK.TUI.Screen;
with CFK.TUI.Input;

package CFK.TUI.Application is

   type Application_State is (Initializing, Running, Paused, Exiting);

   type Application_Type is record
      State      : Application_State := Initializing;
      Config     : Config.Config_Type;
      Screen     : Screen.Screen_Type;
      Input      : Input.Input_Handler;
      Exit_Code  : Integer := 0;
   end record;

   --  Lifecycle procedures
   procedure Initialize
     (App    : in out Application_Type;
      Config : Config.Config_Type);

   procedure Run (App : in out Application_Type);

   procedure Pause (App : in out Application_Type);

   procedure Resume (App : in out Application_Type);

   procedure Request_Exit (App : in out Application_Type; Code : Integer := 0);

   procedure Finalize (App : in out Application_Type);

   --  State queries
   function Is_Running (App : Application_Type) return Boolean;
   function Get_Exit_Code (App : Application_Type) return Integer;

end CFK.TUI.Application;
