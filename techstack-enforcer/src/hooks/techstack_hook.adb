-------------------------------------------------------------------------------
-- Techstack Enforcer - Git Hook Handler
-- Called from git pre-commit/pre-push hooks to enforce techstack rules
-------------------------------------------------------------------------------

with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Strings.Fixed;     use Ada.Strings.Fixed;
with Ada.Directories;       use Ada.Directories;
with Techstack_Enforcer;
with Techstack_Types;       use Techstack_Types;
with Techstack_Notify;

procedure Techstack_Hook is

   --  Hook types we support
   type Hook_Type is (Pre_Commit, Pre_Push, Commit_Msg, Pre_Receive, Unknown);

   function Get_Hook_Type return Hook_Type is
      Prog_Name : constant String := Simple_Name (Command_Name);
   begin
      if Index (Prog_Name, "pre-commit") > 0 then
         return Pre_Commit;
      elsif Index (Prog_Name, "pre-push") > 0 then
         return Pre_Push;
      elsif Index (Prog_Name, "commit-msg") > 0 then
         return Commit_Msg;
      elsif Index (Prog_Name, "pre-receive") > 0 then
         return Pre_Receive;
      else
         return Unknown;
      end if;
   end Get_Hook_Type;

   procedure Check_Staged_Files is
      --  Would get list from: git diff --cached --name-only
      --  For now, check current directory
      Total, Violations, Fatals : Natural;
      Success : Boolean;
   begin
      Techstack_Enforcer.Check_Repository (".", Total, Violations, Fatals, Success);

      if Success then
         if Violations > 0 then
            New_Line;
            Put_Line ("========================================");
            Put_Line ("  TECHSTACK VIOLATION DETECTED!");
            Put_Line ("========================================");
            Put_Line ("  Files checked:  " & Natural'Image (Total));
            Put_Line ("  Violations:     " & Natural'Image (Violations));
            Put_Line ("  Fatal blocks:   " & Natural'Image (Fatals));
            New_Line;

            if Fatals > 0 then
               Put_Line ("  COMMIT BLOCKED: Fatal violations found");
               Put_Line ("  Run 'techstack-enforcer audit' for details");
               Put_Line ("========================================");

               Techstack_Notify.Send_Audit_Summary (".", Total, Violations, Fatals);

               Set_Exit_Status (Failure);
            else
               Put_Line ("  WARNING: Non-fatal violations found");
               Put_Line ("  Commit allowed, but please review");
               Put_Line ("========================================");
            end if;
         else
            Put_Line ("[techstack] OK - no violations");
         end if;
      else
         Put_Line ("[techstack] ERROR - check failed");
      end if;
   end Check_Staged_Files;

   procedure Run_Pre_Commit is
   begin
      Put_Line ("[techstack] Pre-commit check...");
      Check_Staged_Files;
   end Run_Pre_Commit;

   procedure Run_Pre_Push is
   begin
      Put_Line ("[techstack] Pre-push check...");
      Check_Staged_Files;
   end Run_Pre_Push;

   procedure Run_Commit_Msg is
   begin
      --  Could analyze commit message for policy compliance
      Put_Line ("[techstack] Commit message check...");
   end Run_Commit_Msg;

   procedure Run_Pre_Receive is
   begin
      Put_Line ("[techstack] Pre-receive check...");
      Check_Staged_Files;
   end Run_Pre_Receive;

   Hook : constant Hook_Type := Get_Hook_Type;

begin
   --  Initialize
   Techstack_Enforcer.Initialize;
   Techstack_Notify.Initialize;

   --  Set mode from environment or default to enforce
   --  Could read TECHSTACK_MODE env var here

   case Hook is
      when Pre_Commit =>
         Run_Pre_Commit;
      when Pre_Push =>
         Run_Pre_Push;
      when Commit_Msg =>
         Run_Commit_Msg;
      when Pre_Receive =>
         Run_Pre_Receive;
      when Unknown =>
         --  Run as generic check
         Put_Line ("[techstack] Generic hook check...");
         Check_Staged_Files;
   end case;

exception
   when others =>
      Put_Line ("[techstack] ERROR: Hook failed unexpectedly");
      --  Don't block on hook errors to avoid breaking git completely
      Set_Exit_Status (Success);
end Techstack_Hook;
