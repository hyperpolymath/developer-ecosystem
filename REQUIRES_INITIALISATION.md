<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# REQUIRES INITIALISATION

**This repository is not finished being set up.** 67 substitution token(s) across 754 file(s) still have no value.

## Why this is not already done

This repo was created from `hyperpolymath/rsr-template-repo`. The mint
(`just repo-init`) fills every token that has a single mechanical answer —
owner, repo, author, dates, licence, branch — and it has done so here.

The tokens below are the ones it *deliberately cannot* answer. They need a
decision or a fact that exists only in your head: what this project is for,
what command builds it, which port the service listens on, whether a PGP key
is held at all. The template's own token vocabulary says as much — you cannot
sensibly answer "required invariants" in a thirty-second bootstrap.

They were left **visibly unfilled on purpose**. The alternatives were both
worse: inventing plausible values would put confident falsehoods into a
security policy and an architecture document, and silently deleting the
sections would hide the fact that a decision is owed. A visible gap is
honest; a fabricated answer is not.

## Do not delete this file until every item below is resolved

This file is the only marker that the work is outstanding. Deleting it early
does not finish the setup, it just conceals it — and the next person or agent
to arrive will reasonably assume the repo is complete.

- **If you are a person:** delete this file yourself once the last item is done.
- **If you are an agent:** resolve what you legitimately can, leave the rest,
  and delete this file only when no token below remains anywhere in the tree.
  Do not delete it to make a gate go green.

Re-running the estate top-up tool will remove this file automatically once
nothing is outstanding, so the safest way to finish is to fix the tokens and
let the check confirm it.

## Do these first

`.github/settings.yml` is applied to the forge by a GitHub App. An
unfilled token here can be written into the repository's real name or
description. This has fired before in this estate: illegal braces were
collapsed to dashes and a repo was renamed `-REPO-`, which then read as
deleted.

- `{{DESCRIPTION}}` — One-line description used in .github/settings.yml. HIGH PRIORITY: settings.yml is applied by a GitHub App, so an unfilled token here can be written into forge metadata verbatim.

## What is needed, and where it goes

### `{{ARGS}}`

Arguments for the justfile recipe this appears in.

Appears in:

- `affinescript-ecosystem/affinescriptiser/Justfile`
- `affinescript-ecosystem/rattlescript/Justfile`
- `dnfinition/Justfile`
- `iser-tools/alloyiser/Justfile`
- `iser-tools/anvomidaviser/Justfile`
- `iser-tools/atsiser/Justfile`
- `iser-tools/betlangiser/Justfile`
- `iser-tools/bqniser/Justfile`
- `iser-tools/chapeliser/Justfile`
- `iser-tools/dafniser/Justfile`
- `iser-tools/eclexiaiser/Justfile`
- `iser-tools/ephapaxiser/Justfile`
- `iser-tools/futharkiser/Justfile`
- `iser-tools/halideiser/Justfile`
- `iser-tools/idrisiser/Justfile`
- `iser-tools/iseriser/Justfile`
- `iser-tools/julianiser/Justfile`
- `iser-tools/lustreiser/Justfile`
- `iser-tools/mylangiser/Justfile`
- `iser-tools/nimiser/Justfile`
- `iser-tools/oblibeniser/Justfile`
- `iser-tools/otpiser/Justfile`
- `iser-tools/phronesiser/Justfile`
- `iser-tools/ponyiser/Justfile`
- `iser-tools/tlaiser/Justfile`
- `iser-tools/wokelangiser/Justfile`
- `scaffoldia/registry/gitbot/fleet-bot.ncl`
- `scaffoldia/registry/haskell/stack-library.ncl`
- `scaffoldia/registry/rescript/deno-app.ncl`
- `techstack-enforcer/Justfile`

### `{{AUTHOR_EMAIL_ALT}}`

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/.mailmap`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.github/.mailmap`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.github/.mailmap`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.github/.mailmap`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.github/.mailmap`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.github/.mailmap`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.github/.mailmap`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.github/.mailmap`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.github/.mailmap`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.github/.mailmap`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.github/.mailmap`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.github/.mailmap`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.github/.mailmap`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.github/.mailmap`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.github/.mailmap`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.github/.mailmap`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.github/.mailmap`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.github/.mailmap`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.github/.mailmap`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.github/.mailmap`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.github/.mailmap`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.github/.mailmap`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.github/.mailmap`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.github/.mailmap`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.github/.mailmap`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/.github/.mailmap`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-vite/.mailmap`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `v-ecosystem/v-benchmarks/.mailmap`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-grpc/.mailmap`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/.mailmap`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/.mailmap`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/.mailmap`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/.mailmap`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/.mailmap`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/.mailmap`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/.mailmap`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/.mailmap`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`

### `{{AUTHOR_ORG}}`

Author's organisation. NOTE: no filled instance of this exists anywhere in the estate — consider deleting the field instead.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/k9/examples/project-metadata.k9.ncl`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-rest/.machine_readable/contractiles/k9/examples/project-metadata.k9.ncl`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`

### `{{BUILD_CMD}}`

The exact command that builds this project.

Appears in:

- `QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-DEV.adoc`
- `iser-tools/halideiser/QUICKSTART-DEV.adoc`
- `iser-tools/idrisiser/QUICKSTART-DEV.adoc`
- `iser-tools/iseriser/QUICKSTART-DEV.adoc`
- `iser-tools/julianiser/QUICKSTART-DEV.adoc`
- `iser-tools/lustreiser/QUICKSTART-DEV.adoc`
- `iser-tools/mylangiser/QUICKSTART-DEV.adoc`
- `iser-tools/nimiser/QUICKSTART-DEV.adoc`
- `iser-tools/oblibeniser/QUICKSTART-DEV.adoc`
- `iser-tools/otpiser/QUICKSTART-DEV.adoc`
- `iser-tools/phronesiser/QUICKSTART-DEV.adoc`
- `iser-tools/ponyiser/QUICKSTART-DEV.adoc`
- `iser-tools/tlaiser/QUICKSTART-DEV.adoc`
- `iser-tools/wokelangiser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-rest/QUICKSTART-DEV.adoc`

### `{{BUILD_OUTPUT_PATH}}`

Where the build artefact lands.

Appears in:

- `QUICKSTART-MAINTAINER.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-MAINTAINER.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/halideiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/idrisiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/iseriser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/julianiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/lustreiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/mylangiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/nimiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/oblibeniser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/otpiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/phronesiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/ponyiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/tlaiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/wokelangiser/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-rest/QUICKSTART-MAINTAINER.adoc`

### `{{CMD}}`

Appears in:

- `k9-ecosystem/Justfile`

### `{{CONDUCT_TEAM}}`

Name of the conduct body. If there is no committee, rewrite the sentence rather than substituting a plural noun into 'a {{CONDUCT_TEAM}} member'.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/affinescript/CODE_OF_CONDUCT.md`
- `asdf-augmenters/CODE_OF_CONDUCT.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/CODE_OF_CONDUCT (1).md`
- `bridge-nginx-zig/CODE_OF_CONDUCT.md`
- `coq-ecosystem/coq-jr/CODE_OF_CONDUCT.md`
- `deno-ecosystem/CODE_OF_CONDUCT.md`
- `dnfinition/CODE_OF_CONDUCT.md`
- `idris2-ecosystem/CODE_OF_CONDUCT.md`
- `iser-tools/alloyiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `opm-canonicalizer/CODE_OF_CONDUCT.md`
- `packages/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/grpc/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/openapi/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/postgres/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/redis/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/tauri/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/compiler-source/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/early-return/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/env/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/poly-core/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/runtime-tools/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/alib/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/wasm-bridge/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/zig-ffi/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-codemods/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-conformance/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-for-rescript/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-interop/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/create-poly/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/greasy-rescripter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/bridge-web/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/dom-mounter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/full-stack/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/http-server/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/websocket/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-dom-mounter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-tea/.github/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-vite/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `riscv-guix-buildsys/CODE_OF_CONDUCT.md`
- `v-ecosystem/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-benchmarks/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`
- `zig-ecosystem/bridge-nginx-zig/CODE_OF_CONDUCT.md`

### `{{CONSTRAINTS}}`

Appears in:

- `iser-tools/phronesiser/Justfile`

### `{{COPIES}}`

Appears in:

- `rescript-ecosystem/packages/core/compiler-source/tests/analysis_tests/tests-reanalyze/deadcode-benchmark/Justfile`
- `rescript-ecosystem/rescript/tests/analysis_tests/tests-reanalyze/deadcode-benchmark/Justfile`

### `{{CSP_POLICY}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{DEFAULT_LOCALE}}`

Appears in:

- `iser-tools/wokelangiser/src/codegen/i18n.rs`

### `{{DEPS}}`

Prose summary of runtime/build dependencies.

Appears in:

- `QUICKSTART-MAINTAINER.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-MAINTAINER.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/halideiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/idrisiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/iseriser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/julianiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/lustreiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/mylangiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/nimiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/oblibeniser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/otpiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/phronesiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/ponyiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/tlaiser/QUICKSTART-MAINTAINER.adoc`
- `iser-tools/wokelangiser/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-MAINTAINER.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-MAINTAINER.adoc`
- `v-ecosystem/v-rest/QUICKSTART-MAINTAINER.adoc`

### `{{DESCRIPTION}}`

One-line description used in .github/settings.yml. HIGH PRIORITY: settings.yml is applied by a GitHub App, so an unfilled token here can be written into forge metadata verbatim.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/settings.yml`
- `affinescript-ecosystem/rattlescript/.github/settings.yml`

### `{{DILITHIUM5_PUBLIC_KEY}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{DOMAIN}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{DS_RECORD}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{ED448_PUBLIC_KEY}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{EXAMPLE}}`

Appears in:

- `rescript-ecosystem/packages/ffi/wasm-runtime/Justfile`

### `{{EXPIRES_AT}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{FALLBACK_SIGNATURE}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{FILE}}`

Appears in:

- `affinescript-ecosystem/rattlescript/affinescript/.build/Justfile`
- `asdf-augmenters/asdf-ghjk/Justfile`

### `{{GENERATED_AT}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{HALIDE_DIR}}`

Appears in:

- `iser-tools/halideiser/src/codegen/build_gen.rs`

### `{{HALIDE_TARGET}}`

Appears in:

- `iser-tools/halideiser/src/codegen/build_gen.rs`

### `{{LANG}}`

Appears in:

- `iser-tools/iseriser/Justfile`

### `{{LANG_STACK}}`

The language stack, in prose.

Appears in:

- `QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-DEV.adoc`
- `iser-tools/halideiser/QUICKSTART-DEV.adoc`
- `iser-tools/idrisiser/QUICKSTART-DEV.adoc`
- `iser-tools/iseriser/QUICKSTART-DEV.adoc`
- `iser-tools/julianiser/QUICKSTART-DEV.adoc`
- `iser-tools/lustreiser/QUICKSTART-DEV.adoc`
- `iser-tools/mylangiser/QUICKSTART-DEV.adoc`
- `iser-tools/nimiser/QUICKSTART-DEV.adoc`
- `iser-tools/oblibeniser/QUICKSTART-DEV.adoc`
- `iser-tools/otpiser/QUICKSTART-DEV.adoc`
- `iser-tools/phronesiser/QUICKSTART-DEV.adoc`
- `iser-tools/ponyiser/QUICKSTART-DEV.adoc`
- `iser-tools/tlaiser/QUICKSTART-DEV.adoc`
- `iser-tools/wokelangiser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-rest/QUICKSTART-DEV.adoc`

### `{{LICENSE}}`

SPDX identifier for this repo's licence.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescript-vite/container/Containerfile`
- `affinescript-ecosystem/affinescript-vite/container/manifest.toml`
- `affinescript-ecosystem/affinescript-vite/docs/developer/ABI-FFI-README.adoc`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/container/Containerfile`
- `affinescript-ecosystem/affinescriptiser/container/manifest.toml`
- `affinescript-ecosystem/affinescriptiser/docs/developer/ABI-FFI-README.adoc`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/affinescript/ABI-FFI-README.md`
- `affinescript-ecosystem/rattlescript/container/Containerfile`
- `affinescript-ecosystem/rattlescript/container/manifest.toml`
- `affinescript-ecosystem/rattlescript/docs/developer/ABI-FFI-README.adoc`
- `asdf-augmenters/asdf-acceleration-middleware/ABI-FFI-README.md`
- `asdf-augmenters/asdf-control-tower/ABI-FFI-README.md`
- `asdf-augmenters/asdf-metaiconic-plugin/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/ada/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/age/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/apko/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/arangodb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/bebop/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/borg/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/casket-ssg/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cassandra/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cfssl/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cobalt/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cobol/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/coredns/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cosign/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/couchdb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/cue/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/deno/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/dhall/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/doctl/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/dragonfly/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/hashicorp/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/httpd/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/influxdb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/kdl-fmt/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/lego/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/linkerd/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/mariadb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/mdbook/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/melange/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/metaiconic/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/mysql/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/neo4j/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/ocaml/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/opa/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/openlitespeed/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/openssh/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/openssl/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/orchid/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/pollen/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/pomerium/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/rekor/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/rescript/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/restic/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/rethinkdb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/security/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/serum/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/sops/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/step-ca/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/surrealdb/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/syft/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/taplo/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/trivy/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/ui/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/varnish/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/virtuoso/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/vlang/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/yj/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/yq/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/zig/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/zola/ABI-FFI-README.md`
- `asdf-augmenters/asdf-plugin-configurator/ABI-FFI-README.md`
- `asdf-augmenters/asdf-security-plugin/ABI-FFI-README.md`
- `asdf-augmenters/asdf-ui-plugin/ABI-FFI-README.md`
- `bridge-nginx-zig/ABI-FFI-README.md`
- `cadre-router/ABI-FFI-README.md`
- `cadre-tea-router/ABI-FFI-README.md`
- `czech-file-knife/ABI-FFI-README.md`
- `dnfinition/ABI-FFI-README.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/container/Containerfile`
- `iser-tools/alloyiser/container/manifest.toml`
- `iser-tools/alloyiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/container/Containerfile`
- `iser-tools/atsiser/container/manifest.toml`
- `iser-tools/atsiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/container/Containerfile`
- `iser-tools/betlangiser/container/manifest.toml`
- `iser-tools/betlangiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/container/Containerfile`
- `iser-tools/bqniser/container/manifest.toml`
- `iser-tools/bqniser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/container/Containerfile`
- `iser-tools/chapeliser/container/manifest.toml`
- `iser-tools/chapeliser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/container/Containerfile`
- `iser-tools/dafniser/container/manifest.toml`
- `iser-tools/dafniser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/container/Containerfile`
- `iser-tools/eclexiaiser/container/manifest.toml`
- `iser-tools/eclexiaiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/container/Containerfile`
- `iser-tools/ephapaxiser/container/manifest.toml`
- `iser-tools/ephapaxiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/container/Containerfile`
- `iser-tools/futharkiser/container/manifest.toml`
- `iser-tools/futharkiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/container/Containerfile`
- `iser-tools/halideiser/container/manifest.toml`
- `iser-tools/halideiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/container/Containerfile`
- `iser-tools/idrisiser/container/manifest.toml`
- `iser-tools/idrisiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/container/Containerfile`
- `iser-tools/iseriser/container/manifest.toml`
- `iser-tools/iseriser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/container/Containerfile`
- `iser-tools/julianiser/container/manifest.toml`
- `iser-tools/julianiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/container/Containerfile`
- `iser-tools/lustreiser/container/manifest.toml`
- `iser-tools/lustreiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/container/Containerfile`
- `iser-tools/mylangiser/container/manifest.toml`
- `iser-tools/mylangiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/container/Containerfile`
- `iser-tools/nimiser/container/manifest.toml`
- `iser-tools/nimiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/container/Containerfile`
- `iser-tools/oblibeniser/container/manifest.toml`
- `iser-tools/oblibeniser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/container/Containerfile`
- `iser-tools/otpiser/container/manifest.toml`
- `iser-tools/otpiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/container/Containerfile`
- `iser-tools/phronesiser/container/manifest.toml`
- `iser-tools/phronesiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/container/Containerfile`
- `iser-tools/ponyiser/container/manifest.toml`
- `iser-tools/ponyiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/container/Containerfile`
- `iser-tools/tlaiser/container/manifest.toml`
- `iser-tools/tlaiser/docs/developer/ABI-FFI-README.adoc`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/container/Containerfile`
- `iser-tools/wokelangiser/container/manifest.toml`
- `iser-tools/wokelangiser/docs/developer/ABI-FFI-README.adoc`
- `rescript-ecosystem/rescript-tea/container/Containerfile`

### `{{LOG}}`

Appears in:

- `iser-tools/phronesiser/Justfile`

### `{{MANIFEST}}`

Appears in:

- `iser-tools/iseriser/Justfile`
- `iser-tools/lustreiser/Justfile`
- `iser-tools/otpiser/Justfile`

### `{{MESSAGE}}`

Appears in:

- `asdf-augmenters/asdf-ghjk/Justfile`
- `rescript-ecosystem/packages/ffi/wasm-runtime/Justfile`

### `{{MUST_INVARIANTS}}`

The invariants this project guarantees. Not answerable in a bootstrap; it is the point of the repo.

Appears in:

- `QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-DEV.adoc`
- `iser-tools/halideiser/QUICKSTART-DEV.adoc`
- `iser-tools/idrisiser/QUICKSTART-DEV.adoc`
- `iser-tools/iseriser/QUICKSTART-DEV.adoc`
- `iser-tools/julianiser/QUICKSTART-DEV.adoc`
- `iser-tools/lustreiser/QUICKSTART-DEV.adoc`
- `iser-tools/mylangiser/QUICKSTART-DEV.adoc`
- `iser-tools/nimiser/QUICKSTART-DEV.adoc`
- `iser-tools/oblibeniser/QUICKSTART-DEV.adoc`
- `iser-tools/otpiser/QUICKSTART-DEV.adoc`
- `iser-tools/phronesiser/QUICKSTART-DEV.adoc`
- `iser-tools/ponyiser/QUICKSTART-DEV.adoc`
- `iser-tools/tlaiser/QUICKSTART-DEV.adoc`
- `iser-tools/wokelangiser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-rest/QUICKSTART-DEV.adoc`

### `{{NAME}}`

Appears in:

- `asdf-augmenters/asdf-ghjk/Justfile`
- `iser-tools/iseriser/Justfile`
- `rescript-ecosystem/packages/ffi/wasm-runtime/Justfile`
- `rescript-ecosystem/packages/ffi/wasm-runtime/scripts/create-example.sh`

### `{{OPENSSF_PROJECT_ID}}`

OpenSSF project ID, same registration.

Appears in:

- `affinescript-ecosystem/rattlescript/TEMPLATE-STANDARDS-AUDIT.adoc`

### `{{PGP_FINGERPRINT}}`

Full fingerprint of the security-contact PGP key. NOTE: no key is published anywhere in this estate — if none is held, delete the PGP block rather than inventing one.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/SECURITY.md`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.github/SECURITY.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.github/SECURITY.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/affinescript/SECURITY.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/SECURITY (1).md`
- `dnfinition/SECURITY.md`
- `iser-tools/alloyiser/.github/SECURITY.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.github/SECURITY.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.github/SECURITY.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.github/SECURITY.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.github/SECURITY.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.github/SECURITY.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.github/SECURITY.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.github/SECURITY.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.github/SECURITY.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.github/SECURITY.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.github/SECURITY.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.github/SECURITY.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.github/SECURITY.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.github/SECURITY.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.github/SECURITY.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.github/SECURITY.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.github/SECURITY.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.github/SECURITY.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.github/SECURITY.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.github/SECURITY.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.github/SECURITY.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.github/SECURITY.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`

### `{{PGP_KEY_URL}}`

Public URL the PGP key can be fetched from. Same caveat as PGP_FINGERPRINT.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/SECURITY.md`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescript-vite/.well-known/security.txt`
- `affinescript-ecosystem/affinescriptiser/.github/SECURITY.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/.github/SECURITY.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/affinescript/SECURITY.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/SECURITY (1).md`
- `dnfinition/SECURITY.md`
- `iser-tools/alloyiser/.github/SECURITY.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.well-known/security.txt`
- `iser-tools/atsiser/.github/SECURITY.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.well-known/security.txt`
- `iser-tools/betlangiser/.github/SECURITY.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.well-known/security.txt`
- `iser-tools/bqniser/.github/SECURITY.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.well-known/security.txt`
- `iser-tools/chapeliser/.github/SECURITY.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.well-known/security.txt`
- `iser-tools/dafniser/.github/SECURITY.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.well-known/security.txt`
- `iser-tools/eclexiaiser/.github/SECURITY.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.well-known/security.txt`
- `iser-tools/ephapaxiser/.github/SECURITY.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.well-known/security.txt`
- `iser-tools/futharkiser/.github/SECURITY.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.well-known/security.txt`
- `iser-tools/halideiser/.github/SECURITY.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.well-known/security.txt`
- `iser-tools/idrisiser/.github/SECURITY.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.well-known/security.txt`
- `iser-tools/iseriser/.github/SECURITY.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.well-known/security.txt`
- `iser-tools/julianiser/.github/SECURITY.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.well-known/security.txt`
- `iser-tools/lustreiser/.github/SECURITY.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.well-known/security.txt`
- `iser-tools/mylangiser/.github/SECURITY.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.well-known/security.txt`
- `iser-tools/nimiser/.github/SECURITY.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.well-known/security.txt`
- `iser-tools/oblibeniser/.github/SECURITY.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.well-known/security.txt`
- `iser-tools/otpiser/.github/SECURITY.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.well-known/security.txt`
- `iser-tools/phronesiser/.github/SECURITY.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.well-known/security.txt`
- `iser-tools/ponyiser/.github/SECURITY.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.well-known/security.txt`
- `iser-tools/tlaiser/.github/SECURITY.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.well-known/security.txt`
- `iser-tools/wokelangiser/.github/SECURITY.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.well-known/security.txt`
- `packages/SECURITY.md`
- `rescript-ecosystem/packages/bindings/d3/SECURITY.md`
- `rescript-ecosystem/packages/bindings/postgres/SECURITY.md`
- `rescript-ecosystem/packages/bindings/redis/SECURITY.md`
- `rescript-ecosystem/packages/core/compiler-source/SECURITY.md`
- `rescript-ecosystem/packages/core/early-return/SECURITY.md`
- `rescript-ecosystem/packages/core/poly-core/SECURITY.md`
- `rescript-ecosystem/packages/core/runtime-tools/SECURITY.md`
- `rescript-ecosystem/packages/ffi/alib/SECURITY.md`
- `rescript-ecosystem/packages/ffi/wasm-bridge/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-codemods/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-conformance/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-for-rescript/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-interop/SECURITY.md`
- `rescript-ecosystem/packages/tooling/create-poly/SECURITY.md`
- `rescript-ecosystem/packages/tooling/greasy-rescripter/SECURITY.md`
- `rescript-ecosystem/packages/web/http-server/SECURITY.md`
- `rescript-ecosystem/packages/web/websocket/SECURITY.md`
- `rescript-ecosystem/rescript-tea/.github/SECURITY.md`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/.well-known/security.txt`
- `rescript-ecosystem/rescript-vite/.well-known/security.txt`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `rescript-ecosystem/rescript-vite/SECURITY.md`
- `v-ecosystem/v-benchmarks/.well-known/security.txt`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-benchmarks/SECURITY.md`
- `v-ecosystem/v-grpc/.well-known/security.txt`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/.well-known/security.txt`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/SECURITY.md`
- `v-ecosystem/v-middleware/.well-known/security.txt`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/SECURITY.md`
- `v-ecosystem/v-rest/.well-known/security.txt`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/.well-known/security.txt`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/SECURITY.md`
- `v-ecosystem/v-validator/.well-known/security.txt`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/SECURITY.md`
- `v-ecosystem/v-zig-ffi/.well-known/security.txt`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_graphql/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_grpc/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_rest/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/SECURITY.md`

### `{{PLACEHOLDERS}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{POLICY}}`

Appears in:

- `iser-tools/phronesiser/Justfile`

### `{{PORT}}`

Port the container service listens on.

Appears in:

- `affinescript-ecosystem/affinescript-vite/container/Containerfile`
- `affinescript-ecosystem/affinescript-vite/container/compose.toml`
- `affinescript-ecosystem/affinescript-vite/container/deploy.k9.ncl`
- `affinescript-ecosystem/affinescript-vite/container/entrypoint.sh`
- `affinescript-ecosystem/affinescript-vite/container/manifest.toml`
- `affinescript-ecosystem/affinescript-vite/container/vordr.toml`
- `affinescript-ecosystem/affinescriptiser/container/Containerfile`
- `affinescript-ecosystem/affinescriptiser/container/compose.toml`
- `affinescript-ecosystem/affinescriptiser/container/deploy.k9.ncl`
- `affinescript-ecosystem/affinescriptiser/container/entrypoint.sh`
- `affinescript-ecosystem/affinescriptiser/container/manifest.toml`
- `affinescript-ecosystem/affinescriptiser/container/vordr.toml`
- `affinescript-ecosystem/rattlescript/container/Containerfile`
- `affinescript-ecosystem/rattlescript/container/compose.toml`
- `affinescript-ecosystem/rattlescript/container/deploy.k9.ncl`
- `affinescript-ecosystem/rattlescript/container/entrypoint.sh`
- `affinescript-ecosystem/rattlescript/container/manifest.toml`
- `affinescript-ecosystem/rattlescript/container/vordr.toml`
- `asdf-augmenters/asdf-ghjk/Justfile`
- `iser-tools/alloyiser/container/Containerfile`
- `iser-tools/alloyiser/container/compose.toml`
- `iser-tools/alloyiser/container/deploy.k9.ncl`
- `iser-tools/alloyiser/container/entrypoint.sh`
- `iser-tools/alloyiser/container/manifest.toml`
- `iser-tools/alloyiser/container/vordr.toml`
- `iser-tools/atsiser/container/Containerfile`
- `iser-tools/atsiser/container/compose.toml`
- `iser-tools/atsiser/container/deploy.k9.ncl`
- `iser-tools/atsiser/container/entrypoint.sh`
- `iser-tools/atsiser/container/manifest.toml`
- `iser-tools/atsiser/container/vordr.toml`
- `iser-tools/betlangiser/container/Containerfile`
- `iser-tools/betlangiser/container/compose.toml`
- `iser-tools/betlangiser/container/deploy.k9.ncl`
- `iser-tools/betlangiser/container/entrypoint.sh`
- `iser-tools/betlangiser/container/manifest.toml`
- `iser-tools/betlangiser/container/vordr.toml`
- `iser-tools/bqniser/container/Containerfile`
- `iser-tools/bqniser/container/compose.toml`
- `iser-tools/bqniser/container/deploy.k9.ncl`
- `iser-tools/bqniser/container/entrypoint.sh`
- `iser-tools/bqniser/container/manifest.toml`
- `iser-tools/bqniser/container/vordr.toml`
- `iser-tools/chapeliser/container/Containerfile`
- `iser-tools/chapeliser/container/compose.toml`
- `iser-tools/chapeliser/container/deploy.k9.ncl`
- `iser-tools/chapeliser/container/entrypoint.sh`
- `iser-tools/chapeliser/container/manifest.toml`
- `iser-tools/chapeliser/container/vordr.toml`
- `iser-tools/dafniser/container/Containerfile`
- `iser-tools/dafniser/container/compose.toml`
- `iser-tools/dafniser/container/deploy.k9.ncl`
- `iser-tools/dafniser/container/entrypoint.sh`
- `iser-tools/dafniser/container/manifest.toml`
- `iser-tools/dafniser/container/vordr.toml`
- `iser-tools/eclexiaiser/container/Containerfile`
- `iser-tools/eclexiaiser/container/compose.toml`
- `iser-tools/eclexiaiser/container/deploy.k9.ncl`
- `iser-tools/eclexiaiser/container/entrypoint.sh`
- `iser-tools/eclexiaiser/container/manifest.toml`
- `iser-tools/eclexiaiser/container/vordr.toml`
- `iser-tools/ephapaxiser/container/Containerfile`
- `iser-tools/ephapaxiser/container/compose.toml`
- `iser-tools/ephapaxiser/container/deploy.k9.ncl`
- `iser-tools/ephapaxiser/container/entrypoint.sh`
- `iser-tools/ephapaxiser/container/manifest.toml`
- `iser-tools/ephapaxiser/container/vordr.toml`
- `iser-tools/futharkiser/container/Containerfile`
- `iser-tools/futharkiser/container/compose.toml`
- `iser-tools/futharkiser/container/deploy.k9.ncl`
- `iser-tools/futharkiser/container/entrypoint.sh`
- `iser-tools/futharkiser/container/manifest.toml`
- `iser-tools/futharkiser/container/vordr.toml`
- `iser-tools/halideiser/container/Containerfile`
- `iser-tools/halideiser/container/compose.toml`
- `iser-tools/halideiser/container/deploy.k9.ncl`
- `iser-tools/halideiser/container/entrypoint.sh`
- `iser-tools/halideiser/container/manifest.toml`
- `iser-tools/halideiser/container/vordr.toml`
- `iser-tools/idrisiser/container/Containerfile`
- `iser-tools/idrisiser/container/compose.toml`
- `iser-tools/idrisiser/container/deploy.k9.ncl`
- `iser-tools/idrisiser/container/entrypoint.sh`
- `iser-tools/idrisiser/container/manifest.toml`
- `iser-tools/idrisiser/container/vordr.toml`
- `iser-tools/iseriser/container/Containerfile`
- `iser-tools/iseriser/container/compose.toml`
- `iser-tools/iseriser/container/deploy.k9.ncl`
- `iser-tools/iseriser/container/entrypoint.sh`
- `iser-tools/iseriser/container/manifest.toml`
- `iser-tools/iseriser/container/vordr.toml`
- `iser-tools/julianiser/container/Containerfile`
- `iser-tools/julianiser/container/compose.toml`
- `iser-tools/julianiser/container/deploy.k9.ncl`
- `iser-tools/julianiser/container/entrypoint.sh`
- `iser-tools/julianiser/container/manifest.toml`
- `iser-tools/julianiser/container/vordr.toml`
- `iser-tools/lustreiser/container/Containerfile`
- `iser-tools/lustreiser/container/compose.toml`
- `iser-tools/lustreiser/container/deploy.k9.ncl`
- `iser-tools/lustreiser/container/entrypoint.sh`
- `iser-tools/lustreiser/container/manifest.toml`
- `iser-tools/lustreiser/container/vordr.toml`
- `iser-tools/mylangiser/container/Containerfile`
- `iser-tools/mylangiser/container/compose.toml`
- `iser-tools/mylangiser/container/deploy.k9.ncl`
- `iser-tools/mylangiser/container/entrypoint.sh`
- `iser-tools/mylangiser/container/manifest.toml`
- `iser-tools/mylangiser/container/vordr.toml`
- `iser-tools/nimiser/container/Containerfile`
- `iser-tools/nimiser/container/compose.toml`
- `iser-tools/nimiser/container/deploy.k9.ncl`
- `iser-tools/nimiser/container/entrypoint.sh`
- `iser-tools/nimiser/container/manifest.toml`
- `iser-tools/nimiser/container/vordr.toml`
- `iser-tools/oblibeniser/container/Containerfile`
- `iser-tools/oblibeniser/container/compose.toml`
- `iser-tools/oblibeniser/container/deploy.k9.ncl`
- `iser-tools/oblibeniser/container/entrypoint.sh`
- `iser-tools/oblibeniser/container/manifest.toml`
- `iser-tools/oblibeniser/container/vordr.toml`
- `iser-tools/otpiser/container/Containerfile`
- `iser-tools/otpiser/container/compose.toml`
- `iser-tools/otpiser/container/deploy.k9.ncl`
- `iser-tools/otpiser/container/entrypoint.sh`
- `iser-tools/otpiser/container/manifest.toml`
- `iser-tools/otpiser/container/vordr.toml`
- `iser-tools/phronesiser/container/Containerfile`
- `iser-tools/phronesiser/container/compose.toml`
- `iser-tools/phronesiser/container/deploy.k9.ncl`
- `iser-tools/phronesiser/container/entrypoint.sh`
- `iser-tools/phronesiser/container/manifest.toml`
- `iser-tools/phronesiser/container/vordr.toml`
- `iser-tools/ponyiser/container/Containerfile`
- `iser-tools/ponyiser/container/compose.toml`
- `iser-tools/ponyiser/container/deploy.k9.ncl`
- `iser-tools/ponyiser/container/entrypoint.sh`
- `iser-tools/ponyiser/container/manifest.toml`
- `iser-tools/ponyiser/container/vordr.toml`
- `iser-tools/tlaiser/container/Containerfile`
- `iser-tools/tlaiser/container/compose.toml`
- `iser-tools/tlaiser/container/deploy.k9.ncl`
- `iser-tools/tlaiser/container/entrypoint.sh`
- `iser-tools/tlaiser/container/manifest.toml`
- `iser-tools/tlaiser/container/vordr.toml`
- `iser-tools/wokelangiser/container/Containerfile`
- `iser-tools/wokelangiser/container/compose.toml`
- `iser-tools/wokelangiser/container/deploy.k9.ncl`
- `iser-tools/wokelangiser/container/entrypoint.sh`
- `iser-tools/wokelangiser/container/manifest.toml`
- `iser-tools/wokelangiser/container/vordr.toml`
- `rescript-ecosystem/rescript-tea/container/Containerfile`
- `rescript-ecosystem/rescript-tea/container/deploy.k9.ncl`
- `rescript-ecosystem/rescript-tea/container/entrypoint.sh`

### `{{PRIMARY_LANGUAGE}}`

Appears in:

- `affinescript-ecosystem/rattlescript/tests/e2e/template_instantiation_test.sh`

### `{{PRIMARY_SIGNATURE}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{PROJECT_DESCRIPTION}}`

One-line description, matching the forge description.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescript-vite/container/Containerfile`
- `affinescript-ecosystem/affinescript-vite/container/manifest.toml`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/container/Containerfile`
- `affinescript-ecosystem/affinescriptiser/container/manifest.toml`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/container/Containerfile`
- `affinescript-ecosystem/rattlescript/container/manifest.toml`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/container/Containerfile`
- `iser-tools/alloyiser/container/manifest.toml`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/container/Containerfile`
- `iser-tools/atsiser/container/manifest.toml`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/container/Containerfile`
- `iser-tools/betlangiser/container/manifest.toml`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/container/Containerfile`
- `iser-tools/bqniser/container/manifest.toml`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/container/Containerfile`
- `iser-tools/chapeliser/container/manifest.toml`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/container/Containerfile`
- `iser-tools/dafniser/container/manifest.toml`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/container/Containerfile`
- `iser-tools/eclexiaiser/container/manifest.toml`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/container/Containerfile`
- `iser-tools/ephapaxiser/container/manifest.toml`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/container/Containerfile`
- `iser-tools/futharkiser/container/manifest.toml`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/container/Containerfile`
- `iser-tools/halideiser/container/manifest.toml`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/container/Containerfile`
- `iser-tools/idrisiser/container/manifest.toml`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/container/Containerfile`
- `iser-tools/iseriser/container/manifest.toml`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/container/Containerfile`
- `iser-tools/julianiser/container/manifest.toml`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/container/Containerfile`
- `iser-tools/lustreiser/container/manifest.toml`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/container/Containerfile`
- `iser-tools/mylangiser/container/manifest.toml`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/container/Containerfile`
- `iser-tools/nimiser/container/manifest.toml`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/container/Containerfile`
- `iser-tools/oblibeniser/container/manifest.toml`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/container/Containerfile`
- `iser-tools/otpiser/container/manifest.toml`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/container/Containerfile`
- `iser-tools/phronesiser/container/manifest.toml`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/container/Containerfile`
- `iser-tools/ponyiser/container/manifest.toml`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/container/Containerfile`
- `iser-tools/tlaiser/container/manifest.toml`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/container/Containerfile`
- `iser-tools/wokelangiser/container/manifest.toml`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/container/Containerfile`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`

### `{{PROJECT_DOMAIN}}`

Taxonomy value for the subject domain.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/rattlescript/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/alloyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/betlangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/bqniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/chapeliser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/dafniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/eclexiaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ephapaxiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/futharkiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/idrisiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/lustreiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/nimiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/oblibeniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/otpiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/phronesiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ponyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/tlaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/wokelangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `rescript-ecosystem/rescript-tea/.machine_readable/anchors/ANCHOR.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-validator/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/anchors/ANCHOR.a2ml`

### `{{PROJECT_KIND}}`

Taxonomy value (library, service, tool, lab…).

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/rattlescript/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/alloyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/betlangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/bqniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/chapeliser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/dafniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/eclexiaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ephapaxiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/futharkiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/idrisiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/lustreiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/nimiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/oblibeniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/otpiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/phronesiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ponyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/tlaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/wokelangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `k9-ecosystem/.machine_readable/anchors/SATELLITE-ANCHOR.template.a2ml`
- `rescript-ecosystem/rescript-tea/.machine_readable/anchors/ANCHOR.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-validator/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/anchors/ANCHOR.a2ml`

### `{{PROJECT_PURPOSE}}`

One line: what this exists to do.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/affinescript-vite/guix.scm`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/affinescriptiser/guix.scm`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.machine_readable/anchors/ANCHOR.a2ml`
- `affinescript-ecosystem/rattlescript/guix.scm`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/alloyiser/guix.scm`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/guix.scm`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/betlangiser/guix.scm`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/bqniser/guix.scm`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/chapeliser/guix.scm`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/dafniser/guix.scm`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/eclexiaiser/guix.scm`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ephapaxiser/guix.scm`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/futharkiser/guix.scm`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/guix.scm`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/idrisiser/guix.scm`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/guix.scm`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/guix.scm`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/lustreiser/guix.scm`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/guix.scm`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/nimiser/guix.scm`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/oblibeniser/guix.scm`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/otpiser/guix.scm`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/phronesiser/guix.scm`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/ponyiser/guix.scm`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/tlaiser/guix.scm`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.machine_readable/anchors/ANCHOR.a2ml`
- `iser-tools/wokelangiser/guix.scm`
- `k9-ecosystem/.machine_readable/anchors/SATELLITE-ANCHOR.template.a2ml`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/.machine_readable/anchors/ANCHOR.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-grpc/guix.scm`
- `v-ecosystem/v-idris-abi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-rest/guix.scm`
- `v-ecosystem/v-telemetry/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-validator/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/anchors/ANCHOR.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/anchors/ANCHOR.a2ml`

### `{{PROJECT_UNIQUE_STRENGTH}}`

What this does that its alternatives do not.

Appears in:

- `.machine_readable/bot_directives/methodology.a2ml`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/agent_instructions/methodology.a2ml`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/agent_instructions/methodology.a2ml`
- `affinescript-ecosystem/rattlescript/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/alloyiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/anvomidaviser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/atsiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/betlangiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/bqniser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/chapeliser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/dafniser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/eclexiaiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/ephapaxiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/futharkiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/halideiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/idrisiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/iseriser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/julianiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/lustreiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/mylangiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/nimiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/oblibeniser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/otpiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/phronesiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/ponyiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/tlaiser/.machine_readable/agent_instructions/methodology.a2ml`
- `iser-tools/wokelangiser/.machine_readable/agent_instructions/methodology.a2ml`
- `rescript-ecosystem/idaptik-rescript13-staging/.machine_readable/agent_instructions/methodology.a2ml`
- `rescript-ecosystem/rescript-evangeliser/.machine_readable/agent_instructions/methodology.a2ml`
- `rescript-ecosystem/rescript-tea/.machine_readable/agent_instructions/methodology.a2ml`
- `rescript-ecosystem/rescript/.machine_readable/agent_instructions/methodology.a2ml`
- `v-ecosystem/v-graphql/.machine_readable/agent_instructions/methodology.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/agent_instructions/methodology.a2ml`
- `v-ecosystem/v-rest/.machine_readable/agent_instructions/methodology.a2ml`

### `{{RECIPE}}`

Appears in:

- `rescript-ecosystem/packages/tooling/evangeliser/Justfile`
- `rescript-ecosystem/rescript-evangeliser/Justfile`

### `{{REGISTRY}}`

Container registry to publish to.

Appears in:

- `affinescript-ecosystem/affinescript-vite/container/compose.toml`
- `affinescript-ecosystem/affinescript-vite/container/ct-build.sh`
- `affinescript-ecosystem/affinescript-vite/container/deploy.k9.ncl`
- `affinescript-ecosystem/affinescriptiser/container/compose.toml`
- `affinescript-ecosystem/affinescriptiser/container/ct-build.sh`
- `affinescript-ecosystem/affinescriptiser/container/deploy.k9.ncl`
- `affinescript-ecosystem/rattlescript/container/compose.toml`
- `affinescript-ecosystem/rattlescript/container/ct-build.sh`
- `affinescript-ecosystem/rattlescript/container/deploy.k9.ncl`
- `iser-tools/alloyiser/container/compose.toml`
- `iser-tools/alloyiser/container/ct-build.sh`
- `iser-tools/alloyiser/container/deploy.k9.ncl`
- `iser-tools/atsiser/container/compose.toml`
- `iser-tools/atsiser/container/ct-build.sh`
- `iser-tools/atsiser/container/deploy.k9.ncl`
- `iser-tools/betlangiser/container/compose.toml`
- `iser-tools/betlangiser/container/ct-build.sh`
- `iser-tools/betlangiser/container/deploy.k9.ncl`
- `iser-tools/bqniser/container/compose.toml`
- `iser-tools/bqniser/container/ct-build.sh`
- `iser-tools/bqniser/container/deploy.k9.ncl`
- `iser-tools/chapeliser/container/compose.toml`
- `iser-tools/chapeliser/container/ct-build.sh`
- `iser-tools/chapeliser/container/deploy.k9.ncl`
- `iser-tools/dafniser/container/compose.toml`
- `iser-tools/dafniser/container/ct-build.sh`
- `iser-tools/dafniser/container/deploy.k9.ncl`
- `iser-tools/eclexiaiser/container/compose.toml`
- `iser-tools/eclexiaiser/container/ct-build.sh`
- `iser-tools/eclexiaiser/container/deploy.k9.ncl`
- `iser-tools/ephapaxiser/container/compose.toml`
- `iser-tools/ephapaxiser/container/ct-build.sh`
- `iser-tools/ephapaxiser/container/deploy.k9.ncl`
- `iser-tools/futharkiser/container/compose.toml`
- `iser-tools/futharkiser/container/ct-build.sh`
- `iser-tools/futharkiser/container/deploy.k9.ncl`
- `iser-tools/halideiser/container/compose.toml`
- `iser-tools/halideiser/container/ct-build.sh`
- `iser-tools/halideiser/container/deploy.k9.ncl`
- `iser-tools/idrisiser/container/compose.toml`
- `iser-tools/idrisiser/container/ct-build.sh`
- `iser-tools/idrisiser/container/deploy.k9.ncl`
- `iser-tools/iseriser/container/compose.toml`
- `iser-tools/iseriser/container/ct-build.sh`
- `iser-tools/iseriser/container/deploy.k9.ncl`
- `iser-tools/julianiser/container/compose.toml`
- `iser-tools/julianiser/container/ct-build.sh`
- `iser-tools/julianiser/container/deploy.k9.ncl`
- `iser-tools/lustreiser/container/compose.toml`
- `iser-tools/lustreiser/container/ct-build.sh`
- `iser-tools/lustreiser/container/deploy.k9.ncl`
- `iser-tools/mylangiser/container/compose.toml`
- `iser-tools/mylangiser/container/ct-build.sh`
- `iser-tools/mylangiser/container/deploy.k9.ncl`
- `iser-tools/nimiser/container/compose.toml`
- `iser-tools/nimiser/container/ct-build.sh`
- `iser-tools/nimiser/container/deploy.k9.ncl`
- `iser-tools/oblibeniser/container/compose.toml`
- `iser-tools/oblibeniser/container/ct-build.sh`
- `iser-tools/oblibeniser/container/deploy.k9.ncl`
- `iser-tools/otpiser/container/compose.toml`
- `iser-tools/otpiser/container/ct-build.sh`
- `iser-tools/otpiser/container/deploy.k9.ncl`
- `iser-tools/phronesiser/container/compose.toml`
- `iser-tools/phronesiser/container/ct-build.sh`
- `iser-tools/phronesiser/container/deploy.k9.ncl`
- `iser-tools/ponyiser/container/compose.toml`
- `iser-tools/ponyiser/container/ct-build.sh`
- `iser-tools/ponyiser/container/deploy.k9.ncl`
- `iser-tools/tlaiser/container/compose.toml`
- `iser-tools/tlaiser/container/ct-build.sh`
- `iser-tools/tlaiser/container/deploy.k9.ncl`
- `iser-tools/wokelangiser/container/compose.toml`
- `iser-tools/wokelangiser/container/ct-build.sh`
- `iser-tools/wokelangiser/container/deploy.k9.ncl`
- `rescript-ecosystem/packages/ffi/wasm-runtime/Justfile`
- `rescript-ecosystem/rescript-tea/container/ct-build.sh`
- `rescript-ecosystem/rescript-tea/container/deploy.k9.ncl`

### `{{REPO_DESCRIPTION}}`

Appears in:

- `affinescript-ecosystem/affinescript-vite/.machine_readable/ECOSYSTEM.a2ml`
- `affinescript-ecosystem/rattlescript/.machine_readable/ECOSYSTEM.a2ml`
- `affinescript-ecosystem/rattlescript/tests/e2e/template_instantiation_test.sh`

### `{{RESPONSE_TIME}}`

Initial-response SLA for a security or conduct report. Promise only what a solo maintainer can actually meet.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.github/CODE_OF_CONDUCT.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/affinescript/CODE_OF_CONDUCT.md`
- `asdf-augmenters/CODE_OF_CONDUCT.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/CODE_OF_CONDUCT (1).md`
- `bridge-nginx-zig/CODE_OF_CONDUCT.md`
- `coq-ecosystem/coq-jr/CODE_OF_CONDUCT.md`
- `deno-ecosystem/CODE_OF_CONDUCT.md`
- `dnfinition/CODE_OF_CONDUCT.md`
- `idris2-ecosystem/CODE_OF_CONDUCT.md`
- `iser-tools/alloyiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.github/CODE_OF_CONDUCT.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `opm-canonicalizer/CODE_OF_CONDUCT.md`
- `packages/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/grpc/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/openapi/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/postgres/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/redis/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/bindings/tauri/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/compiler-source/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/early-return/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/env/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/poly-core/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/core/runtime-tools/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/alib/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/wasm-bridge/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/ffi/zig-ffi/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-codemods/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-conformance/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-for-rescript/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/alib-interop/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/create-poly/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/tooling/greasy-rescripter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/bridge-web/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/dom-mounter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/full-stack/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/http-server/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/packages/web/websocket/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-dom-mounter/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-tea/.github/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-vite/CODE_OF_CONDUCT.md`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `riscv-guix-buildsys/CODE_OF_CONDUCT.md`
- `v-ecosystem/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-benchmarks/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/CODE_OF_CONDUCT.md`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/CODE_OF_CONDUCT.md`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`
- `zig-ecosystem/bridge-nginx-zig/CODE_OF_CONDUCT.md`

### `{{SCRIPT}}`

Appears in:

- `asdf-augmenters/asdf-ghjk/Justfile`

### `{{SECURITY_CONTACT}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{SECURITY_EMAIL}}`

Address for private vulnerability reports. Two competing values exist in the estate (`6759885+hyperpolymath@users.noreply.github.com` and `security@hyperpolymath.org`) — pick one deliberately.

Appears in:

- `affinescript-ecosystem/affinescript-vite/.github/SECURITY.md`
- `affinescript-ecosystem/affinescript-vite/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescript-vite/.well-known/security.txt`
- `affinescript-ecosystem/affinescriptiser/.github/SECURITY.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/.github/SECURITY.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/affinescript/SECURITY.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/SECURITY (1).md`
- `dnfinition/SECURITY.md`
- `iser-tools/alloyiser/.github/SECURITY.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.well-known/security.txt`
- `iser-tools/atsiser/.github/SECURITY.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.well-known/security.txt`
- `iser-tools/betlangiser/.github/SECURITY.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.well-known/security.txt`
- `iser-tools/bqniser/.github/SECURITY.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.well-known/security.txt`
- `iser-tools/chapeliser/.github/SECURITY.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.well-known/security.txt`
- `iser-tools/dafniser/.github/SECURITY.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.well-known/security.txt`
- `iser-tools/eclexiaiser/.github/SECURITY.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.well-known/security.txt`
- `iser-tools/ephapaxiser/.github/SECURITY.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.well-known/security.txt`
- `iser-tools/futharkiser/.github/SECURITY.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.well-known/security.txt`
- `iser-tools/halideiser/.github/SECURITY.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.well-known/security.txt`
- `iser-tools/idrisiser/.github/SECURITY.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.well-known/security.txt`
- `iser-tools/iseriser/.github/SECURITY.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.well-known/security.txt`
- `iser-tools/julianiser/.github/SECURITY.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.well-known/security.txt`
- `iser-tools/lustreiser/.github/SECURITY.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.well-known/security.txt`
- `iser-tools/mylangiser/.github/SECURITY.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.well-known/security.txt`
- `iser-tools/nimiser/.github/SECURITY.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.well-known/security.txt`
- `iser-tools/oblibeniser/.github/SECURITY.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.well-known/security.txt`
- `iser-tools/otpiser/.github/SECURITY.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.well-known/security.txt`
- `iser-tools/phronesiser/.github/SECURITY.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.well-known/security.txt`
- `iser-tools/ponyiser/.github/SECURITY.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.well-known/security.txt`
- `iser-tools/tlaiser/.github/SECURITY.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.well-known/security.txt`
- `iser-tools/wokelangiser/.github/SECURITY.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.well-known/security.txt`
- `rescript-ecosystem/rescript-tea/.well-known/security.txt`
- `rescript-ecosystem/rescript-vite/.well-known/security.txt`
- `v-ecosystem/v-benchmarks/.well-known/security.txt`
- `v-ecosystem/v-idris-abi/.well-known/security.txt`
- `v-ecosystem/v-middleware/.well-known/security.txt`
- `v-ecosystem/v-rest/.well-known/security.txt`
- `v-ecosystem/v-telemetry/.well-known/security.txt`
- `v-ecosystem/v-validator/.well-known/security.txt`
- `v-ecosystem/v-zig-ffi/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_graphql/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_grpc/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_rest/.well-known/security.txt`

### `{{SECURITY_TXT_EXPIRES}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{SERVICE_NAME}}`

Container service name.

Appears in:

- `affinescript-ecosystem/affinescript-vite/container/.gatekeeper.yaml`
- `affinescript-ecosystem/affinescript-vite/container/Containerfile`
- `affinescript-ecosystem/affinescript-vite/container/compose.toml`
- `affinescript-ecosystem/affinescript-vite/container/ct-build.sh`
- `affinescript-ecosystem/affinescript-vite/container/entrypoint.sh`
- `affinescript-ecosystem/affinescript-vite/container/manifest.toml`
- `affinescript-ecosystem/affinescript-vite/container/vordr.toml`
- `affinescript-ecosystem/affinescriptiser/container/.gatekeeper.yaml`
- `affinescript-ecosystem/affinescriptiser/container/Containerfile`
- `affinescript-ecosystem/affinescriptiser/container/compose.toml`
- `affinescript-ecosystem/affinescriptiser/container/ct-build.sh`
- `affinescript-ecosystem/affinescriptiser/container/entrypoint.sh`
- `affinescript-ecosystem/affinescriptiser/container/manifest.toml`
- `affinescript-ecosystem/affinescriptiser/container/vordr.toml`
- `affinescript-ecosystem/rattlescript/container/.gatekeeper.yaml`
- `affinescript-ecosystem/rattlescript/container/Containerfile`
- `affinescript-ecosystem/rattlescript/container/compose.toml`
- `affinescript-ecosystem/rattlescript/container/ct-build.sh`
- `affinescript-ecosystem/rattlescript/container/entrypoint.sh`
- `affinescript-ecosystem/rattlescript/container/manifest.toml`
- `affinescript-ecosystem/rattlescript/container/vordr.toml`
- `iser-tools/alloyiser/container/.gatekeeper.yaml`
- `iser-tools/alloyiser/container/Containerfile`
- `iser-tools/alloyiser/container/compose.toml`
- `iser-tools/alloyiser/container/ct-build.sh`
- `iser-tools/alloyiser/container/entrypoint.sh`
- `iser-tools/alloyiser/container/manifest.toml`
- `iser-tools/alloyiser/container/vordr.toml`
- `iser-tools/atsiser/container/.gatekeeper.yaml`
- `iser-tools/atsiser/container/Containerfile`
- `iser-tools/atsiser/container/compose.toml`
- `iser-tools/atsiser/container/ct-build.sh`
- `iser-tools/atsiser/container/entrypoint.sh`
- `iser-tools/atsiser/container/manifest.toml`
- `iser-tools/atsiser/container/vordr.toml`
- `iser-tools/betlangiser/container/.gatekeeper.yaml`
- `iser-tools/betlangiser/container/Containerfile`
- `iser-tools/betlangiser/container/compose.toml`
- `iser-tools/betlangiser/container/ct-build.sh`
- `iser-tools/betlangiser/container/entrypoint.sh`
- `iser-tools/betlangiser/container/manifest.toml`
- `iser-tools/betlangiser/container/vordr.toml`
- `iser-tools/bqniser/container/.gatekeeper.yaml`
- `iser-tools/bqniser/container/Containerfile`
- `iser-tools/bqniser/container/compose.toml`
- `iser-tools/bqniser/container/ct-build.sh`
- `iser-tools/bqniser/container/entrypoint.sh`
- `iser-tools/bqniser/container/manifest.toml`
- `iser-tools/bqniser/container/vordr.toml`
- `iser-tools/chapeliser/container/.gatekeeper.yaml`
- `iser-tools/chapeliser/container/Containerfile`
- `iser-tools/chapeliser/container/compose.toml`
- `iser-tools/chapeliser/container/ct-build.sh`
- `iser-tools/chapeliser/container/entrypoint.sh`
- `iser-tools/chapeliser/container/manifest.toml`
- `iser-tools/chapeliser/container/vordr.toml`
- `iser-tools/dafniser/container/.gatekeeper.yaml`
- `iser-tools/dafniser/container/Containerfile`
- `iser-tools/dafniser/container/compose.toml`
- `iser-tools/dafniser/container/ct-build.sh`
- `iser-tools/dafniser/container/entrypoint.sh`
- `iser-tools/dafniser/container/manifest.toml`
- `iser-tools/dafniser/container/vordr.toml`
- `iser-tools/eclexiaiser/container/.gatekeeper.yaml`
- `iser-tools/eclexiaiser/container/Containerfile`
- `iser-tools/eclexiaiser/container/compose.toml`
- `iser-tools/eclexiaiser/container/ct-build.sh`
- `iser-tools/eclexiaiser/container/entrypoint.sh`
- `iser-tools/eclexiaiser/container/manifest.toml`
- `iser-tools/eclexiaiser/container/vordr.toml`
- `iser-tools/ephapaxiser/container/.gatekeeper.yaml`
- `iser-tools/ephapaxiser/container/Containerfile`
- `iser-tools/ephapaxiser/container/compose.toml`
- `iser-tools/ephapaxiser/container/ct-build.sh`
- `iser-tools/ephapaxiser/container/entrypoint.sh`
- `iser-tools/ephapaxiser/container/manifest.toml`
- `iser-tools/ephapaxiser/container/vordr.toml`
- `iser-tools/futharkiser/container/.gatekeeper.yaml`
- `iser-tools/futharkiser/container/Containerfile`
- `iser-tools/futharkiser/container/compose.toml`
- `iser-tools/futharkiser/container/ct-build.sh`
- `iser-tools/futharkiser/container/entrypoint.sh`
- `iser-tools/futharkiser/container/manifest.toml`
- `iser-tools/futharkiser/container/vordr.toml`
- `iser-tools/halideiser/container/.gatekeeper.yaml`
- `iser-tools/halideiser/container/Containerfile`
- `iser-tools/halideiser/container/compose.toml`
- `iser-tools/halideiser/container/ct-build.sh`
- `iser-tools/halideiser/container/entrypoint.sh`
- `iser-tools/halideiser/container/manifest.toml`
- `iser-tools/halideiser/container/vordr.toml`
- `iser-tools/idrisiser/container/.gatekeeper.yaml`
- `iser-tools/idrisiser/container/Containerfile`
- `iser-tools/idrisiser/container/compose.toml`
- `iser-tools/idrisiser/container/ct-build.sh`
- `iser-tools/idrisiser/container/entrypoint.sh`
- `iser-tools/idrisiser/container/manifest.toml`
- `iser-tools/idrisiser/container/vordr.toml`
- `iser-tools/iseriser/container/.gatekeeper.yaml`
- `iser-tools/iseriser/container/Containerfile`
- `iser-tools/iseriser/container/compose.toml`
- `iser-tools/iseriser/container/ct-build.sh`
- `iser-tools/iseriser/container/entrypoint.sh`
- `iser-tools/iseriser/container/manifest.toml`
- `iser-tools/iseriser/container/vordr.toml`
- `iser-tools/julianiser/container/.gatekeeper.yaml`
- `iser-tools/julianiser/container/Containerfile`
- `iser-tools/julianiser/container/compose.toml`
- `iser-tools/julianiser/container/ct-build.sh`
- `iser-tools/julianiser/container/entrypoint.sh`
- `iser-tools/julianiser/container/manifest.toml`
- `iser-tools/julianiser/container/vordr.toml`
- `iser-tools/lustreiser/container/.gatekeeper.yaml`
- `iser-tools/lustreiser/container/Containerfile`
- `iser-tools/lustreiser/container/compose.toml`
- `iser-tools/lustreiser/container/ct-build.sh`
- `iser-tools/lustreiser/container/entrypoint.sh`
- `iser-tools/lustreiser/container/manifest.toml`
- `iser-tools/lustreiser/container/vordr.toml`
- `iser-tools/mylangiser/container/.gatekeeper.yaml`
- `iser-tools/mylangiser/container/Containerfile`
- `iser-tools/mylangiser/container/compose.toml`
- `iser-tools/mylangiser/container/ct-build.sh`
- `iser-tools/mylangiser/container/entrypoint.sh`
- `iser-tools/mylangiser/container/manifest.toml`
- `iser-tools/mylangiser/container/vordr.toml`
- `iser-tools/nimiser/container/.gatekeeper.yaml`
- `iser-tools/nimiser/container/Containerfile`
- `iser-tools/nimiser/container/compose.toml`
- `iser-tools/nimiser/container/ct-build.sh`
- `iser-tools/nimiser/container/entrypoint.sh`
- `iser-tools/nimiser/container/manifest.toml`
- `iser-tools/nimiser/container/vordr.toml`
- `iser-tools/oblibeniser/container/.gatekeeper.yaml`
- `iser-tools/oblibeniser/container/Containerfile`
- `iser-tools/oblibeniser/container/compose.toml`
- `iser-tools/oblibeniser/container/ct-build.sh`
- `iser-tools/oblibeniser/container/entrypoint.sh`
- `iser-tools/oblibeniser/container/manifest.toml`
- `iser-tools/oblibeniser/container/vordr.toml`
- `iser-tools/otpiser/container/.gatekeeper.yaml`
- `iser-tools/otpiser/container/Containerfile`
- `iser-tools/otpiser/container/compose.toml`
- `iser-tools/otpiser/container/ct-build.sh`
- `iser-tools/otpiser/container/entrypoint.sh`
- `iser-tools/otpiser/container/manifest.toml`
- `iser-tools/otpiser/container/vordr.toml`
- `iser-tools/phronesiser/container/.gatekeeper.yaml`
- `iser-tools/phronesiser/container/Containerfile`
- `iser-tools/phronesiser/container/compose.toml`
- `iser-tools/phronesiser/container/ct-build.sh`
- `iser-tools/phronesiser/container/entrypoint.sh`
- `iser-tools/phronesiser/container/manifest.toml`
- `iser-tools/phronesiser/container/vordr.toml`
- `iser-tools/ponyiser/container/.gatekeeper.yaml`
- `iser-tools/ponyiser/container/Containerfile`
- `iser-tools/ponyiser/container/compose.toml`
- `iser-tools/ponyiser/container/ct-build.sh`
- `iser-tools/ponyiser/container/entrypoint.sh`
- `iser-tools/ponyiser/container/manifest.toml`
- `iser-tools/ponyiser/container/vordr.toml`
- `iser-tools/tlaiser/container/.gatekeeper.yaml`
- `iser-tools/tlaiser/container/Containerfile`
- `iser-tools/tlaiser/container/compose.toml`
- `iser-tools/tlaiser/container/ct-build.sh`
- `iser-tools/tlaiser/container/entrypoint.sh`
- `iser-tools/tlaiser/container/manifest.toml`
- `iser-tools/tlaiser/container/vordr.toml`
- `iser-tools/wokelangiser/container/.gatekeeper.yaml`
- `iser-tools/wokelangiser/container/Containerfile`
- `iser-tools/wokelangiser/container/compose.toml`
- `iser-tools/wokelangiser/container/ct-build.sh`
- `iser-tools/wokelangiser/container/entrypoint.sh`
- `iser-tools/wokelangiser/container/manifest.toml`
- `iser-tools/wokelangiser/container/vordr.toml`
- `rescript-ecosystem/rescript-tea/container/Containerfile`
- `rescript-ecosystem/rescript-tea/container/ct-build.sh`
- `rescript-ecosystem/rescript-tea/container/entrypoint.sh`

### `{{SHA3_512}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{SHAKE256}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{SOURCE}}`

Appears in:

- `iser-tools/oblibeniser/Justfile`
- `iser-tools/ponyiser/Justfile`
- `iser-tools/tlaiser/Justfile`

### `{{SPEC}}`

Appears in:

- `iser-tools/tlaiser/Justfile`

### `{{SPF_INCLUDES}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{SPHINCS_PLUS_PUBLIC_KEY}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{TARGET}}`

Appears in:

- `iser-tools/halideiser/src/codegen/build_gen.rs`
- `iser-tools/lustreiser/Justfile`

### `{{TEST_CMD}}`

The exact command that runs its tests.

Appears in:

- `QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/affinescript-vite/QUICKSTART-DEV.adoc`
- `affinescript-ecosystem/rattlescript/QUICKSTART-DEV.adoc`
- `iser-tools/halideiser/QUICKSTART-DEV.adoc`
- `iser-tools/idrisiser/QUICKSTART-DEV.adoc`
- `iser-tools/iseriser/QUICKSTART-DEV.adoc`
- `iser-tools/julianiser/QUICKSTART-DEV.adoc`
- `iser-tools/lustreiser/QUICKSTART-DEV.adoc`
- `iser-tools/mylangiser/QUICKSTART-DEV.adoc`
- `iser-tools/nimiser/QUICKSTART-DEV.adoc`
- `iser-tools/oblibeniser/QUICKSTART-DEV.adoc`
- `iser-tools/otpiser/QUICKSTART-DEV.adoc`
- `iser-tools/phronesiser/QUICKSTART-DEV.adoc`
- `iser-tools/ponyiser/QUICKSTART-DEV.adoc`
- `iser-tools/tlaiser/QUICKSTART-DEV.adoc`
- `iser-tools/wokelangiser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/idaptik-rescript13-staging/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-evangeliser/QUICKSTART-DEV.adoc`
- `rescript-ecosystem/rescript-tea/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-graphql/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-grpc/QUICKSTART-DEV.adoc`
- `v-ecosystem/v-rest/QUICKSTART-DEV.adoc`

### `{{TRUSTFILE_PATH}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{TRUSTFILE_VERSION}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

### `{{VERSION}}`

Version/tag for the container image.

Appears in:

- `affinescript-ecosystem/affinescript-vite/container/deploy.k9.ncl`
- `affinescript-ecosystem/affinescript-vite/container/manifest.toml`
- `affinescript-ecosystem/affinescript-vite/container/vordr.toml`
- `affinescript-ecosystem/affinescriptiser/container/deploy.k9.ncl`
- `affinescript-ecosystem/affinescriptiser/container/manifest.toml`
- `affinescript-ecosystem/affinescriptiser/container/vordr.toml`
- `affinescript-ecosystem/rattlescript/affinescript/.build/Justfile`
- `affinescript-ecosystem/rattlescript/container/deploy.k9.ncl`
- `affinescript-ecosystem/rattlescript/container/manifest.toml`
- `affinescript-ecosystem/rattlescript/container/vordr.toml`
- `asdf-augmenters/asdf-ghjk/Justfile`
- `asdf-augmenters/asdf-metaiconic-plugin/Justfile`
- `asdf-augmenters/asdf-plugin-collection/plugins/metaiconic/Justfile`
- `cadre-router/Justfile`
- `cadre-tea-router/tasks/Justfile`
- `iser-tools/alloyiser/container/deploy.k9.ncl`
- `iser-tools/alloyiser/container/manifest.toml`
- `iser-tools/alloyiser/container/vordr.toml`
- `iser-tools/atsiser/container/deploy.k9.ncl`
- `iser-tools/atsiser/container/manifest.toml`
- `iser-tools/atsiser/container/vordr.toml`
- `iser-tools/betlangiser/container/deploy.k9.ncl`
- `iser-tools/betlangiser/container/manifest.toml`
- `iser-tools/betlangiser/container/vordr.toml`
- `iser-tools/bqniser/container/deploy.k9.ncl`
- `iser-tools/bqniser/container/manifest.toml`
- `iser-tools/bqniser/container/vordr.toml`
- `iser-tools/chapeliser/container/deploy.k9.ncl`
- `iser-tools/chapeliser/container/manifest.toml`
- `iser-tools/chapeliser/container/vordr.toml`
- `iser-tools/dafniser/container/deploy.k9.ncl`
- `iser-tools/dafniser/container/manifest.toml`
- `iser-tools/dafniser/container/vordr.toml`
- `iser-tools/eclexiaiser/container/deploy.k9.ncl`
- `iser-tools/eclexiaiser/container/manifest.toml`
- `iser-tools/eclexiaiser/container/vordr.toml`
- `iser-tools/ephapaxiser/container/deploy.k9.ncl`
- `iser-tools/ephapaxiser/container/manifest.toml`
- `iser-tools/ephapaxiser/container/vordr.toml`
- `iser-tools/futharkiser/container/deploy.k9.ncl`
- `iser-tools/futharkiser/container/manifest.toml`
- `iser-tools/futharkiser/container/vordr.toml`
- `iser-tools/halideiser/container/deploy.k9.ncl`
- `iser-tools/halideiser/container/manifest.toml`
- `iser-tools/halideiser/container/vordr.toml`
- `iser-tools/idrisiser/container/deploy.k9.ncl`
- `iser-tools/idrisiser/container/manifest.toml`
- `iser-tools/idrisiser/container/vordr.toml`
- `iser-tools/iseriser/container/deploy.k9.ncl`
- `iser-tools/iseriser/container/manifest.toml`
- `iser-tools/iseriser/container/vordr.toml`
- `iser-tools/julianiser/container/deploy.k9.ncl`
- `iser-tools/julianiser/container/manifest.toml`
- `iser-tools/julianiser/container/vordr.toml`
- `iser-tools/lustreiser/container/deploy.k9.ncl`
- `iser-tools/lustreiser/container/manifest.toml`
- `iser-tools/lustreiser/container/vordr.toml`
- `iser-tools/mylangiser/container/deploy.k9.ncl`
- `iser-tools/mylangiser/container/manifest.toml`
- `iser-tools/mylangiser/container/vordr.toml`
- `iser-tools/nimiser/container/deploy.k9.ncl`
- `iser-tools/nimiser/container/manifest.toml`
- `iser-tools/nimiser/container/vordr.toml`
- `iser-tools/oblibeniser/container/deploy.k9.ncl`
- `iser-tools/oblibeniser/container/manifest.toml`
- `iser-tools/oblibeniser/container/vordr.toml`
- `iser-tools/otpiser/container/deploy.k9.ncl`
- `iser-tools/otpiser/container/manifest.toml`
- `iser-tools/otpiser/container/vordr.toml`
- `iser-tools/phronesiser/container/deploy.k9.ncl`
- `iser-tools/phronesiser/container/manifest.toml`
- `iser-tools/phronesiser/container/vordr.toml`
- `iser-tools/ponyiser/container/deploy.k9.ncl`
- `iser-tools/ponyiser/container/manifest.toml`
- `iser-tools/ponyiser/container/vordr.toml`
- `iser-tools/tlaiser/container/deploy.k9.ncl`
- `iser-tools/tlaiser/container/manifest.toml`
- `iser-tools/tlaiser/container/vordr.toml`
- `iser-tools/wokelangiser/container/deploy.k9.ncl`
- `iser-tools/wokelangiser/container/manifest.toml`
- `iser-tools/wokelangiser/container/vordr.toml`
- `rescript-ecosystem/cadre-router/Justfile`
- `rescript-ecosystem/cadre-router/tea-router/tasks/Justfile`
- `rescript-ecosystem/cadre-tea-router/tasks/Justfile`
- `rescript-ecosystem/packages/ffi/wasm-runtime/Justfile`
- `rescript-ecosystem/packages/web/bridge-web/Justfile`
- `rescript-ecosystem/rescript-tea/container/deploy.k9.ncl`
- `techstack-enforcer/Justfile`

### `{{WEBSITE}}`

Project homepage URL, or delete the field if there is none.

Appears in:

- `affinescript-ecosystem/affinescriptiser/.github/SECURITY.md`
- `affinescript-ecosystem/affinescriptiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/affinescriptiser/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/.github/SECURITY.md`
- `affinescript-ecosystem/rattlescript/.machine_readable/ai/PLACEHOLDERS.adoc`
- `affinescript-ecosystem/rattlescript/.well-known/security.txt`
- `affinescript-ecosystem/rattlescript/affinescript/SECURITY.md`
- `asdf-augmenters/asdf-plugin-collection/plugins/nickel/SECURITY (1).md`
- `dnfinition/SECURITY.md`
- `iser-tools/alloyiser/.github/SECURITY.md`
- `iser-tools/alloyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/alloyiser/.well-known/security.txt`
- `iser-tools/atsiser/.github/SECURITY.md`
- `iser-tools/atsiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/atsiser/.well-known/security.txt`
- `iser-tools/betlangiser/.github/SECURITY.md`
- `iser-tools/betlangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/betlangiser/.well-known/security.txt`
- `iser-tools/bqniser/.github/SECURITY.md`
- `iser-tools/bqniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/bqniser/.well-known/security.txt`
- `iser-tools/chapeliser/.github/SECURITY.md`
- `iser-tools/chapeliser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/chapeliser/.well-known/security.txt`
- `iser-tools/dafniser/.github/SECURITY.md`
- `iser-tools/dafniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/dafniser/.well-known/security.txt`
- `iser-tools/eclexiaiser/.github/SECURITY.md`
- `iser-tools/eclexiaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/eclexiaiser/.well-known/security.txt`
- `iser-tools/ephapaxiser/.github/SECURITY.md`
- `iser-tools/ephapaxiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ephapaxiser/.well-known/security.txt`
- `iser-tools/futharkiser/.github/SECURITY.md`
- `iser-tools/futharkiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/futharkiser/.well-known/security.txt`
- `iser-tools/halideiser/.github/SECURITY.md`
- `iser-tools/halideiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/halideiser/.well-known/security.txt`
- `iser-tools/idrisiser/.github/SECURITY.md`
- `iser-tools/idrisiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/idrisiser/.well-known/security.txt`
- `iser-tools/iseriser/.github/SECURITY.md`
- `iser-tools/iseriser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/iseriser/.well-known/security.txt`
- `iser-tools/julianiser/.github/SECURITY.md`
- `iser-tools/julianiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/julianiser/.well-known/security.txt`
- `iser-tools/lustreiser/.github/SECURITY.md`
- `iser-tools/lustreiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/lustreiser/.well-known/security.txt`
- `iser-tools/mylangiser/.github/SECURITY.md`
- `iser-tools/mylangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/mylangiser/.well-known/security.txt`
- `iser-tools/nimiser/.github/SECURITY.md`
- `iser-tools/nimiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/nimiser/.well-known/security.txt`
- `iser-tools/oblibeniser/.github/SECURITY.md`
- `iser-tools/oblibeniser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/oblibeniser/.well-known/security.txt`
- `iser-tools/otpiser/.github/SECURITY.md`
- `iser-tools/otpiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/otpiser/.well-known/security.txt`
- `iser-tools/phronesiser/.github/SECURITY.md`
- `iser-tools/phronesiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/phronesiser/.well-known/security.txt`
- `iser-tools/ponyiser/.github/SECURITY.md`
- `iser-tools/ponyiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/ponyiser/.well-known/security.txt`
- `iser-tools/tlaiser/.github/SECURITY.md`
- `iser-tools/tlaiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/tlaiser/.well-known/security.txt`
- `iser-tools/wokelangiser/.github/SECURITY.md`
- `iser-tools/wokelangiser/.machine_readable/ai/PLACEHOLDERS.adoc`
- `iser-tools/wokelangiser/.well-known/security.txt`
- `packages/SECURITY.md`
- `rescript-ecosystem/packages/bindings/d3/SECURITY.md`
- `rescript-ecosystem/packages/bindings/postgres/SECURITY.md`
- `rescript-ecosystem/packages/bindings/redis/SECURITY.md`
- `rescript-ecosystem/packages/core/compiler-source/SECURITY.md`
- `rescript-ecosystem/packages/core/early-return/SECURITY.md`
- `rescript-ecosystem/packages/core/poly-core/SECURITY.md`
- `rescript-ecosystem/packages/core/runtime-tools/SECURITY.md`
- `rescript-ecosystem/packages/ffi/alib/SECURITY.md`
- `rescript-ecosystem/packages/ffi/wasm-bridge/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-codemods/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-conformance/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-for-rescript/SECURITY.md`
- `rescript-ecosystem/packages/tooling/alib-interop/SECURITY.md`
- `rescript-ecosystem/packages/tooling/create-poly/SECURITY.md`
- `rescript-ecosystem/packages/tooling/greasy-rescripter/SECURITY.md`
- `rescript-ecosystem/packages/web/http-server/SECURITY.md`
- `rescript-ecosystem/packages/web/websocket/SECURITY.md`
- `rescript-ecosystem/rescript-tea/.github/SECURITY.md`
- `rescript-ecosystem/rescript-tea/.machine_readable/ai/PLACEHOLDERS.adoc`
- `rescript-ecosystem/rescript-tea/.well-known/security.txt`
- `rescript-ecosystem/rescript-vite/.well-known/security.txt`
- `rescript-ecosystem/rescript-vite/PLACEHOLDERS.md`
- `rescript-ecosystem/rescript-vite/SECURITY.md`
- `v-ecosystem/v-benchmarks/.well-known/security.txt`
- `v-ecosystem/v-benchmarks/PLACEHOLDERS.md`
- `v-ecosystem/v-benchmarks/SECURITY.md`
- `v-ecosystem/v-grpc/.well-known/security.txt`
- `v-ecosystem/v-grpc/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/.well-known/security.txt`
- `v-ecosystem/v-idris-abi/PLACEHOLDERS.md`
- `v-ecosystem/v-idris-abi/SECURITY.md`
- `v-ecosystem/v-middleware/.well-known/security.txt`
- `v-ecosystem/v-middleware/PLACEHOLDERS.md`
- `v-ecosystem/v-middleware/SECURITY.md`
- `v-ecosystem/v-rest/.well-known/security.txt`
- `v-ecosystem/v-rest/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/.well-known/security.txt`
- `v-ecosystem/v-telemetry/PLACEHOLDERS.md`
- `v-ecosystem/v-telemetry/SECURITY.md`
- `v-ecosystem/v-validator/.well-known/security.txt`
- `v-ecosystem/v-validator/PLACEHOLDERS.md`
- `v-ecosystem/v-validator/SECURITY.md`
- `v-ecosystem/v-zig-ffi/.well-known/security.txt`
- `v-ecosystem/v-zig-ffi/PLACEHOLDERS.md`
- `v-ecosystem/v-zig-ffi/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_graphql/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_graphql/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_graphql/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_grpc/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_grpc/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_grpc/SECURITY.md`
- `v-ecosystem/v_api_interfaces/v_rest/.well-known/security.txt`
- `v-ecosystem/v_api_interfaces/v_rest/PLACEHOLDERS.md`
- `v-ecosystem/v_api_interfaces/v_rest/SECURITY.md`

### `{{ZONEMD}}`

Appears in:

- `rescript-ecosystem/rescript-tea/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `rescript-ecosystem/rescript-vite/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-benchmarks/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-idris-abi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-middleware/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-rest/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-telemetry/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-validator/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v-zig-ffi/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_graphql/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_grpc/.machine_readable/contractiles/trust/Trustfile.a2ml`
- `v-ecosystem/v_api_interfaces/v_rest/.machine_readable/contractiles/trust/Trustfile.a2ml`

---

Generated by the estate top-up pass. Rationale and the governing rulings are
in `hyperpolymath/standards`; the token vocabulary is
`.machine_readable/ai/PLACEHOLDERS.adoc` in `rsr-template-repo`.
