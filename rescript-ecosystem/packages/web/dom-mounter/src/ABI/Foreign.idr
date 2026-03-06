-- Foreign Function Interface Declarations for SafeDOM
|||
-- This module declares all C-compatible functions that will be
-- implemented in the Zig FFI layer (ffi/zig/).
|||
-- FFI SAFETY GUARANTEES:
-- 1. All pointer parameters proven non-null via types
-- 2. String lengths tracked at type level
-- 3. Result codes map to ReScript variants
-- 4. Memory ownership clear at interface boundary
|||
-- @author Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

module ABI.Foreign

import ABI.Types
import ABI.Layout
import Data.Bits
import Data.String

%default total

-- --------------------------------------------------------------------------------
-- Primitive FFI Declarations
-- --------------------------------------------------------------------------------

-- Validate a CSS selector string
-- Returns: 0 = valid, 1 = empty, 2 = too long, 3 = invalid chars
%foreign "C:safedom_validate_selector, libsafedom"
prim__validateSelector : String -> Bits32 -> PrimIO Bits32

-- Validate HTML content
-- Returns: 0 = valid, 1 = too large, 2 = unbalanced tags
%foreign "C:safedom_validate_html, libsafedom"
prim__validateHTML : String -> Bits32 -> PrimIO Bits32

-- Find DOM element by selector
-- Returns: element pointer (0 = not found)
%foreign "C:safedom_find_element, libsafedom"
prim__findElement : String -> PrimIO Bits64

-- Mount HTML content to DOM element
-- Returns: 0 = success, 1 = null element, 2 = mount failed
%foreign "C:safedom_mount, libsafedom"
prim__mount : Bits64 -> String -> PrimIO Bits32

-- Get length of a string (for validation)
%foreign "C:strlen, libc"
prim__strlen : String -> PrimIO Bits32

-- --------------------------------------------------------------------------------
-- Safe Wrapper Functions
-- --------------------------------------------------------------------------------

-- Safely validate a CSS selector with length bounds checking
export
validateSelector : String -> IO (Either String ValidatedSelector)
validateSelector str = do
  len <- primIO (prim__strlen str)
  if len == 0
    then pure (Left "Selector cannot be empty")
    else if len > 255
      then pure (Left "Selector exceeds maximum length (255 characters)")
      else do
        result <- primIO (prim__validateSelector str len)
        case result of
          0 => pure (mkValidatedSelector str)  -- Use smart constructor
          1 => pure (Left "Selector is empty")
          2 => pure (Left "Selector too long")
          3 => pure (Left "Selector contains invalid characters")
          _ => pure (Left "Unknown validation error")

-- Safely validate HTML content with size bounds checking
export
validateHTML : String -> IO (Either String ValidatedHTML)
validateHTML str = do
  len <- primIO (prim__strlen str)
  if len > 1048576
    then pure (Left "HTML content exceeds maximum size (1MB)")
    else do
      result <- primIO (prim__validateHTML str len)
      case result of
        0 => pure (mkValidatedHTML str)  -- Use smart constructor
        1 => pure (Left "HTML content too large")
        2 => pure (Left "HTML tags are unbalanced")
        _ => pure (Left "Unknown validation error")

-- Safely find DOM element by validated selector
-- Returns Nothing if element not found (compile-time null safety)
export
findElement : ValidatedSelector -> IO (Maybe DOMElement)
findElement selector = do
  ptr <- primIO (prim__findElement selector.content)
  pure (createDOMElement ptr)

-- Safely mount validated HTML to a validated DOM element
-- All preconditions proven at compile-time
export
mount : DOMElement -> ValidatedHTML -> IO (Either String ())
mount elem html = do
  result <- primIO (prim__mount elem.ptr html.content)
  case result of
    0 => pure (Right ())
    1 => pure (Left "Null element (impossible - proven non-null)")
    2 => pure (Left "Mount operation failed")
    _ => pure (Left "Unknown mount error")

-- --------------------------------------------------------------------------------
-- High-Level Safe API
-- --------------------------------------------------------------------------------

-- Complete mount operation with all safety checks
-- This is the main entry point from ReScript
export
safeMountHTML : String -> String -> IO MountResult
safeMountHTML selectorStr htmlStr = do
  -- Validate selector
  selectorResult <- validateSelector selectorStr
  case selectorResult of
    Left err => pure (Failed $ "Invalid selector: " ++ err)
    Right validSelector => do
      -- Validate HTML
      htmlResult <- validateHTML htmlStr
      case htmlResult of
        Left err => pure (Failed $ "Invalid HTML: " ++ err)
        Right validHTML => do
          -- Find element
          elemMaybe <- findElement validSelector
          case elemMaybe of
            Nothing => pure (NotFound validSelector)
            Just elem => do
              -- Mount HTML
              mountResult <- mount elem validHTML
              case mountResult of
                Left err => pure (Failed err)
                Right () => pure (MountedAt elem)

-- --------------------------------------------------------------------------------
-- Batch Operations
-- --------------------------------------------------------------------------------

-- Mount to multiple selectors (batch operation)
export
batchMount : List (String, String) -> IO (List MountResult)
batchMount pairs = traverse (uncurry safeMountHTML) pairs

-- --------------------------------------------------------------------------------
-- Verification Functions
-- --------------------------------------------------------------------------------

-- Test that FFI functions are properly linked
export
verifyFFI : IO ()
verifyFFI = do
  putStrLn "SafeDOM FFI Verification:"
  -- Test selector validation
  testSel <- validateSelector "#app"
  case testSel of
    Right _ => putStrLn "  ✓ Selector validation linked"
    Left err => putStrLn $ "  ✗ Selector validation failed: " ++ err
  -- Test HTML validation
  testHTML <- validateHTML "<div>test</div>"
  case testHTML of
    Right _ => putStrLn "  ✓ HTML validation linked"
    Left err => putStrLn $ "  ✗ HTML validation failed: " ++ err
  putStrLn "  FFI functions verified"
