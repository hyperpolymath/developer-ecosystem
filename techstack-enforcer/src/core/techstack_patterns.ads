-------------------------------------------------------------------------------
-- Techstack Enforcer - Pattern Matching Engine (SPARK verified)
-- Provides glob-style pattern matching for file/tech detection
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_Patterns with SPARK_Mode is

   --  Check if a filename matches a glob pattern
   --  Supports: * (any chars), ? (single char), ** (recursive)
   function Match_Pattern
     (Pattern     : Pattern_String;
      Pattern_Len : Natural;
      Input       : Path_String;
      Input_Len   : Natural) return Boolean
     with Pre => Pattern_Len <= Max_Pattern_Length and
                 Input_Len <= Max_Path_Length;

   --  Extract file extension from path
   procedure Get_Extension
     (Path      : Path_String;
      Path_Len  : Natural;
      Ext       : out Pattern_String;
      Ext_Len   : out Natural)
     with Pre  => Path_Len <= Max_Path_Length,
          Post => Ext_Len <= Max_Pattern_Length;

   --  Extract filename from full path
   procedure Get_Filename
     (Path      : Path_String;
      Path_Len  : Natural;
      Name      : out Pattern_String;
      Name_Len  : out Natural)
     with Pre  => Path_Len <= Max_Path_Length,
          Post => Name_Len <= Max_Pattern_Length;

   --  Check if path contains a directory component
   function Contains_Directory
     (Path      : Path_String;
      Path_Len  : Natural;
      Dir_Name  : Pattern_String;
      Dir_Len   : Natural) return Boolean
     with Pre => Path_Len <= Max_Path_Length and
                 Dir_Len <= Max_Pattern_Length;

end Techstack_Patterns;
