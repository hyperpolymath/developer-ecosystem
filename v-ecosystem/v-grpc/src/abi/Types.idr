-- SPDX-License-Identifier: PMPL-1.0-or-later
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
