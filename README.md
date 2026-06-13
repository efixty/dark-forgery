# Dark Forgery

A Claude Code slash command that bootstraps complete **dark factory** projects from a raw idea.

A dark factory is an autonomous multi-agent system where specialized Claude agents (Engineer, QA, Designer, and a supervisor) work independently — implementing features, reviewing PRs, testing, and reporting — with no human in the loop except for escalations.

Dark Forgery is the factory that forges factories. Give it a one-line idea; it produces a fully wired project scaffold ready for autonomous development to begin.

---

## Install

Copy the slash command to your Claude Code user commands directory:

```bash
curl -o ~/.claude/commands/dark-forgery.md \
  https://raw.githubusercontent.com/efixty/dark-forgery/main/dark-forgery.md
```

Or clone and symlink:

```bash
git clone git@github.com:efixty/dark-forgery.git ~/dev/dark-forgery
ln -s ~/dev/dark-forgery/dark-forgery.md ~/.claude/commands/dark-forgery.md
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

Claude will guide you through 8 discovery phases across 3 groups, then generate the entire project scaffold in one pass.

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
| 4 — Roles | Which agents are needed and what each owns |
| 5 — Structure | Directory tree adapted to the confirmed stack and execution context |
| **Group 3 — How does it operate?** | |
| 6 — Comms | How the supervisor reaches you (Telegram, Slack, Discord, email, or none) |
| 7 — Credentials | Every secret and env var the project needs |
| 8 — Logging | Where issues and feature progress are tracked (Obsidian, GitHub Issues, markdown, Linear, or none) |

### Generation pass (all files in one shot)

After all phases are confirmed, Dark Forgery synthesizes everything you discussed and generates:

- **`CLAUDE.md`** — the project bible: what it does, how to run it, every interface contract, org structure, MR workflow, logging, comms, env vars. A fresh agent reads this and acts without asking questions.
- **`CONSTITUTION.md`** — locked common core rules (role discipline, output contracts, build gates, spec docs, no secrets in commits, PR workflow, escalation chain) + project-specific additions.
- **`docs/roles/{role}.md`** — one fully written role doc per confirmed agent role
- **`STATUS.md`** — initial task board pre-populated from scope discovery
- **`Makefile`** — setup/build/test targets for the confirmed stack
- **`.claude/settings.json`** — allowed Bash permissions for all scripts and tools
- **`scripts/{supervisor}_entrypoint.sh`** — startup script with preflight checks, crash-tolerant restart loop, first-boot repo clone
- **`scripts/{supervisor}_prompt.md`** — startup prompt injected on every supervisor start
- **`scripts/{notify}.sh`** — notification helper for the chosen comm channel
- **`scripts/vault_write.sh`** — note writer for the chosen logging destination (if file-based)
- **`docs/credentials.md`** — credential table (names and sources; values filled in by you)
- **`docs/environment.md`** — env var reference
- **`.env.example`** — placeholder env file (gitignored)
- **`.gitignore`** — secrets and build artifacts excluded
- Directory structure with `.gitkeep` placeholders
- Initial git commit

### What it doesn't do

- Create the GitHub remote — you do that and push
- Fill in credential values — you fill in `.env` from `docs/credentials.md`
- Start the factory — you run `docker run` or the entrypoint script

---

## Auto mode

If at any point you say "auto", "go ahead", "just do it", or similar — Dark Forgery skips the remaining approval gates and completes all phases in one go.
