# Upstream Sync — Audit-First Workflow

This is a fork. Upstream (`JuliusBrussee/caveman`) is single-maintainer and recently published; treat each upstream commit as untrusted code until reviewed. The currently-installed Claude Code plugin runs from the local clone Claude Code made when `claude plugin marketplace add brandoncc/caveman` ran — it does not auto-fetch. As long as you don't run `claude plugin marketplace update caveman`, you stay on the installed SHA.

The most recent reviewed state is tagged `audited-<sha>`.

## Quick start

```bash
~/dev/caveman/scripts/review-upstream.sh
```

The script fetches `upstream`, finds the latest `audited-*` tag, and either:
- exits cleanly if nothing is new, or
- prints the new commits, writes the full diff to `/tmp/`, and prints a ready-to-paste audit prompt for Claude Code.

Paste the prompt into a fresh Claude Code session. Read the agent's report before merging.

## Manual flow (if you'd rather not run the script)

```bash
cd ~/dev/caveman
git fetch upstream
LAST=$(git tag -l 'audited-*' | sort -V | tail -1)
git log "$LAST..upstream/main" --oneline                       # what's new
git diff "$LAST..upstream/main" > /tmp/caveman-upstream.diff   # full diff
```

## What the review covers

The original full audit flagged correctness/safety issues in five areas. New upstream commits are checked against those same areas:

1. **`install.sh` / `install.ps1`** — new URLs, new defaults flipped ON, new third-party `npx` packages, new `curl | bash`-style patterns.
2. **`hooks/*.js`** (`caveman-activate.js`, `caveman-mode-tracker.js`, `caveman-stats.js`, `caveman-config.js`) — new file reads, new `execFile`/`spawn` callsites, new SessionStart side effects, anything that breaks the no-network / no-`eval` / `O_NOFOLLOW` invariants.
3. **`mcp-servers/caveman-shrink/`** — fixes (or regressions) to the sentinel-restoration bug at `compress.js:58-73`, new top-level field rewriting beyond `description`, new env-var-driven config.
4. **`caveman-compress/scripts/`** — new sensitive-file patterns, validation becoming fail-closed on heading/path/bullet drift, atomic-write (tmp + rename + fsync) introduced.
5. **`package.json` files** — new dependencies, new `postinstall` / `preinstall` / `prepare` scripts.
6. **`.github/workflows/`** — new triggers (especially `pull_request_target`), new secret references.

A diff that touches none of these is safe. A diff that touches them needs a human read after the agent's report.

## Merging after review

```bash
cd ~/dev/caveman
git checkout main
git merge upstream/main
NEW=$(git rev-parse --short HEAD)
git tag -a "audited-$NEW" -m "Reviewed: <one-line summary>"
git push origin main "audited-$NEW"

claude plugin marketplace update caveman   # picks up new HEAD
```

## If review finds blockers

Don't merge. Two options:

- **Cherry-pick the clean commits** and skip the bad one(s). Tag the new tip `audited-<sha>`.
- **Stay put.** The installed plugin keeps working on the old `audited-*` tag indefinitely. Wait for upstream to fix.

## Re-auditing the whole thing

If upstream has drifted far enough that incremental review is harder than a fresh full audit (e.g. the installer or MCP proxy was rewritten), redo the parallel multi-area audit pattern from the original review rather than trying to track diff-by-diff.
