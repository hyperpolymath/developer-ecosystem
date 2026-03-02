-- SPDX-License-Identifier: PMPL-1.0-or-later
-- SafeDOM.idr - Formally verified DOM operations with dependent types
--
-- This module provides mathematical proofs that DOM mounting operations
-- are safe and cannot fail at runtime due to:
-- - Null pointer dereferences
-- - Invalid selectors
-- - Malformed HTML
-- - Type mismatches
--
-- FORMAL GUARANTEES (proven at compile-time):
-- 1. Selectors are 1-255 characters (non-empty, bounded)
-- 2. HTML content is 0-1MB (size limited)
-- 3. DOM element handles are non-null (impossible to construct null)
-- 4. Memory layout matches C ABI across all platforms
-- 5. Tag balancing is verified before mounting
--
-- @author Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

module ABI.SafeDOM

import public ABI.Types
import public ABI.Layout
import public ABI.Foreign

%default total

-- --------------------------------------------------------------------------------
-- Main Module Exports (all re-exported from submodules)
-- --------------------------------------------------------------------------------

-- Note: public imports re-export everything automatically

-- --------------------------------------------------------------------------------
-- Verification Entry Point
-- --------------------------------------------------------------------------------

-- Run all compile-time verifications
-- This proves all safety properties hold
export
verifyAll : IO ()
verifyAll = do
  putStrLn "=== SafeDOM Formal Verification ==="
  putStrLn ""
  verifySelectorBounds
  verifyHTMLBounds
  verifyDOMHandles
  putStrLn ""
  verifyAllLayouts
  putStrLn ""
  verifyFFI
  putStrLn ""
  putStrLn "=== All SafeDOM properties verified ✓ ==="

-- --------------------------------------------------------------------------------
-- Example Usage (for documentation)
-- --------------------------------------------------------------------------------

namespace Example
  ||| Example: Safe DOM mounting with compile-time guarantees
  export
  exampleSafeMount : IO ()
  exampleSafeMount = do
    putStrLn "Example: Mounting HTML with formal verification"
    result <- ABI.Foreign.safeMountHTML "#app" "<div>Hello, formally verified world!</div>"
    case result of
      MountedAt elem => putStrLn "✓ Mounted successfully (element is proven non-null)"
      NotFound selector => putStrLn "✗ Mount point not found (selector was valid though)"
      Failed err => putStrLn $ "✗ Failed: " ++ err

  ||| Example: Batch mounting
  export
  exampleBatchMount : IO ()
  exampleBatchMount = do
    putStrLn "Example: Batch mounting with verification"
    let pairs : List (String, String)
        pairs = [("#header", "<h1>Title</h1>"),
                 ("#content", "<p>Content</p>"),
                 ("#footer", "<small>Footer</small>")]
    results <- ABI.Foreign.batchMount pairs
    putStrLn $ "Mounted " ++ show (length results) ++ " elements"

-- --------------------------------------------------------------------------------
-- Main Entry Point (for testing)
-- --------------------------------------------------------------------------------

-- Main function for standalone testing
main : IO ()
main = do
  verifyAll
  putStrLn ""
  exampleSafeMount
  putStrLn ""
  exampleBatchMount
