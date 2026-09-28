#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# migrate-wellknown-to-www.sh — conflict-safe migration of a repository-root
# .well-known/ tree into www/.well-known/ (czech-file-knife#53).
#
# Stage 1 established the canonical location. Stage 5 (#119) sweeps it across
# ~270 repositories, which changes what "conflict-safe" has to mean: a sweep
# is unattended, so a conflict may not halt it, and may not be silent either.
#
# Semantics, per the #53 migration requirements:
#   * identical content in both locations  -> root copy removed, www kept;
#   * content only at the root             -> moved into www/.well-known/;
#   * content only under www/              -> no-op;
#   * DIVERGENT content in both            -> the ROOT copy is quarantined to
#     www/.legacy-well-known-<YYYYMMDD>/ and the www/ copy is left untouched:
#     never overwritten, never silent. Exit 0 by default so a batch sweep can
#     continue; --strict turns a quarantine into a non-zero exit.
#
# --in-place restores the pre-stage-5 contract (both copies stay where they
# are, exit 1) for anyone who prefers to resolve divergence by hand before the
# tree is touched at all.
#
# Why the quarantine lives under www/ and not at the root:
#   #106's commit message specifies `.legacy-well-known-YYYYMMDD/` at the
#   repository root. The root allowlist (.machine_readable/root-allow.txt) is
#   checked BIDIRECTIONALLY by scripts/check-root-shape.sh and matches entries
#   literally, with no glob support — a root directory whose name carries a
#   date can never be allowlisted, so every swept repository would report root
#   drift the moment the migrator ran. Under www/ it is inside the site-
#   operations bundle the allowlist already permits, and it is NOT under
#   www/public/, so the publication boundary still holds.
#
# Run from the repository root. Uses `git mv`/`git rm` when the tree is a git
# checkout and the files are tracked, plain mv/rm otherwise, so it is safe on
# minted-but-uncommitted trees too. Propagation runners should combine this
# with a `git status --porcelain` / unpushed-commit check of their own; this
# script compares CONTENT, and content comparison is what "divergent" means
# here.
#
# Exit codes:
#   0 — clean migration (quarantines may have occurred; see the report)
#   1 — divergence left unresolved (--in-place), --strict and something was
#       quarantined, or files unexpectedly remain at the root
#   2 — usage / setup error

set -euo pipefail

ROOT=".well-known"
DEST="www/.well-known"

IN_PLACE=0
STRICT=0
DRY_RUN=0
REPORT=""

usage() {
    cat <<'EOF'
Usage: scripts/migrate-wellknown-to-www.sh [options]

Migrate a repository-root .well-known/ into www/.well-known/.

Options:
  --dry-run         report what would change; write nothing (always exit 0)
  --in-place        divergent content stays put, both copies kept, exit 1
                    (pre-stage-5 contract; for hand resolution)
  --strict          exit 1 if anything had to be quarantined
  --report FILE     write a TSV report: action<TAB>path<TAB>detail
  -h, --help        this message

Report actions: moved, deduped, quarantined, conflict, left.
EOF
}

die() { echo "migrate-wellknown: ERROR — $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
    case "$1" in
        --in-place) IN_PLACE=1; shift ;;
        --strict)   STRICT=1; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        --report)   [ $# -ge 2 ] || die "--report requires a path"; REPORT="$2"; shift 2 ;;
        --report=*) REPORT="${1#--report=}"; shift ;;
        -h|--help)  usage; exit 0 ;;
        *)          die "unknown option: $1" ;;
    esac
done

if [ "$IN_PLACE" -eq 1 ] && [ "$STRICT" -eq 1 ]; then
    die "--in-place and --strict are mutually exclusive (--in-place already fails on conflict)"
fi

# The report is written under --dry-run too: a dry run that only prints is
# useless to a batch driver, which needs the planned actions in a form it can
# read. Under --dry-run the rows describe what WOULD happen.
if [ -n "$REPORT" ]; then
    repdir="$(dirname "$REPORT")"
    if [ ! -d "$repdir" ]; then mkdir -p "$repdir"; fi
    printf 'action\tpath\tdetail\n' > "$REPORT"
fi

rep() {
    if [ -n "$REPORT" ]; then
        printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$REPORT"
    fi
    return 0
}

if [ ! -d "$ROOT" ]; then
    echo "migrate-wellknown: no $ROOT/ at repository root — nothing to migrate."
    exit 0
fi

STAMP="$(date -u +%Y%m%d)"
QUARANTINE="www/.legacy-well-known-$STAMP"

git_tracked() { git ls-files --error-unmatch "$1" >/dev/null 2>&1; }

move_file() { # src dst — never overwrites; caller guarantees dst is free
    local src="$1" dst="$2"
    # The dry-run guard precedes every filesystem effect, mkdir included:
    # an empty directory is invisible to `git status` but is still a change
    # to the tree, and --dry-run promises to leave nothing behind.
    if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
    mkdir -p "$(dirname "$dst")"
    if git_tracked "$src"; then
        git mv "$src" "$dst"
    else
        mv "$src" "$dst"
    fi
}

remove_file() { # src
    local src="$1"
    if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
    if git_tracked "$src"; then
        git rm -q "$src"
    else
        rm "$src"
    fi
}

# A quarantine target is never overwritten: if the dated name is taken, the
# next free `.N` suffix is used instead.
quarantine_dest() { # rel -> path
    # Declared one per line on purpose: in `local a="$1" b="$a"` every
    # expansion happens before any assignment, so $a is still unset when it
    # is read — fatal under `set -u`.
    local rel="$1"
    local base="$QUARANTINE/$rel"
    local cand="$base"
    local n=1
    while [ -e "$cand" ]; do
        cand="$base.$n"
        n=$((n + 1))
    done
    printf '%s' "$cand"
}

if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$DEST" ]; then
    mkdir -p "$DEST"
fi

moved=0; deduped=0; conflicts=0; quarantined=0

while IFS= read -r -d '' src; do
    rel="${src#"$ROOT"/}"
    dst="$DEST/$rel"

    if [ -f "$dst" ]; then
        if cmp -s "$src" "$dst"; then
            # Identical: the duplicate root copy goes; www is canonical.
            remove_file "$src"
            deduped=$((deduped + 1))
            echo "  identical, root copy removed: $rel"
            rep deduped "$rel" "identical to $DEST/$rel; root copy removed"
        elif [ "$IN_PLACE" -eq 1 ]; then
            conflicts=$((conflicts + 1))
            echo "  CONFLICT (both preserved): $rel differs between $ROOT/ and $DEST/" >&2
            echo "    root sha256: $(sha256sum "$src" | cut -d' ' -f1)" >&2
            echo "    www  sha256: $(sha256sum "$dst" | cut -d' ' -f1)" >&2
            rep conflict "$rel" "divergent; both preserved in place"
        else
            qdst="$(quarantine_dest "$rel")"
            if [ -e "$qdst" ]; then
                die "refusing to overwrite quarantine target $qdst"
            fi
            # Hashes are read BEFORE the move: afterwards $src no longer
            # exists, and a failing sha256sum inside $( ) would abort the
            # script under `set -e` before the conflict was ever reported.
            root_sha="$(sha256sum "$src" | cut -d' ' -f1)"
            www_sha="$(sha256sum "$dst" | cut -d' ' -f1)"
            move_file "$src" "$qdst"
            quarantined=$((quarantined + 1))
            echo "  DIVERGENT — root copy quarantined: $rel -> $qdst" >&2
            echo "    root sha256: $root_sha" >&2
            echo "    www  sha256: $www_sha  (kept, untouched)" >&2
            rep quarantined "$rel" "divergent; root copy -> $qdst"
        fi
    else
        if [ -e "$dst" ]; then
            die "refusing to overwrite existing $dst"
        fi
        move_file "$src" "$dst"
        moved=$((moved + 1))
        echo "  moved: $rel -> $dst"
        rep moved "$rel" "root-only; -> $DEST/$rel"
    fi
done < <(find "$ROOT" -type f -print0 | sort -z)

# Drop the root directory only when it is fully empty of files.
left=0
if [ -z "$(find "$ROOT" -type f -print -quit 2>/dev/null)" ]; then
    if [ "$DRY_RUN" -eq 0 ]; then
        find "$ROOT" -depth -type d -empty -delete 2>/dev/null || true
    fi
else
    left=$(find "$ROOT" -type f | wc -l | tr -d '[:space:]')
fi

echo "migrate-wellknown: moved=$moved deduped=$deduped quarantined=$quarantined conflicts=$conflicts left_in_root=$left"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "migrate-wellknown: dry run — nothing written."
    exit 0
fi

if [ "$left" -gt 0 ]; then
    echo "migrate-wellknown: WARNING — $left file(s) remain under $ROOT/ (unexpected)." >&2
    exit 1
fi

if [ "$conflicts" -gt 0 ]; then
    echo "migrate-wellknown: DIVERGENT CONTENT — both locations preserved in place; resolve by hand." >&2
    exit 1
fi

if [ "$quarantined" -gt 0 ]; then
    echo "migrate-wellknown: $quarantined divergent file(s) quarantined under $QUARANTINE/ —" >&2
    echo "migrate-wellknown: resolve by hand, then delete that directory. Nothing was overwritten." >&2
    if [ "$STRICT" -eq 1 ]; then
        exit 1
    fi
fi

exit 0
