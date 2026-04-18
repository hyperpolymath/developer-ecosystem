# Tri-Perimeter Contribution Framework (TPCF)

This project implements the **Tri-Perimeter Contribution Framework** (TPCF), a graduated trust model for open source contributions.

## Overview

TPCF organizes contributors into three concentric perimeters based on trust level and contribution history, providing a clear path for community members to increase their involvement.

## Perimeters

### Perimeter 3: Community Sandbox

**Current Status**: ✅ Active

**Access Level**: Public contributions welcomed

**Who**: All external contributors

**Privileges**:
- Fork repository
- Submit pull requests
- Participate in discussions
- Report issues

**Requirements**:
- Follow Code of Conduct
- Pass all CI checks
- Obtain code review approval from Perimeter 1 or 2 maintainers

**Workflow**:
1. Fork the repository
2. Create feature branch
3. Make changes
4. Submit pull request
5. Address review feedback
6. Await approval and merge

**Graduation Criteria** to Perimeter 2:
- ✅ 10+ merged pull requests
- ✅ 6+ months of consistent contributions
- ✅ Active code review participation
- ✅ Zero Code of Conduct violations
- ✅ Demonstrated technical expertise in project domain

### Perimeter 2: Trusted Contributors

**Current Status**: 🔜 Planned

**Access Level**: Direct repository access

**Who**: Experienced contributors with proven track record

**Privileges**:
- Direct commit access to feature branches
- Review and approve pull requests
- Participate in architectural discussions
- Mentor new contributors

**Requirements**:
- All Perimeter 3 requirements met
- Nominated by existing Perimeter 1 maintainer
- Approval vote by Perimeter 1 (2/3 majority)

**Responsibilities**:
- Maintain code quality standards
- Review contributions promptly
- Uphold Code of Conduct
- Support community growth

**Graduation Criteria** to Perimeter 1:
- ✅ 50+ merged pull requests
- ✅ 1+ year in Perimeter 2
- ✅ Significant architectural contributions
- ✅ Active mentoring of other contributors
- ✅ Demonstrated project leadership

### Perimeter 1: Core Maintainers

**Current Status**: 🔜 To be established

**Access Level**: Full repository control

**Who**: Project leaders and primary maintainers

**Privileges**:
- Release authority
- Main branch access
- Security issue triage
- Governance decisions
- Perimeter promotions

**Requirements**:
- All Perimeter 2 requirements met
- Extensive contribution history
- Community leadership demonstrated
- Approval vote by existing Perimeter 1 (2/3 majority)

**Responsibilities**:
- Strategic direction
- Release management
- Security response
- Governance and policy
- Community health

## Benefits of TPCF

### For Contributors

1. **Clear Path**: Transparent progression from contributor to maintainer
2. **Recognition**: Formal acknowledgment of contributions
3. **Meritocratic**: Advancement based on actual contributions
4. **Safety**: Reduced anxiety through clear expectations

### For the Project

1. **Security**: Graduated trust reduces risk
2. **Sustainability**: Distributed maintenance burden
3. **Quality**: Multiple review layers
4. **Growth**: Structured onboarding for new contributors

### For Users

1. **Stability**: Experienced maintainers with skin in the game
2. **Accountability**: Clear ownership and responsibility
3. **Continuity**: Multiple maintainers prevent single points of failure

## Comparison with Traditional Models

| Aspect | Traditional OSS | TPCF |
|--------|----------------|------|
| Contribution | Binary (contributor/maintainer) | Graduated (3 levels) |
| Trust | All or nothing | Incremental |
| Onboarding | Informal | Structured |
| Recognition | Often implicit | Explicit perimeters |
| Security | Single barrier | Defense in depth |

## Emotional Safety (Palimpsest Alignment)

TPCF aligns with Palimpsest License emotional safety principles:

### Attribution Persistence

- Git history preserved permanently
- CHANGELOG.md credits contributors
- humans.txt recognition
- Perimeter promotions publicly acknowledged

### Reversibility

- Contributors can fork at any time
- No lock-in mechanisms
- Clear migration paths documented
- Perimeter demotion possible (with due process)

### Psychological Safety

- Clear expectations reduce anxiety
- Structured feedback through reviews
- Mentorship opportunities
- Experimentation encouraged in feature branches

### Autonomy

- Contributors control their involvement level
- No pressure to advance perimeters
- Fork-friendly governance
- Diverse contribution types valued

## Perimeter Transitions

### Nomination Process

1. **Self-nomination** or nomination by existing member
2. **Discussion** among current perimeter members
3. **Vote** (2/3 majority required)
4. **Onboarding** and access provisioning
5. **Announcement** in CHANGELOG and discussions

### Demotion Process

Rare but possible for:
- Extended inactivity (voluntary step-down)
- Repeated Code of Conduct violations
- Security policy breaches

**Process**:
1. Private discussion with maintainers
2. Opportunity to respond
3. Vote if necessary (2/3 majority)
4. Transition support

### Emeritus Status

Contributors who step down gracefully receive **Emeritus** recognition:
- Listed in MAINTAINERS.md
- Contribution history preserved
- Welcome to return
- Consulting/advisory role available

## Current State

As of 2024-11-22:

- **Perimeter 3**: ✅ Active and accepting contributions
- **Perimeter 2**: 🔜 No members yet (project in initial phase)
- **Perimeter 1**: 🔜 Founding maintainer(s) to be established

## Metrics and Transparency

### Public Dashboards

(Planned):
- Contribution statistics per perimeter
- Time to review for each level
- Graduation timeline tracking

### Regular Reports

Quarterly reports will include:
- New perimeter promotions
- Contribution highlights
- Community growth metrics
- Governance decisions

## Integration with RSR

TPCF is a component of RSR (Rhodium Standard Repository) compliance:

- ✅ Community governance structure
- ✅ Clear contribution pathways
- ✅ Security through graduated trust
- ✅ Emotional safety preservation

## References

- [Code of Conduct](../CODE_OF_CONDUCT.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [Maintainers](../MAINTAINERS.md)
- [Security Policy](../SECURITY.md)
- Palimpsest License: [LICENSE.txt](../LICENSE.txt)

---

**Questions?** Open a discussion or contact maintainers (see MAINTAINERS.md)
