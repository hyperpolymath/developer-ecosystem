# asdf-kdl-fmt

[![Build](https://github.com/hyperpolymath/asdf-kdl-fmt-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-kdl-fmt-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-kdl-fmt-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-kdl-fmt-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [kdl-fmt](https://kdl.dev).

KDL document formatter.

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
asdf plugin add kdl-fmt https://github.com/hyperpolymath/asdf-kdl-fmt-plugin.git
```

kdl-fmt:

```bash
# Show all installable versions
asdf list-all kdl-fmt

# Install specific version
asdf install kdl-fmt latest

# Set a version globally (in your ~/.tool-versions file)
asdf global kdl-fmt latest

# Now kdl-fmt commands are available
kdl-fmt --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list kdl-fmt

# Set local version for current directory
asdf local kdl-fmt <version>

# Uninstall a version
asdf uninstall kdl-fmt <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
