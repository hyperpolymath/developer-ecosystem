# asdf-step-ca

[![Build](https://github.com/hyperpolymath/asdf-step-ca-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-step-ca-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-step-ca-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-step-ca-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [step-ca](https://smallstep.com/certificates).

Private CA.

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
asdf plugin add step-ca https://github.com/hyperpolymath/asdf-step-ca-plugin.git
```

step-ca:

```bash
# Show all installable versions
asdf list-all step-ca

# Install specific version
asdf install step-ca latest

# Set a version globally (in your ~/.tool-versions file)
asdf global step-ca latest

# Now step-ca commands are available
step-ca --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list step-ca

# Set local version for current directory
asdf local step-ca <version>

# Uninstall a version
asdf uninstall step-ca <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
