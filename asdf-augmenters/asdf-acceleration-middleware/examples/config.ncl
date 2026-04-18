# Example Nickel configuration for asdf-acceleration-middleware

{
  asdf = {
    cache = {
      enabled = true,
      ttl_secs = 3600,
      max_size_mb = 500,
    },

    parallel = {
      strategy = "auto",
      fail_fast = false,
      max_retries = 0,
    },

    notifications = {
      enabled = true,
      level = "errors_only",
      desktop = true,
    },

    plugins = {
      exclude = [],
      only = [],
      auto_update = true,
    },
  }
}
