{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Types
Description : Core types for Scaffoldia
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Types
  ( -- * Template Types
    Template(..)
  , TemplateMetadata(..)
  , TemplateFile(..)
  , FileType(..)
    -- * Project Types
  , Project(..)
  , ProjectConfig(..)
  , Language(..)
    -- * Validation Types
  , ValidationResult(..)
  , ValidationError(..)
  , Severity(..)
    -- * Registry Types
  , Registry(..)
  , RegistryEntry(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | A template definition
data Template = Template
  { templateId          :: Text
  , templateMetadata    :: TemplateMetadata
  , templateFiles       :: [TemplateFile]
  , templateDependencies :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON Template
instance ToJSON Template

-- | Template metadata
data TemplateMetadata = TemplateMetadata
  { metaName        :: Text
  , metaDescription :: Text
  , metaVersion     :: Text
  , metaAuthor      :: Text
  , metaLicense     :: Text
  , metaLanguages   :: [Language]
  , metaCategory    :: Text
  , metaTags        :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON TemplateMetadata
instance ToJSON TemplateMetadata

-- | A file within a template
data TemplateFile = TemplateFile
  { filePath     :: FilePath
  , fileType     :: FileType
  , fileTemplate :: Text  -- Nickel template content
  , fileRequired :: Bool
  } deriving (Show, Eq, Generic)

instance FromJSON TemplateFile
instance ToJSON TemplateFile

-- | File type classification
data FileType
  = SourceFile
  | ConfigFile
  | DocumentationFile
  | BuildFile
  | CIFile
  | LicenseFile
  | OtherFile
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON FileType
instance ToJSON FileType

-- | A project being scaffolded
data Project = Project
  { projectName     :: Text
  , projectPath     :: FilePath
  , projectConfig   :: ProjectConfig
  , projectTemplate :: Text  -- Template ID
  } deriving (Show, Eq, Generic)

instance FromJSON Project
instance ToJSON Project

-- | Project configuration
data ProjectConfig = ProjectConfig
  { configLanguage    :: Language
  , configLicense     :: Text
  , configAuthor      :: Text
  , configDescription :: Text
  , configFeatures    :: [Text]
  } deriving (Show, Eq, Generic)

instance FromJSON ProjectConfig
instance ToJSON ProjectConfig

-- | Supported languages
data Language
  = Rust
  | Haskell
  | ReScript
  | Nickel
  | Gleam
  | OCaml
  | Ada
  | Julia
  | Scheme
  | Bash
  deriving (Show, Eq, Generic, Enum, Bounded)

instance FromJSON Language
instance ToJSON Language

-- | Validation result
data ValidationResult
  = ValidationSuccess
  | ValidationFailure [ValidationError]
  deriving (Show, Eq)

-- | A validation error
data ValidationError = ValidationError
  { errorSeverity :: Severity
  , errorMessage  :: Text
  , errorLocation :: Maybe FilePath
  , errorSuggestion :: Maybe Text
  } deriving (Show, Eq, Generic)

instance FromJSON ValidationError
instance ToJSON ValidationError

-- | Error severity levels
data Severity
  = Info
  | Warning
  | Error
  | Critical
  deriving (Show, Eq, Ord, Generic, Enum, Bounded)

instance FromJSON Severity
instance ToJSON Severity

-- | Template registry
data Registry = Registry
  { registryVersion :: Text
  , registryEntries :: [RegistryEntry]
  } deriving (Show, Eq, Generic)

instance FromJSON Registry
instance ToJSON Registry

-- | A registry entry
data RegistryEntry = RegistryEntry
  { entryId       :: Text
  , entryMetadata :: TemplateMetadata
  , entryPath     :: FilePath
  , entryChecksum :: Text  -- SHA256
  } deriving (Show, Eq, Generic)

instance FromJSON RegistryEntry
instance ToJSON RegistryEntry
