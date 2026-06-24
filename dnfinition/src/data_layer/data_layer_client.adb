-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
--
-- Data Layer Client Implementation
pragma Ada_2022;

with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Directories;
with Ada.Environment_Variables;
with GNAT.Expect;
with GNAT.OS_Lib;
with JSON_Utils;

package body Data_Layer_Client is

   use Ada.Text_IO;

   --  Port descriptor for Elixir process
   Port_Descriptor : GNAT.Expect.Process_Descriptor;
   Port_Started    : Boolean := False;

   --  Data directory
   function Get_Data_Dir return String is
      Default : constant String := "/var/lib/dnfinition";
   begin
      if Ada.Environment_Variables.Exists ("DNFINITION_DATA_DIR") then
         return Ada.Environment_Variables.Value ("DNFINITION_DATA_DIR");
      else
         return Default;
      end if;
   end Get_Data_Dir;

   --  Find the Elixir release executable
   function Find_Elixir_Release return String is
      Locations : constant array (1 .. 4) of String (1 .. 80) := (
         "/usr/lib/dnfinition/bin/dnfinition_data                                        ",
         "/opt/dnfinition/bin/dnfinition_data                                            ",
         "./bin/dnfinition_data                                                          ",
         "./_build/prod/rel/dnfinition_data/bin/dnfinition_data                          "
      );
   begin
      for Loc of Locations loop
         declare
            Path : constant String := Ada.Strings.Fixed.Trim (Loc, Ada.Strings.Right);
         begin
            if Ada.Directories.Exists (Path) then
               return Path;
            end if;
         end;
      end loop;
      return "";
   end Find_Elixir_Release;

   ---------------------------------------------------------------------------
   -- Initialization
   ---------------------------------------------------------------------------

   procedure Initialize is
      use GNAT.Expect;
      Elixir_Path : constant String := Find_Elixir_Release;
   begin
      if Elixir_Path = "" then
         --  Elixir release not found, run in degraded mode
         Put_Line (Standard_Error, "Warning: Data layer not available (Elixir release not found)");
         Data_Layer_Available := False;
         return;
      end if;

      --  Start the Elixir port process
      declare
         Args : constant GNAT.OS_Lib.Argument_List :=
           (1 => new String'("eval"),
            2 => new String'("Dnfinition.Port.Server.start_link()"));
         Env  : constant GNAT.OS_Lib.String_Access :=
           new String'("DNFINITION_PORT_MODE=1 DNFINITION_DATA_DIR=" & Get_Data_Dir);
      begin
         Non_Blocking_Spawn
           (Descriptor  => Port_Descriptor,
            Command     => Elixir_Path,
            Args        => Args,
            Buffer_Size => 65536,
            Err_To_Out  => True);

         Port_Started := True;
         Data_Layer_Available := True;

         --  Verify connection with ping
         if not Ping then
            Put_Line (Standard_Error, "Warning: Data layer ping failed");
            Data_Layer_Available := False;
         end if;
      exception
         when E : others =>
            Put_Line (Standard_Error, "Data layer init error: " &
                     Ada.Exceptions.Exception_Message (E));
            Data_Layer_Available := False;
      end;
   end Initialize;

   function Is_Available return Boolean is
   begin
      return Data_Layer_Available;
   end Is_Available;

   procedure Shutdown is
      use GNAT.Expect;
      Status : Integer;
   begin
      if Port_Started then
         Close (Port_Descriptor, Status);
         Port_Started := False;
         Data_Layer_Available := False;
      end if;
   end Shutdown;

   ---------------------------------------------------------------------------
   -- JSON Communication
   ---------------------------------------------------------------------------

   function Send_Request (Operation : String; Args : String := "{}") return String is
      use GNAT.Expect;
      Request  : constant String := "{""op"":""" & Operation & """,""args"":" & Args & "}" & ASCII.LF;
      Match    : Expect_Match;
      Response : Unbounded_String;
   begin
      if not Data_Layer_Available then
         return "{""status"":""error"",""error"":""not_available""}";
      end if;

      --  Send request
      Send (Port_Descriptor, Request);

      --  Read response (single line JSON)
      begin
         Expect (Port_Descriptor, Match, ".*" & ASCII.LF, Timeout => 5000);
         Response := To_Unbounded_String (Expect_Out (Port_Descriptor));
      exception
         when Process_Died =>
            Data_Layer_Available := False;
            return "{""status"":""error"",""error"":""process_died""}";
      end;

      return To_String (Response);
   end Send_Request;

   function Parse_Response (Response : String) return Call_Result is
      use JSON_Utils;
      JSON : constant JSON_Value := Try_Parse (Response);
      Resp_Status : constant Response_Status := Get_Response_Status (JSON);
   begin
      case Resp_Status is
         when OK =>
            return (Status => Success);
         when Error_Response =>
            declare
               Err_Msg : constant String := Get_Error_Message (JSON);
            begin
               return (Status => Error,
                       Error_Code => To_Unbounded_String (Err_Msg),
                       Error_Message => To_Unbounded_String (Err_Msg));
            end;
         when Invalid_Response =>
            return (Status => Error,
                    Error_Code => To_Unbounded_String ("parse_error"),
                    Error_Message => To_Unbounded_String ("Invalid response format"));
      end case;
   end Parse_Response;

   ---------------------------------------------------------------------------
   -- Transaction Operations
   ---------------------------------------------------------------------------

   function Begin_Transaction
     (Description : String;
      User        : String := "") return Transaction_ID
   is
      use JSON_Utils;
      User_Str : constant String := (if User = "" then
                                        Ada.Environment_Variables.Value ("USER", "unknown")
                                     else User);
      Args : JSON_Value := Empty_Object;
   begin
      Set_Field (Args, "description", Description);
      Set_Field (Args, "user", User_Str);

      declare
         Response : constant String := Send_Request ("tx:begin", To_String (Args));
         JSON     : constant JSON_Value := Try_Parse (Response);
         ID       : constant Natural := Get_ID (JSON);
      begin
         if ID > 0 then
            return Transaction_ID (ID);
         else
            return 1;  -- Default fallback
         end if;
      end;
   end Begin_Transaction;

   procedure Add_Operation
     (TX_ID       : Transaction_ID;
      Op_Type     : Operation_Type;
      Package     : String;
      Old_Version : String := "";
      New_Version : String := "")
   is
      use JSON_Utils;
      Op_Obj : JSON_Value := Empty_Object;
      Args   : JSON_Value := Empty_Object;
   begin
      --  Build nested operation object
      Set_Field (Op_Obj, "type", Operation_Type'Image (Op_Type));
      Set_Field (Op_Obj, "package", Package);
      Set_Field (Op_Obj, "old_version", Old_Version);
      Set_Field (Op_Obj, "new_version", New_Version);

      --  Build args with tx_id and operation
      Set_Field (Args, "tx_id", Integer (TX_ID));
      Args.Set_Field ("operation", Op_Obj);

      declare
         Response : constant String := Send_Request ("tx:add_op", To_String (Args));
         pragma Unreferenced (Response);
      begin
         null;
      end;
   end Add_Operation;

   function Commit_Transaction
     (TX_ID       : Transaction_ID;
      Snapshot_ID : Natural := 0) return Call_Result
   is
      use JSON_Utils;
      Args : JSON_Value := Empty_Object;
   begin
      Set_Field (Args, "tx_id", Integer (TX_ID));
      if Snapshot_ID > 0 then
         Set_Field (Args, "snapshot_id", Integer (Snapshot_ID));
      end if;
      return Parse_Response (Send_Request ("tx:commit", To_String (Args)));
   end Commit_Transaction;

   function Fail_Transaction
     (TX_ID   : Transaction_ID;
      Message : String := "") return Call_Result
   is
      Args : constant String :=
        "{""tx_id"":" & Transaction_ID'Image (TX_ID) &
        (if Message /= "" then ",""message"":""" & Message & """" else "") &
        "}";
   begin
      return Parse_Response (Send_Request ("tx:fail", Args));
   end Fail_Transaction;

   function Cancel_Transaction (TX_ID : Transaction_ID) return Call_Result is
      Args : constant String := "{""tx_id"":" & Transaction_ID'Image (TX_ID) & "}";
   begin
      return Parse_Response (Send_Request ("tx:cancel", Args));
   end Cancel_Transaction;

   function Get_Transaction (TX_ID : Transaction_ID) return Transaction_Record is
      Args     : constant String := "{""tx_id"":" & Transaction_ID'Image (TX_ID) & "}";
      Response : constant String := Send_Request ("tx:get", Args);
      Result   : Transaction_Record;
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse JSON response into Transaction_Record
      Result.ID := TX_ID;
      return Result;
   end Get_Transaction;

   function List_Transactions
     (Limit  : Positive := 100;
      Status : Transaction_Status := Pending) return Operation_Vectors.Vector
   is
      pragma Unreferenced (Limit, Status);
   begin
      --  TODO: Implement full parsing
      return Operation_Vectors.Empty_Vector;
   end List_Transactions;

   function Reverse_Transaction (TX_ID : Transaction_ID) return Call_Result is
      Args : constant String := "{""tx_id"":" & Transaction_ID'Image (TX_ID) & "}";
   begin
      return Parse_Response (Send_Request ("tx:reverse", Args));
   end Reverse_Transaction;

   function Replay_Transaction (TX_ID : Transaction_ID) return Call_Result is
      Args : constant String := "{""tx_id"":" & Transaction_ID'Image (TX_ID) & "}";
   begin
      return Parse_Response (Send_Request ("tx:replay", Args));
   end Replay_Transaction;

   function Current_Transaction return Transaction_Record is
      Response : constant String := Send_Request ("tx:current");
      Result   : Transaction_Record;
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse JSON response
      return Result;
   end Current_Transaction;

   function Can_Reverse (TX_ID : Transaction_ID) return Boolean is
      TX : constant Transaction_Record := Get_Transaction (TX_ID);
   begin
      return TX.Status = Completed;
   end Can_Reverse;

   ---------------------------------------------------------------------------
   -- Snapshot Operations
   ---------------------------------------------------------------------------

   function Create_Snapshot
     (Name          : String;
      Description   : String := "";
      Snap_Type     : Snapshot_Type := Snapshot_Manual;
      Transaction   : Natural := 0;
      Protected     : Boolean := False) return Snapshot_ID
   is
      use JSON_Utils;
      Args : JSON_Value := Empty_Object;
   begin
      Set_Field (Args, "name", Name);
      Set_Field (Args, "description", Description);
      Set_Field (Args, "type", Snapshot_Type'Image (Snap_Type));
      if Transaction > 0 then
         Set_Field (Args, "transaction_id", Transaction);
      end if;
      Set_Field (Args, "protected", Protected);

      declare
         Response : constant String := Send_Request ("snap:create", To_String (Args));
         JSON     : constant JSON_Value := Try_Parse (Response);
         ID       : constant Natural := Get_ID (JSON);
      begin
         if ID > 0 then
            return Snapshot_ID (ID);
         else
            return 1;  -- Default fallback
         end if;
      end;
   end Create_Snapshot;

   function Get_Snapshot (ID : Snapshot_ID) return Snapshot_Record is
      Args     : constant String := "{""id"":" & Snapshot_ID'Image (ID) & "}";
      Response : constant String := Send_Request ("snap:get", Args);
      Result   : Snapshot_Record;
      pragma Unreferenced (Response);
   begin
      Result.ID := ID;
      return Result;
   end Get_Snapshot;

   function Delete_Snapshot (ID : Snapshot_ID) return Call_Result is
      Args : constant String := "{""id"":" & Snapshot_ID'Image (ID) & "}";
   begin
      return Parse_Response (Send_Request ("snap:delete", Args));
   end Delete_Snapshot;

   function List_Snapshots
     (Limit     : Positive := 100;
      Snap_Type : Snapshot_Type := Snapshot_Manual) return Snapshot_Vectors.Vector
   is
      pragma Unreferenced (Limit, Snap_Type);
   begin
      --  TODO: Implement full parsing
      return Snapshot_Vectors.Empty_Vector;
   end List_Snapshots;

   function Protect_Snapshot (ID : Snapshot_ID) return Call_Result is
      Args : constant String := "{""id"":" & Snapshot_ID'Image (ID) & "}";
   begin
      return Parse_Response (Send_Request ("snap:protect", Args));
   end Protect_Snapshot;

   function Unprotect_Snapshot (ID : Snapshot_ID) return Call_Result is
      Args : constant String := "{""id"":" & Snapshot_ID'Image (ID) & "}";
   begin
      return Parse_Response (Send_Request ("snap:unprotect", Args));
   end Unprotect_Snapshot;

   function Latest_Snapshot return Snapshot_Record is
      Response : constant String := Send_Request ("snap:latest");
      Result   : Snapshot_Record;
      pragma Unreferenced (Response);
   begin
      return Result;
   end Latest_Snapshot;

   function Snapshot_For_Transaction (TX_ID : Transaction_ID) return Snapshot_Record is
      pragma Unreferenced (TX_ID);
      Result : Snapshot_Record;
   begin
      return Result;
   end Snapshot_For_Transaction;

   ---------------------------------------------------------------------------
   -- Package Operations
   ---------------------------------------------------------------------------

   function Get_Package (Name : String) return Package_State is
      Args     : constant String := "{""name"":""" & Name & """}";
      Response : constant String := Send_Request ("pkg:get", Args);
      Result   : Package_State;
      pragma Unreferenced (Response);
   begin
      Result.Name := To_Unbounded_String (Name);
      return Result;
   end Get_Package;

   function Get_Version (Name : String) return String is
      Args     : constant String := "{""name"":""" & Name & """}";
      Response : constant String := Send_Request ("pkg:version", Args);
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse version from response
      return "";
   end Get_Version;

   function Is_Installed (Name : String) return Boolean is
      State : constant Package_State := Get_Package (Name);
   begin
      return Length (State.Version) > 0;
   end Is_Installed;

   function List_Packages
     (Filter : String := "") return Package_Vectors.Vector
   is
      Args : constant String := (if Filter = "" then "{}" else "{""filter"":""" & Filter & """}");
      Response : constant String := Send_Request ("pkg:list", Args);
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse package list
      return Package_Vectors.Empty_Vector;
   end List_Packages;

   function Search_Packages (Pattern : String) return Package_Vectors.Vector is
      Args     : constant String := "{""pattern"":""" & Pattern & """}";
      Response : constant String := Send_Request ("pkg:search", Args);
      pragma Unreferenced (Response);
   begin
      return Package_Vectors.Empty_Vector;
   end Search_Packages;

   function Hold_Package (Name : String) return Call_Result is
      Args : constant String := "{""name"":""" & Name & """}";
   begin
      return Parse_Response (Send_Request ("pkg:hold", Args));
   end Hold_Package;

   function Unhold_Package (Name : String) return Call_Result is
      Args : constant String := "{""name"":""" & Name & """}";
   begin
      return Parse_Response (Send_Request ("pkg:unhold", Args));
   end Unhold_Package;

   function Mark_Package
     (Name   : String;
      Reason : Install_Reason) return Call_Result
   is
      Reason_Str : constant String := Install_Reason'Image (Reason);
      Args       : constant String := "{""name"":""" & Name &
                                      """,""reason"":""" & Reason_Str & """}";
   begin
      return Parse_Response (Send_Request ("pkg:mark", Args));
   end Mark_Package;

   procedure Record_Package_Install
     (Name       : String;
      Version    : String;
      Reason     : Install_Reason := Manual;
      Repository : String := "";
      Size_Bytes : Natural := 0)
   is
      Reason_Str : constant String := Install_Reason'Image (Reason);
      Args       : constant String :=
        "{""name"":""" & Name &
        """,""version"":""" & Version &
        """,""reason"":""" & Reason_Str &
        """" & (if Repository /= "" then ",""repository"":""" & Repository & """" else "") &
        (if Size_Bytes > 0 then ",""size_bytes"":" & Natural'Image (Size_Bytes) else "") &
        "}";
      Response : constant String := Send_Request ("pkg:record_install", Args);
      pragma Unreferenced (Response);
   begin
      null;
   end Record_Package_Install;

   procedure Record_Package_Update
     (Name        : String;
      Old_Version : String;
      New_Version : String;
      Size_Bytes  : Natural := 0)
   is
      Args : constant String :=
        "{""name"":""" & Name &
        """,""old_version"":""" & Old_Version &
        """,""new_version"":""" & New_Version &
        """" & (if Size_Bytes > 0 then ",""size_bytes"":" & Natural'Image (Size_Bytes) else "") &
        "}";
      Response : constant String := Send_Request ("pkg:record_update", Args);
      pragma Unreferenced (Response);
   begin
      null;
   end Record_Package_Update;

   procedure Record_Package_Remove (Name : String) is
      Args     : constant String := "{""name"":""" & Name & """}";
      Response : constant String := Send_Request ("pkg:record_remove", Args);
      pragma Unreferenced (Response);
   begin
      null;
   end Record_Package_Remove;

   function Get_Package_Manifest return Package_Vectors.Vector is
      Response : constant String := Send_Request ("pkg:manifest");
      pragma Unreferenced (Response);
   begin
      return Package_Vectors.Empty_Vector;
   end Get_Package_Manifest;

   ---------------------------------------------------------------------------
   -- Configuration Operations
   ---------------------------------------------------------------------------

   function Get_Config (Key : String) return String is
      Args     : constant String := "{""key"":""" & Key & """}";
      Response : constant String := Send_Request ("config:get", Args);
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse value from response
      return "";
   end Get_Config;

   procedure Set_Config (Key : String; Value : String) is
      Args     : constant String := "{""key"":""" & Key & """,""value"":""" & Value & """}";
      Response : constant String := Send_Request ("config:set", Args);
      pragma Unreferenced (Response);
   begin
      null;
   end Set_Config;

   function Get_Config_Bool (Key : String; Default : Boolean := False) return Boolean is
      Value : constant String := Get_Config (Key);
   begin
      if Value = "" then
         return Default;
      elsif Value = "true" or Value = "1" or Value = "yes" then
         return True;
      else
         return False;
      end if;
   end Get_Config_Bool;

   function Get_Config_Int (Key : String; Default : Integer := 0) return Integer is
      Value : constant String := Get_Config (Key);
   begin
      if Value = "" then
         return Default;
      else
         return Integer'Value (Value);
      end if;
   exception
      when others => return Default;
   end Get_Config_Int;

   ---------------------------------------------------------------------------
   -- Utility Functions
   ---------------------------------------------------------------------------

   function Ping return Boolean is
      Response : constant String := Send_Request ("ping");
   begin
      return Ada.Strings.Fixed.Index (Response, """pong""") > 0;
   end Ping;

   function Get_Version return String is
      Response : constant String := Send_Request ("version");
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse version from response
      return "0.1.0";
   end Get_Version;

   function Cleanup_Transactions (Keep_Last : Positive := 100) return Natural is
      Args     : constant String := "{""keep_last"":" & Positive'Image (Keep_Last) & "}";
      Response : constant String := Send_Request ("tx:cleanup", Args);
      pragma Unreferenced (Response);
   begin
      --  TODO: Parse deleted count from response
      return 0;
   end Cleanup_Transactions;

   function Cleanup_Snapshots (Keep_Last : Positive := 50) return Natural is
      Args     : constant String := "{""keep_last"":" & Positive'Image (Keep_Last) & "}";
      Response : constant String := Send_Request ("snap:cleanup", Args);
      pragma Unreferenced (Response);
   begin
      return 0;
   end Cleanup_Snapshots;

end Data_Layer_Client;
