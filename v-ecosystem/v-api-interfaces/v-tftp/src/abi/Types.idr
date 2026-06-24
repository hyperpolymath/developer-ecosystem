-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-tftp protocol.
-- TFTP opcodes, transfer modes, error codes, and packet
-- structures for trivial file transfer (RFC 1350).

module Types

import Data.List

||| TFTP packet opcode.
public export
data Opcode : Type where
  RRQ   : Opcode  -- Read request
  WRQ   : Opcode  -- Write request
  DATA  : Opcode  -- Data block
  ACK   : Opcode  -- Acknowledgement
  ERROR : Opcode  -- Error notification

||| TFTP transfer mode.
public export
data TransferMode : Type where
  Octet    : TransferMode  -- Binary transfer
  Netascii : TransferMode  -- ASCII with CR-LF conversion

||| TFTP error code.
public export
data ErrorCode : Type where
  NotDefined      : ErrorCode  -- 0
  FileNotFound    : ErrorCode  -- 1
  AccessViolation : ErrorCode  -- 2
  DiskFull        : ErrorCode  -- 3
  IllegalOp       : ErrorCode  -- 4
  UnknownTID      : ErrorCode  -- 5
  FileExists      : ErrorCode  -- 6

||| TFTP data packet.
public export
record DataPacket where
  constructor MkDataPacket
  blockNo : Bits16
  payload : List Bits8
