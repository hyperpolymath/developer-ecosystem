# Maintainers

This document lists the maintainers of the asdf-acceleration-middleware project.

## Current Maintainers

### Core Team

**Lead Maintainer**
- Role: Project leadership, architecture decisions, release management
- Responsibilities: Strategic direction, final approval on major changes
- Contact: See `.well-known/security.txt`

### Responsibilities

#### All Maintainers

- Review and merge pull requests
- Triage issues
- Maintain code quality standards
- Ensure RSR compliance
- Respond to security reports
- Foster community growth
- Uphold Code of Conduct

#### Release Process

Maintainers coordinate releases following semantic versioning:

1. Version bump in `Cargo.toml`
2. Update `CHANGELOG.md`
3. Tag release: `git tag -a v0.1.0 -m "Release v0.1.0"`
4. Push tag: `git push origin v0.1.0`
5. Publish to crates.io: `cargo publish`
6. Create GitHub release with notes

## Becoming a Maintainer

### Path to Maintainership

The project follows the TPCF (Tri-Perimeter Contribution Framework):

**Perimeter 3 → Perimeter 2 → Perimeter 1**

#### Perimeter 3: Community Sandbox (Current for new contributors)
- Public contributions
- Code review required
- Fork/PR workflow

#### Perimeter 2: Trusted Contributors
- Consistent high-quality contributions
- Deep understanding of codebase
- Demonstrated adherence to Code of Conduct
- Nominated by existing maintainers
- Rights: Direct commit access to feature branches

#### Perimeter 1: Core Maintainers
- Extensive contribution history
- Architecture expertise
- Community leadership
- Nominated by Perimeter 1 maintainers
- Rights: Release authority, main branch access

### Criteria for Promotion

**To Perimeter 2 (Trusted Contributor)**:
- ✅ 10+ merged PRs
- ✅ 6+ months of consistent contributions
- ✅ Code review participation
- ✅ Zero Code of Conduct violations
- ✅ Demonstrated technical expertise

**To Perimeter 1 (Core Maintainer)**:
- ✅ 50+ merged PRs
- ✅ 1+ year in Perimeter 2
- ✅ Architecture contributions
- ✅ Mentoring other contributors
- ✅ Community building

### Nomination Process

1. Self-nomination or nomination by existing maintainer
2. Discussion among current Perimeter 1 maintainers
3. Vote (requires 2/3 majority)
4. Onboarding and access provisioning

## Emeritus Maintainers

Maintainers who have stepped down are recognized here for their contributions:

(None yet)

## Contact

- **GitHub**: [@Hyperpolymath](https://github.com/Hyperpolymath)
- **Email**: See `.well-known/security.txt`
- **Discussions**: [GitHub Discussions](https://github.com/Hyperpolymath/asdf-acceleration-middleware/discussions)

## Decision Making

### Consensus Model

- **Small changes**: Any maintainer can approve
- **Moderate changes**: 2 maintainer approvals
- **Major changes**: Discussion + consensus of Perimeter 1
- **Breaking changes**: RFC process + community input

### RFC Process

For major architectural changes:

1. Create RFC document in `docs/rfcs/`
2. Open discussion issue
3. Gather feedback (minimum 2 weeks)
4. Revise based on feedback
5. Final decision by Perimeter 1 maintainers
6. Implementation

## Conflict Resolution

If conflicts arise:

1. **First**: Direct discussion between parties
2. **Second**: Involve neutral maintainer as mediator
3. **Third**: Escalate to full Perimeter 1 team
4. **Last resort**: Code of Conduct enforcement

## Time Commitment

Maintainers are expected to:
- Review PRs within 3 days
- Respond to security issues within 48 hours
- Participate in monthly maintainer meetings
- Be active in the community

### Stepping Down

Maintainers may step down at any time:
- Notify other maintainers
- Complete transition of responsibilities
- Move to Emeritus status with recognition

## Acknowledgments

Thank you to all maintainers, past and present, for your dedication to this project!

---

**Last Updated**: 2024-11-22
