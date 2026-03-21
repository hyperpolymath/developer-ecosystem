-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-modbus protocol.
-- Modbus function codes, data object types, exception codes,
-- and connection states.

module Types

import Data.List

||| Modbus function codes (standard subset).
public export
data FunctionCode : Type where
  ReadCoils             : FunctionCode  -- FC 01
  ReadDiscreteInputs    : FunctionCode  -- FC 02
  ReadHoldingRegisters  : FunctionCode  -- FC 03
  ReadInputRegisters    : FunctionCode  -- FC 04
  WriteSingleCoil       : FunctionCode  -- FC 05
  WriteSingleRegister   : FunctionCode  -- FC 06
  WriteMultipleCoils    : FunctionCode  -- FC 15
  WriteMultipleRegisters : FunctionCode -- FC 16

||| Modbus exception codes (section 7).
public export
data ExceptionCode : Type where
  IllegalFunction    : ExceptionCode  -- 01
  IllegalDataAddress : ExceptionCode  -- 02
  IllegalDataValue   : ExceptionCode  -- 03
  SlaveDeviceFailure : ExceptionCode  -- 04
  Acknowledge        : ExceptionCode  -- 05
  SlaveDeviceBusy    : ExceptionCode  -- 06

||| Modbus transport variant.
public export
data Transport : Type where
  ModbusTCP : Transport  -- MBAP header over TCP/IP
  ModbusRTU : Transport  -- Serial RTU framing with CRC-16

||| Connection lifecycle state.
public export
data ConnState : Type where
  Disconnected : ConnState
  Connected    : ConnState

||| A Modbus TCP request/response Application Protocol header.
public export
record MBAPHeader where
  constructor MkMBAPHeader
  transactionId : Nat
  protocolId    : Nat   -- Always 0 for Modbus
  length        : Nat
  unitId        : Nat

||| A holding or input register value (16-bit unsigned).
public export
record RegisterValue where
  constructor MkRegisterValue
  address : Nat
  value   : Nat  -- 0..65535
