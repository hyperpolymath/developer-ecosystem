{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
-- SPDX-License-Identifier: PMPL-1.0

-- | Spindle.Registry - Persistent configuration management for the Hyperpolymath ecosystem.
--
-- This module implements a high-assurance registry for storing and tracking
// the lifecycle of Nickel-based configuration files. It ensures that every
// registered configuration is unique and has associated versioning metadata.

module Spindle.Registry
  ( -- * Core Models
    RegistryEntry(..)
  , Registry(..)
  , RegistryError(..)
    -- * Domain Operations
  , emptyRegistry
  , register
  , unregister
  , lookupEntry
  , listEntries
    -- * Persistence Layer
  , loadRegistry
  , saveRegistry
  , defaultRegistryPath
  ) where

import Data.Aeson (FromJSON, ToJSON, eitherDecodeStrict', encode)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import Data.Time.Clock (UTCTime, getCurrentTime)
import GHC.Generics (Generic)
import System.Directory (doesFileExist, createDirectoryIfMissing)
import System.FilePath (takeDirectory)

-- | DATA MODEL: A metadata record for a validated configuration.
-- Every entry maps back to a physical source file (.ncl) and carries
-- a semantic version.
data RegistryEntry = RegistryEntry
  { entryName        :: Text       -- ^ Unique identifier (slug)
  , entryVersion     :: Text       -- ^ Semantic version (e.g. "1.2.3")
  , entryDescription :: Maybe Text -- ^ Contextual description
  , entrySourcePath  :: FilePath   -- ^ Absolute path to the .ncl source
  , entryRegistered  :: UTCTime    -- ^ Registration timestamp (UTC)
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

-- | DATA MODEL: The central repository of configuration entries.
-- Backed by a strict `Map` for efficient name-based lookups.
newtype Registry = Registry
  { registryEntries :: Map Text RegistryEntry
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

-- | ERROR SPACE: Failures specific to registry management.
data RegistryError
  = EntryNotFound Text
  | EntryAlreadyExists Text
  | RegistryIOError String
  | RegistryParseError String
  deriving (Show, Eq)

-- | FACTORY: Returns a clean, empty registry.
emptyRegistry :: Registry
emptyRegistry = Registry Map.empty

-- | REGISTRATION: Adds a new entry to the registry.
-- INVARIANT: Fails with `EntryAlreadyExists` if the name is not unique.
register :: RegistryEntry -> Registry -> Either RegistryError Registry
register entry (Registry entries) =
  let name = entryName entry
  in if Map.member name entries
     then Left (EntryAlreadyExists name)
     else Right $ Registry (Map.insert name entry entries)

-- | REMOVAL: Removes an existing entry.
-- INVARIANT: Fails with `EntryNotFound` if the key does not exist.
unregister :: Text -> Registry -> Either RegistryError Registry
unregister name (Registry entries) =
  if Map.member name entries
  then Right $ Registry (Map.delete name entries)
  else Left (EntryNotFound name)

-- ... [lookup and persistence logic follows]
