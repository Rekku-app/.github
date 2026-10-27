#!/usr/bin/env bash
# Tests org-files.sh on a scratch repository: an out-of-date one fails the
# check, sync fixes it and keeps the repository's own parts, then it passes.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT

mkdir -p "$repo/.github" "$repo/scripts"
printf '# demo\n\nOwn intro.\n\n<!-- org-rules:start -->\nold rules\n<!-- org-rules:end -->\n\n## Code\n\nOwn code section.\n' > "$repo/CLAUDE.md"
printf '## Old template\n\n<!-- repo-specific:start -->\n- [ ] A check of its own\n<!-- repo-specific:end -->\n' > "$repo/.github/pull_request_template.md"
echo '{"nextSteps": []}' > "$repo/scripts/bootstrap.json"
echo 'Someone <someone@example.com>' > "$repo/.mailmap"

if bash "$here/org-files.sh" check "$repo" > /dev/null; then echo "FAIL: an out-of-date repository passed"; exit 1; fi
bash "$here/org-files.sh" sync "$repo" > /dev/null || true
bash "$here/org-files.sh" check "$repo"

grep -q 'Own code section.' "$repo/CLAUDE.md" || { echo "FAIL: sync dropped the repository's own CLAUDE.md text"; exit 1; }
grep -q 'A check of its own' "$repo/.github/pull_request_template.md" || { echo "FAIL: sync dropped the repo-specific block"; exit 1; }
grep -q 'old rules' "$repo/CLAUDE.md" && { echo "FAIL: sync kept the old rules"; exit 1; }

# A changed rule is drift.
sed -i 's/^- Bugs and follow-ups/- Bugs, follow-ups/' "$repo/CLAUDE.md"
if bash "$here/org-files.sh" check "$repo" > /dev/null; then echo "FAIL: a changed rule passed"; exit 1; fi
echo "ok"
