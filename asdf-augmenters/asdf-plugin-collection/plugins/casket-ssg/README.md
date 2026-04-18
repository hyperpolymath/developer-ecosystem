# asdf-casket-ssg

[![Build](https://github.com/hyperpolymath/asdf-casket-ssg-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-casket-ssg-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-casket-ssg-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-casket-ssg-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Casket](https://github.com/caskethosting/casket).

Static site generator.

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
asdf plugin add casket-ssg https://github.com/hyperpolymath/asdf-casket-ssg-plugin.git
```

casket-ssg:

```bash
# Show all installable versions
asdf list-all casket-ssg

# Install specific version
asdf install casket-ssg latest

# Set a version globally (in your ~/.tool-versions file)
asdf global casket-ssg latest

# Now casket-ssg commands are available
casket-ssg --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list casket-ssg

# Set local version for current directory
asdf local casket-ssg <version>

# Uninstall a version
asdf uninstall casket-ssg <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
