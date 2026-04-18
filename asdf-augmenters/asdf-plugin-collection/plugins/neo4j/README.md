# asdf-neo4j

[![Build](https://github.com/hyperpolymath/asdf-neo4j-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-neo4j-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-neo4j-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-neo4j-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Neo4j](https://neo4j.com).

Graph database.

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
asdf plugin add neo4j https://github.com/hyperpolymath/asdf-neo4j-plugin.git
```

neo4j:

```bash
# Show all installable versions
asdf list-all neo4j

# Install specific version
asdf install neo4j latest

# Set a version globally (in your ~/.tool-versions file)
asdf global neo4j latest

# Now neo4j commands are available
neo4j --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list neo4j

# Set local version for current directory
asdf local neo4j <version>

# Uninstall a version
asdf uninstall neo4j <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
