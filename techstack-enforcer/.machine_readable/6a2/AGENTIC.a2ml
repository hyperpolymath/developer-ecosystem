;; SPDX-License-Identifier: MPL-2.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for techstack-enforcer

(define agentic-config
  `((version . "1.0.0")
    (claude-code
      ((model . "claude-opus-4-6")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")))
    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")))
    (constraints
      ((languages . ("ada" "spark"))
       (banned . ("typescript" "go" "python" "makefile"))
       (build-tool . "gprbuild")
       (verify-tool . "gnatprove")))
    (affordances
      ((primary-language . "Ada/SPARK")
       (build . "gprbuild -P techstack_enforcer.gpr -XMODE=release")
       (verify . "gnatprove -P techstack_enforcer.gpr --level=2")
       (test . "just test")
       (tui . "./bin/techstack_tui_main")
       (audit . "./bin/techstack_main audit .")))
    (critical-invariants
      ("Core engine MUST be SPARK_Mode — no unsafe Ada in src/core/"
       "All enforcement decisions MUST flow through the formally verified core"
       "Multi-layer architecture: never remove a blocking layer without adding a replacement"
       "Learning mode MUST NOT block — it is observe-only by design"
       "Lockdown mode MUST block on ALL violations including Warn level"))))
