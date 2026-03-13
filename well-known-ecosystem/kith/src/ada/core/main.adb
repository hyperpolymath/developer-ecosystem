with Ada.Text_IO; use Ada.Text_IO;
with TUI; use TUI;
with AIBDP_Validation; use AIBDP_Validation;

procedure Main is
begin
   Put_Line("Hello from Kith!");
   Show_Menu;
   Validate_AIBDP(".well-known/aibdp/default.json");
end Main;
