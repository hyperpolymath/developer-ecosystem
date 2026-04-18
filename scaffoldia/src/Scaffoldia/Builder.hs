{- SPDX-License-Identifier: MPL-2.0 -}
{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Scaffoldia.Builder
Description : Scaffold builder - interfaces with Nickel
Copyright   : (c) Hyperpolymath, 2026
License     : MPL-2.0
-}

module Scaffoldia.Builder
  ( -- * Build Operations
    buildScaffold
  , buildFromTemplate
    -- * Nickel Integration
  , evalNickel
  , renderNickelTemplate
    -- * File Operations
  , writeScaffold
  , createStructure
  ) where

import Scaffoldia.Types

import Control.Monad (forM_, when)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist)
import System.FilePath ((</>), takeDirectory)
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode(..))

-- | Build a scaffold from a template
buildScaffold :: Template -> ProjectConfig -> FilePath -> IO (Either Text ())
buildScaffold template config outputPath = do
  -- Render template files
  case renderTemplate template config of
    Left err -> return $ Left err
    Right files -> writeScaffold outputPath files

-- | Build scaffold from template path
buildFromTemplate :: FilePath -> ProjectConfig -> FilePath -> IO (Either Text ())
buildFromTemplate templatePath config outputPath = do
  templateResult <- loadTemplateForBuild templatePath
  case templateResult of
    Left err -> return $ Left err
    Right template -> buildScaffold template config outputPath

-- | Load template for building (simplified)
loadTemplateForBuild :: FilePath -> IO (Either Text Template)
loadTemplateForBuild path = do
  exists <- doesDirectoryExist path
  if not exists
    then return $ Left $ "Template not found: " <> T.pack path
    else return $ Right Template
      { templateId = T.pack path
      , templateMetadata = defaultMetadata
      , templateFiles = []
      , templateDependencies = []
      }

-- | Default metadata for templates without metadata.json
defaultMetadata :: TemplateMetadata
defaultMetadata = TemplateMetadata
  { metaName = "unnamed"
  , metaDescription = ""
  , metaVersion = "0.1.0"
  , metaAuthor = ""
  , metaLicense = "MPL-2.0"
  , metaLanguages = []
  , metaCategory = "general"
  , metaTags = []
  }

-- | Render template with Nickel (uses template's own rendering for now)
renderTemplate :: Template -> ProjectConfig -> Either Text [(FilePath, Text)]
renderTemplate template config =
  -- TODO: Integrate with actual Nickel evaluation
  Right $ map renderFile (templateFiles template)
  where
    renderFile tf = (filePath tf, substituteVariables (fileTemplate tf) config)

-- | Substitute variables in template
substituteVariables :: Text -> ProjectConfig -> Text
substituteVariables template config =
  T.replace "{{project_name}}" (configDescription config) $
  T.replace "{{author}}" (configAuthor config) $
  T.replace "{{license}}" (configLicense config) $
  template

-- | Evaluate a Nickel expression
evalNickel :: Text -> IO (Either Text Text)
evalNickel expr = do
  (exitCode, stdout, stderr) <- readProcessWithExitCode "nickel" ["eval", "-"] (T.unpack expr)
  case exitCode of
    ExitSuccess   -> return $ Right (T.pack stdout)
    ExitFailure _ -> return $ Left (T.pack stderr)

-- | Render a Nickel template file
renderNickelTemplate :: FilePath -> [(Text, Text)] -> IO (Either Text Text)
renderNickelTemplate path vars = do
  -- Build Nickel expression with variables
  let varBindings = T.intercalate ", " [k <> " = " <> quote v | (k, v) <- vars]
      expr = "let config = { " <> varBindings <> " } in import \"" <> T.pack path <> "\""
  evalNickel expr
  where
    quote v = "\"" <> T.replace "\"" "\\\"" v <> "\""

-- | Write scaffold files to disk
writeScaffold :: FilePath -> [(FilePath, Text)] -> IO (Either Text ())
writeScaffold basePath files = do
  createDirectoryIfMissing True basePath
  mapM_ (writeFile' basePath) files
  return $ Right ()
  where
    writeFile' base (path, content) = do
      let fullPath = base </> path
      createDirectoryIfMissing True (takeDirectory fullPath)
      TIO.writeFile fullPath content

-- | Create directory structure from list
createStructure :: FilePath -> [FilePath] -> IO ()
createStructure basePath dirs =
  forM_ dirs $ \dir ->
    createDirectoryIfMissing True (basePath </> dir)
