-------------------------------------------------------------------------------
-- Techstack Enforcer - Notification System Implementation
-------------------------------------------------------------------------------

with Ada.Text_IO;       use Ada.Text_IO;
with Ada.Calendar;      use Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with GNAT.OS_Lib;

package body Techstack_Notify is

   function Timestamp return String is
      Now : constant Time := Clock;
   begin
      return Ada.Calendar.Formatting.Image (Now);
   exception
      when others => return "UNKNOWN";
   end Timestamp;

   function Level_To_Urgency (Level : Block_Level) return String is
   begin
      case Level is
         when Allow => return "low";
         when Warn  => return "normal";
         when Block => return "normal";
         when Fatal => return "critical";
      end case;
   end Level_To_Urgency;

   procedure Send_Desktop_Notification
     (Title   : String;
      Message : String;
      Urgency : String)
   is
      use GNAT.OS_Lib;
      Args    : Argument_List (1 .. 5);
      Success : Boolean;
      Pid     : Process_Id;
   begin
      if not Enable_Desktop then
         return;
      end if;

      --  Try notify-send (Linux)
      Args (1) := new String'("-u");
      Args (2) := new String'(Urgency);
      Args (3) := new String'("-a");
      Args (4) := new String'("Techstack Enforcer");
      Args (5) := new String'(Title & ASCII.LF & Message);

      begin
         Pid := Non_Blocking_Spawn
           (Program_Name => "/usr/bin/notify-send",
            Args         => Args);
         pragma Unreferenced (Pid);
         Success := True;
      exception
         when others =>
            Success := False;
      end;

      --  Free allocated strings
      for I in Args'Range loop
         Free (Args (I));
      end loop;

      pragma Unreferenced (Success);
   end Send_Desktop_Notification;

   procedure Log_To_File (Message : String) is
      File : File_Type;
      Path : constant String :=
        (if Log_Path_Len > 0
         then Trim (Log_Path (1 .. Log_Path_Len), Ada.Strings.Both)
         else "techstack.log");
   begin
      if not Enable_Log then
         return;
      end if;

      begin
         Open (File, Append_File, Path);
      exception
         when Name_Error =>
            Create (File, Out_File, Path);
      end;

      Put_Line (File, "[" & Timestamp & "] " & Message);
      Close (File);

   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
   end Log_To_File;

   procedure Send_To_Syslog
     (Message  : String;
      Priority : Natural)
   is
      pragma Unreferenced (Priority);
   begin
      if not Enable_Syslog then
         return;
      end if;

      --  Would use syslog bindings here
      --  For now, just log to stderr
      Put_Line (Standard_Error, "SYSLOG: " & Message);
   end Send_To_Syslog;

   procedure Send_Violation
     (File_Path : String;
      Pattern   : String;
      Reason    : String;
      Level     : Block_Level)
   is
      Level_Str : String (1 .. 5);
      Title     : constant String := "TECHSTACK VIOLATION";
      Message   : constant String :=
        File_Path & ASCII.LF &
        "Pattern: " & Pattern & ASCII.LF &
        "Reason: " & Reason;
      Log_Msg   : constant String :=
        "VIOLATION " & Level_Str & " " & File_Path & " | " & Pattern & " | " & Reason;
   begin
      case Level is
         when Allow => Level_Str := "ALLOW";
         when Warn  => Level_Str := "WARN ";
         when Block => Level_Str := "BLOCK";
         when Fatal => Level_Str := "FATAL";
      end case;

      Send_Desktop_Notification (Title, Message, Level_To_Urgency (Level));
      Log_To_File (Log_Msg);

      if Level = Fatal then
         Send_To_Syslog (Log_Msg, 2);  --  Critical priority
      end if;
   end Send_Violation;

   procedure Send_Audit_Summary
     (Repo_Path   : String;
      Total_Files : Natural;
      Violations  : Natural;
      Fatal_Count : Natural)
   is
      Title   : constant String := "TECHSTACK AUDIT";
      Message : constant String :=
        "Repository: " & Repo_Path & ASCII.LF &
        "Files: " & Natural'Image (Total_Files) & ASCII.LF &
        "Violations: " & Natural'Image (Violations) & ASCII.LF &
        "Fatal: " & Natural'Image (Fatal_Count);
      Log_Msg : constant String :=
        "AUDIT " & Repo_Path &
        " files=" & Natural'Image (Total_Files) &
        " violations=" & Natural'Image (Violations) &
        " fatal=" & Natural'Image (Fatal_Count);
      Urgency : constant String :=
        (if Fatal_Count > 0 then "critical" elsif Violations > 0 then "normal" else "low");
   begin
      Send_Desktop_Notification (Title, Message, Urgency);
      Log_To_File (Log_Msg);

      if Fatal_Count > 0 then
         Send_To_Syslog (Log_Msg, 2);
      end if;
   end Send_Audit_Summary;

   procedure Send_Learning_Suggestion
     (Vulnerability : Vuln_Category;
      Current_Lang  : String;
      Suggested     : String;
      Confidence    : Natural)
   is
      Vuln_Str : String (1 .. 20) := (others => ' ');
      Title    : constant String := "TECHSTACK LEARNING SUGGESTION";
      Message  : constant String :=
        "Vulnerability: " & Vuln_Str & ASCII.LF &
        "Current: " & Current_Lang & ASCII.LF &
        "Suggested: " & Suggested & ASCII.LF &
        "Confidence: " & Natural'Image (Confidence) & "%";
   begin
      case Vulnerability is
         when Buffer_Overflow   => Vuln_Str (1 .. 15) := "Buffer Overflow";
         when Null_Dereference  => Vuln_Str (1 .. 16) := "Null Dereference";
         when Race_Condition    => Vuln_Str (1 .. 14) := "Race Condition";
         when Injection_Attack  => Vuln_Str (1 .. 16) := "Injection Attack";
         when Use_After_Free    => Vuln_Str (1 .. 14) := "Use After Free";
         when Integer_Overflow  => Vuln_Str (1 .. 16) := "Integer Overflow";
         when Type_Confusion    => Vuln_Str (1 .. 14) := "Type Confusion";
         when Memory_Leak       => Vuln_Str (1 .. 11) := "Memory Leak";
         when Unvalidated_Input => Vuln_Str (1 .. 17) := "Unvalidated Input";
         when Other_Vuln        => Vuln_Str (1 .. 5)  := "Other";
      end case;

      Send_Desktop_Notification (Title, Message, "normal");
      Log_To_File ("LEARNING " & Message);
   end Send_Learning_Suggestion;

   procedure Initialize is
   begin
      Enable_Desktop := True;
      Enable_Log := True;
      Enable_Syslog := False;
      Enable_Webhook := False;
      Log_Path := (others => ' ');
      Log_Path_Len := 0;
   end Initialize;

   procedure Set_Log_Path (Path : String) is
   begin
      Log_Path := (others => ' ');
      Log_Path_Len := Natural'Min (Path'Length, 256);
      Log_Path (1 .. Log_Path_Len) := Path (Path'First .. Path'First + Log_Path_Len - 1);
   end Set_Log_Path;

   procedure Set_Webhook_URL (URL : String) is
   begin
      Webhook_URL := (others => ' ');
      Webhook_URL_Len := Natural'Min (URL'Length, 512);
      Webhook_URL (1 .. Webhook_URL_Len) := URL (URL'First .. URL'First + Webhook_URL_Len - 1);
   end Set_Webhook_URL;

end Techstack_Notify;
