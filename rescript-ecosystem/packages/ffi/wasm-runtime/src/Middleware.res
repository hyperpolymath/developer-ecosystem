// Common middleware implementations

// CORS middleware
let cors = (
  ~origin="*",
  ~methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  ~headers=["Content-Type", "Authorization"],
  ~credentials=false,
  ()
): Router.middleware => {
  (req, next) => {
    let requestMethod = Deno.Request.method(req)

    if requestMethod === "OPTIONS" {
      // Handle preflight
      let headersDict = Js.Dict.empty()
      Js.Dict.set(headersDict, "Access-Control-Allow-Origin", origin)
      Js.Dict.set(headersDict, "Access-Control-Allow-Methods", methods->Array.joinWith(", "))
      Js.Dict.set(headersDict, "Access-Control-Allow-Headers", headers->Array.joinWith(", "))
      if credentials {
        Js.Dict.set(headersDict, "Access-Control-Allow-Credentials", "true")
      }

      Promise.resolve(Deno.Response.text("", ~status=204, ~headers=headersDict, ()))
    } else {
      // Add CORS headers to response
      next(req)->Promise.thenResolve(response => {
        // Note: In production, you'd clone the response and add headers
        // This is simplified for the example
        response
      })
    }
  }
}

// Logging middleware
let logger = (): Router.middleware => {
  (req, next) => {
    let method = Deno.Request.method(req)
    let url = Deno.Request.url(req)
    let start = Deno.now()

    next(req)->Promise.thenResolve(response => {
      let duration = Deno.now() -. start
      Deno.log(`${method} ${url} - ${Float.toString(duration)}ms`)
      response
    })
  }
}

// JSON body parser middleware
let jsonParser = (): Router.middleware => {
  (req, next) => {
    let method = Deno.Request.method(req)

    if method === "POST" || method === "PUT" || method === "PATCH" {
      Deno.Request.json(req)->Promise.then(body => {
        // In a real implementation, we'd attach this to the request context
        next(req)
      })->Promise.catch(_ => {
        Promise.resolve(Deno.Response.json(
          Js.Json.object_(Js.Dict.fromArray([("error", Js.Json.string("Invalid JSON"))])),
          ~status=400,
          ()
        ))
      })
    } else {
      next(req)
    }
  }
}

// Rate limiting middleware
type rateLimitState = {
  mutable requests: Js.Dict.t<array<float>>,
  maxRequests: int,
  windowMs: float
}

let rateLimit = (~maxRequests=100, ~windowMs=60000.0, ()): Router.middleware => {
  let state: rateLimitState = {
    requests: Js.Dict.empty(),
    maxRequests,
    windowMs
  }

  (req, next) => {
    let url = Deno.Request.url(req)
    let urlObj = Deno.Url.make(url)
    // In production, use client IP instead
    let clientId = Deno.Url.pathname(urlObj)
    let now = Deno.now()

    let timestamps = switch Js.Dict.get(state.requests, clientId) {
    | Some(ts) => ts->Belt.Array.keep(t => now -. t < state.windowMs)
    | None => []
    }

    if Array.length(timestamps) >= state.maxRequests {
      Promise.resolve(Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([("error", Js.Json.string("Too many requests"))])),
        ~status=429,
        ()
      ))
    } else {
      Array.push(timestamps, now)->ignore
      Js.Dict.set(state.requests, clientId, timestamps)
      next(req)
    }
  }
}

// Authentication middleware (JWT example)
let auth = (~secret: string): Router.middleware => {
  (req, next) => {
    let headers = Deno.Request.headers(req)

    switch Js.Dict.get(headers, "authorization") {
    | None =>
      Promise.resolve(Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([("error", Js.Json.string("No authorization header"))])),
        ~status=401,
        ()
      ))
    | Some(authHeader) => {
        if Js.String2.startsWith(authHeader, "Bearer ") {
          let _token = Js.String2.sliceToEnd(authHeader, ~from=7)
          // In production, verify JWT token here
          next(req)
        } else {
          Promise.resolve(Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([("error", Js.Json.string("Invalid authorization format"))])),
            ~status=401,
            ()
          ))
        }
      }
    }
  }
}

// Compression middleware (placeholder - would need Deno compression APIs)
let compress = (): Router.middleware => {
  (req, next) => {
    // In production, check Accept-Encoding header and compress response
    next(req)
  }
}

// Error handling middleware
let errorHandler = (): Router.middleware => {
  (req, next) => {
    next(req)->Promise.catch(error => {
      Deno.error(error)
      Promise.resolve(Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Internal server error")),
          ("message", Js.Json.string(Exn.asJsExn(error)->Belt.Option.flatMap(Js.Exn.message)->Belt.Option.getWithDefault("Unknown error")))
        ])),
        ~status=500,
        ()
      ))
    })
  }
}
