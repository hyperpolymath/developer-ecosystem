;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - rescript-dom-mounter ecosystem

(ecosystem
  (version "1.0.0")
  (name "rescript-dom-mounter")
  (type "infrastructure-library")
  (purpose
    "Formally verified DOM mounting with compile-time safety guarantees"
    "Prevents null pointer crashes, invalid selectors, malformed HTML")

  (position-in-ecosystem
    "rescript-dom-mounter is CRITICAL INFRASTRUCTURE for all ReScript web apps."
    ""
    "It provides mathematical proofs that DOM mounting cannot fail, making it"
    "the foundation for:"
    "- rescript-tea applications (TEA framework)"
    "- All ReScript+Deno web sites"
    "- Any ReScript code that manipulates the DOM"
    ""
    "This is not optional—it's the proven-safe way to mount DOM elements.")

  (related-projects
    (project "proven"
      (relationship "sibling-standard")
      (description "Parent library with 90+ formally verified modules")
      (integration "Uses proven's verification approach")
      (url "https://github.com/hyperpolymath/proven"))

    (project "rescript-tea"
      (relationship "potential-consumer")
      (description "TEA framework should use SafeDOM for mounting")
      (integration "Replace unsafe Tea.App.standardProgram mounting")
      (url "https://github.com/hyperpolymath/rescript-tea"))

    (project "stamp-website"
      (relationship "potential-consumer")
      (description "STAMP demo site needs safe DOM mounting")
      (integration "Use SafeDOM.mountWhenReady for app mounting")
      (url "https://github.com/hyperpolymath/stamp-website"))

    (project "rsr-template-repo"
      (relationship "sibling-standard")
      (description "Standard repo template—SafeDOM should be included")
      (integration "Add as default dependency for web projects")
      (url "https://github.com/hyperpolymath/rsr-template-repo")))

  (what-this-is
    "The ONLY DOM mounting library with formal verification"
    "Compile-time proofs eliminate runtime DOM errors"
    "Type-safe, memory-safe, guaranteed-correct DOM operations"
    "Zero runtime overhead (proofs erased)")

  (what-this-is-not
    "NOT a virtual DOM framework (use React/rescript-tea for that)"
    "NOT a component framework (just mounting)"
    "NOT a testing library (provides guarantees, not tests)"
    "NOT optional (should be standard for all ReScript DOM work)"))
