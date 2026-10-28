#!/usr/bin/env bash
# Checks (or syncs) the files that are the same in every Rekku repository
# against their canonical copies in this repository (Rekku-app/.github).
#
#   scripts/org-files.sh check <repository>   exit 1 and list what differs
#   scripts/org-files.sh sync  <repository>   copy the canonical versions in
#
# <repository> is the path of a checked-out Rekku repository. What is
# compared:
#   CLAUDE.md                          the block between the org-rules markers,
#                                      against ORG_RULES.md's
#   .github/pull_request_template.md   all but the block between the
#                                      repo-specific markers
#   .gitattributes, .gitleaks.toml,    whole files
#   LICENSE, AGENTS.md
#   scripts/bootstrap.mjs              whole file, in repositories that have
#                                      scripts/bootstrap.json
#   .mailmap                           present (it names people's addresses,
#                                      so its canonical copy isn't public)
#
# CI runs `check` through .github/workflows/org-files.yml. Plain bash, awk
# and diff: it runs the same on a runner and on a laptop.
set -euo pipefail

usage() { echo "usage: $0 check|sync <repository>" >&2; exit 2; }
[ $# -eq 2 ] || usage
mode=$1
repo=$2
case "$mode" in check|sync) ;; *) usage ;; esac
[ -d "$repo" ] || { echo "no such directory: $repo" >&2; exit 2; }

canon=$(cd "$(dirname "$0")/.." && pwd)
failed=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The lines from the start marker to the end marker, both included.
block() { awk -v s="$2" -v e="$3" '$0 == s {f=1} f {print} $0 == e {f=0}' "$1"; }
# The file with the lines between the markers removed (the markers stay).
without_block() { awk -v s="$2" -v e="$3" '$0 == s {print; f=1; next} $0 == e {f=0} !f {print}' "$1"; }

report() { # what, expected file, actual file
  echo "::error file=$1::$1 differs from Rekku-app/.github (run scripts/org-files.sh sync)"
  diff -u --label "Rekku-app/.github" --label "$1" "$2" "$3" || true
  failed=1
}

# --- CLAUDE.md: the org rules block
S='<!-- org-rules:start -->'
E='<!-- org-rules:end -->'
block "$canon/ORG_RULES.md" "$S" "$E" > "$tmp/rules.want"
if [ ! -f "$repo/CLAUDE.md" ]; then
  echo "::error::CLAUDE.md is missing"; failed=1
else
  block "$repo/CLAUDE.md" "$S" "$E" > "$tmp/rules.have"
  if ! cmp -s "$tmp/rules.want" "$tmp/rules.have"; then
    if [ "$mode" = sync ] && [ -s "$tmp/rules.have" ]; then
      awk -v s="$S" -v e="$E" -v f2="$tmp/rules.want" '
        $0 == s { while ((getline l < f2) > 0) print l; skip=1; next }
        $0 == e { skip=0; next }
        !skip { print }' "$repo/CLAUDE.md" > "$tmp/claude" && cat "$tmp/claude" > "$repo/CLAUDE.md"
      echo "synced CLAUDE.md (org rules)"
    elif [ "$mode" = sync ]; then
      echo "::error::CLAUDE.md has no org-rules markers: add the two marker lines where the rules go, then sync again"; failed=1
    else
      report CLAUDE.md "$tmp/rules.want" "$tmp/rules.have"
    fi
  fi
fi

# --- the pull request template, except its repository-specific block
T=.github/pull_request_template.md
RS='<!-- repo-specific:start -->'
RE='<!-- repo-specific:end -->'
without_block "$canon/$T" "$RS" "$RE" > "$tmp/pr.want"
if [ -f "$repo/$T" ]; then without_block "$repo/$T" "$RS" "$RE" > "$tmp/pr.have"; else : > "$tmp/pr.have"; fi
if ! cmp -s "$tmp/pr.want" "$tmp/pr.have"; then
  if [ "$mode" = sync ]; then
    mkdir -p "$repo/.github"
    if [ -f "$repo/$T" ]; then block "$repo/$T" "$RS" "$RE" > "$tmp/pr.own"; else : > "$tmp/pr.own"; fi
    if [ -s "$tmp/pr.own" ]; then
      awk -v s="$RS" -v f2="$tmp/pr.own" '
        $0 == s { while ((getline l < f2) > 0) print l; skip=1; next }
        skip && $0 == "<!-- repo-specific:end -->" { skip=0; next }
        !skip { print }' "$canon/$T" > "$repo/$T"
    else
      cp "$canon/$T" "$repo/$T"
    fi
    echo "synced $T"
  else
    report "$T" "$tmp/pr.want" "$tmp/pr.have"
  fi
fi

# --- whole files
files=(.gitattributes .gitleaks.toml LICENSE AGENTS.md)
[ -f "$repo/scripts/bootstrap.json" ] && files+=("scripts/bootstrap.mjs")
for f in "${files[@]}"; do
  src="$canon/$f"
  [ "$f" = scripts/bootstrap.mjs ] && src="$canon/devtools/bootstrap.mjs"
  if ! cmp -s "$src" "$repo/$f" 2>/dev/null; then
    if [ "$mode" = sync ]; then
      mkdir -p "$(dirname "$repo/$f")"; cp "$src" "$repo/$f"; echo "synced $f"
    elif [ -f "$repo/$f" ]; then
      report "$f" "$src" "$repo/$f"
    else
      echo "::error::$f is missing (run scripts/org-files.sh sync)"; failed=1
    fi
  fi
done

# --- .mailmap: present
if [ ! -s "$repo/.mailmap" ]; then
  echo "::error::.mailmap is missing: copy it from another Rekku repository"; failed=1
fi

if [ "$failed" = 0 ]; then echo "$mode: the organization files match Rekku-app/.github"; fi
exit "$failed"
