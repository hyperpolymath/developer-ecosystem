# Reversibility

## Overview

The aggregate-library (aLib) project embraces **reversibility** as a core design principle. Every operation, decision, and contribution can be undone or revised. This document explains our reversibility philosophy and implementation.

## Philosophy: Why Reversibility Matters

### Psychological Safety

**Reversibility reduces anxiety** by eliminating fear of permanent mistakes:

- Contributors can experiment freely
- Errors don't cause lasting damage
- Learning happens through safe exploration
- Innovation emerges from low-risk experimentation

### Technical Benefits

**Reversibility enables better engineering**:

- Test different approaches safely
- Roll back problematic changes instantly
- Maintain stable production while experimenting
- Learn from failures without consequences

### Community Health

**Reversibility supports healthy collaboration**:

- Disagreements can be resolved by trying both approaches
- No need for perfect decisions upfront
- Community can evolve organically
- Trust builds through safe experimentation

## Reversibility in Practice

### 1. Specification Changes

**Every specification change is reversible through Git**:

```bash
# Revert a specific commit
git revert <commit-hash>

# Revert to previous version
git checkout <previous-commit> -- specs/arithmetic/add.md

# Create alternative branch to test approach
git checkout -b experiment/alternative-semantics
```

**Test cases provide safety net**:
- Implementations verify against test cases
- Breaking changes detected immediately
- Safe to experiment with semantics

**Deprecation period allows reversal**:
- Minimum 6 months for breaking changes
- Community feedback can reverse decisions
- Nothing is permanent until v1.0.0+

### 2. Contribution Workflow

**All contributions are reversible**:

1. **Branches**: Work happens in isolated branches
2. **Pull Requests**: Review before merge
3. **Revert**: Any merged PR can be reverted
4. **Alternative PRs**: Multiple approaches can coexist in branches

**No destructive operations**:
- No force pushes to main (protected branch)
- No history rewriting after merge
- Complete audit trail preserved

### 3. Operations Are Inherently Reversible

**The Common Library operations are designed for reversibility**:

| Operation | Reverse Operation | Notes |
|-----------|-------------------|-------|
| `add(a, b)` | `subtract(result, b)` | Returns `a` |
| `subtract(a, b)` | `add(result, b)` | Returns `a` |
| `concat(a, b)` | `substring(result, 0, length(a))` | Returns `a` |
| `map(c, f)` | `map(result, inverse(f))` | If `f` invertible |
| `if_then_else(c, t, e)` | N/A | Selection, not transformation |

**Immutability preferred**:
- Operations return new values
- Original data unchanged
- History preserved
- Undo by referencing previous state

### 4. Decision Reversibility

**Governance decisions can be revisited**:

- **Process**: Follow GOVERNANCE.adoc amendment process
- **Timeline**: No minimum wait (though stability valued)
- **Requirements**:
  - Clear rationale for reversal
  - Community discussion
  - Maintainer consensus
- **Examples**:
  - New operation added, then removed if problematic
  - Specification wording reverted to previous version
  - Policy changes reversed based on feedback

**Even governance itself is reversible**:
- GOVERNANCE.adoc can be amended
- Maintainers can step down and return
- TPCF perimeters can be adjusted

### 5. Build and Validation

**Validation is non-destructive**:

```bash
# All checks are read-only
just validate   # Validates specs, doesn't modify
just test       # Runs tests, doesn't change files
just docs       # Checks docs, doesn't alter
just check      # Full validation, zero changes
```

**Automated checks prevent accidental damage**:
- Pre-commit hooks catch errors before commit
- CI/CD validates before merge
- No automated commits without human approval

### 6. Community Contributions

**Low-risk contribution environment**:

- **Perimeter 3** (Community Sandbox): Experiment freely
- **Branches**: Create as many as needed
- **Forks**: Fork and experiment independently
- **Pull Requests**: Reviewed before merging
- **Revert**: Merged PRs can be reverted if problematic

**First-time contributor safety**:
- Mistakes are expected and welcomed
- Maintainers help fix issues
- No shaming for errors
- Learning encouraged through experimentation

### 7. Release Management

**Releases follow reversibility principles**:

- **Semantic Versioning**: Clearly signals compatibility
- **Deprecation**: Minimum 2 releases or 12 months
- **Migration Guides**: Clear path forward and backward
- **Rollback**: Previous versions always available

**Version 1.0.0+ stability**:
- Breaking changes reserved for major versions
- Minor versions strictly backward compatible
- Patch versions for fixes only

### 8. Documentation

**Documentation changes are fully reversible**:

- All in version control (Git)
- History preserved indefinitely
- Alternative versions in branches
- Previous versions accessible via tags

**Living documents**:
- Can be amended anytime
- Community proposals welcomed
- Regular reviews ensure relevance

## Reversibility Checklist

When making changes, ask:

- [ ] Can this change be reverted easily?
- [ ] Is there an undo mechanism?
- [ ] Are we preserving history?
- [ ] Have we documented the reversal process?
- [ ] Are we avoiding destructive operations?
- [ ] Is this change isolated (not cascading)?
- [ ] Do tests verify reversibility where applicable?

## Exceptions to Reversibility

Some things are intentionally hard to reverse:

### Security Actions

- **Reason**: Protect community
- **Examples**: Bans for severe Code of Conduct violations
- **Process**: Still reviewable through appeal process
- **Note**: Even bans can be lifted after appropriate repair

### Legal Requirements

- **Reason**: Legal compliance
- **Examples**: DMCA takedowns, court orders
- **Process**: Follow legal procedures
- **Note**: Reversible once legal issue resolved

### Practical Limits

- **Merged PRs**: Can be reverted, but may disrupt downstream users
- **Published Releases**: Can't delete from history, but can deprecate
- **Community Decisions**: Can reverse, but repeated reversals erode trust

## Implementing Reversibility

### For Contributors

```bash
# Always work in branches
git checkout -b feat/my-experiment

# Make changes freely
# If it doesn't work, just:
git checkout main  # Discard experiment

# If it works:
# Submit PR, get review, merge
# If merged PR causes issues:
# Maintainer can revert
```

### For Maintainers

```bash
# Review before merging
# If problematic change merged:
git revert <commit-hash>
git push origin main

# Or for multiple commits:
git revert <start-commit>..<end-commit>
```

### For Implementers

- Keep previous specification versions accessible
- Implement operations to preserve original data
- Document state transitions clearly
- Provide migration tools for breaking changes

## Reversibility Metrics

We track reversibility health:

| Metric | Target | Current |
|--------|--------|---------|
| Time to revert | < 1 hour | ✅ |
| % destructive operations | 0% | ✅ 0% |
| % force pushes to main | 0% | ✅ 0% |
| Contributor anxiety (self-reported) | Low | 🟡 TBD |
| Revert success rate | 100% | ✅ 100% |

## Cultural Aspects

### Growth Mindset

**Mistakes are learning opportunities**:
- Errors expected and normalized
- Experimentation encouraged
- Failure is data, not defeat
- Reversibility enables growth

### Trust Through Safety

**Reversibility builds trust**:
- Contributors trust they won't break things permanently
- Maintainers trust contributors to experiment
- Community trusts governance can self-correct
- Users trust specifications can improve

### Innovation Through Safety

**Safety enables innovation**:
- Low risk = high experimentation
- Experimentation = learning
- Learning = innovation
- Innovation = better specifications

## Resources

- **Git Documentation**: https://git-scm.com/doc
- **Reversible Computing**: Theoretical foundations
- **Event Sourcing**: Immutable event logs
- **CRDTs**: Conflict-free replicated data types (automatically reversible)

## Questions?

For questions about reversibility:

- Open issue with `reversibility` or `question` label
- Reference this document in discussions
- Propose improvements via pull request

---

**Remember**: *If it can't be undone easily, reconsider if it should be done at all.*

**Version**: 1.0.0
**Last Updated**: 2025-11-22
**Next Review**: 2026-02-22 (3 months)
