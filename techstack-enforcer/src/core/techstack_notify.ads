-------------------------------------------------------------------------------
-- Techstack Enforcer - Notification System
-- Desktop and logging notifications for violations
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_Notify is

   --  Notification channels
   type Notify_Channel is (Desktop, Log_File, Syslog, Webhook, All_Channels);

   --  Configuration
   Enable_Desktop   : Boolean := True;
   Enable_Log       : Boolean := True;
   Enable_Syslog    : Boolean := False;
   Enable_Webhook   : Boolean := False;
   Log_Path         : String (1 .. 256) := (others => ' ');
   Log_Path_Len     : Natural := 0;
   Webhook_URL      : String (1 .. 512) := (others => ' ');
   Webhook_URL_Len  : Natural := 0;

   --  Send a single violation notification
   procedure Send_Violation
     (File_Path : String;
      Pattern   : String;
      Reason    : String;
      Level     : Block_Level);

   --  Send audit summary notification
   procedure Send_Audit_Summary
     (Repo_Path   : String;
      Total_Files : Natural;
      Violations  : Natural;
      Fatal_Count : Natural);

   --  Send learning mode suggestion
   procedure Send_Learning_Suggestion
     (Vulnerability : Vuln_Category;
      Current_Lang  : String;
      Suggested     : String;
      Confidence    : Natural);

   --  Low-level notification senders
   procedure Send_Desktop_Notification
     (Title   : String;
      Message : String;
      Urgency : String);

   procedure Log_To_File
     (Message : String);

   procedure Send_To_Syslog
     (Message  : String;
      Priority : Natural);

   --  Initialize notification system
   procedure Initialize;

   --  Configure notification settings
   procedure Set_Log_Path (Path : String);
   procedure Set_Webhook_URL (URL : String);

end Techstack_Notify;
