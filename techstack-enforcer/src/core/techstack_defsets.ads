-------------------------------------------------------------------------------
-- Techstack Enforcer - Definition Sets Library
-- Pre-defined filter configurations for common use cases
-------------------------------------------------------------------------------
--
-- Definition Sets provide pre-configured filter rule collections that can be
-- applied based on project requirements. Each set defines a coherent policy
-- for techstack enforcement.
--
-- AVAILABLE SETS:
--
--   strict      - Maximum memory safety enforcement
--                 Blocks: Python, PHP, C/C++, JavaScript, Ruby, Perl
--                 Allows: Rust, Ada/SPARK, Haskell, OCaml, Elm
--
--   moderate    - Balanced safety with practical exceptions
--                 Blocks: Python, PHP, C/C++ (memory-unsafe cores)
--                 Warns:  JavaScript, Ruby, Shell scripts
--                 Allows: TypeScript, Rust, Go, Haskell
--
--   permissive  - Minimal enforcement, advisory only
--                 Blocks: Known vulnerable patterns only
--                 Warns:  Memory-unsafe languages
--                 Allows: Most languages with warnings
--
--   enterprise  - Corporate environments with legacy support
--                 Blocks: Scripting in production paths
--                 Warns:  Legacy languages, vendor lock-in
--                 Allows: Java, Go, Rust, TypeScript
--
--   memory_safe - Focused on memory safety only
--                 Blocks: C, C++, Assembly
--                 Warns:  Languages without ownership/GC
--                 Allows: All GC'd and ownership-based languages
--
-- USAGE:
--
--   techstack-enforcer --defset=strict audit .
--   techstack-enforcer --defset=enterprise decide src/
--
-- COMBINING SETS:
--
--   Sets can be combined with custom filters. The definition set loads first,
--   then custom filters in config/techstack.toml override or extend.
--
-------------------------------------------------------------------------------

with Techstack_Types; use Techstack_Types;

package Techstack_DefSets with SPARK_Mode => Off is

   --  Available definition set identifiers
   type DefSet_ID is
     (Strict,       -- Maximum memory safety
      Moderate,     -- Balanced approach
      Permissive,   -- Advisory only
      Enterprise,   -- Corporate/legacy support
      Memory_Safe,  -- Focus on memory safety
      Custom);      -- User-defined only

   --  Definition set metadata
   type DefSet_Info is record
      ID          : DefSet_ID;
      Name        : String (1 .. 32);
      Name_Len    : Natural range 0 .. 32;
      Description : String (1 .. 128);
      Desc_Len    : Natural range 0 .. 128;
      Filter_Count : Natural;
   end record;

   --  Maximum filters per definition set
   Max_DefSet_Filters : constant := 200;

   --  Get information about a definition set
   function Get_DefSet_Info (ID : DefSet_ID) return DefSet_Info;

   --  Load a definition set into the enforcer database
   --  This clears existing filters and loads the set's filters
   procedure Load_DefSet (ID : DefSet_ID; Success : out Boolean);

   --  Apply a definition set on top of existing filters
   --  Existing filters are preserved, set filters are appended
   procedure Apply_DefSet (ID : DefSet_ID; Success : out Boolean);

   --  Get the default enforcement mode for a definition set
   function Get_DefSet_Mode (ID : DefSet_ID) return Enforce_Mode;

   --  Parse a definition set name string to ID
   function Parse_DefSet_Name (Name : String) return DefSet_ID;

   --  Get definition set name as string
   function DefSet_To_String (ID : DefSet_ID) return String;

   --  List all available definition sets (for help output)
   procedure List_DefSets;

   --  Export a definition set to TOML format (for customization)
   procedure Export_DefSet_TOML
     (ID       : DefSet_ID;
      Filename : String;
      Success  : out Boolean);

private

   --  Internal: Add filters for strict set
   procedure Load_Strict_Filters;

   --  Internal: Add filters for moderate set
   procedure Load_Moderate_Filters;

   --  Internal: Add filters for permissive set
   procedure Load_Permissive_Filters;

   --  Internal: Add filters for enterprise set
   procedure Load_Enterprise_Filters;

   --  Internal: Add filters for memory_safe set
   procedure Load_Memory_Safe_Filters;

end Techstack_DefSets;
