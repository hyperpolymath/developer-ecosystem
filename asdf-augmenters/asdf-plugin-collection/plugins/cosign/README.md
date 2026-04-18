# asdf-cosign

[![Build](https://github.com/hyperpolymath/asdf-cosign-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-cosign-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-cosign-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-cosign-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Cosign](https://sigstore.dev).

Container signing from Sigstore.

## Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Dependencies

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html)

## Install

Plugin:

```bash
asdf plugin add cosign https://github.com/hyperpolymath/asdf-cosign-plugin.git
```

cosign:

```bash
# Show all installable versions
asdf list-all cosign

# Install specific version
asdf install cosign latest

# Set a version globally (in your ~/.tool-versions file)
asdf global cosign latest

# Now cosign commands are available
cosign --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list cosign

# Set local version for current directory
asdf local cosign <version>

# Uninstall a version
asdf uninstall cosign <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
