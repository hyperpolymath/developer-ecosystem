-------------------------------------------------------------------------------
-- Techstack Enforcer - Core Enforcement Engine (SPARK verified)
-- Provides main filtering and blocking functionality
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_Enforcer with SPARK_Mode is

   --  Result of checking a file against filters
   type Check_Result is record
      Blocked       : Boolean;
      Level         : Block_Level;
      Pattern       : Pattern_String;
      Pattern_Len   : Natural range 0 .. Max_Pattern_Length;
      Reason        : Reason_String;
      Reason_Len    : Natural range 0 .. Max_Reason_Length;
   end record;

   Null_Result : constant Check_Result :=
     (Blocked      => False,
      Level        => Allow,
      Pattern      => (others => ' '),
      Pattern_Len  => 0,
      Reason       => (others => ' '),
      Reason_Len   => 0);

   --  Global filter database
   DB : Filter_Database;

   --  Initialize the enforcer with default filters
   procedure Initialize
     with Post => DB.Count >= 0;

   --  Load filters from configuration
   procedure Load_Config (Config_Path : String; Success : out Boolean)
     with Pre => Config_Path'Length > 0 and Config_Path'Length <= Max_Path_Length;

   --  Save current filters to configuration
   procedure Save_Config (Config_Path : String; Success : out Boolean)
     with Pre => Config_Path'Length > 0 and Config_Path'Length <= Max_Path_Length;

   --  Check a single file against all filters
   procedure Check_File
     (File_Path : Path_String;
      Path_Len  : Natural;
      Result    : out Check_Result)
     with Pre  => Path_Len <= Max_Path_Length,
          Post => (Result.Blocked = (Result.Level >= Block));

   --  Check entire repository/directory tree
   procedure Check_Repository
     (Repo_Path     : String;
      Total_Files   : out Natural;
      Violations    : out Natural;
      Fatal_Blocks  : out Natural;
      Success       : out Boolean)
     with Pre => Repo_Path'Length > 0 and Repo_Path'Length <= Max_Path_Length;

   --  Add a new filter entry
   procedure Add_Filter
     (Pattern     : String;
      Level       : Block_Level;
      Reason      : String;
      Success     : out Boolean)
     with Pre => Pattern'Length > 0 and Pattern'Length <= Max_Pattern_Length and
                 Reason'Length <= Max_Reason_Length;

   --  Remove a filter by index
   procedure Remove_Filter (Index : Positive; Success : out Boolean)
     with Pre => Index <= Max_Filter_Entries;

   --  Toggle filter enabled state
   procedure Toggle_Filter (Index : Positive; Success : out Boolean)
     with Pre => Index <= Max_Filter_Entries;

   --  Set enforcement mode
   procedure Set_Mode (Mode : Enforce_Mode)
     with Post => DB.Mode = Mode;

   --  Get current mode
   function Get_Mode return Enforce_Mode
     with Post => Get_Mode'Result = DB.Mode;

   --  Get filter count
   function Get_Filter_Count return Natural
     with Post => Get_Filter_Count'Result = DB.Count;

   --  Get filter by index
   function Get_Filter (Index : Positive) return Filter_Entry
     with Pre => Index <= Max_Filter_Entries;

   --  Reset hit counters
   procedure Reset_Stats;

end Techstack_Enforcer;
