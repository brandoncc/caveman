#!/usr/bin/env bash
# Fetch upstream, identify new commits since the last `audited-*` tag,
# write a diff to /tmp/, and print a ready-to-paste audit prompt for Claude Code.
#
# Does not merge. Does not push. Does not modify the working tree beyond
# `git fetch upstream`.
set -euo pipefail

REPO="${REPO:-$HOME/dev/caveman}"
cd "$REPO"

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "✘ No 'upstream' remote in $REPO" >&2
  echo "  add with: git remote add upstream https://github.com/JuliusBrussee/caveman.git" >&2
  exit 1
fi

LAST_AUDITED=$(git tag -l 'audited-*' | sort -V | tail -1)
if [ -z "$LAST_AUDITED" ]; then
  echo "✘ No 'audited-*' tag found in $REPO" >&2
  echo "  tag the current reviewed state first:" >&2
  echo "    git tag -a audited-\$(git rev-parse --short HEAD) -m 'Reviewed'" >&2
  exit 1
fi

echo "→ Fetching upstream…"
git fetch upstream --quiet

NEW_COUNT=$(git rev-list --count "$LAST_AUDITED..upstream/main")
if [ "$NEW_COUNT" -eq 0 ]; then
  echo "✓ No new commits since $LAST_AUDITED. Nothing to review."
  exit 0
fi

echo
echo "→ $NEW_COUNT new commit(s) since $LAST_AUDITED:"
echo
git log "$LAST_AUDITED..upstream/main" --oneline
echo

DIFF=$(mktemp /tmp/caveman-upstream-diff.XXXXXX)
git diff "$LAST_AUDITED..upstream/main" > "$DIFF"
SIZE=$(wc -c < "$DIFF" | tr -d ' ')
echo "→ Full diff written to: $DIFF ($SIZE bytes)"
echo
echo "─── paste into Claude Code ──────────────────────────────────────────"
cat <<EOF
Audit the diff at $DIFF — these are new upstream commits to caveman
since the last audited state ($LAST_AUDITED). Read $REPO/AUDIT-WORKFLOW.md
for the focus areas, then check each new commit against them:

1. install.sh / install.ps1 — new URLs, new defaults flipped to ON-by-default,
   new third-party npx packages, new curl|bash patterns.
2. hooks/*.js — new file reads, new execFile/spawn callsites, new SessionStart
   side effects, anything that breaks no-network / no-eval / O_NOFOLLOW.
3. mcp-servers/caveman-shrink/ — fixes or regressions to the sentinel-restoration
   bug at compress.js:58-73, new top-level field rewriting beyond \`description\`,
   new env-var-driven config.
4. caveman-compress/scripts/ — new sensitive-file patterns, validation becoming
   fail-closed on heading/path/bullet drift, atomic-write (tmp+rename+fsync).
5. package.json — new deps, postinstall/preinstall/prepare scripts.
6. .github/workflows/ — new triggers (especially pull_request_target),
   new secret references.

Report under 600 words. Group findings by severity (Critical / High / Medium /
Low / Informational). End with a verdict line:
  SAFE TO MERGE  /  NEEDS FIXES  /  DO NOT MERGE
and one sentence on why.
EOF
echo "─────────────────────────────────────────────────────────────────────"
