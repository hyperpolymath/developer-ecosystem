# asdf-fortran

[![Build](https://github.com/hyperpolymath/asdf-fortran-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-fortran-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-fortran-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-fortran-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [GFortran](https://gcc.gnu.org/fortran).

GNU Fortran compiler.

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
asdf plugin add fortran https://github.com/hyperpolymath/asdf-fortran-plugin.git
```

fortran:

```bash
# Show all installable versions
asdf list-all fortran

# Install specific version
asdf install fortran latest

# Set a version globally (in your ~/.tool-versions file)
asdf global fortran latest

# Now fortran commands are available
fortran --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list fortran

# Set local version for current directory
asdf local fortran <version>

# Uninstall a version
asdf uninstall fortran <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
