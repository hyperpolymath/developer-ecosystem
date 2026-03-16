;; SPDX-License-Identifier: MPL-2.0-or-later
;; PLAYBOOK.scm - Operational runbook for techstack-enforcer

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build
         (("debug" . "gprbuild -P techstack_enforcer.gpr -XMODE=debug")
          ("release" . "gprbuild -P techstack_enforcer.gpr -XMODE=release")
          ("verify" . "gnatprove -P techstack_enforcer.gpr --level=2")))
       (deploy
         (("install-hooks" . "./scripts/install-repo-hooks.sh <repo-path>")
          ("install-all" . "./scripts/install.sh")
          ("audit-repo" . "./bin/techstack_main audit <repo-path>")
          ("audit-ecosystem" . "for repo in ~/Documents/hyperpolymath-repos/*/; do ./bin/techstack_main audit \"$repo\"; done")))
       (test
         (("spark-proofs" . "gnatprove -P techstack_enforcer.gpr --level=2")
          ("hook-flow" . "cd /tmp/test-repo && git init && ln -sf $(pwd)/scripts/hooks/pre-commit .git/hooks/ && touch test.py && git add . && git commit -m test")))
       (tui
         (("launch" . "./bin/techstack_tui_main")
          ("learning-mode" . "./bin/techstack_tui_main --mode=learning")))
       (rollback
         (("remove-hooks" . "rm .git/hooks/pre-commit .git/hooks/pre-push .git/hooks/commit-msg")))
       (debug
         (("verbose-audit" . "./bin/techstack_main --mode=learning audit . 2>&1 | tee techstack.log")
          ("json-decisions" . "./bin/techstack_main decide <file> | jq .")))))
    (alerts
      ((violation
         (("desktop" . "notify-send -u critical 'TECHSTACK BLOCKED' '<details>'")
          ("log" . "techstack.log")
          ("webhook" . "configurable in techstack.toml")))))
    (contacts
      ((maintainer . "Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>")))))
