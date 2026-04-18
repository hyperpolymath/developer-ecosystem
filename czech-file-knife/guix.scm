;; SPDX-License-Identifier: MPL-2.0-or-later
;; SPDX-FileCopyrightText: 2025 hyperpolymath
;;
;; Guix package definition for czech-file-knife
;; Build: guix build -f guix.scm
;; Shell: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system cargo)
             (guix licenses)
             (gnu packages rust)
             (gnu packages rust-apps)
             (gnu packages pkg-config)
             (gnu packages tls)
             (gnu packages linux)
             (gnu packages databases)
             (gnu packages compression))

(define-public czech-file-knife
  (package
    (name "czech-file-knife")
    (version "0.1.0")
    (source
     (local-file "." "czech-file-knife-checkout"
                 #:recursive? #t
                 #:select? (git-predicate ".")))
    (build-system cargo-build-system)
    (arguments
     `(#:cargo-build-flags '("-p" "cfk-cli")
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'install-completions
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bash (string-append out "/share/bash-completion/completions"))
                    (zsh (string-append out "/share/zsh/site-functions"))
                    (fish (string-append out "/share/fish/vendor_completions.d")))
               (mkdir-p bash)
               (mkdir-p zsh)
               (mkdir-p fish)
               ;; Generate completions via cfk cli
               (invoke (string-append out "/bin/cfk") "completion" "bash"
                       "--output" (string-append bash "/cfk"))
               (invoke (string-append out "/bin/cfk") "completion" "zsh"
                       "--output" (string-append zsh "/_cfk"))
               (invoke (string-append out "/bin/cfk") "completion" "fish"
                       "--output" (string-append fish "/cfk.fish"))))))))
    (native-inputs
     (list pkg-config rust rust-cargo))
    (inputs
     (list openssl
           fuse
           sqlite))
    (synopsis "Universal cloud file management CLI")
    (description
     "Czech File Knife (CFK) provides unified access to multiple cloud storage
providers through a single command-line interface.  Features include:
@itemize
@item Multi-provider support (S3, GCS, Azure, local)
@item Content-addressable caching with BLAKE3
@item Full-text search with Tantivy
@item FUSE virtual filesystem mount
@item Provider-agnostic file operations
@end itemize")
    (home-page "https://github.com/hyperpolymath/czech-file-knife")
    (license agpl3+)))

;; Workspace development package
(define-public czech-file-knife-dev
  (package
    (inherit czech-file-knife)
    (name "czech-file-knife-dev")
    (arguments
     `(#:cargo-build-flags '("--workspace")))
    (synopsis "Czech File Knife development package")
    (description
     "Development package with all workspace crates for czech-file-knife.")))

czech-file-knife
