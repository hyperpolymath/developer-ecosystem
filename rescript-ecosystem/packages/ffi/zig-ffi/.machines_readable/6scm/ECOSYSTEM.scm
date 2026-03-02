;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Project relationship mapping

(ecosystem
  (version "1.0")
  (name "rescript-zig-ffi")
  (type "project")
  (purpose "ReScript bindings for calling Zig libraries via the C ABI.")

  (position-in-ecosystem
    (role "component")
    (layer "application")
    (description "ReScript bindings for calling Zig libraries via the C ABI."))

  (related-projects . ())

  (what-this-is
    "ReScript bindings for calling Zig libraries via the C ABI.")

  (what-this-is-not . ()))
