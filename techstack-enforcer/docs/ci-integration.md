# CI/CD Integration

Integrate Techstack Enforcer into your CI/CD pipelines to automatically enforce techstack policies.

## GitLab CI

### Quick Setup

Add to your `.gitlab-ci.yml`:

```yaml
include:
  - project: 'your-group/techstack-enforcer'
    file: '/ci-templates/gitlab-ci-techstack.yml'
    ref: main

variables:
  TECHSTACK_DEFSET: moderate
  TECHSTACK_MODE: enforce
```

### Manual Setup

```yaml
stages:
  - validate

variables:
  TECHSTACK_DEFSET: moderate
  TECHSTACK_MODE: enforce

techstack:check:
  stage: validate
  image: registry.gitlab.com/ada-lang/gnat:latest
  script:
    - gprbuild -P techstack_enforcer.gpr -XMODE=release -j0
    - ./bin/techstack_main audit . --defset=$TECHSTACK_DEFSET --mode=$TECHSTACK_MODE --fatal-exit
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Available Jobs

The CI template provides these extendable jobs:

| Job | Description |
|-----|-------------|
| `.techstack-check` | Quick validation on MRs |
| `.techstack-audit` | Full audit with JSON output |
| `.techstack-decide` | Check only changed files |
| `.techstack-learning` | Scheduled learning mode |

---

## GitHub Actions

### Quick Setup

1. Copy `ci-templates/github-action-techstack.yml` to `.github/workflows/techstack.yml`

2. Set repository variable `TECHSTACK_REPO`:
   - Go to Settings > Secrets and variables > Actions > Variables
   - Add: `TECHSTACK_REPO` = `hyperpolymath/techstack-enforcer`

3. Customize definition set and mode in the workflow file

### Manual Setup

```yaml
name: Techstack Enforcement

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

env:
  TECHSTACK_DEFSET: moderate
  TECHSTACK_MODE: enforce
  TECHSTACK_REPO: ${{ vars.TECHSTACK_REPO || 'hyperpolymath/techstack-enforcer' }}

jobs:
  techstack-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/checkout@v4
        with:
          repository: ${{ env.TECHSTACK_REPO }}
          path: techstack-enforcer

      - uses: alire-project/setup-alire@v3

      - name: Build
        working-directory: techstack-enforcer
        run: gprbuild -P techstack_enforcer.gpr -XMODE=release -j0

      - name: Check
        run: |
          ./techstack-enforcer/bin/techstack_main audit . \
            --defset=$TECHSTACK_DEFSET \
            --mode=$TECHSTACK_MODE \
            --fatal-exit
```

---

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TECHSTACK_DEFSET` | Definition set to use | `moderate` |
| `TECHSTACK_MODE` | Enforcement mode | `enforce` |
| `TECHSTACK_FATAL_EXIT` | Fail on violations | `true` |
| `TECHSTACK_PATH` | Path to scan | `.` |

---

## Checking Changed Files Only

For faster PR checks, only validate changed files:

### GitLab CI

```yaml
techstack:decide:
  script:
    - git diff --name-only $CI_MERGE_REQUEST_DIFF_BASE_SHA..$CI_COMMIT_SHA > changed_files.txt
    - cat changed_files.txt | ./bin/techstack_main decide --defset=$TECHSTACK_DEFSET
```

### GitHub Actions

```yaml
- name: Get changed files
  run: |
    git diff --name-only ${{ github.event.pull_request.base.sha }}..${{ github.sha }} > changed_files.txt

- name: Check changed files
  run: cat changed_files.txt | ./techstack-enforcer/bin/techstack_main decide
```

---

## Learning Mode

Run periodically to analyze patterns without blocking:

```yaml
# GitLab CI
techstack:learning:
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
  script:
    - ./bin/techstack_main audit . --mode=learning
  artifacts:
    paths:
      - techstack.log

# GitHub Actions
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
```

---

## Artifacts

Preserve reports for review:

```yaml
# GitLab
artifacts:
  paths:
    - techstack-report.json
    - techstack.log
  expire_in: 1 week

# GitHub
- uses: actions/upload-artifact@v4
  with:
    name: techstack-report
    path: |
      techstack-report.json
      techstack.log
```

---

## Best Practices

1. **Start with `permissive`** - Begin in advisory mode to understand violations
2. **Graduate to `moderate`** - Block high-risk patterns
3. **Use `strict` for security-critical** - Maximum enforcement for sensitive code
4. **Run learning mode weekly** - Discover new patterns
5. **Check changed files on PRs** - Faster feedback for developers
6. **Full audit on main branch** - Comprehensive coverage

## See Also

- [Definition Sets](./definition-sets.md)
- [Git Hooks](./git-hooks.md)
- [CLI Reference](./cli-reference.md)
