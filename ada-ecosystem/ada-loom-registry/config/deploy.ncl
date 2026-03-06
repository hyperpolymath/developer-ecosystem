# Deployment Configuration for Ada-loom-registry (Spindle)

{
  deployment = {
    name = "spindle-deploy",
    description = "Haskell Nickel parser deployment",
  },

  environments = {
    production = {
      enabled = false,
      approval_required = true,
    },
  },

  release = {
    binary = {
      enabled = true,
      strip_symbols = true,
      static_linking = false,
      platforms = ["linux-x86_64", "macos-x86_64"],
    },
  },

  hackage = {
    enabled = false,
    publish = {
      on_tag = false,
      category = "Development",
      package_name = "spindle",
    },
  },

  pages = {
    enabled = true,
    source = "dist-newstyle/doc",
  },

  artifacts = {
    executables = ["dist-newstyle/build/spindle"],
    libraries = ["dist-newstyle/build/libspindle.*"],
    documentation = ["dist-newstyle/doc/html/spindle/"],
    checksums = true,
  },

  registry = {
    ada_loom_sync = {
      enabled = false,
      endpoint = null,
    },
  },
}
