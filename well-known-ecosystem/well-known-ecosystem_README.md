# Well-Known Ecosystem

[![Palimpsest-MPL License v1.0 (PMPL-1.0)](https://img.shields.io/badge/License-PMPL-1.0-green.svg)](https://choosealicense.com/licenses/mit/)
[![GitHub Stars](https://img.shields.io/github/stars/hyperpolymath/well-known-ecosystem.svg)](https://github.com/hyperpolymath/well-known-ecosystem/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/hyperpolymath/well-known-ecosystem.svg)](https://github.com/hyperpolymath/well-known-ecosystem/issues)
[![GitHub Forks](https://img.shields.io/github/forks/hyperpolymath/well-known-ecosystem.svg)](https://github.com/hyperpolymath/well-known-ecosystem/network)
[![RFC 8615](https://img.shields.io/badge/RFC-8615-blue.svg)](https://www.rfc-editor.org/rfc/rfc8615.html)

## Overview

**Well-Known Ecosystem** is a comprehensive toolkit for managing and implementing well-known URIs as defined in RFC 8615. This project provides tools, validators, and infrastructure for creating, managing, and serving well-known resources that enable site-wide metadata, security policies, and service discovery.

## What are Well-Known URIs?

Well-known URIs are standardized paths (`.well-known/`) used by web services to publish metadata, configuration, and policy information. Common examples include:
- `.well-known/security.txt` - Security contact information
- `.well-known/openid-configuration` - OpenID Connect discovery
- `.well-known/apple-app-site-association` - iOS app deep linking
- `.well-known/change-password` - Password change endpoint
- `.well-known/webfinger` - Identity discovery

## Features

- **URI Management**: Create, validate, and manage well-known URIs
- **Template System**: Pre-built templates for common well-known resources
- **Validation Engine**: Ensure compliance with RFC 8615 and specific standards
- **Auto-Discovery**: Automated detection and mapping of well-known resources
- **Security Policies**: Tools for implementing security.txt, CSP, and CORS policies
- **Service Integration**: Easy integration with popular web frameworks
- **Documentation Generator**: Automatic documentation for your well-known endpoints
- **Testing Suite**: Comprehensive testing tools for well-known implementations

## Installation

```bash
# Clone the repository
git clone https://github.com/hyperpolymath/well-known-ecosystem.git

# Navigate to the project directory
cd well-known-ecosystem

# Install dependencies
npm install
# or
pip install -r requirements.txt
```

## Quick Start

### Creating a Security.txt File

```javascript
const { WellKnown } = require('well-known-ecosystem');

const wk = new WellKnown();

wk.createSecurityTxt({
  contact: ['mailto:security@example.com', 'https://example.com/security'],
  expires: '2026-12-31T23:59:59.000Z',
  acknowledgments: 'https://example.com/hall-of-fame',
  preferredLanguages: 'en, es',
  canonical: 'https://example.com/.well-known/security.txt'
});
```

### Setting Up OpenID Configuration

```python
from well_known_ecosystem import OpenIDConfig

config = OpenIDConfig(
    issuer="https://example.com",
    authorization_endpoint="https://example.com/oauth/authorize",
    token_endpoint="https://example.com/oauth/token",
    jwks_uri="https://example.com/.well-known/jwks.json"
)

config.save()
```

### Validating Well-Known Resources

```bash
# Validate security.txt
npx well-known validate security.txt

# Validate OpenID configuration
npx well-known validate openid-configuration

# Validate all well-known resources
npx well-known validate --all
```

## Supported Well-Known Resources

| Resource | RFC/Standard | Purpose |
|----------|--------------|---------|
| `security.txt` | RFC 9116 | Security contact information |
| `openid-configuration` | OpenID Connect | Identity provider discovery |
| `webfinger` | RFC 7033 | User/resource discovery |
| `change-password` | WICG Spec | Password change URL |
| `apple-app-site-association` | Apple | Universal links |
| `assetlinks.json` | Google | Android app links |
| `dnt-policy.txt` | W3C | Do Not Track policy |
| `host-meta` | RFC 6415 | Host metadata |
| `matrix` | Matrix Spec | Matrix homeserver |
| `nodeinfo` | NodeInfo | Federated service info |

## Usage Examples

### Express.js Integration

```javascript
const express = require('express');
const { WellKnownMiddleware } = require('well-known-ecosystem');

const app = express();

// Serve all well-known resources
app.use('/.well-known', WellKnownMiddleware({
  directory: './well-known',
  autoGenerate: true
}));

app.listen(3000);
```

### Django Integration

```python
from django.urls import path
from well_known_ecosystem.django import WellKnownView

urlpatterns = [
    path('.well-known/<path:resource>', WellKnownView.as_view()),
]
```

### Static Site Generation

```bash
# Generate all well-known files
well-known generate --config well-known.config.json

# Output to specific directory
well-known generate --output ./public/.well-known
```

## Configuration

```json
{
  "wellKnown": {
    "baseUrl": "https://example.com",
    "outputDir": "./.well-known",
    "resources": {
      "securityTxt": {
        "enabled": true,
        "contact": ["mailto:security@example.com"],
        "expires": "2026-12-31T23:59:59.000Z"
      },
      "changePassword": {
        "enabled": true,
        "url": "https://example.com/account/password"
      },
      "openidConfiguration": {
        "enabled": true,
        "issuer": "https://example.com"
      }
    }
  }
}
```

## CLI Commands

```bash
# Initialize well-known directory
well-known init

# Generate specific resource
well-known generate security.txt

# Validate resources
well-known validate

# List all well-known resources
well-known list

# Check remote site's well-known resources
well-known check https://example.com
```

## API Reference

### JavaScript/TypeScript

```typescript
import {
  WellKnown,
  SecurityTxt,
  OpenIDConfig,
  Validator
} from 'well-known-ecosystem';

// Create manager
const manager = new WellKnown({
  baseUrl: 'https://example.com',
  outputDir: './.well-known'
});

// Add resources
await manager.add('security.txt', securityTxtData);
await manager.add('openid-configuration', openidData);

// Validate all
const results = await manager.validateAll();
```

### Python

```python
from well_known_ecosystem import Manager, validate_resource

# Create manager
manager = Manager(
    base_url='https://example.com',
    output_dir='./.well-known'
)

# Add and validate
manager.add_resource('security.txt', data)
manager.validate('security.txt')
```

## Security Considerations

- Always use HTTPS for serving well-known resources
- Set appropriate CORS headers for cross-origin requests
- Regularly update security.txt expiration dates
- Validate all well-known resources before deployment
- Monitor access logs for unusual patterns
- Keep sensitive information out of public well-known files

## Testing

```bash
# Run all tests
npm test

# Run specific test suite
npm test -- --suite=validation

# Run integration tests
npm run test:integration

# Check coverage
npm run coverage
```

## Documentation

- [Getting Started Guide](./docs/getting-started.md)
- [API Documentation](./docs/api.md)
- [Well-Known Resources Reference](./docs/resources.md)
- [Integration Guides](./docs/integrations.md)
- [Security Best Practices](./docs/security.md)
- [RFC 8615 Overview](./docs/rfc8615.md)

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details on:
- Adding new well-known resource types
- Improving validation logic
- Framework integrations
- Documentation improvements

## Roadmap

- [ ] Additional well-known resource templates
- [ ] Visual web interface for management
- [ ] Automated monitoring and alerts
- [ ] Multi-site management dashboard
- [ ] Plugin system for custom resources
- [ ] Cloud deployment integrations

## License

This project is licensed under the Palimpsest-MPL License v1.0 (PMPL-1.0) - see the [LICENSE](LICENSE) file for details.

## Author

**hyperpolymath**
- GitHub: [@hyperpolymath](https://github.com/hyperpolymath)

## Keywords

well-known URI, RFC 8615, security.txt, RFC 9116, OpenID Connect, webfinger, metadata discovery, web standards, site-wide metadata, service discovery, security policies, universal links, deep linking, web security

## Resources

- [RFC 8615 - Well-Known URIs](https://www.rfc-editor.org/rfc/rfc8615.html)
- [RFC 9116 - security.txt](https://www.rfc-editor.org/rfc/rfc9116.html)
- [IANA Well-Known URIs Registry](https://www.iana.org/assignments/well-known-uris/)
- [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html)

## Acknowledgments

- IETF and RFC authors
- OpenID Foundation
- Web standards community
- Contributors and supporters

---

**Standardize your web metadata** - Star this repository to support well-known URI adoption!
