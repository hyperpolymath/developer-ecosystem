-------------------------------------------------------------------------------
-- Techstack Enforcer - Core Types (SPARK verified)
-- Defines fundamental types for techstack filtering
-------------------------------------------------------------------------------

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Techstack_Types with SPARK_Mode is

   --  Block severity levels for enforcement
   type Block_Level is (Allow, Warn, Block, Fatal);
   for Block_Level use (Allow => 0, Warn => 1, Block => 2, Fatal => 3);

   --  Enforcement modes
   type Enforce_Mode is (Learning, Warn_Only, Enforce, Lockdown);

   --  Maximum limits for SPARK verification
   Max_Pattern_Length  : constant := 256;
   Max_Reason_Length   : constant := 512;
   Max_Filter_Entries  : constant := 1000;
   Max_Path_Length     : constant := 4096;

   --  Bounded string types for SPARK
   subtype Pattern_String is String (1 .. Max_Pattern_Length);
   subtype Reason_String is String (1 .. Max_Reason_Length);
   subtype Path_String is String (1 .. Max_Path_Length);

   --  Filter entry record (SPARK-compatible bounded version)
   type Filter_Entry is record
      Pattern       : Pattern_String;
      Pattern_Len   : Natural range 0 .. Max_Pattern_Length;
      Level         : Block_Level;
      Reason        : Reason_String;
      Reason_Len    : Natural range 0 .. Max_Reason_Length;
      Enabled       : Boolean;
      Learned       : Boolean;  --  True if auto-learned from security analysis
      Hit_Count     : Natural;
   end record;

   --  Default/null filter entry
   Null_Filter_Entry : constant Filter_Entry :=
     (Pattern       => (others => ' '),
      Pattern_Len   => 0,
      Level         => Allow,
      Reason        => (others => ' '),
      Reason_Len    => 0,
      Enabled       => False,
      Learned       => False,
      Hit_Count     => 0);

   --  Array of filter entries
   type Filter_Array is array (Positive range 1 .. Max_Filter_Entries) of Filter_Entry;

   --  Filter database
   type Filter_Database is record
      Entries : Filter_Array;
      Count   : Natural range 0 .. Max_Filter_Entries;
      Mode    : Enforce_Mode;
   end record;

   --  Violation record for tracking
   type Violation_Record is record
      File_Path     : Path_String;
      Path_Len      : Natural range 0 .. Max_Path_Length;
      Pattern       : Pattern_String;
      Pattern_Len   : Natural range 0 .. Max_Pattern_Length;
      Level         : Block_Level;
      Reason        : Reason_String;
      Reason_Len    : Natural range 0 .. Max_Reason_Length;
      Timestamp     : Natural;  -- Unix timestamp
   end record;

   --  Vulnerability categories for learning mode
   type Vuln_Category is
     (Buffer_Overflow,
      Null_Dereference,
      Race_Condition,
      Injection_Attack,
      Use_After_Free,
      Integer_Overflow,
      Type_Confusion,
      Memory_Leak,
      Unvalidated_Input,
      Other_Vuln);

   --  Language recommendation based on vulnerability
   type Language_Rec is record
      Lang_Name    : String (1 .. 32);
      Name_Len     : Natural range 0 .. 32;
      Confidence   : Natural range 0 .. 100;
      Fixes_Vuln   : Vuln_Category;
   end record;

end Techstack_Types;
