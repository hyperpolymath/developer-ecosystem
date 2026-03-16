;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-http-server

(define neurosym-config
  `((version . "1.0.0")
    (project . "rescript-http-server")

    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "type-checked")
       (artifacts
         ((".machine_readable/STATE.scm" . "Project state tracking")
          (".machine_readable/META.scm" . "Architecture decisions")
          (".machine_readable/ECOSYSTEM.scm" . "Ecosystem position")
          (".machine_readable/PLAYBOOK.scm" . "Operational procedures")))))

    (neural-layer
      ((embeddings . #f)
       (fine-tuning . #f)
       (llm-assistance . #t)
       (assistance-patterns
         (("code-generation" . "Route handlers, middleware")
          ("documentation" . "API docs, examples")
          ("testing" . "Test case generation")
          ("debugging" . "Error analysis and fixes")))))

    (integration
      ((state-tracking .
        "STATE.scm updated on significant changes")
       (decision-logging .
        "META.scm records architecture decisions")
       (ecosystem-awareness .
        "ECOSYSTEM.scm defines relationships")
       (llm-context .
        "AGENTIC.scm guides AI interactions")))

    (type-system-integration
      ((rescript-types . "Primary type safety layer")
       (resi-interfaces . "API boundary definition")
       (symbolic-validation . "Scheme S-expressions for metadata")))

    (knowledge-representation
      ((domain . "HTTP server development")
       (concepts
         (("request" . "Incoming HTTP request with method, path, headers, body")
          ("response" . "Outgoing HTTP response with status, headers, body")
          ("handler" . "Async function transforming request to response")
          ("middleware" . "Function wrapping handler with cross-cutting logic")
          ("route" . "Mapping from method+pattern to handler")))
       (relationships
         (("handler" "processes" "request")
          ("handler" "produces" "response")
          ("middleware" "wraps" "handler")
          ("router" "dispatches-to" "handler")
          ("server" "invokes" "handler")))))))
