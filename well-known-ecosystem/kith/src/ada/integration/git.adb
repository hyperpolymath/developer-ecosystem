-- SPDX-License-Identifier: MPL-2.0
-- Git Integration for Kith

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories; use Ada.Directories;

package body Git is

   -- Check if current directory is a Git repository
   function Is_Git_Repo return Boolean is
   begin
      return Exists (".git");
   end Is_Git_Repo;

   -- Stage .well-known files for commit
   procedure Stage_Well_Known is
   begin
      if not Is_Git_Repo then
         Put_Line ("Error: Not a Git repository");
         return;
      end if;
      Put_Line ("Staging .well-known/ files...");
      -- Uses GNAT.OS_Lib.Spawn in full implementation
      Put_Line ("Run: git add .well-known/");
   end Stage_Well_Known;

   -- Commit .well-known changes with message
   procedure Commit (Message : String) is
   begin
      if not Is_Git_Repo then
         Put_Line ("Error: Not a Git repository");
         return;
      end if;
      Put_Line ("Committing: " & Message);
      Put_Line ("Run: git commit -m """ & Message & """");
   end Commit;

   -- Get current Git status of .well-known directory
   procedure Show_Status is
   begin
      if not Is_Git_Repo then
         Put_Line ("Error: Not a Git repository");
         return;
      end if;
      Put_Line ("Run: git status .well-known/");
   end Show_Status;

end Git;
