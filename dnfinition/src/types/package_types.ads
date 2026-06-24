-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Package_Types - Core data types for package management
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Ordered_Sets;

package Package_Types is

   --  Package state enumeration
   type Package_State is (
      Available,      --  Package exists in repository but not installed
      Installed,      --  Package is currently installed
      Upgradeable,    --  Newer version available
      Downgradeable,  --  Older version available (rollback possible)
      Orphaned,       --  Installed but not in any repo
      Broken,         --  Dependencies unsatisfied
      Held            --  Version pinned by user
   );

   --  Package priority/importance
   type Package_Priority is (
      Required,       --  System cannot function without
      Important,      --  Recommended for normal operation
      Standard,       --  Default packages
      Optional,       --  Nice to have
      Extra           --  Specialized use cases
   );

   --  Maximum lengths for bounded strings
   Max_Name_Length    : constant := 256;
   Max_Version_Length : constant := 64;
   Max_Arch_Length    : constant := 32;
   Max_Desc_Length    : constant := 4096;
   Max_URL_Length     : constant := 2048;

   --  Subtype for package names (identifier-safe)
   subtype Package_Name_Type is Unbounded_String;

   --  Version string type
   subtype Version_String is Unbounded_String;

   --  Architecture string
   subtype Architecture_Type is Unbounded_String;

   --  Package size in bytes
   type Package_Size is range 0 .. 2 ** 63 - 1;

   --  Package information record
   type Package_Info is record
      Name         : Package_Name_Type;
      Version      : Version_String;
      Release      : Version_String;
      Epoch        : Natural := 0;
      Architecture : Architecture_Type;
      Summary      : Unbounded_String;
      Description  : Unbounded_String;
      URL          : Unbounded_String;
      License      : Unbounded_String;
      Repository   : Unbounded_String;
      Size         : Package_Size := 0;
      Install_Size : Package_Size := 0;
      State        : Package_State := Available;
      Priority     : Package_Priority := Standard;
      Is_Automatic : Boolean := False;  --  Installed as dependency
   end record;

   --  Null package constant
   Null_Package : constant Package_Info := (
      Name         => Null_Unbounded_String,
      Version      => Null_Unbounded_String,
      Release      => Null_Unbounded_String,
      Epoch        => 0,
      Architecture => Null_Unbounded_String,
      Summary      => Null_Unbounded_String,
      Description  => Null_Unbounded_String,
      URL          => Null_Unbounded_String,
      License      => Null_Unbounded_String,
      Repository   => Null_Unbounded_String,
      Size         => 0,
      Install_Size => 0,
      State        => Available,
      Priority     => Standard,
      Is_Automatic => False
   );

   --  Package vector for lists of packages
   package Package_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Package_Info);

   subtype Package_Array is Package_Vectors.Vector;

   --  Package name comparison for sets
   function "<" (Left, Right : Package_Info) return Boolean is
     (Left.Name < Right.Name);

   --  Package set for unique collections
   package Package_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Package_Info);

   subtype Package_Set is Package_Sets.Set;

   --  Dependency types
   type Dependency_Kind is (
      Requires,       --  Hard dependency
      Recommends,     --  Soft dependency (usually installed)
      Suggests,       --  Optional enhancement
      Conflicts,      --  Cannot coexist
      Obsoletes,      --  Replaces older package
      Provides,       --  Virtual package provision
      Enhances,       --  Enhances another package
      Supplements     --  Supplements another package
   );

   --  Version comparison operators
   type Version_Operator is (
      Equal,          --  ==
      Less_Than,      --  <
      Greater_Than,   --  >
      Less_Equal,     --  <=
      Greater_Equal,  --  >=
      Any_Version     --  No version constraint
   );

   --  Dependency specification
   type Dependency_Spec is record
      Kind        : Dependency_Kind := Requires;
      Name        : Package_Name_Type;
      Operator    : Version_Operator := Any_Version;
      Version     : Version_String;
      Is_Optional : Boolean := False;
   end record;

   --  Dependency vector
   package Dependency_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Dependency_Spec);

   subtype Dependency_Array is Dependency_Vectors.Vector;

   --  Extended package info with dependencies
   type Package_Full_Info is record
      Base         : Package_Info;
      Dependencies : Dependency_Array;
      Files        : Package_Vectors.Vector;  --  List of files in package
   end record;

   --  Helper functions
   function To_Unbounded (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function To_String (U : Unbounded_String) return String
      renames Ada.Strings.Unbounded.To_String;

   function "-" (U : Unbounded_String) return String
      renames Ada.Strings.Unbounded.To_String;

   --  Create a basic package info from name and version
   function Make_Package
     (Name    : String;
      Version : String := "";
      Arch    : String := "")
      return Package_Info;

   --  Compare versions (returns -1, 0, or 1)
   function Compare_Versions
     (Left, Right : Version_String)
      return Integer;

   --  Check if version satisfies a constraint
   function Version_Satisfies
     (Version  : Version_String;
      Operator : Version_Operator;
      Target   : Version_String)
      return Boolean;

end Package_Types;
