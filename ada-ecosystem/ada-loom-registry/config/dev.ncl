# Development Environment for Ada-loom-registry (Spindle)

{
  environment = {
    name = "spindle-dev",
    description = "Haskell Nickel parser development",
  },

  tools = {
    haskell = { version = "9.4.8", install_via = "asdf", required = true },
    nickel = { version = "1.4.0", install_via = "asdf", required = true },
    just = { version = "1.25.2", install_via = "asdf", required = true },
    nodejs = { version = "20.11.1", install_via = "asdf", required = false },
  },

  cabal = {
    version = "3.10.2.0",
    local_repo = "~/.cabal",
  },

  editor = {
    vscode = {
      extensions = [
        "haskell.haskell",
        "justusadam.language-haskell",
      ],
    },
  },

  git_hooks = {
    enabled = true,
    pre_commit = ["hlint"],
    pre_push = ["test"],
  },

  testing = {
    watch_mode = false,
    coverage = true,
    nickel_test_files = true,
  },

  env_vars = {
    CABAL_DIR = ".cabal",
  },
}
