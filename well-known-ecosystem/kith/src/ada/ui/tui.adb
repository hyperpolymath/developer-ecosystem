with Ada.Text_IO; use Ada.Text_IO;

package body TUI is
    procedure Show_Menu is
    begin
        Put_Line("1. Auto-generate files");
        Put_Line("2. Validate .well-known");
        Put_Line("3. Exit");
    end Show_Menu;
end TUI;
