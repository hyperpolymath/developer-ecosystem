{-# LANGUAGE OverloadedStrings #-}
-- SPDX-License-Identifier: PMPL-1.0

-- | Spindle - Parse Nickel configurations into Haskell types.
--
-- This library acts as the bridge between the Nickel configuration language
-- and Haskell application logic. It enables the Hyperpolymath Registry to
-- consume declarative definitions while maintaining Haskell's type safety.
--
-- Integration Pattern:
-- 1. Nickel (DSL) -> 2. Spindle (Parser/Mapper) -> 3. Haskell (Service Logic)

module Spindle
  ( -- * Re-exports
    -- The Registry module contains the core logic for mapping Nickel records
    -- to Haskell data structures.
    module Spindle.Registry
  ) where

import Spindle.Registry
