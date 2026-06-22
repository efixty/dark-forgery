# Dark Forgery

**Dark Forgery** bootstraps a complete dark factory project from a raw idea.
A dark factory is an autonomous multi-agent Claude Code system where specialized agents
(Engineer, QA, Designer, and a supervisor) work independently under a CLAUDE.md+CONSTITUTION.md
governance layer, with no human in the loop except for escalations.

Invocation: `/dark-forgery <one-line idea>`

---

## How you run this command

Work phase by phase. After each phase, show a brief summary of what you learned/decided,
then move to the next. If the user says "auto", "go ahead", "just do it", or similar at
any point — infer that they want you to complete all remaining phases without waiting for
approval between them.

**Never create files during the discovery phases (0–8).** Only generate files after all
phases are confirmed. Then generate everything in one pass.

The argument `$ARGUMENTS` is the user's one-line idea. Use it as Phase 0 intake.

---

## Phase 0 — Intake

Read the one-line idea from `$ARGUMENTS`. Restate it back in one sentence to confirm you
understood it. Note any obvious ambiguities you'll clarify in the phases ahead.

If no argument was provided, ask: "What's the idea? Give me one line."

---

## Group 1 — What are we building?

*Phases 1–3 establish the full technical picture of the project before touching org structure
or operations. Knowing the stack and execution environment early means every subsequent
question is framed correctly.*

### Phase 1 — Scope

Ask until you have unambiguous answers to all four:

1. **What does it do?** — user-facing description, one paragraph max
2. **What is NOT in scope for v1?** — explicit exclusions prevent scope creep
3. **What does "done" look like?** — the moment when v1 ships and agents stop
4. **Who uses it and what's their goal?** — end user + job-to-be-done

If the idea is clear enough that you can infer answers, state your inferences and ask
the user to correct rather than making them answer from scratch.

### Phase 2 — Stack

Based on the project's nature, propose a stack with a rationale for each choice:

| Project type | Suggested language |
|---|---|
| CPU-bound processing, audio/video, ML inference | Rust |
| API orchestration, subprocess management, I/O-heavy | Go |
| Data pipelines, ML training, scripting | Python |
| Web frontend, SPA, interactive UI | TypeScript + Svelte 5 or React |
| CLI tools | Go or Rust |
| Mobile | React Native or Swift/Kotlin |

Ask about constraints: language preferences, team familiarity, deployment target.
Confirm the final stack before moving on. Document the "why" — agents need this context.

### Phase 3 — Execution environment

Ask: "Where does this run?"

- **Host machine** — `source .env` pattern is fine; simpler entrypoint; no headful flow concerns
- **Docker container** — env vars via `docker run --env-file`; flag any headful flows (browser auth, GUIs); generate entrypoint with preflight checks; document `--restart unless-stopped`
- **Remote server** — same as Docker but note SSH/deploy workflow

This decision shapes everything downstream: comms setup, credential handling, the entrypoint
script, and whether headless compatibility is a concern. Confirm before proceeding.

For Docker/remote, the entrypoint must:
1. Check all required env vars — collect and report every miss, then exit non-zero if any
2. Check all required tools in PATH — collect and report every miss
3. Verify external auth (e.g. `gh auth status`) at startup
4. Clone the repo on first boot if not present
5. Clone the vault repo on first boot if vault logging is used
6. Export `VAULT_PATH` before `cd {project}` (if vault is used)
7. Loop forever: run supervisor → sleep on exit → restart
8. Support a **`--check` dry-run flag**: run the full preflight (steps 1–3), a one-shot
   Claude Code spawn test, then a **deep self-test** — clone the repo to a throwaway temp dir
   and spawn the supervisor on a dedicated *check prompt* that (a) reads CLAUDE.md,
   CONSTITUTION.md, and the supervisor role doc and confirms the critical facts are present
   and coherent, and (b) sends a sample message through the comm channel if one is configured.
   Report all findings, tear down the temp clone, and exit — no persistent clone, no `make
   setup`, no poller, no loop. This is how the operator validates the environment before a
   real run: same preflight as the live boot, plus proof the governance docs and comm channel
   actually work, run once.

---

## Group 2 — Who's working on it?

*Phases 4–5 define the agent org chart and the physical project layout. Stack and execution
context are already known, so these decisions are fully informed.*

### Phase 4 — Roles

Based on the scope and stack, propose a role set. The only mandatory role is:
- **Supervisor** (name it based on project — CEO, PM, Lead, Orchestrator — but the role is always the same: spawns agents, manages STATUS.md, reports to the user)

Suggest the following only if the project actually needs them:
- **Engineer** — if there is implementation work (code, config, infra)
- **QA** — if correctness verification against a spec is valuable (most projects benefit; some pure research or automation projects don't need it)
- **Designer** — if there's a user-facing frontend requiring UX decisions
- **Researcher** — if the project requires ongoing data/market/technical research
- **Data Engineer** — if the project has significant data pipeline work
- **DevOps** — if the project has complex infrastructure beyond a single container

For each role, briefly state: what they do, when they're spawned, what they output.
Confirm the role list with the user before proceeding.

Then, for each role that **reviews or approves work** (e.g. Reviewer Engineer, QA, Designer),
ask: **"How many back-and-forth cycles before the supervisor pauses that PR and notifies you?"**

Suggest sensible defaults based on the role:
- Code review (Reviewer Engineer): 3 cycles
- Testing/QA: 2 cycles
- Design review: 1 cycle

The user may override any of these. If a review role doesn't exist (e.g. no QA), skip that question.
These limits are project-specific — record them in the CONSTITUTION project-specific additions section,
not in the common core. The common core defines the mechanism; the project defines the numbers.

Then ask: **"Should agents work sequentially or in parallel?"**

- **Sequential** (default, simpler) — supervisor spawns one agent at a time; waits for it to finish before spawning the next; no branch conflicts; easier crash recovery
- **Parallel** — supervisor spawns multiple agents simultaneously on independent tasks; faster throughput; **requires git worktrees** so each agent has an isolated checkout and they don't clobber each other's working tree

If parallel is chosen:
- The supervisor must create a worktree per agent before spawning: `git worktree add ../{project}-{branch} {branch}`
- Each agent runs inside its own worktree directory, not the main checkout
- `.claude/settings.json` must include `"Bash(git worktree *)"` in the allow list
- Document the worktree lifecycle in CLAUDE.md: create on spawn, remove after merge (`git worktree remove`)

Then ask: **"Which model should each role run on?"**

Present per-role suggestions as a starting point — the user overrides any of them:

| Role | Suggested model | Notes |
|---|---|---|
| Supervisor | Sonnet | Always Sonnet — coordination and judgment, not deep implementation |
| Engineer | Sonnet, **Opus for complex tasks** | Supervisor escalates to Opus only when it judges the task complex |
| Reviewer Engineer | Sonnet, **Opus for complex tasks** | Same complexity-gated escalation as Engineer |
| QA | Sonnet | |
| Designer | Sonnet | |

Three rules always hold regardless of the user's per-role choices:

1. **Effort is always high** for every role, every spawn. This is non-negotiable and is not a per-role choice.
2. **Opus is reserved for complexity.** When a role's policy is "Opus for complex tasks," the supervisor must *infer* task complexity and state *explicitly in the task brief* whether this spawn is Opus or Sonnet, with a one-line reason. No silent upgrades — every Opus spawn is a stated decision.
3. **Model availability is bounded by the Phase 9 auth tier.** If OAuth on a tier without Opus access is chosen, the Opus-for-complex-tasks policy cannot apply — fall back to Sonnet for those roles and note it in the role doc.

Record the final per-role model policy. During generation it is encoded in two places:
- the **supervisor's own model** → `--model {supervisor-model}` flag in the entrypoint
- **every other role's model** → the `model` parameter the supervisor passes to the Agent tool at spawn time, per the policy and the complexity rule above

### Phase 5 — Project structure

Present the directory tree you'll generate, adapted to the confirmed stack.

Base template:
```
{project-name}/
  CLAUDE.md                  ← project context for agents (CRITICAL)
  CONSTITUTION.md            ← rules all agents follow (CRITICAL)
  STATUS.md                  ← supervisor's task board
  Makefile                   ← build shortcuts
  .gitignore
  .env.example               ← env var placeholders (never commit .env)
  .claude/
    settings.json            ← allowed Bash permissions
  docs/
    roles/                   ← one .md per confirmed role
    features/                ← one .md per feature spec
    issues/                  ← one .md per bug
    design/                  ← UX flows (if frontend exists)
    qa/
      reports/               ← QA PR audit trail
      {test-assets}/         ← test data (tracks/, datasets/, fixtures/, etc.)
  scripts/
    {supervisor}_entrypoint.sh
    {comm_channel}_notify.sh
    vault_write.sh           ← if logging uses Obsidian/file-based vault
```

Show the actual tree with project-specific names filled in. Note any additions or
removals from the base template and why.

---

## Group 3 — How does it operate?

*Phases 6–8 cover the operational layer: how the supervisor talks to you, what secrets the
project needs, and where work is tracked. Execution environment is already confirmed, so
all three questions can be answered with full context.*

### Phase 6 — Communication channel

Ask: "How do you want the supervisor to reach you with updates?"

Present the options:
- **Telegram** (recommended) — async, mobile-first, works headless; needs bot token + chat ID
- **Slack** — needs workspace + bot token + channel ID; webhook or Web API
- **Discord** — needs bot token + channel ID; simple webhook or bot
- **Email** — needs SMTP creds; least real-time
- **None / manual** — user checks STATUS.md themselves; no async channel

For the chosen option, explain what credentials are needed and how to obtain them.
Document the notify script name (e.g. `scripts/telegram_notify.sh`).

### Phase 7 — Credentials & environment

Based on the stack, execution environment, and comm channel confirmed above, list every
credential and env var the project needs. You'll generate three files:

- `docs/credentials.md` — human-readable table: name | purpose | where to get it
- `docs/environment.md` — all runtime env vars: name | source | description
- `.env.example` — shell file with placeholders (`VAR=your-value-here`)

Values are NEVER filled in — the user fills them in their private `.env` after setup.

### Phase 8 — Logging & task tracking

Ask: "Where should issues and feature progress be logged?"

Options and what each means:
- **Obsidian vault (git-backed)** — agents write markdown notes to a git repo; Obsidian Git plugin pulls to your Mac; you read notes in Obsidian
- **GitHub Issues** — agents open/close issues via `gh`; visible on the repo
- **Linear** — agents create/update issues via API; good for teams
- **Plain markdown (git-tracked)** — notes committed to the repo itself; simple, no external service
- **None** — STATUS.md is the only tracking surface

For Obsidian vault: ask whether they want it git-backed (separate repo, auto-push after each write). If yes, document the `VAULT_PATH` export strategy (captured as `$(pwd)/vault` before `cd {project}` so it resolves to WORKDIR).

Generate the appropriate write script and document the note format.

### Phase 9 — Claude Code authentication & billing

Ask: "How will the factory's Claude Code process authenticate?"

Present the two options:

**Option A — API key**
Set `ANTHROPIC_API_KEY` in the env-file. Claude Code uses it for every call. Billing is pay-as-you-go via console.anthropic.com. Simple to set up; costs accumulate per token.

- Add `ANTHROPIC_API_KEY` to `docs/credentials.md` and `.env.example`
- Add it to the entrypoint preflight env var check
- Recommend the user set a spend alert in the Anthropic console

**Option B — OAuth session (Claude Max / Pro)**
Claude Code authenticates via a stored session rather than an API key. Usage is billed against the subscription. No API key needed. Works headlessly via a volume-mounted config directory.

Setup on the host before the first `docker run`:
```bash
# Create a dedicated config dir without touching ~/.claude
CLAUDE_CONFIG_DIR=~/.claude-{project} claude
# Run /login inside the session
```

Then mount it into the container:
```bash
--volume ~/.claude-{project}:/home/{container-user}/.claude
```

The entrypoint must symlink `.claude.json` to the home root (Claude Code looks there too):
```bash
ln -sf "${HOME}/.claude/.claude.json" "${HOME}/.claude.json" 2>/dev/null || true
```

**Do NOT set `ANTHROPIC_API_KEY`** — if present, it overrides OAuth and bills separately.

**Ownership warning**: the mounted directory is owned by the host user's UID. If the container runs as a different user, permission errors will prevent Claude Code from writing session state.

Two solutions:
- Add `--user $(id -u):$(id -g) -e HOME=/home/{container-user}` to `docker run` — container process runs as the host UID, owns the mount natively (recommended)
- Or: `find ~/.claude-{project} -type d -exec chmod 777 {} \; && find ~/.claude-{project} -type f -exec chmod 644 {} \;` on the host (simpler, acceptable on a private server)

**Re-authentication**: OAuth tokens expire. When the factory reports "Not logged in":
```bash
CLAUDE_CONFIG_DIR=~/.claude-{project} claude
# Run /login
```
Refreshed credentials are picked up on next container start via the volume mount.

Document the chosen approach in `docs/environment.md` and `docs/credentials.md`.

---

## Before you generate — synthesis is the job

Before writing a single file, re-read everything the user said across all phases.
Every answer, every preference they expressed, every idea you worked out together —
all of it goes into the generated files. This is not template-filling. This is synthesis.

The structure described below is a strong default, not a cage. Adapt it when the project
genuinely needs it: rename directories, skip sections that don't apply, add sections
that do, reorder the role workflow, choose a different Makefile target name — whatever
makes this factory correct for *this* project. The one thing that is rigid: CLAUDE.md
and CONSTITUTION.md must be complete and accurate no matter what else changes.

Ask yourself before committing each file: "Could a fresh agent read this and act without
asking any questions?" If the answer is no, rewrite it until it is.

---

## Generation pass

After all phases are confirmed, generate everything in one pass. Work in this order:

### 1. Git init and directory structure
```bash
mkdir {project-name}
cd {project-name}
git init
# create all dirs with .gitkeep
```

### 2. `.gitignore`
Always include:
```
.env
*.env
node_modules/
target/
dist/
__pycache__/
*.pyc
.DS_Store
```
Add build artifacts for the confirmed stack.

### 3. `CONSTITUTION.md` — CRITICAL, write this carefully

The CONSTITUTION has a **locked common core** (rules 1–13, identical across ALL dark factories)
followed by project-specific additions. The common core is:

```markdown
# {Project Name} Agent Constitution

Agents operating in this repository follow these rules unconditionally.

## 1. Role discipline
You are spawned with a role. Work only within that role. Do not perform work that belongs
to another role unless the supervisor explicitly delegates it in the task brief.

## 2. Read before acting
Before touching any file, read: (1) your role doc in `docs/roles/`, (2) `CLAUDE.md`,
(3) `CONSTITUTION.md`. A task brief from the supervisor does not replace this reading step.

## 3. Output contracts are inviolable
Every interface defined in `CLAUDE.md` (API contracts, CLI output schemas, data formats) is
a hard contract. No agent may change an interface without the supervisor writing a versioned
update to `CLAUDE.md` first. Breaking a contract is not an implementation detail — it is
a blocking defect.

## 4. Every commit must pass its component's build
Run the build command for your component before committing. No broken builds in main.
If the build cannot pass due to a dependency on another component's unreleased work,
write a `BLOCKED:` entry to STATUS.md and stop.

## 5. Tests are part of the task
A task is not done until there is a test covering the new behavior. The test lives in the
same PR as the behavior. Untested PRs fail Engineer review.

## 6. Spec docs are mandatory for every PR
- New feature → create `docs/features/{slug}.md` in the same PR
- Bug fix → create or update `docs/issues/{id}.md` in the same PR
Spec format: Current state → What we need → Why. No file paths, no implementation detail.
QA uses this as their test brief. A PR with no spec doc fails review.

## 7. Fail loudly, fail fast
If a task cannot be completed (missing dependency, broken contract, ambiguous spec),
write a structured entry to STATUS.md immediately. Do not partially implement.
Format: `BLOCKED: [{Role}] {task} — {reason} — needs: {what unblocks this}`

## 8. No speculative work
Implement exactly what the task requires. No features, abstractions, or refactors
beyond scope. Three similar lines is better than a premature abstraction.

## 9. Security — never commit secrets
Never write credentials, tokens, API keys, or passwords to any committed file.
Secrets live in `.env` (gitignored) and are passed to processes via environment variables.
If you discover a secret in the codebase, flag it to the supervisor immediately.

## 10. Commit message format
`[{role}] {short description} — {what changed and why}`
Examples:
  `[engineer] add upload handler — accepts multipart/form-data, streams to temp dir`
  `[qa] approve PR #7 — all API tests pass, no regressions found`

## 11. PR workflow — no direct commits to main
Every change goes through a PR:
  Engineer implements → opens PR
  → Supervisor spawns Reviewer Engineer → up to 3 review cycles
  → After each "changes requested" review: the acting agent addresses, pushes/updates,
    then increments that role's cycle counter in the STATUS.md PR entry
  → When any cycle counter hits its project-defined limit with no approval: agent sets
    Status to needs-human, writes a plain-English Reason → Supervisor sends Reason to
    user via comm channel → work on that PR stops immediately
  → On receiving user resolution: Supervisor resets cycle counts, sets Status back to
    in-review, clears Reason, resumes from the appropriate step
Bypass requires explicit supervisor instruction.

Cycle limits are **not defined here** — they are project-specific and live in the
CONSTITUTION project additions section (set during Phase 4 of Dark Forgery).

## 12. STATUS.md is the supervisor's domain
Only the supervisor writes to STATUS.md — with one exception: agents update their own
cycle count and Status on their active PR entry after each review response.

Every Active PR entry must follow this format:
```
### PR #N — title
- Branch: `feature/branch-name`
- Spec: `docs/features/slug.md` or `docs/issues/id.md`
- Status: open | in-review | merged | needs-human
- Phase: {role-that-acts-now}
- {Role} cycles: N / {limit}   (one line per review role; omit roles not in this project)
- Reason: ...                   (needs-human only — sent verbatim to user via comm channel)
```
`Status` = big-picture state of the PR.
`Phase` = who must act right now; supervisor reads this on every startup to re-spawn.
`Reason` = plain-English explanation; sent verbatim to the user when needs-human is set.
Cycle limits come from the project-specific CONSTITUTION additions, not the common core.
This makes conflict detection crash-tolerant: both signals survive process restarts.

## 13. Vault/log notes are mandatory for every feature and issue
Every PR introducing a new feature must include a note written to the configured logging
destination. Every bug fix and every regression found must produce a note. On merge, the
Engineer updates the note status. See `CLAUDE.md` "Logging" section for format and script.
```

After the common core, append **project-specific rules** for anything unique to this
project's constraints (domain-specific contracts, unusual tooling, special security
requirements). If nothing is unique, append a single rule:

```markdown
## 14. No project-specific additions
No additional rules have been added for this project. The common core governs all behavior.
```

### 4. `CLAUDE.md` — CRITICAL, write this carefully

This is the agent's project bible. A fresh agent reading CLAUDE.md must be able to act
without asking any questions. Include:

- **What the project does** — one paragraph, user-facing
- **Components** — table: name | language | purpose
- **How to run** — step-by-step per component, then full-stack
- **Interface contracts** — every API endpoint, CLI flag, stdout schema, data format
- **Org structure** — role table linking to `docs/roles/`, report chain diagram
- **MR workflow** — the exact sequence from implement to merge
- **Logging** — where notes go, which script to use, what format
- **Communication** — which channel, which script, message format
- **Environment** — which env vars the project uses and where they come from
- **Build shortcuts** — Makefile targets

Write this as prose + tables + code blocks. No placeholder text. If a value isn't known
yet (e.g. the GitHub repo URL), use a clear placeholder like `{GITHUB_REPO_URL}` so
agents know to look it up.

### 5. `docs/roles/{role}.md` — one per confirmed role

Each role doc must include:
- **Identity** — who they are, when they're spawned, what context they receive
- **What this role is (and isn't)** — explicit scope boundaries
- **Workflow** — numbered steps, every step
- **Output format** — exactly what they produce (PR, comment, committed file, etc.)
- **Stack reference** — how to build/run their component (if Engineer)
- **Escalation** — when and how to escalate to the supervisor

Role docs are the agent's operating manual. They must be complete enough that a fresh
agent can work without any prior context beyond what's injected in the task brief.

**The supervisor's role doc must additionally encode the Phase 4 model policy** in its
"Spawning agents" section:
- The exact `model` to pass to the Agent tool for each role.
- The complexity rule verbatim for any role with an Opus-for-complex-tasks policy: the
  supervisor infers complexity, picks Opus or Sonnet, and states the choice plus a one-line
  reason in the task brief. No silent upgrades.
- A reminder that all spawns run at high effort.

### 6. `STATUS.md` — initial board

Pre-populate from Phase 1 discovery:

```markdown
# {Project Name} — Status

## Active
*(none — factory not yet started)*

## Backlog
- [ ] {first feature or component from Phase 1 scope}
- [ ] {second feature}
...

## Completed
*(none)*

## Blocked
*(none)*

## Active PRs
*(none)*
```

### 7. `Makefile`
Build/test/setup targets for the confirmed stack. Always include `setup`, `build`, `test`.

### 8. `.claude/settings.json`
Bash permissions for the scripts and tools used in this project:
```json
{
  "permissions": {
    "allow": [
      "Bash(make *)",
      "Bash(git *)",
      "Bash(gh *)",
      "Bash(scripts/{supervisor}_entrypoint.sh *)",
      "Bash(scripts/{notify_script}.sh *)",
      "Bash(scripts/vault_write.sh *)",
      "Bash(mkdir -p *)",
      ...stack-specific entries...
    ]
  }
}
```

If **parallel** agent spawning was chosen in Phase 4, add `"Bash(git worktree *)"` to the allow list. `git *` does not cover `git worktree` subcommands in Claude Code's permission model — it must be listed explicitly.

### 9. `scripts/{supervisor}_entrypoint.sh`

For Docker/remote execution:
```bash
#!/usr/bin/env bash
set -e

# --check runs preflight + spawn test + a deep self-test (docs + comm channel),
# then exits without cloning persistently, without the poller, and without the loop.
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# ── Preflight: collect every miss, don't stop at the first ────────────────────
echo "Checking environment..."
FAIL=0
for var in {LIST_OF_REQUIRED_ENV_VARS}; do
  if [ -z "${!var:-}" ]; then
    echo "MISSING ENV:  $var — check your --env-file" >&2
    FAIL=1
  fi
done

for cmd in {LIST_OF_REQUIRED_TOOLS}; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "MISSING TOOL: $cmd — check the Docker image" >&2
    FAIL=1
  fi
done

# Verify external auth
if ! gh auth status > /dev/null 2>&1; then
  echo "AUTH FAIL:    GitHub — check your token" >&2
  FAIL=1
fi

if [ "$FAIL" = "1" ]; then
  echo "Preflight FAILED — fix the items above and re-run." >&2
  exit 1
fi
echo "Preflight OK."

# ── Spawn test: confirm Claude Code launches and authenticates (both modes) ───
echo "Testing Claude Code spawn..."
SPAWN_OUT="$(claude --model {supervisor-model} --dangerously-skip-permissions \
  -p 'Reply with exactly this token and nothing else: FACTORY_CHECK_OK' 2>&1)" || true
if echo "$SPAWN_OUT" | grep -q "FACTORY_CHECK_OK"; then
  echo "Claude Code spawn test: PASS"
else
  echo "Claude Code spawn test: FAIL — Claude Code did not launch/authenticate." >&2
  echo "$SPAWN_OUT" >&2
  exit 1
fi

# ── --check: deep self-test against the real docs, then exit (no loop) ─────────
# Clones to a throwaway dir so nothing persists. Spawns the supervisor on the check
# prompt: it validates the governance docs and pings the comm channel, then we tear down.
if [ "$CHECK_ONLY" = "1" ]; then
  echo "Running deep self-test (docs + comm channel)..."
  CHECK_DIR="$(mktemp -d)"
  if ! git clone --depth 1 "https://${GITHUB_TOKEN}@github.com/{GITHUB_REPO_URL}.git" \
       "$CHECK_DIR/{project-name}" > /dev/null 2>&1; then
    echo "Repo clone FAILED — check the repo URL and token." >&2
    rm -rf "$CHECK_DIR"; exit 1
  fi
  ( cd "$CHECK_DIR/{project-name}" \
    && claude --model {supervisor-model} --dangerously-skip-permissions \
         -p "$(cat scripts/{supervisor}_check_prompt.md)" )
  rm -rf "$CHECK_DIR"
  echo "--check complete — review PASS/FAIL above. No persistent clone, no poller, no loop."
  exit 0
fi

# First boot: clone repo
if [ ! -f "{project-name}/CLAUDE.md" ]; then
  echo "Repo not found — cloning..."
  git clone "https://${GITHUB_TOKEN}@github.com/{GITHUB_REPO_URL}.git" {project-name}
  make -C {project-name} setup
fi

# First boot: clone vault (if vault logging is configured)
if [ ! -f "vault/{first-vault-file}" ]; then
  echo "Vault not found — cloning..."
  git clone "https://${GITHUB_TOKEN}@github.com/{VAULT_REPO_URL}.git" vault
fi
export VAULT_PATH="$(pwd)/vault"

cd {project-name}

git config --global user.name "{user-name}"
git config --global user.email "{user-email}"

while true; do
  claude --model {supervisor-model} --dangerously-skip-permissions -p \
    "$(cat scripts/{supervisor}_prompt.md)

Current factory state (STATUS.md):
$(cat STATUS.md)"

  echo "{Supervisor} exited (code $?) at $(date) — restarting in 5 minutes..."
  sleep 300
done
```

`{supervisor-model}` is the model confirmed in Phase 4 (suggested default: `sonnet`). The
supervisor always runs at high effort.

For host machine execution, a simpler version without preflight and Docker patterns.

### 10. `scripts/{supervisor}_prompt.md`

The startup prompt injected every time the supervisor starts (fresh or after crash):

```markdown
You are the {Supervisor} of the {project} project running inside a dark factory.

Read in this order before doing anything else:
1. `docs/roles/{supervisor}.md` — your role, authority, and workflows
2. `CLAUDE.md` — project context and interface contracts
3. `CONSTITUTION.md` — rules all agents follow unconditionally

The current factory state (STATUS.md) has been injected above.
Use it to determine what was happening before this session started.

Startup procedure:
- If active agents or in-progress PRs are listed in STATUS.md: re-spawn the relevant
  agents with the same task brief to continue where they left off.
- If no active work: send a {comm_channel} message to {user} that you are online
  and awaiting instructions.

You are running autonomously. Do not wait for confirmation before reading docs.
```

### 10b. `scripts/{supervisor}_check_prompt.md`

The prompt injected by the entrypoint's `--check` deep self-test. Unlike the real startup
prompt, it **never spawns agents, never touches STATUS.md, and never starts real work** — it
reads the governance docs, confirms they are complete and coherent, exercises the comm
channel, and reports. Tailor the checklist to the project's actual contracts and roles.

```markdown
You are running a one-shot ENVIRONMENT SELF-TEST for the {project} dark factory.
This is NOT a real session. Do not spawn agents. Do not modify STATUS.md. Do not start work.
Read the docs, verify each item below, and report PASS or FAIL with a one-line reason for each.

## 1. Governance docs are present and coherent
Read `CLAUDE.md`, `CONSTITUTION.md`, and `docs/roles/{supervisor}.md`. Confirm each contains
the critical facts a fresh agent needs — FAIL any that is missing, empty, or self-contradictory:
- CLAUDE.md: project purpose, component table, every interface contract (API/CLI/data schemas),
  role roster, MR workflow, logging destination, comm channel, env vars, build shortcuts
- CONSTITUTION.md: the common-core rules and the project-specific cycle limits
- {supervisor}.md: authority, spawn procedure, per-role model policy, escalation chain
Cross-check: the roles named in CLAUDE.md exist as docs under `docs/roles/`; the cycle limits
in CONSTITUTION.md match what {supervisor}.md enforces.

## 2. Comm channel round-trip   (only if a channel is configured)
Send a sample message via `scripts/{notify_script}.sh`:
  "{Project} --check self-test OK — governance docs validated, comm channel live."
PASS if the script exits 0 and {user} would receive it. FAIL on any error.

## 3. Logging destination is reachable   (only if vault/log writes are configured)
Confirm the write script exists and `VAULT_PATH` (or the configured target) is set.
Do a dry validation only — do not commit a real note.

## Summary
List every FAIL with a one-line fix. If all pass, end with exactly: SELF_TEST_OK
```

Adapt section 1's checklist to the exact contracts this project defines — the goal is that
a green self-test means a fresh supervisor could boot and act without missing information.

### 11. `scripts/{notify_script}.sh`
The notification helper for the confirmed comm channel. Include usage comments,
required env var checks, and the actual API call.

### 12. `scripts/vault_write.sh` (if vault logging is configured)
```bash
#!/usr/bin/env bash
# Write a note to the vault and push it.
# VAULT_PATH is exported by the entrypoint before cd {project}.
set -euo pipefail

DEST="${VAULT_PATH}/${RELATIVE_PATH}"
mkdir -p "$(dirname "$DEST")"
printf '%s\n' "$NOTE_CONTENT" > "$DEST"
echo "Vault note written: $DEST"

if git -C "$VAULT_PATH" rev-parse --git-dir > /dev/null 2>&1; then
  git -C "$VAULT_PATH" add "$RELATIVE_PATH"
  git -C "$VAULT_PATH" commit -m "vault: ${RELATIVE_PATH}" --quiet || true
  git -C "$VAULT_PATH" push --quiet \
    || echo "WARNING: vault push failed — note written locally but not synced" >&2
fi
```

### 13. Credential and environment templates
- `docs/credentials.md` — table with all secrets: name | purpose | where to get it
- `docs/environment.md` — table with all env vars: name | source (credential/derived/fixed) | description
- `.env.example` — placeholder shell file

### 14. Directory placeholders
Create `.gitkeep` in every empty directory: `docs/features/`, `docs/issues/`,
`docs/design/` (if frontend), `docs/qa/reports/`, `docs/qa/{test-assets}/`.

### 15. Initial git commit
```bash
git add -A
git commit -m "forge: dark factory scaffold — {project description}"
```

---

## What Dark Forgery does NOT do

- **Does not create the GitHub remote** — left to the user (run `gh repo create` or create via GitHub UI, then `git remote add origin` + `git push -u origin main`)
- **Does not fill in credential values** — `.env` is written by the user with real secrets
- **Does not start the factory** — that's `docker run` or `bash scripts/{supervisor}_entrypoint.sh`
- **Does not build or test the code** — generates the scaffold; implementation is what the factory is FOR

After generation, tell the user exactly what to do next:
1. Create the GitHub remote and push
2. Fill in `.env` with real credentials (referencing `docs/credentials.md` for what's needed)
3. Validate the environment with the dry run: `scripts/{supervisor}_entrypoint.sh --check`
   (Docker: same image, override the entrypoint with the `--check` arg.) Fix anything it
   reports before the real start.
4. Start the factory with the appropriate command

---

## Quality bar for CLAUDE.md and CONSTITUTION.md

These two files are what make the factory work. Hold them to this standard:

**CLAUDE.md** — a fresh agent with no prior context reads this and can act. No "TBD". No
vague phrases like "configure appropriately". Every interface is documented with exact
field names, types, and examples. Every command is copy-pasteable.

**CONSTITUTION.md** — a fresh agent reads this and knows every constraint, escalation
path, and behavior expectation. The common core is never weakened. Project-specific rules
add constraints; they never remove or soften common core rules.

If you find yourself writing a placeholder in either of these files, go back and fill it in.
Time spent on CLAUDE.md and CONSTITUTION.md is the highest-leverage investment in the factory.
