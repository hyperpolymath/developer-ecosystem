-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Language_Backend_Interface - Abstract interface for language package managers
--
-- This interface defines operations for language-specific package managers
-- (cargo, hex, cabal, pip, npm, etc.) which have different semantics from
-- system package managers.
--
-- Key differences from system PMs:
--   - Project-local vs global installation
--   - Lock files for reproducibility
--   - Virtual environments / sandboxing
--   - Registry/repository concepts
--   - Semantic versioning constraints
--   - Build from source is common
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Detection;             use Detection;

package Language_Backend_Interface is

   ---------------------------------------------------------------------------
   --  Exceptions
   ---------------------------------------------------------------------------

   Backend_Error           : exception;
   Package_Not_Found       : exception;
   Dependency_Conflict     : exception;
   Version_Constraint_Error : exception;
   Registry_Unavailable    : exception;
   Build_Failed            : exception;
   Lock_File_Error         : exception;

   ---------------------------------------------------------------------------
   --  Language Package Information
   ---------------------------------------------------------------------------

   --  Version constraint types (semver-style)
   type Version_Constraint_Kind is (
      Exact,            --  = 1.2.3
      Greater_Than,     --  > 1.2.3
      Greater_Or_Equal, --  >= 1.2.3
      Less_Than,        --  < 1.2.3
      Less_Or_Equal,    --  <= 1.2.3
      Compatible,       --  ~> 1.2 (pessimistic, allows patch updates)
      Caret,            --  ^1.2.3 (allows minor updates)
      Any,              --  * (any version)
      Range             --  >= 1.0, < 2.0
   );

   type Version_Constraint is record
      Kind      : Version_Constraint_Kind := Any;
      Version   : Unbounded_String;
      Max_Version : Unbounded_String;  -- For Range constraints
   end record;

   --  Package source types
   type Package_Source_Kind is (
      Registry,         --  Official registry (crates.io, hex.pm, pypi, etc.)
      Git_Repo,         --  Git repository URL
      Git_Tag,          --  Git repo at specific tag
      Git_Branch,       --  Git repo at specific branch
      Git_Rev,          --  Git repo at specific commit
      Path_Local,       --  Local filesystem path
      URL_Tarball,      --  URL to tarball/archive
      Unknown_Source
   );

   type Package_Source is record
      Kind : Package_Source_Kind := Registry;
      Location : Unbounded_String;  -- URL, path, or registry name
      Ref : Unbounded_String;       -- Tag, branch, or commit for git sources
   end record;

   --  Language package info (different from system Package_Info)
   type Language_Package_Info is record
      Name           : Unbounded_String;
      Version        : Unbounded_String;
      Constraint     : Version_Constraint;
      Source         : Package_Source;
      Description    : Unbounded_String;
      License        : Unbounded_String;
      Homepage       : Unbounded_String;
      Repository     : Unbounded_String;
      Documentation  : Unbounded_String;
      Is_Dev_Dep     : Boolean := False;  -- Development dependency
      Is_Optional    : Boolean := False;  -- Optional/feature dependency
      Is_Locked      : Boolean := False;  -- Version locked in lock file
      Installed      : Boolean := False;
      Installed_Version : Unbounded_String;
   end record;

   type Language_Package_Array is array (Positive range <>) of Language_Package_Info;

   ---------------------------------------------------------------------------
   --  Installation Scope
   ---------------------------------------------------------------------------

   type Installation_Scope is (
      Project_Local,    --  Install to project directory (node_modules, .venv, etc.)
      User_Global,      --  Install to user's home (~/.cargo, ~/.local, etc.)
      System_Global     --  Install system-wide (requires privileges)
   );

   ---------------------------------------------------------------------------
   --  Backend Capabilities
   ---------------------------------------------------------------------------

   type Language_Backend_Capability is (
      Cap_Install,           --  Can install packages
      Cap_Remove,            --  Can remove packages
      Cap_Update,            --  Can update packages
      Cap_Search,            --  Can search registry
      Cap_List_Installed,    --  Can list installed packages
      Cap_Show_Info,         --  Can show package details
      Cap_Lock_File,         --  Supports lock files
      Cap_Virtual_Env,       --  Supports virtual environments
      Cap_Dev_Dependencies,  --  Distinguishes dev vs prod deps
      Cap_Optional_Deps,     --  Supports optional/feature deps
      Cap_Build_From_Source, --  Can build packages from source
      Cap_Binary_Cache,      --  Has binary/prebuilt cache
      Cap_Offline_Mode,      --  Can work offline with cache
      Cap_Workspaces,        --  Supports monorepo/workspaces
      Cap_Scripts,           --  Can run package scripts
      Cap_Publish,           --  Can publish packages to registry
      Cap_Audit,             --  Can audit for vulnerabilities
      Cap_Outdated,          --  Can check for outdated packages
      Cap_Tree,              --  Can show dependency tree
      Cap_Why,               --  Can explain why package is installed
      Cap_Clean,             --  Can clean cache/artifacts
      Cap_Init               --  Can initialize new project
   );

   type Language_Capability_Set is array (Language_Backend_Capability) of Boolean;

   All_Language_Capabilities : constant Language_Capability_Set := (others => True);

   ---------------------------------------------------------------------------
   --  Project Context
   ---------------------------------------------------------------------------

   --  Information about the current project context
   type Project_Context is record
      Project_Root     : Unbounded_String;  -- Path to project root
      Manifest_File    : Unbounded_String;  -- Cargo.toml, mix.exs, package.json, etc.
      Lock_File        : Unbounded_String;  -- Cargo.lock, mix.lock, etc.
      Has_Lock_File    : Boolean := False;
      Virtual_Env_Path : Unbounded_String;  -- .venv, node_modules, etc.
      Is_In_Workspace  : Boolean := False;
      Workspace_Root   : Unbounded_String;
   end record;

   ---------------------------------------------------------------------------
   --  Abstract Backend Interface
   ---------------------------------------------------------------------------

   type Language_Package_Backend is interface;

   --  Identity
   function Name (Backend : Language_Package_Backend) return String is abstract;
   function PM_Type (Backend : Language_Package_Backend)
      return Language_Package_Manager is abstract;
   function Language (Backend : Language_Package_Backend)
      return Programming_Language is abstract;

   --  Capabilities
   function Capabilities (Backend : Language_Package_Backend)
      return Language_Capability_Set is abstract;

   --  Availability
   function Is_Available (Backend : Language_Package_Backend)
      return Boolean is abstract;
   function Get_Version (Backend : Language_Package_Backend)
      return String is abstract;

   --  Initialization
   procedure Initialize (Backend : in out Language_Package_Backend) is abstract;

   ---------------------------------------------------------------------------
   --  Package Operations
   ---------------------------------------------------------------------------

   --  Install packages
   procedure Install_Package
     (Backend : in out Language_Package_Backend;
      Package : Language_Package_Info;
      Scope   : Installation_Scope := Project_Local) is abstract;

   procedure Install_Packages
     (Backend  : in Out Language_Package_Backend;
      Packages : Language_Package_Array;
      Scope    : Installation_Scope := Project_Local) is abstract;

   --  Install from manifest (e.g., `cargo build`, `mix deps.get`)
   procedure Install_From_Manifest
     (Backend : in Out Language_Package_Backend;
      Context : Project_Context) is abstract;

   --  Remove packages
   procedure Remove_Package
     (Backend : in Out Language_Package_Backend;
      Package : Language_Package_Info) is abstract;

   procedure Remove_Packages
     (Backend  : in Out Language_Package_Backend;
      Packages : Language_Package_Array) is abstract;

   --  Update packages
   procedure Update_Package
     (Backend : in Out Language_Package_Backend;
      Package : Language_Package_Info) is abstract;

   procedure Update_All
     (Backend : in Out Language_Package_Backend) is abstract;

   ---------------------------------------------------------------------------
   --  Query Operations
   ---------------------------------------------------------------------------

   --  Search registry
   function Search_Packages
     (Backend : Language_Package_Backend;
      Query   : String)
      return Language_Package_Array is abstract;

   --  Get package info from registry
   function Get_Package_Info
     (Backend : Language_Package_Backend;
      Name    : String)
      return Language_Package_Info is abstract;

   --  List installed packages
   function List_Installed
     (Backend : Language_Package_Backend;
      Scope   : Installation_Scope := Project_Local)
      return Language_Package_Array is abstract;

   --  Check for outdated packages
   function Check_Outdated
     (Backend : Language_Package_Backend)
      return Language_Package_Array is abstract;

   --  Get dependency tree as formatted string
   function Get_Dependency_Tree
     (Backend : Language_Package_Backend)
      return String is abstract;

   --  Explain why a package is installed
   function Explain_Dependency
     (Backend : Language_Package_Backend;
      Package : String)
      return String is abstract;

   ---------------------------------------------------------------------------
   --  Lock File Operations
   ---------------------------------------------------------------------------

   --  Generate/update lock file
   procedure Generate_Lock_File
     (Backend : in Out Language_Package_Backend;
      Context : Project_Context) is abstract;

   --  Install exactly what's in lock file
   procedure Install_From_Lock_File
     (Backend : in Out Language_Package_Backend;
      Context : Project_Context) is abstract;

   --  Check if lock file is in sync with manifest
   function Lock_File_In_Sync
     (Backend : Language_Package_Backend;
      Context : Project_Context)
      return Boolean is abstract;

   ---------------------------------------------------------------------------
   --  Virtual Environment Operations
   ---------------------------------------------------------------------------

   --  Create virtual environment
   procedure Create_Virtual_Env
     (Backend : in Out Language_Package_Backend;
      Path    : String) is abstract;

   --  Activate virtual environment (returns shell commands)
   function Activate_Virtual_Env_Command
     (Backend : Language_Package_Backend;
      Path    : String)
      return String is abstract;

   --  Check if in virtual environment
   function In_Virtual_Env
     (Backend : Language_Package_Backend)
      return Boolean is abstract;

   ---------------------------------------------------------------------------
   --  Security & Maintenance
   ---------------------------------------------------------------------------

   --  Audit for security vulnerabilities
   function Audit_Packages
     (Backend : Language_Package_Backend)
      return String is abstract;  -- Returns audit report

   --  Clean cache/artifacts
   procedure Clean_Cache
     (Backend : in Out Language_Package_Backend) is abstract;

   --  Verify package integrity
   function Verify_Packages
     (Backend : Language_Package_Backend)
      return Boolean is abstract;

   ---------------------------------------------------------------------------
   --  Project Initialization
   ---------------------------------------------------------------------------

   --  Initialize a new project
   procedure Init_Project
     (Backend      : in Out Language_Package_Backend;
      Project_Path : String;
      Project_Name : String) is abstract;

   --  Add package to manifest (without installing)
   procedure Add_To_Manifest
     (Backend : in Out Language_Package_Backend;
      Package : Language_Package_Info;
      Context : Project_Context;
      Dev_Dep : Boolean := False) is abstract;

   ---------------------------------------------------------------------------
   --  Helper Functions
   ---------------------------------------------------------------------------

   function Has_Capability
     (Backend : Language_Package_Backend'Class;
      Cap     : Language_Backend_Capability)
      return Boolean;

   --  Get the appropriate backend for a language
   function Get_Backend_For_Language
     (Lang : Programming_Language)
      return access Language_Package_Backend'Class;

   --  Get backend by PM type
   function Get_Backend
     (PM : Language_Package_Manager)
      return access Language_Package_Backend'Class;

   --  Detect project context from current directory
   function Detect_Project_Context
      return Project_Context;

   ---------------------------------------------------------------------------
   --  Registry Information
   ---------------------------------------------------------------------------

   --  Get the default registry URL for a language PM
   function Default_Registry_URL
     (PM : Language_Package_Manager) return String is
     (case PM is
         when Cargo       => "https://crates.io",
         when Hex | Mix | Gleam => "https://hex.pm",
         when Cabal | Stack     => "https://hackage.haskell.org",
         when Julia_Pkg         => "https://juliahub.com",
         when Pip | Pip3 | Uv | Poetry | Pipx => "https://pypi.org",
         when Conda | Mamba     => "https://anaconda.org",
         when Gem | Bundler     => "https://rubygems.org",
         when Npm | Pnpm | Yarn | Bun => "https://npmjs.com",
         when Deno              => "https://jsr.io",
         when Go_Mod            => "https://pkg.go.dev",
         when Opam              => "https://opam.ocaml.org",
         when Nuget | Dotnet    => "https://nuget.org",
         when Maven             => "https://central.sonatype.com",
         when Composer          => "https://packagist.org",
         when Luarocks          => "https://luarocks.org",
         when Nimble            => "https://nimble.directory",
         when Pub               => "https://pub.dev",
         when Alire             => "https://alire.ada.dev",
         when Shards            => "https://shardbox.org",
         when others            => "");

   ---------------------------------------------------------------------------
   --  Manifest File Names
   ---------------------------------------------------------------------------

   function Manifest_File_Name
     (PM : Language_Package_Manager) return String is
     (case PM is
         when Cargo             => "Cargo.toml",
         when Hex | Mix         => "mix.exs",
         when Gleam             => "gleam.toml",
         when Rebar3            => "rebar.config",
         when Cabal             => "*.cabal",
         when Stack             => "stack.yaml",
         when Julia_Pkg         => "Project.toml",
         when Pip | Pip3 | Pipx => "requirements.txt",
         when Uv | Poetry       => "pyproject.toml",
         when Gem               => "*.gemspec",
         when Bundler           => "Gemfile",
         when Npm | Pnpm | Yarn | Bun => "package.json",
         when Deno              => "deno.json",
         when Go_Mod            => "go.mod",
         when Opam              => "*.opam",
         when Nuget             => "*.csproj",
         when Dotnet            => "*.csproj",
         when Maven             => "pom.xml",
         when Gradle            => "build.gradle",
         when Sbt               => "build.sbt",
         when Leiningen         => "project.clj",
         when Clojure_CLI       => "deps.edn",
         when Composer          => "composer.json",
         when Luarocks          => "*.rockspec",
         when Nimble            => "*.nimble",
         when Pub               => "pubspec.yaml",
         when Alire             => "alire.toml",
         when Shards            => "shard.yml",
         when Fpm               => "fpm.toml",
         when others            => "");

   function Lock_File_Name
     (PM : Language_Package_Manager) return String is
     (case PM is
         when Cargo             => "Cargo.lock",
         when Hex | Mix         => "mix.lock",
         when Gleam             => "manifest.toml",
         when Julia_Pkg         => "Manifest.toml",
         when Poetry            => "poetry.lock",
         when Uv                => "uv.lock",
         when Bundler           => "Gemfile.lock",
         when Npm               => "package-lock.json",
         when Pnpm              => "pnpm-lock.yaml",
         when Yarn              => "yarn.lock",
         when Bun               => "bun.lockb",
         when Deno              => "deno.lock",
         when Go_Mod            => "go.sum",
         when Composer          => "composer.lock",
         when Pub               => "pubspec.lock",
         when Shards            => "shard.lock",
         when others            => "");

private

   function Has_Capability
     (Backend : Language_Package_Backend'Class;
      Cap     : Language_Backend_Capability)
      return Boolean
   is (Backend.Capabilities (Cap));

end Language_Backend_Interface;
