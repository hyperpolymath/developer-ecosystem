# asdf-dhall

[![Build](https://github.com/hyperpolymath/asdf-dhall-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-dhall-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-dhall-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-dhall-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Dhall](https://dhall-lang.org).

Programmable configuration.

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
asdf plugin add dhall https://github.com/hyperpolymath/asdf-dhall-plugin.git
```

dhall:

```bash
# Show all installable versions
asdf list-all dhall

# Install specific version
asdf install dhall latest

# Set a version globally (in your ~/.tool-versions file)
asdf global dhall latest

# Now dhall commands are available
dhall --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list dhall

# Set local version for current directory
asdf local dhall <version>

# Uninstall a version
asdf uninstall dhall <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
