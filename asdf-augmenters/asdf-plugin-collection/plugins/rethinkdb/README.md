# asdf-rethinkdb

[![Build](https://github.com/hyperpolymath/asdf-rethinkdb-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-rethinkdb-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-rethinkdb-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-rethinkdb-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [RethinkDB](https://rethinkdb.com).

Real-time document database.

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
asdf plugin add rethinkdb https://github.com/hyperpolymath/asdf-rethinkdb-plugin.git
```

rethinkdb:

```bash
# Show all installable versions
asdf list-all rethinkdb

# Install specific version
asdf install rethinkdb latest

# Set a version globally (in your ~/.tool-versions file)
asdf global rethinkdb latest

# Now rethinkdb commands are available
rethinkdb --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list rethinkdb

# Set local version for current directory
asdf local rethinkdb <version>

# Uninstall a version
asdf uninstall rethinkdb <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
