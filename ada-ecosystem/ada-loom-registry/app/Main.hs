{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
-- SPDX-License-Identifier: PMPL-1.0-or-later

module Main where

import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import GHC.Generics (Generic)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.ByteString as B
import Data.Aeson (FromJSON, eitherDecodeStrict')
import Data.Time.Clock (getCurrentTime)
import Language.Nickel.Parser (parseNickelFile)
import Language.Nickel.Eval (eval)
import Language.Nickel.Types (NValue, nvalueToJSON)

import Spindle.Registry

-- | Config type parsed from Nickel files
data Config = Config
  { name    :: Text
  , version :: Text
  } deriving (Show, Generic, FromJSON)

main :: IO ()
main = do
  args <- getArgs
  case args of
    -- Registry commands
    ["register", configPath] -> cmdRegister configPath
    ["list"]                 -> cmdList
    ["get", entryName]       -> cmdGet entryName
    ["remove", entryName]    -> cmdRemove entryName

    -- Parse command (original functionality)
    ["parse", filename]      -> cmdParse filename
    [filename]               -> cmdParse filename  -- backwards compat

    -- Help
    ["--help"]               -> printUsage
    ["-h"]                   -> printUsage
    []                       -> printUsage

    _                        -> do
      putStrLn "Error: Invalid arguments"
      printUsage
      exitFailure

-- | Register a Nickel config in the registry
cmdRegister :: FilePath -> IO ()
cmdRegister configPath = do
  putStrLn $ "Registering: " ++ configPath

  -- Parse and validate the config first
  content <- B.readFile configPath
  case parseAndValidate configPath content of
    Left err -> do
      putStrLn $ "Error: Failed to parse config: " ++ err
      exitFailure
    Right config -> do
      -- Create registry entry
      now <- getCurrentTime
      let entry = RegistryEntry
            { entryName        = name config
            , entryVersion     = version config
            , entryDescription = Nothing
            , entrySourcePath  = configPath
            , entryRegistered  = now
            }

      -- Load existing registry and add entry
      regResult <- loadRegistry defaultRegistryPath
      case regResult of
        Left err -> do
          putStrLn $ "Error loading registry: " ++ show err
          exitFailure
        Right registry ->
          case register entry registry of
            Left (EntryAlreadyExists n) -> do
              putStrLn $ "Error: Entry '" ++ T.unpack n ++ "' already exists"
              exitFailure
            Left err -> do
              putStrLn $ "Error: " ++ show err
              exitFailure
            Right newRegistry -> do
              saveResult <- saveRegistry defaultRegistryPath newRegistry
              case saveResult of
                Left err -> putStrLn $ "Error saving: " ++ show err
                Right () -> putStrLn $ "Registered: " ++ T.unpack (name config)
                              ++ " v" ++ T.unpack (version config)

-- | List all registered configs
cmdList :: IO ()
cmdList = do
  regResult <- loadRegistry defaultRegistryPath
  case regResult of
    Left err -> putStrLn $ "Error: " ++ show err
    Right registry -> do
      let entries = listEntries registry
      if null entries
        then putStrLn "Registry is empty"
        else do
          putStrLn "Registered configs:"
          putStrLn $ replicate 50 '-'
          mapM_ printEntry entries
  where
    printEntry e = putStrLn $ T.unpack (entryName e)
                   ++ " v" ++ T.unpack (entryVersion e)
                   ++ " (" ++ entrySourcePath e ++ ")"

-- | Get details of a specific entry
cmdGet :: String -> IO ()
cmdGet entryNameStr = do
  regResult <- loadRegistry defaultRegistryPath
  case regResult of
    Left err -> putStrLn $ "Error: " ++ show err
    Right registry ->
      case lookupEntry (T.pack entryNameStr) registry of
        Left (EntryNotFound _) ->
          putStrLn $ "Error: Entry '" ++ entryNameStr ++ "' not found"
        Left err ->
          putStrLn $ "Error: " ++ show err
        Right entry -> do
          putStrLn $ "Name:       " ++ T.unpack (entryName entry)
          putStrLn $ "Version:    " ++ T.unpack (entryVersion entry)
          putStrLn $ "Source:     " ++ entrySourcePath entry
          putStrLn $ "Registered: " ++ show (entryRegistered entry)
          case entryDescription entry of
            Just desc -> putStrLn $ "Description: " ++ T.unpack desc
            Nothing   -> return ()

-- | Remove an entry from the registry
cmdRemove :: String -> IO ()
cmdRemove entryNameStr = do
  regResult <- loadRegistry defaultRegistryPath
  case regResult of
    Left err -> putStrLn $ "Error: " ++ show err
    Right registry ->
      case unregister (T.pack entryNameStr) registry of
        Left (EntryNotFound _) ->
          putStrLn $ "Error: Entry '" ++ entryNameStr ++ "' not found"
        Left err ->
          putStrLn $ "Error: " ++ show err
        Right newRegistry -> do
          saveResult <- saveRegistry defaultRegistryPath newRegistry
          case saveResult of
            Left err -> putStrLn $ "Error saving: " ++ show err
            Right () -> putStrLn $ "Removed: " ++ entryNameStr

-- | Parse a Nickel file (original functionality)
cmdParse :: FilePath -> IO ()
cmdParse filename = do
  content <- B.readFile filename
  case parseAndValidate filename content of
    Left err     -> putStrLn $ "Error: " ++ err
    Right config -> putStrLn $ "Parsed: " ++ show config

-- | Parse and validate a Nickel file into a Config
parseAndValidate :: FilePath -> B.ByteString -> Either String Config
parseAndValidate filename content = do
  expr <- parseNickelFile filename content
  evaluatedValue <- eval expr
  let jsonValue = nvalueToJSON evaluatedValue
  eitherDecodeStrict' jsonValue

-- | Print usage information
printUsage :: IO ()
printUsage = do
  putStrLn "spindle - Nickel config parser and registry"
  putStrLn ""
  putStrLn "USAGE:"
  putStrLn "  spindle <command> [args]"
  putStrLn ""
  putStrLn "COMMANDS:"
  putStrLn "  register <file.ncl>   Register a config in the registry"
  putStrLn "  list                  List all registered configs"
  putStrLn "  get <name>            Show details of a registered config"
  putStrLn "  remove <name>         Remove a config from the registry"
  putStrLn "  parse <file.ncl>      Parse and validate a Nickel file"
  putStrLn ""
  putStrLn "EXAMPLES:"
  putStrLn "  spindle register config.ncl"
  putStrLn "  spindle list"
  putStrLn "  spindle get my-config"
  putStrLn "  spindle parse config.ncl"
