#!/usr/bin/env bash
# Feed Digester — factory entrypoint. Runs the Editor supervisor one cycle per session inside
# a crash-tolerant loop. Auth is OAuth (Claude Max) via a volume-mounted ~/.claude — do NOT set
# ANTHROPIC_API_KEY (it would override OAuth and bill separately).
set -e

# ── Config knobs ──────────────────────────────────────────────────────────────
REQUIRED_ENV_VARS="IMAP_HOST IMAP_USER IMAP_PASSWORD TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID GITHUB_TOKEN"
REQUIRED_TOOLS="git gh claude python3 make"
SUPERVISOR_MODEL="sonnet"
SUPERVISOR_EFFORT="high"
PROJECT="feed-digester"
CYCLE_TIMEOUT="${CYCLE_TIMEOUT:-1800}"    # hard cap on one supervisor cycle (s) — hang protection
MAX_CRASHES="${MAX_CRASHES:-5}"           # consecutive crashes before a single alert + long backoff
LOG_DIR="logs"

# Sub-agent model is mixed / complexity-gated (Engineer uses Opus-for-complex), so
# CLAUDE_CODE_SUBAGENT_MODEL is deliberately NOT set — the Editor chooses per spawn.

# OAuth: Claude Code also looks for .claude.json at the home root.
ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json" 2>/dev/null || true

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# ── Preflight: collect every miss, don't stop at the first ────────────────────
echo "Checking environment..."
FAIL=0
for var in $REQUIRED_ENV_VARS; do
  if [ -z "${!var:-}" ]; then
    echo "MISSING ENV:  $var — check your --env-file" >&2
    FAIL=1
  fi
done
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "WARNING: ANTHROPIC_API_KEY is set — it overrides OAuth and bills separately. Unset it." >&2
fi
for cmd in $REQUIRED_TOOLS; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "MISSING TOOL: $cmd — check the Docker image" >&2
    FAIL=1
  fi
done
if ! gh auth status > /dev/null 2>&1; then
  echo "AUTH FAIL:    GitHub — check GITHUB_TOKEN" >&2
  FAIL=1
fi
if [ "$FAIL" = "1" ]; then
  echo "Preflight FAILED — fix the items above and re-run." >&2
  exit 1
fi
echo "Preflight OK."

# ── Spawn test: confirm Claude Code launches and authenticates ────────────────
echo "Testing Claude Code spawn..."
SPAWN_OUT="$(claude --model "$SUPERVISOR_MODEL" --dangerously-skip-permissions \
  -p 'Reply with exactly this token and nothing else: FACTORY_CHECK_OK' 2>&1)" || true
if echo "$SPAWN_OUT" | grep -q "FACTORY_CHECK_OK"; then
  echo "Claude Code spawn test: PASS"
else
  echo "Claude Code spawn test: FAIL — Claude Code did not launch/authenticate." >&2
  echo "$SPAWN_OUT" >&2
  exit 1
fi

# ── --check: deep self-test against the real docs, then exit (no loop) ─────────
if [ "$CHECK_ONLY" = "1" ]; then
  echo "Running deep self-test (docs + comm channel)..."
  CHECK_DIR="$(mktemp -d)"
  if ! git clone --depth 1 "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO_URL}.git" \
       "$CHECK_DIR/$PROJECT" > /dev/null 2>&1; then
    echo "Repo clone FAILED — check GITHUB_REPO_URL and token." >&2
    rm -rf "$CHECK_DIR"; exit 1
  fi
  ( cd "$CHECK_DIR/$PROJECT" \
    && claude --model "$SUPERVISOR_MODEL" --dangerously-skip-permissions \
         -p "$(cat scripts/editor_check_prompt.md)" )
  rm -rf "$CHECK_DIR"
  echo "--check complete — review PASS/FAIL above. No persistent clone, no loop."
  exit 0
fi

# ── First boot: clone repo ─────────────────────────────────────────────────────
if [ ! -f "$PROJECT/CLAUDE.md" ]; then
  echo "Repo not found — cloning..."
  git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO_URL}.git" "$PROJECT"
  make -C "$PROJECT" setup
fi

cd "$PROJECT"
mkdir -p "$LOG_DIR"

git config --global user.name "Feed Digester Factory"
git config --global user.email "factory@feed-digester.local"

# Announce boot exactly once — never fatal.
scripts/telegram_notify.sh "Feed Digester factory online" || true

# ── Supervisor loop: one disposable cycle per iteration ───────────────────────
CRASHES=0
CRASH_ALERTED=0
while true; do
  rm -f .editor_exit
  TS="$(date +%Y%m%d-%H%M%S)"
  CYCLE_LOG="$LOG_DIR/cycle-$TS.log"
  CODE=0

  # timeout is hang protection: a wedged session can never stall the factory forever.
  timeout "$CYCLE_TIMEOUT" \
    claude --model "$SUPERVISOR_MODEL" --effort "$SUPERVISOR_EFFORT" \
      --dangerously-skip-permissions -p \
      "$(cat scripts/editor_prompt.md)

Current factory state (STATUS.md):
$(cat STATUS.md)" > >(tee "$CYCLE_LOG") 2>&1 || CODE=$?

  # The Editor's last action is one word in .editor_exit. Absent = crash. 124 = timeout.
  REASON="crash"
  if [ "$CODE" = "124" ]; then
    REASON="timeout"
  elif [ -f .editor_exit ]; then
    REASON="$(tr -d '[:space:]' < .editor_exit)"
    rm -f .editor_exit
  fi

  case "$REASON" in
    done)
      echo "Editor reported v1 complete at $(date). Factory stopping."
      scripts/telegram_notify.sh "Feed Digester v1 complete — factory stopped." || true
      exit 0
      ;;
    completed)
      WAIT=90;  CRASHES=0; CRASH_ALERTED=0 ;;
    idle)
      WAIT=900; CRASHES=0; CRASH_ALERTED=0 ;;
    timeout)
      WAIT=300; CRASHES=$((CRASHES + 1)) ;;
    *)  # crash / missing sentinel
      WAIT=300; CRASHES=$((CRASHES + 1)) ;;
  esac

  # Crash-loop protection: after MAX_CRASHES in a row, alert the user ONCE and back off hard.
  # This is what surfaces an expired OAuth token instead of failing silently forever.
  if [ "$CRASHES" -ge "$MAX_CRASHES" ]; then
    if [ "$CRASH_ALERTED" = "0" ]; then
      scripts/telegram_notify.sh \
        "Feed Digester: $CRASHES consecutive failed cycles (last reason=$REASON). Likely expired OAuth or a wedged environment — check the host. Backing off to 1h." || true
      CRASH_ALERTED=1
    fi
    WAIT=3600
  fi

  echo "Editor exited (reason=$REASON, code=$CODE, crashes=$CRASHES) at $(date) — log: $CYCLE_LOG — next in ${WAIT}s..."
  sleep "$WAIT"
done
