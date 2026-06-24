-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Detection - OS, system package manager, and language package manager detection
pragma Ada_2022;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;

package Detection is

   ---------------------------------------------------------------------------
   --  Package Manager Categories
   ---------------------------------------------------------------------------

   --  High-level categorization of package managers
   type Package_Manager_Category is (
      System_PM,      --  OS-level package managers (apt, dnf, pacman, etc.)
      Language_PM,    --  Language-specific package managers (cargo, hex, etc.)
      Universal_PM    --  Cross-platform universal (flatpak, snap, appimage)
   );

   ---------------------------------------------------------------------------
   --  Operating System Detection
   ---------------------------------------------------------------------------

   --  Operating system family
   type OS_Family is (
      Linux,
      BSD,
      MacOS,
      Windows,
      Unknown_OS
   );

   --  Linux distribution identifiers
   type Linux_Distro is (
      Fedora,
      Fedora_Kinoite,      --  rpm-ostree based
      Fedora_Silverblue,   --  rpm-ostree based
      RHEL,
      Rocky,
      Alma,
      CentOS,
      CentOS_Stream,
      Debian,
      Ubuntu,
      Linux_Mint,
      Pop_OS,
      Elementary,
      Arch,
      Manjaro,
      EndeavourOS,
      OpenSUSE_Tumbleweed,
      OpenSUSE_Leap,
      SLE,                 --  SUSE Linux Enterprise
      Void,
      Alpine,
      Gentoo,
      Slackware,
      NixOS,
      Guix_System,
      Unknown_Distro
   );

   --  BSD variants
   type BSD_Variant is (
      FreeBSD,
      OpenBSD,
      NetBSD,
      DragonFlyBSD,
      Unknown_BSD
   );

   ---------------------------------------------------------------------------
   --  System Package Managers (OS-level)
   ---------------------------------------------------------------------------

   type System_Package_Manager is (
      --  RPM-based
      RPM_Ostree,          --  Fedora Kinoite/Silverblue (atomic)
      DNF,                 --  Fedora, RHEL 8+
      DNF5,                --  Fedora 41+
      Yum,                 --  RHEL 7, CentOS 7
      RPM_Raw,             --  Raw rpm command

      --  Debian-based
      APT,                 --  Debian, Ubuntu
      Aptitude,            --  Debian, Ubuntu (alternative TUI)
      Dpkg_Raw,            --  Raw dpkg command

      --  Arch-based
      Pacman,              --  Arch, Manjaro
      Paru,                --  AUR helper
      Yay,                 --  AUR helper

      --  SUSE
      Zypper,              --  openSUSE, SLE

      --  Other Linux
      XBPS,                --  Void Linux
      APK,                 --  Alpine Linux
      Portage,             --  Gentoo (emerge)
      Slackpkg,            --  Slackware
      Nix,                 --  NixOS / Nix package manager
      Guix,                --  Guix System / GNU Guix

      --  BSD
      Pkg_FreeBSD,         --  FreeBSD pkg
      Pkg_Add,             --  OpenBSD pkg_add
      Pkgin,               --  NetBSD pkgin
      Pkg_Info,            --  BSD pkg_info

      --  macOS
      Brew,                --  Homebrew
      MacPorts,            --  MacPorts

      --  Windows
      Winget,              --  Windows Package Manager
      Chocolatey,          --  Chocolatey
      Scoop,               --  Scoop

      --  Universal/Cross-platform
      Flatpak,             --  Flatpak (Linux)
      Snap,                --  Snapcraft (Ubuntu/Linux)
      AppImage,            --  AppImage (Linux)

      Unknown_System_PM
   );

   --  Backward compatibility alias
   subtype Package_Manager_Type is System_Package_Manager;

   ---------------------------------------------------------------------------
   --  Language Package Managers
   ---------------------------------------------------------------------------

   type Language_Package_Manager is (
      --  Rust
      Cargo,               --  Rust package manager (crates.io)

      --  Elixir / Erlang
      Hex,                 --  Hex.pm (Elixir/Erlang)
      Mix,                 --  Elixir build tool (uses Hex)
      Rebar3,              --  Erlang build tool

      --  Haskell
      Cabal,               --  Cabal (Hackage)
      Stack,               --  Haskell Stack
      GHCup,               --  GHC toolchain manager

      --  Julia
      Julia_Pkg,           --  Julia Pkg (General registry / JuliaHub)

      --  Python
      Pip,                 --  pip (PyPI)
      Pip3,                --  pip3 (Python 3)
      Uv,                  --  uv (fast Python package installer)
      Poetry,              --  Poetry
      Conda,               --  Conda / Anaconda / Miniconda
      Mamba,               --  Mamba (fast conda)
      Pipx,                --  pipx (isolated apps)

      --  Ruby
      Gem,                 --  RubyGems
      Bundler,             --  Bundler

      --  JavaScript / TypeScript
      Npm,                 --  npm (Node.js)
      Pnpm,                --  pnpm
      Yarn,                --  Yarn
      Bun,                 --  Bun
      Deno,                --  Deno (JSR / deno.land)

      --  Go
      Go_Mod,              --  Go modules

      --  OCaml
      Opam,                --  opam (OCaml)

      --  Gleam
      Gleam,               --  Gleam (uses Hex)

      --  .NET
      Nuget,               --  NuGet (.NET)
      Dotnet,              --  dotnet CLI

      --  Java / JVM
      Maven,               --  Apache Maven
      Gradle,              --  Gradle
      Sbt,                 --  sbt (Scala)
      Leiningen,           --  Leiningen (Clojure)
      Clojure_CLI,         --  Clojure CLI tools

      --  PHP
      Composer,            --  Composer (Packagist)

      --  Lua
      Luarocks,            --  LuaRocks

      --  Zig
      Zigmod,              --  Zigmod
      Gyro,                --  Gyro (Zig)

      --  Nim
      Nimble,              --  Nimble (Nim)

      --  D
      Dub,                 --  Dub (D)

      --  R
      R_Pkg,               --  R install.packages (CRAN)
      Renv,                --  renv

      --  Perl
      Cpan,                --  CPAN
      Cpanm,               --  cpanminus

      --  Swift
      Swift_PM,            --  Swift Package Manager

      --  Dart / Flutter
      Pub,                 --  pub (pub.dev)

      --  Fortran
      Fpm,                 --  Fortran Package Manager

      --  V
      Vpm,                 --  V Package Manager

      --  Crystal
      Shards,              --  Shards (Crystal)

      --  Racket
      Raco,                --  raco pkg (Racket)

      --  Common Lisp
      Quicklisp,           --  Quicklisp

      --  Scheme (various)
      Akku,                --  Akku (R6RS/R7RS Scheme)

      --  Ada
      Alire,               --  Alire (Ada)

      Unknown_Language_PM
   );

   ---------------------------------------------------------------------------
   --  Language Ecosystem Information
   ---------------------------------------------------------------------------

   type Programming_Language is (
      Lang_Ada,
      Lang_C,
      Lang_Cpp,
      Lang_Clojure,
      Lang_Crystal,
      Lang_D,
      Lang_Dart,
      Lang_Elixir,
      Lang_Erlang,
      Lang_Fortran,
      Lang_Gleam,
      Lang_Go,
      Lang_Haskell,
      Lang_Java,
      Lang_JavaScript,
      Lang_Julia,
      Lang_Kotlin,
      Lang_Lisp,
      Lang_Lua,
      Lang_Nim,
      Lang_OCaml,
      Lang_Perl,
      Lang_PHP,
      Lang_Python,
      Lang_R,
      Lang_Racket,
      Lang_Ruby,
      Lang_Rust,
      Lang_Scala,
      Lang_Scheme,
      Lang_Swift,
      Lang_TypeScript,
      Lang_V,
      Lang_Zig,
      Lang_Unknown
   );

   --  Map language PM to its primary language
   function PM_Language (PM : Language_Package_Manager) return Programming_Language;

   ---------------------------------------------------------------------------
   --  System Information
   ---------------------------------------------------------------------------

   type System_Info is record
      OS           : OS_Family := Unknown_OS;
      Distro       : Linux_Distro := Unknown_Distro;
      BSD_Type     : BSD_Variant := Unknown_BSD;
      PM           : System_Package_Manager := Unknown_System_PM;
      OS_Name      : Unbounded_String;
      OS_Version   : Unbounded_String;
      OS_ID        : Unbounded_String;
      Kernel       : Unbounded_String;
      Arch         : Unbounded_String;
      Is_Atomic    : Boolean := False;      --  Immutable OS (rpm-ostree, etc)
      Is_Container : Boolean := False;      --  Running in container
   end record;

   --  Cached system info (computed once)
   Cached_Info : System_Info;
   Cache_Valid : Boolean := False;

   ---------------------------------------------------------------------------
   --  Detection Functions - System
   ---------------------------------------------------------------------------

   function Detect_OS return OS_Family;
   function Detect_Linux_Distro return Linux_Distro;
   function Detect_BSD_Variant return BSD_Variant;
   function Detect_Package_Manager return System_Package_Manager;
   function Get_System_Info return System_Info;
   procedure Refresh_System_Info;
   function Is_Atomic_System return Boolean;
   function Is_Container return Boolean;
   function Get_OS_Version return String;
   function Get_Kernel_Version return String;
   function Get_Architecture return String;

   ---------------------------------------------------------------------------
   --  Detection Functions - Language Package Managers
   ---------------------------------------------------------------------------

   --  Check if a specific language PM is available on the system
   function Language_PM_Available (PM : Language_Package_Manager) return Boolean;

   --  Detect all available language package managers
   type Language_PM_Array is array (Positive range <>) of Language_Package_Manager;
   function Detect_Language_Package_Managers return Language_PM_Array;

   --  Get the primary PM for a language (if installed)
   function Get_Primary_PM_For_Language
     (Lang : Programming_Language) return Language_Package_Manager;

   ---------------------------------------------------------------------------
   --  Availability Checks
   ---------------------------------------------------------------------------

   function PM_Available (PM : System_Package_Manager) return Boolean;

   ---------------------------------------------------------------------------
   --  Helper Functions
   ---------------------------------------------------------------------------

   function "+" (S : String) return Unbounded_String
      renames To_Unbounded_String;

   function "-" (U : Unbounded_String) return String
      renames To_String;

   ---------------------------------------------------------------------------
   --  Display Names
   ---------------------------------------------------------------------------

   function PM_Name (PM : System_Package_Manager) return String is
     (case PM is
         when RPM_Ostree     => "rpm-ostree",
         when DNF            => "dnf",
         when DNF5           => "dnf5",
         when Yum            => "yum",
         when RPM_Raw        => "rpm",
         when APT            => "apt",
         when Aptitude       => "aptitude",
         when Dpkg_Raw       => "dpkg",
         when Pacman         => "pacman",
         when Paru           => "paru",
         when Yay            => "yay",
         when Zypper         => "zypper",
         when XBPS           => "xbps",
         when APK            => "apk",
         when Portage        => "emerge",
         when Slackpkg       => "slackpkg",
         when Nix            => "nix",
         when Guix           => "guix",
         when Pkg_FreeBSD    => "pkg",
         when Pkg_Add        => "pkg_add",
         when Pkgin          => "pkgin",
         when Pkg_Info       => "pkg_info",
         when Brew           => "brew",
         when MacPorts       => "port",
         when Winget         => "winget",
         when Chocolatey     => "choco",
         when Scoop          => "scoop",
         when Flatpak        => "flatpak",
         when Snap           => "snap",
         when AppImage       => "appimage",
         when Unknown_System_PM => "unknown");

   function PM_Name (PM : Language_Package_Manager) return String is
     (case PM is
         when Cargo          => "cargo",
         when Hex            => "hex",
         when Mix            => "mix",
         when Rebar3         => "rebar3",
         when Cabal          => "cabal",
         when Stack          => "stack",
         when GHCup          => "ghcup",
         when Julia_Pkg      => "julia -e 'using Pkg'",
         when Pip            => "pip",
         when Pip3           => "pip3",
         when Uv             => "uv",
         when Poetry         => "poetry",
         when Conda          => "conda",
         when Mamba          => "mamba",
         when Pipx           => "pipx",
         when Gem            => "gem",
         when Bundler        => "bundle",
         when Npm            => "npm",
         when Pnpm           => "pnpm",
         when Yarn           => "yarn",
         when Bun            => "bun",
         when Deno           => "deno",
         when Go_Mod         => "go",
         when Opam           => "opam",
         when Gleam          => "gleam",
         when Nuget          => "nuget",
         when Dotnet         => "dotnet",
         when Maven          => "mvn",
         when Gradle         => "gradle",
         when Sbt            => "sbt",
         when Leiningen      => "lein",
         when Clojure_CLI    => "clj",
         when Composer       => "composer",
         when Luarocks       => "luarocks",
         when Zigmod         => "zigmod",
         when Gyro           => "gyro",
         when Nimble         => "nimble",
         when Dub            => "dub",
         when R_Pkg          => "R",
         when Renv           => "renv",
         when Cpan           => "cpan",
         when Cpanm          => "cpanm",
         when Swift_PM       => "swift",
         when Pub            => "pub",
         when Fpm            => "fpm",
         when Vpm            => "v",
         when Shards         => "shards",
         when Raco           => "raco",
         when Quicklisp      => "quicklisp",
         when Akku           => "akku",
         when Alire          => "alr",
         when Unknown_Language_PM => "unknown");

   ---------------------------------------------------------------------------
   --  Capability Queries
   ---------------------------------------------------------------------------

   --  Check if system PM supports native snapshots
   function PM_Has_Native_Snapshots (PM : System_Package_Manager) return Boolean
   is
     (PM in RPM_Ostree | Zypper | Nix | Guix);

   --  Check if system PM is atomic/transactional
   function PM_Is_Atomic (PM : System_Package_Manager) return Boolean
   is
     (PM in RPM_Ostree | Nix | Guix | Flatpak | Snap);

   --  Get category for a system PM
   function PM_Category (PM : System_Package_Manager) return Package_Manager_Category
   is
     (case PM is
         when Flatpak | Snap | AppImage => Universal_PM,
         when others                    => System_PM);

end Detection;
