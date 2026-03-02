// Session management utilities

// Session data type
type sessionData = Js.Dict.t<Js.Json.t>

type session = {
  id: string,
  data: sessionData,
  createdAt: float,
  expiresAt: float
}

// Session store
type store = {
  sessions: ref<Js.Dict.t<session>>,
  ttl: float, // Time to live in milliseconds
}

// Create session store
let createStore = (~ttl=3600000.0): store => {
  {
    sessions: ref(Js.Dict.empty()),
    ttl,
  }
}

// Generate session ID
let generateSessionId = (): string => {
  let timestamp = Deno.now()->Float.toString
  let random = Js.Math.random()->Float.toString
  let random2 = Js.Math.random()->Float.toString
  `sess_${timestamp}_${random}_${random2}`
}

// Create new session
let createSession = (store: store): session => {
  let now = Deno.now()
  let session = {
    id: generateSessionId(),
    data: Js.Dict.empty(),
    createdAt: now,
    expiresAt: now +. store.ttl
  }

  Js.Dict.set(store.sessions.contents, session.id, session)
  session
}

// Get session by ID
let getSession = (store: store, id: string): option<session> => {
  switch Js.Dict.get(store.sessions.contents, id) {
  | None => None
  | Some(session) => {
      let now = Deno.now()
      if now > session.expiresAt {
        // Session expired
        Js.Dict.set(store.sessions.contents, id, session) // Remove
        None
      } else {
        Some(session)
      }
    }
  }
}

// Update session data
let setSessionData = (session: session, key: string, value: Js.Json.t): unit => {
  Js.Dict.set(session.data, key, value)
}

// Get session data
let getSessionData = (session: session, key: string): option<Js.Json.t> => {
  Js.Dict.get(session.data, key)
}

// Destroy session
let destroySession = (store: store, id: string): unit => {
  let newSessions = Js.Dict.empty()

  Js.Dict.entries(store.sessions.contents)->Array.forEach(((sessionId, session)) => {
    if sessionId !== id {
      Js.Dict.set(newSessions, sessionId, session)
    }
  })

  store.sessions := newSessions
}

// Clean up expired sessions
let cleanupExpiredSessions = (store: store): int => {
  let now = Deno.now()
  let initialCount = Js.Dict.keys(store.sessions.contents)->Array.length
  let newSessions = Js.Dict.empty()

  Js.Dict.entries(store.sessions.contents)->Array.forEach(((id, session)) => {
    if now <= session.expiresAt {
      Js.Dict.set(newSessions, id, session)
    }
  })

  store.sessions := newSessions

  let finalCount = Js.Dict.keys(newSessions)->Array.length
  initialCount - finalCount
}

// Extract session ID from cookie
let extractSessionIdFromCookie = (req: Deno.request): option<string> => {
  let headers = Deno.Request.headers(req)

  switch Js.Dict.get(headers, "cookie") {
  | None => None
  | Some(cookieHeader) => {
      // Simple cookie parsing
      let cookies = cookieHeader->Js.String2.split(";")

      cookies->Array.findMap(cookie => {
        let trimmed = Js.String2.trim(cookie)
        if Js.String2.startsWith(trimmed, "sessionId=") {
          Some(Js.String2.sliceToEnd(trimmed, ~from=10))
        } else {
          None
        }
      })
    }
  }
}

// Session middleware
let sessionMiddleware = (store: store): Router.middleware => {
  (req, next) => {
    // Try to get existing session
    let sessionId = extractSessionIdFromCookie(req)

    let session = switch sessionId {
    | None => createSession(store)
    | Some(id) => {
        switch getSession(store, id) {
        | Some(s) => s
        | None => createSession(store)
        }
      }
    }

    // Attach session to request context (in real implementation)
    Deno.log(`Session: ${session.id}`)

    // Continue with request
    next(req)->Promise.thenResolve(response => {
      // Add Set-Cookie header to response
      // In production, this would properly set the cookie
      response
    })
  }
}

// Start cleanup interval
let startCleanupInterval = (store: store, ~intervalMs=300000.0): unit => {
  // In a real implementation, this would use setInterval
  Deno.log(`Session cleanup would run every ${Float.toString(intervalMs)}ms`)
}
