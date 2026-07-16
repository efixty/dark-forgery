#!/usr/bin/env bash
# check_scaffold.sh — verify a generated dark factory scaffold is complete and correct.
#
# Usage: scripts/check_scaffold.sh <path-to-generated-project>
#
# Verifies the contracts Dark Forgery promises:
#   - required files exist (CLAUDE.md, CONSTITUTION.md, STATUS.md, Makefile, ...)
#   - the CONSTITUTION locked common core (rules 1-13) is intact
#   - STATUS.md has the required board sections
#   - the entrypoint honors the one-cycle lifecycle (exit sentinel, loop, --check)
#   - Makefile exposes setup/build/test
#   - .claude/settings.json is valid JSON with a permissions allow list
#   - no .env is tracked by git; .gitignore excludes secrets and the sentinel
#
# FAIL = the scaffold violates a hard contract. WARN = a conditional artifact is
# absent (may be intentional: comms=none, no vault, host-machine execution).
#
# Exit code: 0 if no failures (warnings allowed), 1 otherwise.
# Compatible with macOS bash 3.2.

set -u

if [ $# -ne 1 ] || [ ! -d "${1:-}" ]; then
  echo "Usage: $0 <path-to-generated-project>" >&2
  exit 2
fi
P="$(cd "$1" && pwd)"

ERRORS=0
WARNINGS=0
fail() { printf 'FAIL: %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { printf 'WARN: %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
ok()   { printf '  ok: %s\n' "$*"; }

echo "Checking scaffold: $P"
echo

# ── 1. Required files ────────────────────────────────────────────────────────
for f in CLAUDE.md CONSTITUTION.md STATUS.md Makefile .gitignore .env.example \
         .claude/settings.json docs/credentials.md docs/environment.md; do
  if [ -f "$P/$f" ]; then ok "$f"; else fail "missing required file: $f"; fi
done

# At least one role doc (supervisor is mandatory).
if [ -n "$(find "$P/docs/roles" -name '*.md' -type f 2>/dev/null | head -n 1)" ]; then
  ok "docs/roles/ has at least one role doc"
else
  fail "docs/roles/ has no role docs (supervisor role doc is mandatory)"
fi

# Exactly one supervisor entrypoint.
ENTRYPOINT="$(find "$P/scripts" -maxdepth 1 -name '*_entrypoint.sh' -type f 2>/dev/null | head -n 1)"
if [ -n "$ENTRYPOINT" ]; then
  ok "entrypoint: ${ENTRYPOINT#$P/}"
else
  fail "no scripts/*_entrypoint.sh found"
fi

# Supervisor startup prompt.
PROMPT="$(find "$P/scripts" -maxdepth 1 -name '*_prompt.md' ! -name '*_check_prompt.md' -type f 2>/dev/null | head -n 1)"
if [ -n "$PROMPT" ]; then
  ok "supervisor prompt: ${PROMPT#$P/}"
else
  fail "no scripts/*_prompt.md found (supervisor startup prompt)"
fi

# Conditional artifacts — absence may be intentional.
if [ -z "$(find "$P/scripts" -maxdepth 1 -name '*_check_prompt.md' -type f 2>/dev/null | head -n 1)" ]; then
  warn "no scripts/*_check_prompt.md — --check deep self-test has no prompt (ok for host-machine execution)"
fi
if [ -z "$(find "$P/scripts" -maxdepth 1 -name '*notify*.sh' -type f 2>/dev/null | head -n 1)" ]; then
  warn "no notify script under scripts/ (ok if comm channel is 'none')"
fi

# ── 2. CONSTITUTION common core (rules 1-13) ─────────────────────────────────
if [ -f "$P/CONSTITUTION.md" ]; then
  CORE_OK=1
  # Rule number + exact locked title.
  while IFS='|' read -r num title; do
    [ -z "$num" ] && continue
    if ! grep -qF "## $num. $title" "$P/CONSTITUTION.md"; then
      fail "CONSTITUTION.md common core missing or altered: rule $num ($title)"
      CORE_OK=0
    fi
  done <<'EOF'
1|Role discipline
2|Read before acting
3|Output contracts are inviolable
4|Every commit must pass its component's build
5|Tests are part of the task
6|Spec docs are mandatory for every PR
7|Fail loudly, fail fast
8|No speculative work
9|Security — never commit secrets
10|Commit message format
11|PR workflow — no direct commits to main
12|STATUS.md is the supervisor's domain
13|Vault/log notes are mandatory for every feature and issue
EOF
  [ "$CORE_OK" -eq 1 ] && ok "CONSTITUTION common core rules 1-13 intact"

  # Cycle limits are project-specific and must live in the additions section.
  if grep -qE 'cycles?' "$P/CONSTITUTION.md"; then
    ok "CONSTITUTION mentions cycle limits"
  else
    warn "CONSTITUTION.md never mentions cycle limits — review-cycle caps may be undefined"
  fi
fi

# ── 3. STATUS.md board sections ──────────────────────────────────────────────
if [ -f "$P/STATUS.md" ]; then
  for section in Active Backlog Completed Blocked "Active PRs"; do
    if grep -qE "^##[[:space:]]+$section([[:space:]]|\$)" "$P/STATUS.md"; then
      ok "STATUS.md section: $section"
    else
      fail "STATUS.md missing section: ## $section"
    fi
  done
fi

# ── 4. Entrypoint contract ───────────────────────────────────────────────────
if [ -n "$ENTRYPOINT" ]; then
  # Hard contract: the one-cycle lifecycle.
  grep -q '_exit' "$ENTRYPOINT" \
    && ok "entrypoint reads the exit sentinel" \
    || fail "entrypoint never touches the .*_exit sentinel — one-cycle lifecycle broken"
  grep -qE 'while[[:space:]]+true' "$ENTRYPOINT" \
    && ok "entrypoint has the relaunch loop" \
    || fail "entrypoint has no relaunch loop (while true)"
  grep -q 'claude ' "$ENTRYPOINT" \
    && ok "entrypoint spawns claude" \
    || fail "entrypoint never invokes claude"
  grep -q '\-\-check' "$ENTRYPOINT" \
    && ok "entrypoint supports --check" \
    || warn "entrypoint has no --check dry-run flag (ok for host-machine execution)"
  grep -qE 'MISSING ENV|required env|env var' "$ENTRYPOINT" \
    && ok "entrypoint has env preflight" \
    || warn "entrypoint has no env-var preflight (ok for host-machine execution)"
fi

# ── 5. Makefile targets ──────────────────────────────────────────────────────
if [ -f "$P/Makefile" ]; then
  for target in setup build test; do
    if grep -qE "^$target[[:space:]]*:" "$P/Makefile"; then
      ok "Makefile target: $target"
    else
      fail "Makefile missing target: $target"
    fi
  done
fi

# ── 6. .claude/settings.json ─────────────────────────────────────────────────
if [ -f "$P/.claude/settings.json" ]; then
  if command -v python3 > /dev/null 2>&1; then
    if python3 -c "
import json, sys
d = json.load(open('$P/.claude/settings.json'))
allow = d.get('permissions', {}).get('allow', [])
sys.exit(0 if isinstance(allow, list) and allow else 1)
" 2>/dev/null; then
      ok ".claude/settings.json is valid JSON with a non-empty permissions.allow"
    else
      fail ".claude/settings.json is invalid JSON or has no permissions.allow entries"
    fi
  else
    warn "python3 not available — skipped settings.json JSON validation"
  fi
fi

# ── 7. Secrets hygiene ───────────────────────────────────────────────────────
if [ -f "$P/.gitignore" ]; then
  grep -qE '^\.env$' "$P/.gitignore" \
    && ok ".gitignore excludes .env" \
    || fail ".gitignore does not exclude .env"
  grep -q '_exit' "$P/.gitignore" \
    && ok ".gitignore excludes the exit sentinel" \
    || fail ".gitignore does not exclude the .*_exit sentinel"
fi

if git -C "$P" rev-parse --git-dir > /dev/null 2>&1; then
  if [ -n "$(git -C "$P" ls-files '.env' '*.env' 2>/dev/null)" ]; then
    fail ".env file is tracked by git — secrets may be committed"
  else
    ok "no .env tracked by git"
  fi
else
  warn "not a git repository — skipped tracked-secrets check (scaffold should be git init'd)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "Scaffold check complete: $ERRORS failure(s), $WARNINGS warning(s)."
[ "$ERRORS" -eq 0 ] || exit 1
exit 0
