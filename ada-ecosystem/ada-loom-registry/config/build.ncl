# Build Configuration for Ada-loom-registry (Spindle)
# Haskell Nickel parser and registry manager

{
  project = {
    name = "spindle",
    version = "0.1.0",
    description = "Haskell Nickel parser and Ada-loom registry manager",
    license = "PMPL-1.0",
  },

  # Haskell configuration
  haskell = {
    version = "9.4.8",
    compiler = "ghc",
    build_tool | [| 'cabal, 'stack |] = 'cabal,

    cabal = {
      version = "3.10.2.0",
      optimization_level | [| '0, '1, '2 |] = '2,

      flags = {
        split_sections = true,
        executable_stripping = true,
      },

      paths = {
        build_dir = "dist-newstyle",
      },
    },

    settings = {
      ghc_options = [
        "-Wall",
        "-Wcompat",
        "-Widentities",
        "-Wincomplete-record-updates",
        "-Wincomplete-uni-patterns",
        "-Wmissing-export-lists",
        "-Wpartial-fields",
        "-Wredundant-constraints",
      ],
      language_extensions = [
        "OverloadedStrings",
        "DeriveGeneric",
        "RecordWildCards",
      ],
    },
  },

  # Nickel integration
  nickel = {
    version = "1.4.0",
    use_for = ["parsing", "validation", "testing"],

    paths = {
      test_files = "test/nickel",
      schemas = "schemas",
    },

    parser = {
      target_nickel_version = "1.4.0",
      support_legacy_versions = false,
    },
  },

  # Build outputs
  outputs = {
    executables = "dist-newstyle/build/spindle",
    libraries = "dist-newstyle/build/libspindle",
    documentation = "dist-newstyle/doc",
    artifacts_dir = "artifacts",
  },

  # Build environment
  env_vars = {
    GHC_VERSION = "9.4.8",
    CABAL_DIR = ".cabal",
  },

  # Build hooks
  hooks = {
    pre_build = [],
    post_build = ["cabal haddock"],
  },

  # Validation
  validation = {
    run_tests = true,
    nickel_integration_tests = true,
    run_hlint = true,
  },
}
