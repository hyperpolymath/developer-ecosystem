# asdf-deno

[![Build](https://github.com/hyperpolymath/asdf-deno-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/hyperpolymath/asdf-deno-plugin/actions/workflows/build.yml)
[![Lint](https://github.com/hyperpolymath/asdf-deno-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/hyperpolymath/asdf-deno-plugin/actions/workflows/lint.yml)
image:https://img.shields.io/badge/License-PMPL--1.0-blue.svg[License: PMPL-1.0,link="https://github.com/hyperpolymath/palimpsest-license"]

[asdf](https://asdf-vm.com) plugin for [Deno](https://deno.land).

Secure TypeScript/JavaScript runtime.

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
asdf plugin add deno https://github.com/hyperpolymath/asdf-deno-plugin.git
```

deno:

```bash
# Show all installable versions
asdf list-all deno

# Install specific version
asdf install deno latest

# Set a version globally (in your ~/.tool-versions file)
asdf global deno latest

# Now deno commands are available
deno --version
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) readme for more instructions.

## Usage

```bash
# List installed versions
asdf list deno

# Set local version for current directory
asdf local deno <version>

# Uninstall a version
asdf uninstall deno <version>
```

## Contributing

Contributions welcome! Read the [contributing guidelines](CONTRIBUTING.adoc) first.

## License

Licensed under the [Palimpsest-MPL License (PMPL-1.0)](LICENSE).

---

> Maintained by [hyperpolymath](https://github.com/hyperpolymath)
