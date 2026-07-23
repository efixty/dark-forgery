# Dark Forgery

A Claude Code **skill** that bootstraps complete **dark factory** projects from a raw idea.

A dark factory is an autonomous multi-agent system where specialized Claude agents (Engineer, QA, Designer, and a supervisor) work independently — implementing features, reviewing PRs, testing, and reporting — with no human in the loop except for escalations.

Dark Forgery is the factory that forges factories. Give it a one-line idea; it produces a fully wired project scaffold ready for autonomous development to begin.

---

## Install

Clone and symlink into your Claude Code skills directory:

```bash
git clone git@github.com:efixty/dark-forgery.git ~/dev/dark-forgery
ln -s ~/dev/dark-forgery ~/.claude/skills/dark-forgery
```

Available immediately in any Claude Code session — no restart needed.

---

## Usage

```
/dark-forgery <one-line idea>
```

Examples:

```
/dark-forgery a CLI tool that converts Figma exports to Tailwind components
/dark-forgery an API that transcribes voice memos and tags them by topic
/dark-forgery a self-hosted price tracker for Amazon wishlists
```

Claude will guide you through 10 discovery phases across 3 groups, then generate the entire project scaffold in one pass.

---

## Repository structure

```
dark-forgery/            ← repo root = the installable skill
  SKILL.md               ← the skill: discovery phases + generation pass
  references/            ← on-demand deep-dive docs linked from SKILL.md
  examples/              ← worked example factories linked from SKILL.md
  scripts/
    validate.sh          ← skill linter (see Validation below)
    check_scaffold.sh    ← generated-scaffold checker (see Validation below)
```

---

## What it does

### Discovery phases (no files created yet)

| Phase | What gets decided |
|---|---|
| 0 — Intake | Confirms the idea, notes ambiguities |
| **Group 1 — What are we building?** | |
| 1 — Scope | What the project does, v1 boundaries, definition of done, who uses it |
| 2 — Stack | Language choices with rationale; constraints and preferences |
| 3 — Execution environment | Host machine, Docker, or remote — frames everything downstream |
| **Group 2 — Who's working on it?** | |
| 4 — Roles | Which agents are needed, what each owns, review-cycle limits, sequential vs parallel spawning, per-role model policy, factory-wide effort |
| 5 — Structure | Directory tree adapted to the confirmed stack and execution context |
| **Group 3 — How does it operate?** | |
| 6 — Comms | How the supervisor reaches you (Telegram, Slack, Discord, email, or none) |
| 7 — Credentials | Every secret and env var the project needs |
| 8 — Logging | Where issues and feature progress are tracked (Obsidian, GitHub Issues, markdown, Linear, or none) |
| 9 — Auth & billing | How the factory's Claude Code authenticates: API key or OAuth session (Max/Pro) |

### Generation pass (all files in one shot)

After all phases are confirmed, Dark Forgery synthesizes everything you discussed and generates:

- **`CLAUDE.md`** — the project bible: what it does, how to run it, every interface contract, org structure, model & effort policy, MR workflow, logging, comms, env vars. A fresh agent reads this and acts without asking questions.
- **`CONSTITUTION.md`** — locked common core rules (role discipline, output contracts, build gates, spec docs, no secrets in commits, PR workflow, escalation chain) + project-specific additions.
- **`docs/roles/{role}.md`** — one fully written role doc per confirmed agent role
- **`STATUS.md`** — initial task board pre-populated from scope discovery
- **`Makefile`** — setup/build/test targets for the confirmed stack
- **`.claude/settings.json`** — allowed Bash permissions for all scripts and tools
- **`scripts/{supervisor}_entrypoint.sh`** — startup script with preflight checks, crash-tolerant one-cycle relaunch loop, `--check` self-test, first-boot repo clone
- **`scripts/{supervisor}_prompt.md`** — startup prompt injected on every supervisor start
- **`scripts/{supervisor}_check_prompt.md`** — deep self-test prompt for the `--check` dry run
- **`scripts/{notify}.sh`** — notification helper for the chosen comm channel
- **`scripts/vault_write.sh`** — note writer for the chosen logging destination (if file-based)
- **`docs/credentials.md`** — credential table (names and sources; values filled in by you)
- **`docs/environment.md`** — env var reference
- **`.env.example`** — placeholder env file (gitignored)
- **`.gitignore`** — secrets, build artifacts, and runtime sentinels excluded
- Directory structure with `.gitkeep` placeholders
- Initial git commit

### What it doesn't do

- Create the GitHub remote — you do that and push
- Fill in credential values — you fill in `.env` from `docs/credentials.md`
- Start the factory — you run `docker run` or the entrypoint script

---

## Validation

Two checkers ship with the repo:

**Skill linter** — verifies this repo is a well-formed skill: frontmatter is valid, every link in `SKILL.md` and `references/` resolves, no orphaned reference files, `SKILL.md` stays within its line budget.

```bash
scripts/validate.sh
```

**Scaffold checker** — verifies a factory that Dark Forgery generated is complete and honors its contracts: required files present, CONSTITUTION common core (rules 1–13) intact, STATUS.md board sections in place, entrypoint implements the one-cycle lifecycle (exit sentinel, relaunch loop, `--check`), Makefile targets exist, no secrets tracked by git.

```bash
scripts/check_scaffold.sh /path/to/generated-factory
```

Both exit non-zero on any failure, so they slot into CI or pre-commit hooks directly.

---

## Auto mode

If at any point you say "auto", "go ahead", "just do it", or similar — Dark Forgery skips the remaining approval gates and completes all phases in one go.
