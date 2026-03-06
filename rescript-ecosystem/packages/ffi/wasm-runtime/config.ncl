# Nickel configuration for ReScript WASM Runtime
# Type-safe configuration with validation

{
  server = {
    # HTTP server configuration
    http = {
      host | String = "127.0.0.1",
      port | Number = 8000,
      timeout | Number = 30000,
      keepAliveTimeout | Number = 5000,
    },

    # Runtime configuration
    runtime = {
      deno | Bool = true,
      bun | Bool = false,
      wasm | Bool = false,
    },

    # Performance settings
    performance = {
      maxConnections | Number = 10000,
      requestBodyLimit | Number = 10485760, # 10MB
      enableCompression | Bool = true,
    },
  },

  # Build configuration
  build = {
    target | String = "deno",
    optimization | String = "size", # or "speed"
    sourceMap | Bool = false,
    minify | Bool = true,

    wasm = {
      enabled | Bool = false,
      optimize | Bool = true,
      threads | Bool = false,
    },
  },

  # Development settings
  dev = {
    hotReload | Bool = true,
    verbose | Bool = false,
    port | Number = 8000,
  },

  # Security settings
  security = {
    cors = {
      enabled | Bool = true,
      origins | Array String = ["*"],
      methods | Array String = ["GET", "POST", "PUT", "DELETE", "PATCH"],
      headers | Array String = ["Content-Type", "Authorization"],
      credentials | Bool = false,
    },

    rateLimit = {
      enabled | Bool = true,
      maxRequests | Number = 100,
      windowMs | Number = 60000,
    },

    jwt = {
      secret | String = "change-this-secret-in-production",
      expiresIn | String = "24h",
    },
  },

  # Logging configuration
  logging = {
    level | String = "info", # debug, info, warn, error
    format | String = "json", # json or text
    timestamp | Bool = true,
  },

  # Database configuration (for examples)
  database = {
    type | String = "sqlite",
    path | String = "./data/db.sqlite",
    poolSize | Number = 10,
  },

  # Deployment settings
  deployment = {
    platform | String = "deno-deploy", # deno-deploy, docker, kubernetes
    region | String = "us-east-1",
    replicas | Number = 1,
  },

  # Benchmark settings
  benchmark = {
    duration | Number = 30,
    connections | Number = 100,
    warmup | Number = 5,
  },
}
