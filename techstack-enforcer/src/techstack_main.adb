-------------------------------------------------------------------------------
-- Techstack Enforcer - Main CLI Entry Point
-- Command-line interface for checking and enforcing techstack rules
-------------------------------------------------------------------------------

with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Strings.Fixed;     use Ada.Strings.Fixed;
with Techstack_Enforcer;
with Techstack_Types;       use Techstack_Types;
with Techstack_Notify;
with Techstack_JSON_IO;
with Techstack_DefSets;

procedure Techstack_Main is

   procedure Print_Usage is
   begin
      Put_Line ("Techstack Enforcer - Technology Stack Filter");
      Put_Line ("Usage: techstack-enforcer <command> [options]");
      New_Line;
      Put_Line ("Commands:");
      Put_Line ("  check <path>      Check a file or directory");
      Put_Line ("  audit <path>      Full repository audit");
      Put_Line ("  decide [<path>]   Output allow/deny decision as JSON");
      Put_Line ("                    Reads paths from stdin if no path given");
      Put_Line ("  list              List all filters");
      Put_Line ("  defsets           List available definition sets");
      Put_Line ("  add <pattern>     Add a filter interactively");
      Put_Line ("  init              Initialize with default filters");
      Put_Line ("  version           Show version information");
      New_Line;
      Put_Line ("Options:");
      Put_Line ("  --defset=<name>   Use definition set: strict, moderate, permissive,");
      Put_Line ("                    enterprise, memory_safe");
      Put_Line ("  --mode=<mode>     Set mode: learning, warn, enforce, lockdown");
      Put_Line ("  --config=<file>   Use specific config file");
      Put_Line ("  --fatal-exit      Exit with code 1 on any fatal violation");
      Put_Line ("  --notify          Send desktop notifications");
      Put_Line ("  --json            Output in JSON format");
      New_Line;
      Put_Line ("Definition Sets:");
      Put_Line ("  strict       Maximum memory safety - blocks all unsafe languages");
      Put_Line ("  moderate     Balanced safety with practical exceptions");
      Put_Line ("  permissive   Advisory mode - warns but rarely blocks");
      Put_Line ("  enterprise   Corporate environments with legacy support");
      Put_Line ("  memory_safe  Focus on memory safety - blocks C/C++/Assembly");
      New_Line;
      Put_Line ("Input Format (for decide command with stdin):");
      Put_Line ("  One file path per line");
      New_Line;
      Put_Line ("Output Format (decide command JSON):");
      Put_Line ("  {""decisions"": [{""file"": ""..."", ""decision"": ""allow|deny|warn"",");
      Put_Line ("    ""level"": ""allow|warn|block|fatal"", ""pattern"": ""..."", ""reason"": ""...""}],");
      Put_Line ("   ""summary"": {""total"": N, ""allowed"": N, ""denied"": N, ""warnings"": N},");
      Put_Line ("   ""mode"": ""enforce""}");
   end Print_Usage;

   procedure Print_Version is
   begin
      Put_Line ("Techstack Enforcer v1.0.0");
      Put_Line ("Built with Ada/SPARK for formal verification");
      Put_Line ("(c) 2024 - Memory-safe technology enforcement");
   end Print_Version;

   procedure Do_Check (Path : String; Notify : Boolean) is
      P : Path_String := (others => ' ');
      P_Len : constant Natural := Natural'Min (Path'Length, Max_Path_Length);
      Result : Techstack_Enforcer.Check_Result;
   begin
      P (1 .. P_Len) := Path (Path'First .. Path'First + P_Len - 1);
      Techstack_Enforcer.Check_File (P, P_Len, Result);

      if Result.Blocked then
         Put ("BLOCKED: ");
         Put (Trim (Result.Pattern (1 .. Result.Pattern_Len), Ada.Strings.Both));
         Put (" - ");
         Put_Line (Trim (Result.Reason (1 .. Result.Reason_Len), Ada.Strings.Both));

         if Notify then
            Techstack_Notify.Send_Violation
              (Path,
               Trim (Result.Pattern (1 .. Result.Pattern_Len), Ada.Strings.Both),
               Trim (Result.Reason (1 .. Result.Reason_Len), Ada.Strings.Both),
               Result.Level);
         end if;

         Set_Exit_Status (Failure);
      else
         Put_Line ("OK: " & Path);
      end if;
   end Do_Check;

   procedure Do_Audit (Path : String; Notify : Boolean; Fatal_Exit : Boolean) is
      Total, Violations, Fatals : Natural;
      Success : Boolean;
   begin
      Put_Line ("Scanning: " & Path);
      Put_Line ("----------------------------------------");

      Techstack_Enforcer.Check_Repository (Path, Total, Violations, Fatals, Success);

      if Success then
         Put_Line ("Files scanned:  " & Natural'Image (Total));
         Put_Line ("Violations:     " & Natural'Image (Violations));
         Put_Line ("Fatal blocks:   " & Natural'Image (Fatals));
         New_Line;

         if Violations = 0 then
            Put_Line ("PASS: Repository complies with techstack policy");
         else
            Put_Line ("FAIL: Repository has techstack violations");

            if Notify then
               Techstack_Notify.Send_Audit_Summary
                 (Path, Total, Violations, Fatals);
            end if;

            if Fatal_Exit and Fatals > 0 then
               Set_Exit_Status (Failure);
            end if;
         end if;
      else
         Put_Line ("ERROR: Could not scan repository");
         Set_Exit_Status (Failure);
      end if;
   end Do_Audit;

   --  Decide command: outputs structured JSON with allow/deny decisions
   procedure Do_Decide_Single (Path : String) is
      Dec : Techstack_JSON_IO.File_Decision;
   begin
      Techstack_JSON_IO.Decide_File (Path, Dec);
      Techstack_JSON_IO.Output_Decision_JSON (Dec);

      if Dec.Decision = Techstack_JSON_IO.Deny_Decision then
         Set_Exit_Status (Failure);
      end if;
   end Do_Decide_Single;

   procedure Do_Decide_Batch is
      Batch   : Techstack_JSON_IO.Batch_Result;
      Success : Boolean;
   begin
      Techstack_JSON_IO.Decide_Batch_From_Stdin (Batch, Success);

      if Success then
         Techstack_JSON_IO.Output_Batch_JSON (Batch);

         if Batch.Summary.Denied > 0 then
            Set_Exit_Status (Failure);
         end if;
      else
         Put_Line ("{""error"": ""Failed to read input""}");
         Set_Exit_Status (Failure);
      end if;
   end Do_Decide_Batch;

   procedure Do_List is
      Count : constant Natural := Techstack_Enforcer.Get_Filter_Count;
   begin
      Put_Line ("Techstack Filter List (" & Natural'Image (Count) & " entries)");
      Put_Line ("----------------------------------------");

      for I in 1 .. Count loop
         declare
            E : constant Filter_Entry := Techstack_Enforcer.Get_Filter (I);
            Level_Str : String (1 .. 5);
            Enable_Str : constant String := (if E.Enabled then "  " else "X ");
         begin
            case E.Level is
               when Allow => Level_Str := "ALLOW";
               when Warn  => Level_Str := "WARN ";
               when Block => Level_Str := "BLOCK";
               when Fatal => Level_Str := "FATAL";
            end case;

            Put (Enable_Str);
            Put ("[" & Level_Str & "] ");
            Put (Head (Trim (E.Pattern (1 .. E.Pattern_Len), Ada.Strings.Both), 30));
            Put (" | ");
            Put_Line (Trim (E.Reason (1 .. E.Reason_Len), Ada.Strings.Both));
         end;
      end loop;
   end Do_List;

   --  Parsed arguments
   Cmd         : String (1 .. 20) := (others => ' ');
   Cmd_Len     : Natural := 0;
   Target_Path : String (1 .. 1024) := (others => ' ');
   Path_Len    : Natural := 0;
   Notify_Flag : Boolean := False;
   Fatal_Exit  : Boolean := False;
   DefSet_Name : String (1 .. 32) := (others => ' ');
   DefSet_Len  : Natural := 0;
   DefSet_ID   : Techstack_DefSets.DefSet_ID := Techstack_DefSets.Custom;
   DefSet_Used : Boolean := False;

begin
   --  Initialize enforcer (will be re-initialized if defset is specified)
   Techstack_Enforcer.Initialize;

   --  Parse arguments
   if Argument_Count = 0 then
      Print_Usage;
      return;
   end if;

   --  Get command
   declare
      Arg1 : constant String := Argument (1);
   begin
      Cmd_Len := Natural'Min (Arg1'Length, 20);
      Cmd (1 .. Cmd_Len) := Arg1 (Arg1'First .. Arg1'First + Cmd_Len - 1);
   end;

   --  Parse remaining arguments
   for I in 2 .. Argument_Count loop
      declare
         Arg : constant String := Argument (I);
      begin
         if Arg'Length > 9 and then Arg (Arg'First .. Arg'First + 8) = "--defset=" then
            --  Parse definition set name
            declare
               Set_Str : constant String := Arg (Arg'First + 9 .. Arg'Last);
            begin
               DefSet_Len := Natural'Min (Set_Str'Length, 32);
               DefSet_Name (1 .. DefSet_Len) := Set_Str (Set_Str'First .. Set_Str'First + DefSet_Len - 1);
               DefSet_ID := Techstack_DefSets.Parse_DefSet_Name (Set_Str);
               DefSet_Used := True;
            end;
         elsif Arg'Length > 9 and then Arg (Arg'First .. Arg'First + 6) = "--mode=" then
            declare
               Mode_Str : constant String := Arg (Arg'First + 7 .. Arg'Last);
            begin
               if Mode_Str = "learning" then
                  Techstack_Enforcer.Set_Mode (Learning);
               elsif Mode_Str = "warn" then
                  Techstack_Enforcer.Set_Mode (Warn_Only);
               elsif Mode_Str = "enforce" then
                  Techstack_Enforcer.Set_Mode (Enforce);
               elsif Mode_Str = "lockdown" then
                  Techstack_Enforcer.Set_Mode (Lockdown);
               end if;
            end;
         elsif Arg = "--notify" then
            Notify_Flag := True;
         elsif Arg = "--fatal-exit" then
            Fatal_Exit := True;
         elsif Arg (Arg'First) /= '-' then
            Path_Len := Natural'Min (Arg'Length, 1024);
            Target_Path (1 .. Path_Len) := Arg (Arg'First .. Arg'First + Path_Len - 1);
         end if;
      end;
   end loop;

   --  Load definition set if specified
   if DefSet_Used then
      declare
         Success : Boolean;
      begin
         Techstack_DefSets.Load_DefSet (DefSet_ID, Success);
         if not Success then
            Put_Line ("Error: Failed to load definition set: " &
                      Trim (DefSet_Name (1 .. DefSet_Len), Ada.Strings.Both));
            Set_Exit_Status (Failure);
            return;
         end if;
      end;
   end if;

   --  Execute command
   declare
      Command : constant String := Trim (Cmd (1 .. Cmd_Len), Ada.Strings.Both);
   begin
      if Command = "check" then
         if Path_Len > 0 then
            Do_Check (Target_Path (1 .. Path_Len), Notify_Flag);
         else
            Put_Line ("Error: check requires a path argument");
            Set_Exit_Status (Failure);
         end if;

      elsif Command = "audit" then
         if Path_Len > 0 then
            Do_Audit (Target_Path (1 .. Path_Len), Notify_Flag, Fatal_Exit);
         else
            Do_Audit (".", Notify_Flag, Fatal_Exit);
         end if;

      elsif Command = "decide" then
         --  Decide command: output allow/deny decision as JSON
         --  If path given, decide on single file
         --  If no path, read paths from stdin (batch mode)
         if Path_Len > 0 then
            Do_Decide_Single (Target_Path (1 .. Path_Len));
         else
            Do_Decide_Batch;
         end if;

      elsif Command = "list" then
         Do_List;

      elsif Command = "defsets" then
         --  List available definition sets
         Techstack_DefSets.List_DefSets;

      elsif Command = "init" then
         Put_Line ("Initialized with default filters");
         Do_List;

      elsif Command = "version" or Command = "-v" or Command = "--version" then
         Print_Version;

      elsif Command = "help" or Command = "-h" or Command = "--help" then
         Print_Usage;

      else
         Put_Line ("Unknown command: " & Command);
         Print_Usage;
         Set_Exit_Status (Failure);
      end if;
   end;

exception
   when others =>
      Put_Line ("Error: Unexpected exception");
      Set_Exit_Status (Failure);
end Techstack_Main;
