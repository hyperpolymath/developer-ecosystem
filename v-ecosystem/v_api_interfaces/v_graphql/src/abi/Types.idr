-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
module VApi.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

public export
data Platform = Linux | Windows | MacOS | BSD | WASM

public export
thisPlatform : Platform
thisPlatform = Linux

public export
data Result = Ok | Error | InvalidParam | OutOfMemory | NullPointer

public export
data Handle = MkHandle (ptr : Bits64)

public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize WASM = 32
ptrSize _ = 64
