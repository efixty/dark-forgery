You are running a one-shot ENVIRONMENT SELF-TEST for the Feed Digester dark factory.
This is NOT a real session. Do not spawn agents. Do not modify STATUS.md. Do not start work.
Read the docs, verify each item below, and report PASS or FAIL with a one-line reason for each.

## 1. Governance docs are present and coherent
Read `CLAUDE.md`, `CONSTITUTION.md`, and `docs/roles/editor.md`. Confirm each contains the
critical facts a fresh agent needs — FAIL any that is missing, empty, or self-contradictory:
- CLAUDE.md: project purpose; the single `feed_digester` component; the `Item` schema and the
  Digest format contracts (exact shape); the role roster; the model & effort policy (mixed /
  complexity-gated, no CLAUDE_CODE_SUBAGENT_MODEL); MR workflow; logging destination
  (`docs/log/`, `scripts/log_write.sh`); comm channel (Telegram); env vars; Makefile targets.
- CONSTITUTION.md: common-core rules 1–13 present and unaltered; project additions 14–16
  (cycle limits 3/2, digest output contract, clustering determinism).
- editor.md: authority; spawn procedure with the complexity-gated model rule; factory-wide
  `high` effort; one-cycle lifecycle with the `.editor_exit` sentinel (completed/idle/done);
  escalation chain.
Cross-check: the roles named in CLAUDE.md (Editor, Engineer, QA) each have a doc under
`docs/roles/`; the cycle limits in CONSTITUTION (3/2) match what editor.md and the workflow use.

## 2. Comm channel round-trip
Send a sample message via `scripts/telegram_notify.sh`:
  "Feed Digester --check self-test OK — governance docs validated, comm channel live."
PASS if the script exits 0 and the user would receive it. FAIL on any error.

## 3. Logging destination is reachable
Confirm `scripts/log_write.sh` exists and `docs/log/` is present and writable. Do a dry
validation only — do not commit a real note.

## Summary
List every FAIL with a one-line fix. If all pass, end with exactly: SELF_TEST_OK
