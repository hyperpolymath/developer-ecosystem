-------------------------------------------------------------------------------
-- Techstack Enforcer - JSON Input/Output for CLI Actions
-- Defines input format and decision output (allow/deny + reasons)
-------------------------------------------------------------------------------
--
-- INPUT FORMAT (stdin or file, one path per line OR JSON array):
--
--   Line format:
--     path/to/file1.py
--     path/to/file2.rs
--
--   JSON format:
--     {"files": ["path/to/file1.py", "path/to/file2.rs"], "mode": "enforce"}
--
-- OUTPUT FORMAT (JSON):
--
--   {
--     "decisions": [
--       {
--         "file": "path/to/file1.py",
--         "decision": "deny",
--         "level": "fatal",
--         "pattern": "*.py",
--         "reason": "Python: No static typing, memory-unsafe runtime"
--       },
--       {
--         "file": "path/to/file2.rs",
--         "decision": "allow",
--         "level": "allow",
--         "pattern": null,
--         "reason": null
--       }
--     ],
--     "summary": {
--       "total": 2,
--       "allowed": 1,
--       "denied": 1,
--       "warnings": 0
--     },
--     "mode": "enforce"
--   }
--
-------------------------------------------------------------------------------

with Techstack_Types;    use Techstack_Types;
with Techstack_Enforcer; use Techstack_Enforcer;

package Techstack_JSON_IO with SPARK_Mode => Off is

   --  Maximum files that can be processed in a single batch
   Max_Batch_Size : constant := 10000;

   --  Decision result for a single file
   type Decision_Kind is (Allow_Decision, Deny_Decision, Warn_Decision);

   type File_Decision is record
      File_Path     : Path_String;
      Path_Len      : Natural range 0 .. Max_Path_Length;
      Decision      : Decision_Kind;
      Level         : Block_Level;
      Pattern       : Pattern_String;
      Pattern_Len   : Natural range 0 .. Max_Pattern_Length;
      Reason        : Reason_String;
      Reason_Len    : Natural range 0 .. Max_Reason_Length;
   end record;

   Null_Decision : constant File_Decision :=
     (File_Path   => (others => ' '),
      Path_Len    => 0,
      Decision    => Allow_Decision,
      Level       => Allow,
      Pattern     => (others => ' '),
      Pattern_Len => 0,
      Reason      => (others => ' '),
      Reason_Len  => 0);

   --  Batch decision results
   type Decision_Array is array (Positive range 1 .. Max_Batch_Size) of File_Decision;

   type Decision_Summary is record
      Total     : Natural := 0;
      Allowed   : Natural := 0;
      Denied    : Natural := 0;
      Warnings  : Natural := 0;
   end record;

   type Batch_Result is record
      Decisions : Decision_Array;
      Count     : Natural range 0 .. Max_Batch_Size;
      Summary   : Decision_Summary;
      Mode      : Enforce_Mode;
   end record;

   --  Check a single file and return decision
   procedure Decide_File
     (File_Path : String;
      Result    : out File_Decision);

   --  Read file paths from stdin (line format) and process them
   --  Returns batch results for all files
   procedure Decide_Batch_From_Stdin
     (Result  : out Batch_Result;
      Success : out Boolean);

   --  Output a single file decision as JSON to stdout
   procedure Output_Decision_JSON (Dec : File_Decision);

   --  Output batch results as JSON to stdout
   procedure Output_Batch_JSON (Batch : Batch_Result);

   --  Escape a string for JSON output (handles quotes, backslashes, etc.)
   function Escape_JSON_String (S : String) return String;

   --  Convert Block_Level to lowercase string
   function Level_To_String (L : Block_Level) return String;

   --  Convert Decision_Kind to string
   function Decision_To_String (D : Decision_Kind) return String;

   --  Convert Enforce_Mode to string
   function Mode_To_String (M : Enforce_Mode) return String;

end Techstack_JSON_IO;
