-------------------------------------------------------------------------------
-- Techstack Enforcer - Learning Mode Analyzer
-- Analyzes security failures and suggests better language choices
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_Learning is

   --  Maximum entries in learning database
   Max_Learn_Entries : constant := 500;

   --  A learned security pattern
   type Learn_Entry is record
      Vuln_Type     : Vuln_Category;
      Source_Lang   : String (1 .. 32);
      Lang_Len      : Natural range 0 .. 32;
      File_Pattern  : Pattern_String;
      Pattern_Len   : Natural range 0 .. Max_Pattern_Length;
      Occurrences   : Natural;
      Last_Seen     : Natural;  --  Unix timestamp
   end record;

   Null_Learn_Entry : constant Learn_Entry :=
     (Vuln_Type    => Other_Vuln,
      Source_Lang  => (others => ' '),
      Lang_Len     => 0,
      File_Pattern => (others => ' '),
      Pattern_Len  => 0,
      Occurrences  => 0,
      Last_Seen    => 0);

   --  Learning database
   type Learn_Array is array (1 .. Max_Learn_Entries) of Learn_Entry;

   type Learning_Database is record
      Entries : Learn_Array;
      Count   : Natural range 0 .. Max_Learn_Entries;
      Enabled : Boolean;
   end record;

   --  Global learning database
   Learn_DB : Learning_Database;

   --  Initialize learning system
   procedure Initialize;

   --  Record a security finding for learning
   procedure Record_Finding
     (Vuln        : Vuln_Category;
      Source_File : String;
      Details     : String);

   --  Analyze accumulated findings and generate suggestions
   procedure Analyze_Patterns;

   --  Get language recommendation for a vulnerability type
   type Recommendation is record
      Languages   : String (1 .. 128);
      Lang_Len    : Natural range 0 .. 128;
      Confidence  : Natural range 0 .. 100;
      Explanation : Reason_String;
      Expl_Len    : Natural range 0 .. Max_Reason_Length;
   end record;

   function Get_Recommendation (Vuln : Vuln_Category) return Recommendation;

   --  Map file extension to language name
   function Extension_To_Language (Ext : String) return String;

   --  Map vulnerability string to category
   function Parse_Vulnerability (Vuln_Str : String) return Vuln_Category;

   --  Check if a language is memory-safe
   function Is_Memory_Safe (Lang : String) return Boolean;

   --  Check if a language has static typing
   function Has_Static_Typing (Lang : String) return Boolean;

   --  Load/save learning database
   procedure Load_Learning_DB (Path : String; Success : out Boolean);
   procedure Save_Learning_DB (Path : String; Success : out Boolean);

   --  Generate report of learned patterns
   procedure Generate_Report (Output_Path : String);

   --  Clear learning database
   procedure Reset_Learning;

   --  Auto-suggest filter based on findings
   procedure Auto_Suggest_Filter
     (Pattern   : out Pattern_String;
      Pat_Len   : out Natural;
      Level     : out Block_Level;
      Reason    : out Reason_String;
      Reas_Len  : out Natural;
      Suggested : out Boolean);

end Techstack_Learning;
