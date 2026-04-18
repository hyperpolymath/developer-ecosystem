;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; SPDX-License-Identifier: MPL-2.0-or-later
;; META.scm - Architecture decisions (pruned 2025-12-30)

(define meta
  '((architecture-decisions
     ((adr-001 accepted "Ada+SPARK for safety-critical reversibility logic")
      (adr-002 accepted "Elixir+CubDB for embedded ACID storage")
      (adr-003 accepted "JSON-over-pipe IPC between Ada and Elixir")
      (adr-004 accepted "OWASP HTTP headers + optional VPN/SDP")
      (adr-005 accepted "GNATCOLL.JSON for Ada IPC via json_utils wrapper")))

    (design-principles
     ((safety-first  "SPARK proofs before features")
      (reversibility "Every operation must be undoable")
      (atomicity     "Transaction + snapshot linked or neither")
      (defense-depth "Validate at every boundary")))

    (code-standards
     ((ada    "GNAT style, -gnatwa -gnatyO, SPARK_Mode on critical")
      (elixir "mix format, Credo strict, pattern matching")
      (all    "SPDX headers, no hardcoded secrets")))

    (security-requirements
     ((http   "TLS 1.2+, OWASP headers, no MD5/SHA1")
      (input  "Sanitize all external input, shell-escape paths")
      (ipc    "Validate JSON structure, bound string lengths")))))

(define opsm-link "OPSM link: OS-level package manager bridge for OPSM.")
