# CI/CD Configuration for Ada-loom-registry (Spindle)

{
  pipeline = {
    name = "spindle-ci",
    version = "1.0.0",
  },

  gitlab = {
    stages = ["build", "test", "quality", "security", "docs", "deploy"],

    cache = {
      cabal = {
        key = "cabal-$CI_COMMIT_REF_SLUG",
        paths = [".cabal/", "dist-newstyle/"],
      },
    },
  },

  build = {
    cabal = {
      enabled = true,
      commands = [
        "cabal update",
        "cabal build --enable-tests --enable-benchmarks all",
      ],
    },
  },

  test = {
    unit = {
      enabled = true,
      command = "cabal test --enable-coverage --test-show-details=direct all",
    },
    nickel_integration = {
      enabled = true,
      command = "cabal test nickel-integration",
    },
    benchmarks = {
      enabled = false,
      command = "cabal bench all",
    },
  },

  quality = {
    hlint = { enabled = true, command = "hlint src/" },
    stylish_haskell = { enabled = false },
    stan = { enabled = true, command = "stan" },
  },

  security = {
    cabal_outdated = { enabled = true },
    secret_detection = { enabled = true },
  },

  docs = {
    haddock = {
      enabled = true,
      command = "cabal haddock --enable-documentation --haddock-hyperlink-source",
    },
  },

  deploy = {
    hackage = {
      enabled = false,
      publish_on_tag = false,
    },
    binary_release = {
      enabled = true,
      platforms = ["linux-x86_64"],
    },
  },
}
