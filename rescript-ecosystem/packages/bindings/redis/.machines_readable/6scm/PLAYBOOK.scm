;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-redis

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build
         (steps
           ("deno task build"))
         (on-failure "Check rescript.json and src/ files"))
       (test
         (steps
           ("Start Redis: docker run -p 6379:6379 redis:7-alpine")
           ("deno task test"))
         (on-failure "Ensure Redis is running on localhost:6379"))
       (release
         (steps
           ("Verify all tests pass")
           ("Update version in deno.json")
           ("Create git tag")
           ("deno publish"))
         (on-failure "Check JSR authentication"))
       (debug
         (steps
           ("Enable verbose logging: DENO_REDIS_DEBUG=1")
           ("Check Redis connection: redis-cli ping")
           ("Verify network: deno run --allow-net debug.ts")))))
    (alerts
      ((redis-connection-failed
         (severity . "critical")
         (action . "Check Redis server status and network"))
       (type-error
         (severity . "high")
         (action . "Run deno task build to identify issue"))))
    (contacts
      ((maintainer . "hyperpolymath")
       (issues . "github.com/hyperpolymath/rescript-redis/issues")))))
