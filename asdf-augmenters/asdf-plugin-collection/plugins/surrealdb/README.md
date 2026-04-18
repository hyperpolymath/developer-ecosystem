# asdf-surrealdb

[![Build](https://github.com/hyperpolymath/asdf-surrealdb-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-surrealdb-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-surrealdb-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-surrealdb-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [SurrealDB](https://surrealdb.com).

Multi-model database.

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
asdf plugin add surrealdb https://github.com/hyperpolymath/asdf-surrealdb-plugin.git
```

surrealdb:

```bash
# Show all installable versions
asdf list-all surrealdb

# Install specific version
asdf install surrealdb latest

# Set a version globally (in your ~/.tool-versions file)
asdf global surrealdb latest

# Now surrealdb commands are available
surrealdb --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list surrealdb

# Set local version for current directory
asdf local surrealdb <version>

# Uninstall a version
asdf uninstall surrealdb <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
