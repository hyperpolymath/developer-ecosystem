-- SPDX-License-Identifier: MPL-2.0
-- Git Integration for Kith
--
-- Provides Git operations for versioning .well-known files.

package Git is

   -- Check if current directory is a Git repository
   function Is_Git_Repo return Boolean;

   -- Stage .well-known files for commit
   procedure Stage_Well_Known;

   -- Commit .well-known changes with message
   procedure Commit (Message : String);

   -- Get current Git status of .well-known directory
   procedure Show_Status;

end Git;
