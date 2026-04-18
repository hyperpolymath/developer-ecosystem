# asdf-git-crypt

[![Build](https://github.com/hyperpolymath/asdf-git-crypt-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-git-crypt-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-git-crypt-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-git-crypt-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [git-crypt](https://www.agwa.name/projects/git-crypt).

Transparent git encryption.

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
asdf plugin add git-crypt https://github.com/hyperpolymath/asdf-git-crypt-plugin.git
```

git-crypt:

```bash
# Show all installable versions
asdf list-all git-crypt

# Install specific version
asdf install git-crypt latest

# Set a version globally (in your ~/.tool-versions file)
asdf global git-crypt latest

# Now git-crypt commands are available
git-crypt --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list git-crypt

# Set local version for current directory
asdf local git-crypt <version>

# Uninstall a version
asdf uninstall git-crypt <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
