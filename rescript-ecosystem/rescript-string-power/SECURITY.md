<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Security Policy

## Supported Versions

Only the current `main` branch and the most recent published release receive
security updates.

| Version | Supported |
|---------|-----------|
| main    | yes       |
| 0.1.x   | yes       |
| < 0.1   | no        |

## Reporting a Vulnerability

Please report security issues **privately** via GitHub's security advisories:

- <https://github.com/hyperpolymath/rescript-string-power/security/advisories/new>

Alternatively, contact the maintainer directly:

- Email: `j.d.a.jewell@open.ac.uk`
- PGP: available on request

Please do not open public issues for security problems.

## Scope

This library handles user-provided strings that may reach SQL queries, HTML
output, CSS, and URLs. Of particular interest:

- **SQL injection** via `Sql.inline` or unsafe `Raw` values.
- **XSS** via `Fmt.fmt` used where `Fmt.html` should have been used.
- **Open redirects** via `Url.url` with unvalidated path segments.
- **Regex denial of service** in `tools/string-union-gen`.

## Response

Acknowledgement within 5 working days. Fix and coordinated disclosure within
30 days where practical.
