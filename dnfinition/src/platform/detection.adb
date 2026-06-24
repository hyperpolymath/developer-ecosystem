-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Detection - Implementation
pragma Ada_2022;

with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;

package body Detection is

   --  File reading utility
   function Read_File_First_Line (Path : String) return String is
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
      begin
         Ada.Text_IO.Close (File);
         return Line;
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Read_File_First_Line;

   --  Check if a command exists
   function Command_Exists (Cmd : String) return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path (Cmd);
      if Path /= null then
         GNAT.OS_Lib.Free (Path);
         return True;
      end if;
      return False;
   end Command_Exists;

   --  Parse key=value from os-release
   function Parse_OS_Release_Value
     (Path : String;
      Key  : String)
      return String
   is
      use Ada.Strings.Fixed;
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line   : constant String := Ada.Text_IO.Get_Line (File);
            Eq_Pos : constant Natural := Index (Line, "=");
         begin
            if Eq_Pos > 0 then
               declare
                  Line_Key : constant String := Line (Line'First .. Eq_Pos - 1);
                  Value    : constant String := Line (Eq_Pos + 1 .. Line'Last);
               begin
                  if Line_Key = Key then
                     Ada.Text_IO.Close (File);
                     --  Strip quotes if present
                     if Value'Length >= 2
                       and then Value (Value'First) = '"'
                       and then Value (Value'Last) = '"'
                     then
                        return Value (Value'First + 1 .. Value'Last - 1);
                     else
                        return Value;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Parse_OS_Release_Value;

   ---------------
   -- Detect_OS
   ---------------

   function Detect_OS return OS_Family is
   begin
      --  Check for Linux first (most common)
      if Ada.Directories.Exists ("/proc/version") then
         return Linux;
      end if;

      --  Check for macOS
      if Ada.Directories.Exists ("/System/Library/CoreServices") then
         return MacOS;
      end if;

      --  Check for Windows
      if Ada.Directories.Exists ("C:\Windows") then
         return Windows;
      end if;

      --  Check for BSD variants
      if Ada.Directories.Exists ("/etc/rc.conf") then
         if Ada.Directories.Exists ("/etc/freebsd-update.conf") then
            return BSD;
         elsif Ada.Directories.Exists ("/etc/myname") then
            return BSD;  --  OpenBSD
         elsif Ada.Directories.Exists ("/etc/rc.d/rc.conf") then
            return BSD;  --  NetBSD
         end if;
      end if;

      return Unknown_OS;
   end Detect_OS;

   -------------------------
   -- Detect_Linux_Distro
   -------------------------

   function Detect_Linux_Distro return Linux_Distro is
      use Ada.Strings.Fixed;
      ID         : constant String := Parse_OS_Release_Value
                     ("/etc/os-release", "ID");
      Variant_ID : constant String := Parse_OS_Release_Value
                     ("/etc/os-release", "VARIANT_ID");
   begin
      --  Check for atomic variants first
      if Index (Variant_ID, "kinoite") > 0 then
         return Fedora_Kinoite;
      elsif Index (Variant_ID, "silverblue") > 0 then
         return Fedora_Silverblue;
      end if;

      --  Main distribution detection
      if ID = "fedora" then
         return Fedora;
      elsif ID = "rhel" then
         return RHEL;
      elsif ID = "rocky" then
         return Rocky;
      elsif ID = "almalinux" then
         return Alma;
      elsif ID = "centos" then
         if Index (Parse_OS_Release_Value ("/etc/os-release", "NAME"),
                   "Stream") > 0
         then
            return CentOS_Stream;
         else
            return CentOS;
         end if;
      elsif ID = "debian" then
         return Debian;
      elsif ID = "ubuntu" then
         return Ubuntu;
      elsif ID = "linuxmint" then
         return Linux_Mint;
      elsif ID = "pop" then
         return Pop_OS;
      elsif ID = "elementary" then
         return Elementary;
      elsif ID = "arch" then
         return Arch;
      elsif ID = "manjaro" then
         return Manjaro;
      elsif ID = "endeavouros" then
         return EndeavourOS;
      elsif ID = "opensuse-tumbleweed" then
         return OpenSUSE_Tumbleweed;
      elsif ID = "opensuse-leap" then
         return OpenSUSE_Leap;
      elsif ID = "sles" or ID = "sled" then
         return SLE;
      elsif ID = "void" then
         return Void;
      elsif ID = "alpine" then
         return Alpine;
      elsif ID = "gentoo" then
         return Gentoo;
      elsif ID = "slackware" then
         return Slackware;
      elsif ID = "nixos" then
         return NixOS;
      elsif ID = "guix" then
         return Guix_System;
      end if;

      return Unknown_Distro;
   end Detect_Linux_Distro;

   ------------------------
   -- Detect_BSD_Variant
   ------------------------

   function Detect_BSD_Variant return BSD_Variant is
   begin
      if Ada.Directories.Exists ("/etc/freebsd-update.conf") then
         return FreeBSD;
      elsif Ada.Directories.Exists ("/etc/myname")
        and then Ada.Directories.Exists ("/bsd")
      then
         return OpenBSD;
      elsif Ada.Directories.Exists ("/netbsd")
        or else Ada.Directories.Exists ("/etc/rc.d/rc.conf")
      then
         return NetBSD;
      elsif Ada.Directories.Exists ("/etc/defaults/hammer.conf") then
         return DragonFlyBSD;
      end if;
      return Unknown_BSD;
   end Detect_BSD_Variant;

   ----------------------------
   -- Detect_Package_Manager
   ----------------------------

   function Detect_Package_Manager return Package_Manager_Type is
      OS     : constant OS_Family := Detect_OS;
      Distro : Linux_Distro;
   begin
      case OS is
         when Linux =>
            Distro := Detect_Linux_Distro;

            --  Atomic variants use rpm-ostree
            if Distro in Fedora_Kinoite | Fedora_Silverblue then
               return RPM_Ostree;
            end if;

            --  Check for rpm-ostree on other systems
            if Command_Exists ("rpm-ostree")
              and then Ada.Directories.Exists ("/ostree")
            then
               return RPM_Ostree;
            end if;

            --  Fedora/RHEL family
            if Distro in Fedora | RHEL | Rocky | Alma | CentOS | CentOS_Stream
            then
               if Command_Exists ("dnf5") then
                  return DNF5;
               elsif Command_Exists ("dnf") then
                  return DNF;
               elsif Command_Exists ("yum") then
                  return Yum;
               end if;
            end if;

            --  Debian family
            if Distro in Debian | Ubuntu | Linux_Mint | Pop_OS | Elementary
            then
               return APT;
            end if;

            --  Arch family
            if Distro in Arch | Manjaro | EndeavourOS then
               return Pacman;
            end if;

            --  SUSE family
            if Distro in OpenSUSE_Tumbleweed | OpenSUSE_Leap | SLE then
               return Zypper;
            end if;

            --  Other distros
            case Distro is
               when Void        => return XBPS;
               when Alpine      => return APK;
               when Gentoo      => return Portage;
               when Slackware   => return Slackpkg;
               when NixOS       => return Nix;
               when Guix_System => return Guix;
               when others      => null;
            end case;

            --  Fallback: check for common package managers
            if Command_Exists ("dnf") then
               return DNF;
            elsif Command_Exists ("apt") then
               return APT;
            elsif Command_Exists ("pacman") then
               return Pacman;
            elsif Command_Exists ("zypper") then
               return Zypper;
            end if;

         when BSD =>
            case Detect_BSD_Variant is
               when FreeBSD | DragonFlyBSD =>
                  return Pkg_FreeBSD;
               when OpenBSD =>
                  return Pkg_Add;
               when NetBSD =>
                  return Pkgin;
               when Unknown_BSD =>
                  if Command_Exists ("pkg") then
                     return Pkg_FreeBSD;
                  end if;
            end case;

         when MacOS =>
            if Command_Exists ("brew") then
               return Brew;
            elsif Command_Exists ("port") then
               return MacPorts;
            end if;

         when Windows =>
            if Command_Exists ("winget") then
               return Winget;
            elsif Command_Exists ("choco") then
               return Chocolatey;
            elsif Command_Exists ("scoop") then
               return Scoop;
            end if;

         when Unknown_OS =>
            null;
      end case;

      return Unknown_PM;
   end Detect_Package_Manager;

   ---------------------
   -- Get_System_Info
   ---------------------

   function Get_System_Info return System_Info is
   begin
      if Cache_Valid then
         return Cached_Info;
      end if;

      Refresh_System_Info;
      return Cached_Info;
   end Get_System_Info;

   -------------------------
   -- Refresh_System_Info
   -------------------------

   procedure Refresh_System_Info is
      Info : System_Info;
   begin
      Info.OS := Detect_OS;

      case Info.OS is
         when Linux =>
            Info.Distro := Detect_Linux_Distro;
            Info.OS_Name := +Parse_OS_Release_Value
              ("/etc/os-release", "PRETTY_NAME");
            Info.OS_Version := +Parse_OS_Release_Value
              ("/etc/os-release", "VERSION_ID");
            Info.OS_ID := +Parse_OS_Release_Value
              ("/etc/os-release", "ID");
            Info.Kernel := +Read_File_First_Line ("/proc/version");

            --  Check for atomic systems
            Info.Is_Atomic := Info.Distro in Fedora_Kinoite | Fedora_Silverblue
              or else Ada.Directories.Exists ("/ostree");

         when BSD =>
            Info.BSD_Type := Detect_BSD_Variant;

         when MacOS =>
            Info.OS_Name := +"macOS";

         when Windows =>
            Info.OS_Name := +"Windows";

         when Unknown_OS =>
            null;
      end case;

      Info.PM := Detect_Package_Manager;
      Info.Is_Container := Is_Container;

      --  Get architecture
      Info.Arch := +Get_Architecture;

      Cached_Info := Info;
      Cache_Valid := True;
   end Refresh_System_Info;

   ----------------------
   -- Is_Atomic_System
   ----------------------

   function Is_Atomic_System return Boolean is
   begin
      return Get_System_Info.Is_Atomic;
   end Is_Atomic_System;

   ------------------
   -- Is_Container
   ------------------

   function Is_Container return Boolean is
   begin
      --  Check for Docker
      if Ada.Directories.Exists ("/.dockerenv") then
         return True;
      end if;

      --  Check for Podman/systemd-nspawn
      if Ada.Directories.Exists ("/run/.containerenv") then
         return True;
      end if;

      --  Check cgroup for container runtime
      declare
         Cgroup : constant String := Read_File_First_Line
           ("/proc/1/cgroup");
         use Ada.Strings.Fixed;
      begin
         if Index (Cgroup, "docker") > 0
           or else Index (Cgroup, "lxc") > 0
           or else Index (Cgroup, "kubepods") > 0
         then
            return True;
         end if;
      end;

      return False;
   end Is_Container;

   --------------------
   -- Get_OS_Version
   --------------------

   function Get_OS_Version return String is
   begin
      return -Get_System_Info.OS_Version;
   end Get_OS_Version;

   ------------------------
   -- Get_Kernel_Version
   ------------------------

   function Get_Kernel_Version return String is
   begin
      return -Get_System_Info.Kernel;
   end Get_Kernel_Version;

   ----------------------
   -- Get_Architecture
   ----------------------

   function Get_Architecture return String is
   begin
      --  On Linux, read from uname
      if Ada.Directories.Exists ("/proc/sys/kernel/osrelease") then
         --  Try common architecture indicators
         if Ada.Directories.Exists ("/lib64") then
            --  Could be x86_64 or aarch64
            if Ada.Directories.Exists ("/lib/aarch64-linux-gnu") then
               return "aarch64";
            else
               return "x86_64";
            end if;
         elsif Ada.Directories.Exists ("/lib/arm-linux-gnueabihf") then
            return "armv7l";
         else
            return "i686";  --  Default to 32-bit
         end if;
      end if;
      return "unknown";
   end Get_Architecture;

   -------------------
   -- PM_Available
   -------------------

   function PM_Available (PM : System_Package_Manager) return Boolean is
   begin
      return Command_Exists (PM_Name (PM));
   end PM_Available;

   ---------------------------------------------------------------------------
   --  Language Package Manager Detection
   ---------------------------------------------------------------------------

   function Language_PM_Available (PM : Language_Package_Manager) return Boolean is
   begin
      case PM is
         --  Special cases that need more than just command check
         when Julia_Pkg =>
            return Command_Exists ("julia");
         when R_Pkg | Renv =>
            return Command_Exists ("R") or else Command_Exists ("Rscript");
         when Quicklisp =>
            --  Quicklisp is loaded into a Lisp, check for sbcl/ccl
            return Command_Exists ("sbcl") or else Command_Exists ("ccl");
         when others =>
            return Command_Exists (PM_Name (PM));
      end case;
   end Language_PM_Available;

   function Detect_Language_Package_Managers return Language_PM_Array is
      --  Count available PMs first
      Count : Natural := 0;
   begin
      for PM in Language_Package_Manager'Range loop
         if PM /= Unknown_Language_PM and then Language_PM_Available (PM) then
            Count := Count + 1;
         end if;
      end loop;

      --  Build result array
      declare
         Result : Language_PM_Array (1 .. Count);
         Idx    : Positive := 1;
      begin
         for PM in Language_Package_Manager'Range loop
            if PM /= Unknown_Language_PM and then Language_PM_Available (PM) then
               Result (Idx) := PM;
               Idx := Idx + 1;
            end if;
         end loop;
         return Result;
      end;
   end Detect_Language_Package_Managers;

   function Get_Primary_PM_For_Language
     (Lang : Programming_Language) return Language_Package_Manager
   is
   begin
      --  Return the primary/preferred PM for each language
      case Lang is
         when Lang_Rust =>
            if Language_PM_Available (Cargo) then return Cargo; end if;
         when Lang_Elixir =>
            if Language_PM_Available (Mix) then return Mix; end if;
         when Lang_Erlang =>
            if Language_PM_Available (Rebar3) then return Rebar3; end if;
         when Lang_Haskell =>
            if Language_PM_Available (Cabal) then return Cabal;
            elsif Language_PM_Available (Stack) then return Stack;
            end if;
         when Lang_Julia =>
            if Language_PM_Available (Julia_Pkg) then return Julia_Pkg; end if;
         when Lang_Python =>
            if Language_PM_Available (Uv) then return Uv;
            elsif Language_PM_Available (Poetry) then return Poetry;
            elsif Language_PM_Available (Pip3) then return Pip3;
            elsif Language_PM_Available (Pip) then return Pip;
            end if;
         when Lang_Ruby =>
            if Language_PM_Available (Bundler) then return Bundler;
            elsif Language_PM_Available (Gem) then return Gem;
            end if;
         when Lang_JavaScript | Lang_TypeScript =>
            if Language_PM_Available (Deno) then return Deno;
            elsif Language_PM_Available (Pnpm) then return Pnpm;
            elsif Language_PM_Available (Npm) then return Npm;
            end if;
         when Lang_Go =>
            if Language_PM_Available (Go_Mod) then return Go_Mod; end if;
         when Lang_OCaml =>
            if Language_PM_Available (Opam) then return Opam; end if;
         when Lang_Gleam =>
            if Language_PM_Available (Gleam) then return Gleam; end if;
         when Lang_PHP =>
            if Language_PM_Available (Composer) then return Composer; end if;
         when Lang_Lua =>
            if Language_PM_Available (Luarocks) then return Luarocks; end if;
         when Lang_Zig =>
            if Language_PM_Available (Zigmod) then return Zigmod; end if;
         when Lang_Nim =>
            if Language_PM_Available (Nimble) then return Nimble; end if;
         when Lang_D =>
            if Language_PM_Available (Dub) then return Dub; end if;
         when Lang_R =>
            if Language_PM_Available (Renv) then return Renv;
            elsif Language_PM_Available (R_Pkg) then return R_Pkg;
            end if;
         when Lang_Perl =>
            if Language_PM_Available (Cpanm) then return Cpanm;
            elsif Language_PM_Available (Cpan) then return Cpan;
            end if;
         when Lang_Swift =>
            if Language_PM_Available (Swift_PM) then return Swift_PM; end if;
         when Lang_Dart =>
            if Language_PM_Available (Pub) then return Pub; end if;
         when Lang_Fortran =>
            if Language_PM_Available (Fpm) then return Fpm; end if;
         when Lang_V =>
            if Language_PM_Available (Vpm) then return Vpm; end if;
         when Lang_Crystal =>
            if Language_PM_Available (Shards) then return Shards; end if;
         when Lang_Racket =>
            if Language_PM_Available (Raco) then return Raco; end if;
         when Lang_Lisp =>
            if Language_PM_Available (Quicklisp) then return Quicklisp; end if;
         when Lang_Scheme =>
            if Language_PM_Available (Akku) then return Akku; end if;
         when Lang_Ada =>
            if Language_PM_Available (Alire) then return Alire; end if;
         when Lang_Java | Lang_Kotlin =>
            if Language_PM_Available (Maven) then return Maven;
            elsif Language_PM_Available (Gradle) then return Gradle;
            end if;
         when Lang_Scala =>
            if Language_PM_Available (Sbt) then return Sbt; end if;
         when Lang_Clojure =>
            if Language_PM_Available (Clojure_CLI) then return Clojure_CLI;
            elsif Language_PM_Available (Leiningen) then return Leiningen;
            end if;
         when others =>
            null;
      end case;
      return Unknown_Language_PM;
   end Get_Primary_PM_For_Language;

   function PM_Language (PM : Language_Package_Manager) return Programming_Language
   is
   begin
      case PM is
         when Cargo => return Lang_Rust;
         when Hex | Mix => return Lang_Elixir;
         when Rebar3 => return Lang_Erlang;
         when Cabal | Stack | GHCup => return Lang_Haskell;
         when Julia_Pkg => return Lang_Julia;
         when Pip | Pip3 | Uv | Poetry | Conda | Mamba | Pipx => return Lang_Python;
         when Gem | Bundler => return Lang_Ruby;
         when Npm | Pnpm | Yarn | Bun => return Lang_JavaScript;
         when Deno => return Lang_TypeScript;
         when Go_Mod => return Lang_Go;
         when Opam => return Lang_OCaml;
         when Gleam => return Lang_Gleam;
         when Nuget | Dotnet => return Lang_Cpp;  -- .NET/C#
         when Maven | Gradle => return Lang_Java;
         when Sbt => return Lang_Scala;
         when Leiningen | Clojure_CLI => return Lang_Clojure;
         when Composer => return Lang_PHP;
         when Luarocks => return Lang_Lua;
         when Zigmod | Gyro => return Lang_Zig;
         when Nimble => return Lang_Nim;
         when Dub => return Lang_D;
         when R_Pkg | Renv => return Lang_R;
         when Cpan | Cpanm => return Lang_Perl;
         when Swift_PM => return Lang_Swift;
         when Pub => return Lang_Dart;
         when Fpm => return Lang_Fortran;
         when Vpm => return Lang_V;
         when Shards => return Lang_Crystal;
         when Raco => return Lang_Racket;
         when Quicklisp => return Lang_Lisp;
         when Akku => return Lang_Scheme;
         when Alire => return Lang_Ada;
         when Unknown_Language_PM => return Lang_Unknown;
      end case;
   end PM_Language;

end Detection;
