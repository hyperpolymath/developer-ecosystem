= Greasy-Rescripter: The Neuro-Symbolic Framework
:version: 0.1.0-alpha
:status: Stable
:stack: Must-Just-Nickel

== Overview

`greasy-rescripter` is a high-integrity development environment designed to bridge **ReScript’s** neural-functional logic with **Nickel’s** symbolic configuration. The primary objective is to produce resilient userscripts for modern browsers (Chrome, Mozilla) while maintaining strict cross-platform compatibility (Linux, Minix, Android) via Podman.

By anchoring the non-deterministic nature of functional logic in a typed, symbolic layer, we eliminate Greasemonkey metadata "hallucinations" often found in purely agentic workflows.

== The Stack

* **ReScript**: Neural-functional logic layer.
* **Nickel**: Symbolic configuration and metadata contract.
* **Just**: Orchestration and lifecycle management.
* **Podman**: Containerised, deterministic build environment.
* **Esbuild**: Final fusion of logic and header.

== Playbook Workflow

The framework follows a strict execution path to ensure build integrity:

1. **Strike**: Initialise the configuration environment.
2. **Get-Nickel**: Evaluate symbolic contracts and validate types.
3. **Export**: Generate the Greasemonkey/Tampermonkey metadata block.
4. **ReScript Build**: Compile `.res` files into clean JavaScript.
5. **Esbuild**: Fuse the validated header with the compiled logic into a `.user.js` bundle.

== Getting Started

Ensure you have `just`, `nickel`, and `podman` installed.

[source,bash]
----
# Initialise the environment
just strike

# Run the full build pipeline
just bundle

# Build for cross-platform targets (Minix/Android) via Podman
just podman-build
----

== Agentic Compatibility

`greasy-rescripter` is fully compatible with autonomous CI/CD pipelines. The **Nickel** layer acts as a structural anchor; agents may manipulate the symbolic configuration (e.g., updating `@match` rules or `@version`), but they cannot violate the functional contract defined in ReScript. If an agent attempts to inject malformed metadata, the Nickel evaluation will fail, protecting the build integrity.

== Deployment Targets

Supported shells for deployment and orchestration include:
* **Standard**: `bash`, `zsh`, `dash`, `ash`.
* **Systems**: `minix-sh`, `ksh`, `tcsh`.
* **Modern**: `nushell`, `fish`, `elvish`.

---
_Maintaining the neuro-symbolic balance between functional expression and symbolic rigour._
