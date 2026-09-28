#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# sweep-wellknown.sh — stage 5 (#119) batch driver.
#
# #119 enumerated the denominator: 270 of 348 owner repositories carry a root
# .well-known/. This drives the sweep the issue asked for —
#
#     per repo: classify -> run migrator -> run suite -> commit
#
# in batches, rather than as 270 hand-made pull requests. It is deliberately
# a driver and not a bot: it never pushes unless you pass --push, and it
# refuses to guess on the one class of repository where migrating is not
# obviously correct.
#
# Classification (one GitHub API call per repo) decides who gets swept:
#
#   sweep          — identifiably RSR-derived and not served from the repo
#                    root: migrate it. RSR-ness is judged on a tiered marker
#                    (root-allow.txt under either spelling, else a
#                    .machine_readable/ tree), because the allowlist only
#                    entered the template in August 2026 and most of the
#                    estate predates it. The marker that fired is recorded.
#   review-pages   — GitHub Pages / CDN-served from the repo root. #119 names
#                    these as undecided: for a Pages repo the root
#                    .well-known/ may be a SERVING REQUIREMENT rather than
#                    legacy layout, and moving it out of the served root can
#                    break live discovery. Not swept without --include-review.
#   review-other   — has a root .well-known/ but no RSR marker at all, so the
#                    arrangement is not known to be template-derived.
#                    Not swept without --include-review.
#
# Requirements: bash, git, curl, jq. A token with `repo` scope (public repos
# need only `public_repo`) in GITHUB_TOKEN, or a signed-in `gh` — or pass
# --no-auth with --trees-dir to do everything except push, unauthenticated.
#
# Exit codes:
#   0 — every selected repository ended clean or already-clean
#   1 — at least one repository failed, or quarantined content needs a human
#       (suppress the latter with --allow-conflicts)
#   2 — usage / setup error

set -euo pipefail

OWNER="hyperpolymath"
REPOS_FILE=""
BATCH=""
BATCH_SIZE=25
LIMIT=""
DRY_RUN=0
PUSH=0
INCLUDE_REVIEW=0
ALLOW_CONFLICTS=0
CLASSIFY_ONLY=0
NO_AUTH=0
TREES_DIR=""
WORK=""
BRANCH="chore/well-known-to-www"
MIGRATOR=""
SUITE=""

usage() {
    cat <<'EOF'
Usage: scripts/sweep-wellknown.sh [options] [repo ...]

Classify, migrate and test repositories in batches (czech-file-knife#119).

Selecting repositories:
  --repos-file FILE   one repository name per line ('#' comments allowed)
  --owner OWNER       default: hyperpolymath
  --batch N           process only batch N (1-based) of --batch-size
  --batch-size N      default: 25
  --limit N           process only the first N selected repositories

What to do:
  --classify-only     classify and write classification.csv; migrate nothing
  --include-review    also sweep review-pages / review-other (see header)
  --dry-run           classify, migrate --dry-run, run the suite; commit nothing
  --push              push the branch to origin (default: commit only)
  --branch NAME       branch to commit on (default: chore/well-known-to-www)
  --allow-conflicts   exit 0 even where content was quarantined
  --work-dir DIR      where to put clones and reports (default: mktemp -d)
  --no-auth           run without a token: clone read-only over https and
                      classify from --trees-dir. Classify, migrate, test and
                      commit all work; only --push needs a credential.
  --trees-dir DIR     classify from cached `git/trees` listings, one file per
                      repository, one path per line, as written by a previous
                      run's <work>/trees/. Required by --no-auth: the
                      unauthenticated API is capped at 60 requests/hour.

Environment:
  GITHUB_TOKEN / GH_TOKEN   required; falls back to `gh auth token`
EOF
}

die() { echo "sweep: ERROR — $*" >&2; exit 2; }
note() { echo "sweep: $*"; }

POSITIONAL=()

while [ $# -gt 0 ]; do
    case "$1" in
        --owner)        [ $# -ge 2 ] || die "--owner requires a value"; OWNER="$2"; shift 2 ;;
        --repos-file)   [ $# -ge 2 ] || die "--repos-file requires a path"; REPOS_FILE="$2"; shift 2 ;;
        --batch)        [ $# -ge 2 ] || die "--batch requires a number"; BATCH="$2"; shift 2 ;;
        --batch-size)   [ $# -ge 2 ] || die "--batch-size requires a number"; BATCH_SIZE="$2"; shift 2 ;;
        --limit)        [ $# -ge 2 ] || die "--limit requires a number"; LIMIT="$2"; shift 2 ;;
        --classify-only) CLASSIFY_ONLY=1; shift ;;
        --include-review) INCLUDE_REVIEW=1; shift ;;
        --no-auth)      NO_AUTH=1; shift ;;
        --trees-dir)    [ $# -ge 2 ] || die "--trees-dir requires a path"; TREES_DIR="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=1; shift ;;
        --push)         PUSH=1; shift ;;
        --allow-conflicts) ALLOW_CONFLICTS=1; shift ;;
        --branch)       [ $# -ge 2 ] || die "--branch requires a value"; BRANCH="$2"; shift 2 ;;
        --work-dir)     [ $# -ge 2 ] || die "--work-dir requires a path"; WORK="$2"; shift 2 ;;
        --migrator)     [ $# -ge 2 ] || die "--migrator requires a path"; MIGRATOR="$2"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        -*)             die "unknown option: $1" ;;
        *)              POSITIONAL+=("$1"); shift ;;
    esac
done

for c in git curl jq; do
    command -v "$c" >/dev/null 2>&1 || die "$c is required but not installed"
done

# Fail before cloning anything: discovering on repo 200 of 270 that commits
# cannot be made wastes the whole run and leaves 199 half-swept checkouts.
# `git var` honours config and GIT_COMMITTER_* alike, so either setup passes.
if [ "$CLASSIFY_ONLY" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    if ! git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
        die "git cannot determine a committer identity, and the sweep commits. Either:
  git config --global user.name  \"Your Name\"
  git config --global user.email \"you@example.com\"
or export GIT_COMMITTER_NAME / GIT_COMMITTER_EMAIL (plus GIT_AUTHOR_*)."
    fi
fi

# ── token ───────────────────────────────────────────────────────────────────
TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
    TOKEN="$(gh auth token 2>/dev/null || true)"
fi
if [ -z "$TOKEN" ]; then
    if [ "$NO_AUTH" -eq 0 ]; then
        die "no token: set GITHUB_TOKEN (repo scope), sign in with gh, or pass --no-auth to run read-only"
    fi
    note "no token available; running unauthenticated (--no-auth) — push unavailable"
    [ -n "$TREES_DIR" ] || die "--no-auth requires --trees-dir (unauthenticated API is 60 req/hour)"
    [ -d "$TREES_DIR" ] || die "trees dir not found: $TREES_DIR"
fi
if [ "$PUSH" -eq 1 ] && [ -z "$TOKEN" ]; then
    die "--push requires a token; re-run with GITHUB_TOKEN set"
fi

# ── paths ───────────────────────────────────────────────────────────────────
# The migrator is located rather than assumed: this script is run from a
# template checkout, from a copy on $PATH, or from an unrelated directory, and
# each of those puts the scripts/ directory somewhere different.
resolve_migrator() {
    if [ -n "$MIGRATOR" ]; then printf '%s' "$MIGRATOR"; return; fi
    local c
    for c in "$(git rev-parse --show-toplevel 2>/dev/null || true)" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" \
             "$PWD"; do
        if [ -n "$c" ] && [ -f "$c/scripts/migrate-wellknown-to-www.sh" ]; then
            printf '%s' "$c/scripts/migrate-wellknown-to-www.sh"
            return
        fi
    done
    printf ''
}
MIGRATOR="$(resolve_migrator)"
[ -n "$MIGRATOR" ] || die "migrator not found; pass --migrator /path/to/migrate-wellknown-to-www.sh"

if [ -z "$WORK" ]; then
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/wellknown-sweep.XXXXXX")"
else
    mkdir -p "$WORK"
fi
mkdir -p "$WORK/reports" "$WORK/repos"

CLASS_CSV="$WORK/classification.csv"
RESULT_CSV="$WORK/sweep-results.csv"
printf 'repo,classification,root_wellknown,www_wellknown,notes\n' > "$CLASS_CSV"
printf 'repo,classification,status,detail\n' > "$RESULT_CSV"

# ── repository list ─────────────────────────────────────────────────────────
REPOS=()
if [ -n "$REPOS_FILE" ]; then
    [ -f "$REPOS_FILE" ] || die "repos file not found: $REPOS_FILE"
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | tr -d '[:space:]')"
        [ -n "$line" ] && REPOS+=("$line")
    done < "$REPOS_FILE"
fi
REPOS+=(${POSITIONAL[@]+"${POSITIONAL[@]}"})

if [ ${#REPOS[@]} -eq 0 ]; then
    die "no repositories selected: pass --repos-file FILE or names as arguments"
fi

if [ -n "$BATCH" ]; then
    start=$(( (BATCH - 1) * BATCH_SIZE ))
    REPOS=(${REPOS[@]:$start:$BATCH_SIZE})
    [ ${#REPOS[@]} -gt 0 ] || die "batch $BATCH is empty"
    note "batch $BATCH of size $BATCH_SIZE: ${#REPOS[@]} repository(ies)"
fi
if [ -n "$LIMIT" ] && [ "$LIMIT" -lt ${#REPOS[@]} ]; then
    REPOS=(${REPOS[@]:0:$LIMIT})
fi
note "selected ${#REPOS[@]} repository(ies) from $OWNER; work dir $WORK"

# ── classification ─────────────────────────────────────────────────────────
gh_api() { # path...
    curl -sS --fail --retry 2 --retry-delay 1 --max-time 60 \
         -H "Authorization: Bearer $TOKEN" \
         -H "Accept: application/vnd.github+json" \
         -H "X-GitHub-Api-Version: 2022-11-28" \
         "$@"
}

classify_repo() { # repo -> "class|root_wk|www_wk|notes"; paths cached in $WORK/trees/<repo>
    local repo="$1"
    local json paths=""
    mkdir -p "$WORK/trees"

    # A cached tree listing is the same data the API would return, so prefer
    # it: unauthenticated classification is capped at 60 requests/hour.
    if [ -n "$TREES_DIR" ] && [ -f "$TREES_DIR/$repo" ]; then
        paths="$(cat "$TREES_DIR/$repo")"
    fi
    if [ -n "$paths" ]; then
        printf '%s\n' "$paths" > "$WORK/trees/$repo"
    else
        if ! json="$(gh_api "https://api.github.com/repos/$OWNER/$repo/git/trees/HEAD?recursive=1" 2>/dev/null)"; then
            printf 'unknown|?|?|API error (missing/empty/private, or rate limited)\n'
            return 0
        fi
        if [ "$(printf '%s' "$json" | jq -r '.truncated // false')" = "true" ]; then
            printf 'review-other|?|?|tree truncated by API — classify by hand\n'
            return 0
        fi
        paths="$(printf '%s' "$json" | jq -r '.tree[]?.path // empty')"
        printf '%s\n' "$paths" > "$WORK/trees/$repo"
    fi

    has() { grep -qxF "$1" <<<"$paths"; }

    local root_wk=no www_wk=no rsr=no pages=no notes=""
    has ".well-known/security.txt" && root_wk=yes
    has "www/.well-known/security.txt" && www_wk=yes
    # Any file under either location counts, not just security.txt.
    grep -qx "\.well-known/..*" <<<"$paths" && root_wk=yes
    grep -qx "www/\.well-known/..*" <<<"$paths" && www_wk=yes

    # RSR-derived, tiered by evidence strength. The root allowlist is the
    # marker check-root-shape.sh itself resolves — but it only entered the
    # template in August 2026, so a repository minted before then is still
    # RSR-derived and simply does not carry it. Measured over the #119
    # denominator: 269/270 have a .machine_readable/ tree while only 59 have
    # root-allow.txt. Treating the allowlist as the sole marker therefore
    # misclassifies two thirds of the estate as "not an RSR instance", which
    # is wrong in the safe direction only by accident. The marker used is
    # recorded in the notes column so the call is auditable.
    local marker=""
    if has ".machine_readable/root-allow.txt" || has "machine-readable/root-allow.txt"; then
        rsr=yes
        marker="root-allow.txt"
    elif grep -q "^\.machine_readable/" <<<"$paths" \
         || grep -q "^machine-readable/" <<<"$paths"; then
        rsr=yes
        marker=".machine_readable/ (predates root-allow.txt)"
    fi

    # Pages / CDN served from the repo root: migrating .well-known/ out of the
    # served root is not obviously safe here (#119 special cases).
    case "$repo" in
        *.github.io) pages=yes; notes="repo name is a Pages site" ;;
    esac
    if has "CNAME"; then pages=yes; notes="${notes:+$notes; }CNAME at root (custom domain)" ; fi
    for f in netlify.toml vercel.json _config.yml wrangler.toml wrangler.jsonc; do
        if has "$f"; then pages=yes; notes="${notes:+$notes; }$f present" ; fi
    done

    local class
    if [ "$pages" = yes ]; then
        class=review-pages
    elif [ "$rsr" = yes ]; then
        class=sweep
    else
        class=review-other
        notes="${notes:+$notes; }no RSR marker found"
    fi
    [ -n "$marker" ] && notes="${notes:+$notes; }marker: $marker"
    printf '%s|%s|%s|%s\n' "$class" "$root_wk" "$www_wk" "$notes"
}

# ── migration ───────────────────────────────────────────────────────────────
sweep_repo() { # repo class -> appends to RESULT_CSV
    local repo="$1" class="$2"
    local dir="$WORK/repos/$repo"
    rm -rf "$dir"

    if [ "$CLASSIFY_ONLY" -eq 1 ]; then
        printf '%s,%s,skipped,classify-only\n' "$repo" "$class" >> "$RESULT_CSV"
        return 0
    fi

    export GIT_TERMINAL_PROMPT=0
    # Public repositories clone fine over plain https; the token only buys
    # push access (and a higher rate limit), so do not require it to read.
    local clone_url="https://github.com/${OWNER}/${repo}.git"
    [ -n "$TOKEN" ] && clone_url="https://x-access-token:${TOKEN}@github.com/${OWNER}/${repo}.git"
    if ! git clone --depth 1 -q "$clone_url" "$dir" 2>"$WORK/reports/$repo.clone.log"; then
        printf '%s,%s,failed,clone failed (see %s)\n' "$repo" "$class" "$WORK/reports/$repo.clone.log" >> "$RESULT_CSV"
        return 0
    fi

    if [ ! -d "$dir/.well-known" ]; then
        printf '%s,%s,clean,no root .well-known/ (already migrated or never had one)\n' "$repo" "$class" >> "$RESULT_CSV"
        return 0
    fi

    local report="$WORK/reports/$repo.tsv"
    local migflags=()
    [ "$DRY_RUN" -eq 1 ] && migflags+=(--dry-run)

    local status=migrated detail=""
    if (cd "$dir" && bash "$MIGRATOR" "${migflags[@]}" --report "$report") >"$WORK/reports/$repo.migrate.log" 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
            status=would-migrate
        fi
        if [ -f "$report" ] && grep -qP '^quarantined\t' "$report"; then
            status=quarantined
            detail="$(grep -cP '^quarantined\t' "$report") divergent file(s) quarantined — needs a human"
        fi
    else
        status=failed
        detail="migrator exited non-zero (see $WORK/reports/$repo.migrate.log)"
    fi

    # Post-migration suite: only meaningful where the repo carries the bundle.
    if [ -f "$dir/www/tests/run-all.sh" ]; then
        if ! (cd "$dir" && bash www/tests/run-all.sh) >"$WORK/reports/$repo.tests.log" 2>&1; then
            status=failed
            detail="${detail:+$detail; }www/tests/run-all.sh failed (see $WORK/reports/$repo.tests.log)"
        fi
    else
        detail="${detail:+$detail; }no www/tests bundle — run the RSR update mechanism first"
    fi

    if [ "$DRY_RUN" -eq 0 ] && [ "$status" != failed ]; then
        if [ -n "$(cd "$dir" && git status --porcelain)" ]; then
            # A commit failure is recorded, never fatal: one repository with an
            # unusual hook or an unwritable ref must not abandon the batch.
            if (cd "$dir" && git add -A && git commit -qm "chore(www): migrate root .well-known/ to www/.well-known/ (czech-file-knife#119)"); then
                if [ "$PUSH" -eq 1 ]; then
                    (cd "$dir" && git push -q origin "HEAD:$BRANCH") \
                        || detail="${detail:+$detail; }push failed"
                fi
            else
                status=failed
                detail="${detail:+$detail; }commit failed"
            fi
        else
            [ "$status" = migrated ] && status=clean
        fi
    fi

    printf '%s,%s,%s,%s\n' "$repo" "$class" "$status" "$detail" >> "$RESULT_CSV"
    return 0
}

# ── main ────────────────────────────────────────────────────────────────────
declare -i total=0 swept=0 review=0
for repo in "${REPOS[@]}"; do
    total+=1
    IFS='|' read -r class root_wk www_wk notes <<<"$(classify_repo "$repo")"
    printf '%s,%s,%s,%s,%s\n' "$repo" "$class" "$root_wk" "$www_wk" "$notes" >> "$CLASS_CSV"
    printf '  %-40s %s\n' "$repo" "$class${notes:+ — $notes}"

    if [ "$class" = sweep ] || [ "$INCLUDE_REVIEW" -eq 1 ]; then
        swept+=1
        # Belt and braces: sweep_repo records its own failures and returns 0,
        # but an unexpected abort must still not take the batch down with it.
        if ! sweep_repo "$repo" "$class"; then
            printf '%s,%s,failed,unexpected abort (see %s)\n' "$repo" "$class" "$WORK" >> "$RESULT_CSV"
        fi
    else
        review+=1
        printf '%s,%s,skipped,%s\n' "$repo" "$class" "needs a decision: $class" >> "$RESULT_CSV"
    fi
done

echo
note "classification: $CLASS_CSV"
note "results:        $RESULT_CSV"
echo
echo "--- results by status ---"
tail -n +2 "$RESULT_CSV" | cut -d, -f3 | sort | uniq -c | sort -rn

failed=$(tail -n +2 "$RESULT_CSV" | grep -c ',failed,' || true)
quarantined=$(tail -n +2 "$RESULT_CSV" | grep -c ',quarantined,' || true)

if [ "$failed" -gt 0 ]; then
    echo
    echo "sweep: $failed repository(ies) FAILED:" >&2
    grep ',failed,' "$RESULT_CSV" >&2
    exit 1
fi
if [ "$quarantined" -gt 0 ] && [ "$ALLOW_CONFLICTS" -eq 0 ]; then
    echo
    echo "sweep: $quarantined repository(ies) quarantined divergent content — resolve before merging." >&2
    grep ',quarantined,' "$RESULT_CSV" >&2
    exit 1
fi
note "done: $total classified, $swept swept, $review held for review"
exit 0
