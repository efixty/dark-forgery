# Feed Digester

## What this project does

Feed Digester is an autonomous worker that turns a firehose of feeds into one short daily
briefing. On a schedule it pulls a configured set of RSS feeds and one IMAP newsletter inbox,
normalizes every entry to a common `Item` shape, removes duplicates, clusters the remaining
items by topic, renders a single markdown digest, and delivers it via Telegram push while
archiving a copy to disk. The end user is one person who wants to replace N daily feed checks
with a single five-minute read.

## Components

| Name | Language | Purpose |
|---|---|---|
| `feed_digester` | Python 3.11 | The whole pipeline: ingest → normalize → dedupe → cluster → render → deliver, plus the in-process scheduler that runs it daily |

This is a single-component project. The table exists so the contract format is consistent
with multi-component factories; there is no cross-component interface to coordinate.

## How to run

Local (host, for development):
```bash
make setup          # create venv, install requirements
make test           # run the test suite against docs/qa/fixtures
cp .env.example .env # then fill in real values
make run            # runs one digest cycle immediately, then exits (DIGEST_RUN_ONCE=1)
```

Production (Docker, the real deployment):
```bash
docker build -t feed-digester .
docker run --name feed-digester --restart unless-stopped \
  --env-file .env \
  --volume ~/.claude-feed-digester:/home/factory/.claude \
  --volume "$PWD/archive:/app/archive" \
  feed-digester
```
The container runs `scripts/editor_entrypoint.sh`, which preflights the environment, then
loops the Editor supervisor one cycle at a time. The digest worker itself is started by the
Engineer's application code, not the entrypoint — the entrypoint runs the *factory*, the
factory builds and runs the *product*.

Validate the environment before the first real run:
```bash
docker run --rm --env-file .env feed-digester --check
```

## Interface contracts

### `Item` schema (internal data contract)
Every ingested entry, from any source, is normalized to this shape before dedupe/cluster:
```json
{
  "id": "sha256 of (source_url + guid)",   // stable dedupe key, string
  "source": "ars-technica",                 // feed/newsletter slug, string
  "source_type": "rss | newsletter",        // string enum
  "title": "string",
  "url": "https://…",                        // canonical link to the item
  "published": "2026-07-23T08:00:00Z",       // ISO-8601 UTC
  "summary": "string, plain text, <= 500 chars"
}
```
`id` is the dedupe identity: two items with the same `id` are the same item. `published` is
always UTC ISO-8601. `summary` is plain text — HTML is stripped during normalization.

### Digest format (user-facing output contract — see CONSTITUTION rule 15)
The rendered digest, written to `archive/digest-YYYY-MM-DD.md` and sent to Telegram:
```markdown
# Daily Digest — {YYYY-MM-DD}
_{N} items across {M} topics · generated {HH:MM} UTC_

## {Topic label}
- **{title}** — {source} · [link]({url})
- …

## {Topic label}
- …
```
One `##` section per topic cluster, ordered by cluster size descending. Each item is one
bullet with bold title, source slug, and a markdown link. No cluster may be empty. This shape
is a hard contract; changing it requires a versioned edit to this section first.

### Config contract (`config/feeds.yaml`, not a secret)
```yaml
feeds:
  - slug: ars-technica
    url: https://feeds.arstechnica.com/arstechnica/index
schedule:
  hour_utc: 8          # daily run time, 0–23
clustering:
  min_cluster_size: 2  # singletons collapse into a "Misc" cluster
```

## Org structure

| Role | Doc | Responsibility |
|---|---|---|
| Editor (supervisor) | `docs/roles/editor.md` | Spawns agents, owns STATUS.md, reports to the user, runs one cycle per session |
| Engineer | `docs/roles/engineer.md` | Implements pipeline features, opens PRs; also acts as Reviewer Engineer on others' PRs |
| QA | `docs/roles/qa.md` | Validates each PR against its spec doc using fixture corpora; writes QA reports |

Report chain: Engineer/QA → Editor → user (via Telegram). Only the Editor talks to the user.

## Model & effort policy

- **Editor (supervisor):** `--model sonnet --effort high`, pinned on the `claude -p`
  invocation in the entrypoint. Every sub-agent inherits `high` effort from this session.
- **Sub-agent model — mixed / complexity-gated policy.** Models differ by role and the
  Engineer uses Opus-for-complex-tasks, so `CLAUDE_CODE_SUBAGENT_MODEL` is **NOT** set. The
  Editor chooses each sub-agent's model at spawn time via the Agent tool's `model` parameter:
  - Engineer: Sonnet by default; **Opus only when the Editor judges the task complex** and
    states so, with a one-line reason, in the task brief. No silent upgrades.
  - QA: Sonnet always.
- Effort is the single factory-wide value `high`; the Editor never sets effort per spawn.

## MR workflow

1. Editor picks a backlog item, writes a task brief, spawns an Engineer (stating model + reason
   if Opus).
2. Engineer reads role doc + CLAUDE.md + CONSTITUTION, implements on a `feature/…` branch,
   writes the feature spec (`docs/features/{slug}.md`) and a test in the same PR, ensures
   `make test` passes, opens the PR, sets the STATUS.md PR entry `Phase: reviewer`.
3. Editor spawns a Reviewer Engineer (≤ 3 cycles). Each "changes requested" bumps the Reviewer
   cycle counter; the Engineer addresses and re-pushes.
4. On code approval, Editor spawns QA (≤ 2 cycles). QA validates against the spec doc using
   fixtures, writes `docs/qa/reports/pr-{N}.md`, and approves or requests changes.
5. On QA approval, Editor merges (squash), updates the log note status, moves the item to
   Completed in STATUS.md, deletes the branch.
6. Any counter hitting its limit → `needs-human` + Reason (see CONSTITUTION rules 11–12, 14).

## Logging

Destination: **plain markdown, git-tracked in this repo** under `docs/log/`. No external
service. Every feature and every issue gets a note via `scripts/log_write.sh`:
```bash
scripts/log_write.sh feature dedupe-by-id "Item dedupe" "Items sharing an id collapse to one."
scripts/log_write.sh issue 12 "Empty digest crash" "Renderer crashed on a zero-item day."
```
Note format (written by the script):
```markdown
# {title}
- Type: feature | issue
- Slug/ID: {slug-or-id}
- Status: open | shipped | fixed
- Date: {YYYY-MM-DD}

{body}
```
On merge, the Engineer updates `Status:` to `shipped` (feature) or `fixed` (issue). Notes are
committed with the PR — they are part of the change, not a side effect.

## Communication

Channel: **Telegram**. Script: `scripts/telegram_notify.sh "message"`. Used for two things:
1. The Editor's escalations and the one-per-boot "factory online" ping.
2. Delivery of the daily digest itself (the product output), sent by the application code.
Message format is plain text (digest delivery may exceed one Telegram message; the app splits
on `##` section boundaries if over 4096 chars).

## Environment

See `docs/environment.md` for the full table and `docs/credentials.md` for where each secret
comes from. Required at runtime: `IMAP_HOST`, `IMAP_USER`, `IMAP_PASSWORD`,
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `GITHUB_TOKEN`. Auth is **OAuth session (Claude
Max)** via a volume-mounted `~/.claude-feed-digester` — `ANTHROPIC_API_KEY` is deliberately
NOT set (it would override OAuth and bill separately).

## Build shortcuts (Makefile)

| Target | Does |
|---|---|
| `make setup` | create venv, `pip install -r requirements.txt` |
| `make build` | compile-check (`python -m compileall src`) |
| `make test` | run `pytest` against `docs/qa/fixtures` |
| `make run` | one immediate digest cycle then exit (`DIGEST_RUN_ONCE=1`) |
| `make lint` | `ruff check src tests` |

`{GITHUB_REPO_URL}` is filled in after you create the remote (see `docs/environment.md`).
