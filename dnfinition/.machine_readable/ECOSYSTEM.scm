;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; SPDX-License-Identifier: MPL-2.0-or-later
;; ECOSYSTEM.scm - Project relationships (pruned 2025-12-30)

(ecosystem
 (name . "dnfinition")
 (purpose . "Universal package manager with built-in reversibility")
 (position . "Between traditional PMs and immutable systems")

 (integrations
  ((backends  (dnf rpm-ostree apt pacman zypper brew))
   (snapshots (btrfs zfs lvm transaction-log))
   (storage   (cubdb elixir))
   (security  (owasp-headers vpn-sdp))))

 (inspirations
  ((nala      "CLI UX and output style")
   (timeshift "System restore concept")
   (nixos     "Declarative, reversible management")))

 (dependencies
  ((runtime  (gnat-runtime erlang-otp cubdb hackney))
   (build    (gprbuild gnatprove mix))))
  (opsm-integration
    (relationship "core")
    (description "OS-level package manager bridge for OPSM.")
    (direction "opsm -> dnfinition"))
)
