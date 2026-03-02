# Tri-Perimeter Contribution Framework (TPCF)

## Overview

This project uses the **Tri-Perimeter Contribution Framework** to balance openness with security and sustainability. TPCF defines three graduated trust zones with different access levels and contribution requirements.

## The Three Perimeters

### Perimeter 3: Community Sandbox (PUBLIC)

**Access Level**: Open to all
**Trust Level**: Untrusted
**Current Status**: ✅ **ACTIVE** - This project operates here

**What You Can Do:**
- Fork the repository
- Submit pull requests
- Open issues
- Participate in discussions
- Use the code (MIT License)
- Create derivative works
- Share and distribute
- Learn and experiment

**Requirements:**
- Follow Code of Conduct
- Sign-off commits (Developer Certificate of Origin)
- Pass automated tests
- Maintain code quality standards
- Include tests for new features
- Update documentation

**Review Process:**
- All PRs reviewed by maintainers
- Automated CI/CD checks required
- Two maintainer approvals for major changes
- Response time: 7 days (target)

**Security:**
- All contributions sandboxed
- Automated security scanning
- No direct write access
- Code review before merge
- Reversible changes (Git history)

### Perimeter 2: Trusted Contributors (SEMI-PRIVATE)

**Access Level**: Invitation only
**Trust Level**: Established contributors
**Current Status**: ⚠️ Not yet active (no contributors at this level)

**How to Get Here:**
- 6+ months of quality contributions in Perimeter 3
- Demonstrated technical excellence
- Community engagement (helpful in issues, reviews)
- Alignment with project values
- Maintainer recommendation

**What You Get:**
- Direct commit access (for minor changes)
- Triager role on issues
- Ability to label and close issues
- Early access to security discussions (non-critical)
- Invitation to contributor meetings
- Listed in CONTRIBUTORS.md

**Responsibilities:**
- Uphold Code of Conduct
- Respond to assigned issues within 7 days
- Review PRs from Perimeter 3
- Mentor new contributors
- Participate in project discussions

**Still Required:**
- PRs for major changes
- Code review for security-sensitive changes
- Test coverage maintained
- Documentation updates

### Perimeter 1: Core Team (PRIVATE)

**Access Level**: Core maintainers only
**Trust Level**: Full trust
**Current Status**: ⚠️ Seeking core team members

**How to Get Here:**
- 12+ months as Perimeter 2 contributor
- Sustained high-quality contributions
- Leadership in technical decisions
- Community building efforts
- Maintainer unanimous approval

**What You Get:**
- Full repository access
- Release management
- Security vulnerability access
- Architecture decision authority
- Budget/funding decisions (if applicable)
- Listed in MAINTAINERS.md
- Conference representation

**Responsibilities:**
- Project sustainability
- Security response coordination
- Release management
- Conflict resolution
- Community health monitoring
- Mentoring junior contributors
- Strategic planning

## Movement Between Perimeters

### Promotion Process

**3 → 2 (Community → Trusted):**
1. Self-nomination or maintainer nomination
2. Review contribution history (quality, quantity, behavior)
3. Maintainer consensus
4. Invitation sent
5. Onboarding completed
6. 3-month trial period

**2 → 1 (Trusted → Core):**
1. Maintainer nomination only
2. Comprehensive review (technical + community)
3. Unanimous maintainer approval
4. Formal invitation
5. Full onboarding with existing core team
6. Public announcement

### Demotion/Removal

Any contributor can be moved to a lower perimeter or removed for:
- Code of Conduct violations
- Security breaches
- Sustained inactivity (12+ months with notice)
- Loss of trust
- Personal request (stepping down)

**Process:**
1. Private discussion among maintainers
2. Warning given (except for serious violations)
3. Opportunity to respond
4. Decision made
5. Access revoked
6. Public explanation (if appropriate)

## Security Boundaries

### Perimeter 3 Security
- No direct write access
- All changes via PR
- Automated scanning (SAST, dependency check)
- Code review required
- Signed commits required
- Rate limiting on API access

### Perimeter 2 Security
- Direct commit for minor changes only
- Security-sensitive changes via PR
- Access to non-critical security discussions
- Enhanced monitoring
- Two-factor authentication required

### Perimeter 1 Security
- Full access with accountability
- Security key or hardware token required
- Audit logging of all actions
- Annual security training
- Coordinated disclosure authority
- Emergency response authority

## Contribution Types by Perimeter

### All Perimeters Can:
- Report bugs
- Suggest features
- Improve documentation
- Answer questions
- Share the project
- Use the code (MIT License)

### Perimeter 3 Can:
- Submit bug fixes
- Add new features (via PR)
- Improve tests
- Enhance examples
- Write blog posts
- Give talks (with attribution)

### Perimeter 2 Can:
- Commit minor fixes directly
- Triage issues
- Review PRs
- Close duplicate/invalid issues
- Mentor new contributors

### Perimeter 1 Can:
- Make architectural decisions
- Manage releases
- Handle security vulnerabilities
- Resolve conflicts
- Modify TPCF policy
- Invite new contributors

## Transparency

### Public Information:
- All code and changes (Git history)
- All issues and PRs
- All documentation
- CI/CD logs
- Contribution guidelines
- Perimeter membership (CONTRIBUTORS.md, MAINTAINERS.md)

### Semi-Private Information (Perimeter 2+):
- Contributor discussions
- Pre-release planning
- Non-critical security issues (after 90 days)

### Private Information (Perimeter 1 only):
- Security vulnerabilities (pre-disclosure)
- Conflict mediation details
- Individual performance discussions
- Budget information (if applicable)

## Emotional Safety Across Perimeters

### All Perimeters:
- No "stupid questions"
- Reversible contributions (Git)
- Constructive feedback only
- Right to take breaks
- Right to step down
- Recognition of contributions

### Perimeter 3:
- Patient mentorship
- Learning-friendly environment
- Experimentation encouraged
- Mistakes are learning opportunities

### Perimeter 2:
- Trusted voice in discussions
- Early access to technical decisions
- Mentorship opportunities
- Community building support

### Perimeter 1:
- Leadership development
- Conference opportunities
- Academic paper co-authorship
- Sustained recognition

## Metrics and Evaluation

### Contribution Quality Metrics:
- Code correctness (tests pass, types check)
- Test coverage (new code >80%)
- Documentation completeness
- Code review thoroughness
- Response time to issues/PRs
- Community helpfulness

### Not Used for Evaluation:
- Lines of code
- Number of commits
- Response speed (we value thoughtfulness)
- Time of day active (respect timezones)
- Popularity metrics

## Appeal Process

If you disagree with a perimeter decision:
1. Email: appeals@example.com
2. State your case with evidence
3. Independent review by uninvolved maintainer
4. Decision within 14 days
5. Final appeal to entire maintainer team

## Frequently Asked Questions

**Q: Can I contribute without signing up for anything?**
A: Yes! Perimeter 3 is open to all. Just follow the Code of Conduct and submit PRs.

**Q: How long to reach Perimeter 2?**
A: Typically 6-12 months of sustained contributions, but quality matters more than time.

**Q: Can I skip Perimeter 3 and go straight to Perimeter 2?**
A: No. Trust must be earned through demonstrated contributions.

**Q: What if I become inactive?**
A: We understand life happens. Just let us know. After 12 months of inactivity, we may move you to Perimeter 3, but you can return anytime.

**Q: Can companies contribute?**
A: Yes! Company employees participate as individuals in Perimeter 3, following the same process as everyone.

**Q: What about paid contributions?**
A: All perimeters welcome paid and unpaid contributors equally. Motivation doesn't affect trust level.

## TPCF Version

- **Framework Version**: 1.0.0
- **Adopted**: 2025-01-22
- **Last Updated**: 2025-01-22
- **Next Review**: 2025-07-22

## Changes to This Policy

This TPCF policy can be modified by:
1. Any contributor proposing changes (via issue)
2. Discussion period (minimum 14 days)
3. Core team consensus (Perimeter 1)
4. Public announcement
5. Grace period (30 days) before enforcement

## Contact

- **TPCF Questions**: tpcf@example.com
- **Perimeter Appeals**: appeals@example.com
- **General Contact**: contact@example.com

---

**Related Documents:**
- CODE_OF_CONDUCT.md - Behavioral expectations
- CONTRIBUTING.md - How to contribute
- MAINTAINERS.md - Current core team
- SECURITY.md - Security policy

**Framework Credit:**
The TPCF framework was inspired by graduated trust models in open source communities, security perimeters in enterprise systems, and psychological safety research in software teams.
