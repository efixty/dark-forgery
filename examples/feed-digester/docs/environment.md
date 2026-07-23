# Environment

All runtime environment variables. Secrets come from `docs/credentials.md` and live only in
your private `.env`.

| Name | Source | Description |
|---|---|---|
| `IMAP_HOST` | credential | Newsletter inbox IMAP host |
| `IMAP_USER` | credential | Newsletter inbox username |
| `IMAP_PASSWORD` | credential | Newsletter inbox app password |
| `TELEGRAM_BOT_TOKEN` | credential | Telegram bot auth token |
| `TELEGRAM_CHAT_ID` | credential | Destination chat id for digests + alerts |
| `GITHUB_TOKEN` | credential | Repo clone + `gh` PR workflow auth |
| `GITHUB_REPO_URL` | fixed (you set) | `owner/repo` — filled in after you create the remote |
| `DIGEST_RUN_ONCE` | fixed (optional) | `1` = run one digest cycle and exit; unset = scheduled loop |
| `CYCLE_TIMEOUT` | fixed (optional) | Hard cap in seconds on one supervisor cycle (default 1800) |
| `MAX_CRASHES` | fixed (optional) | Consecutive failures before the crash-loop alert (default 5) |

**Deliberately NOT set:** `ANTHROPIC_API_KEY`. This factory authenticates Claude Code via an
OAuth session (Claude Max) mounted at `~/.claude`; an API key would override it and bill
separately.

## Run command (Docker, production)

```bash
docker run --name feed-digester --restart unless-stopped \
  --user "$(id -u):$(id -g)" -e HOME=/home/factory \
  --env-file .env \
  --volume ~/.claude-feed-digester:/home/factory/.claude \
  --volume "$PWD/archive:/app/archive" \
  feed-digester
```

`--user $(id -u):$(id -g)` makes the container process own the mounted OAuth dir natively
(it is created by your host user), avoiding permission errors on session-state writes.

## Validate before the first real run

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" -e HOME=/home/factory \
  --env-file .env \
  --volume ~/.claude-feed-digester:/home/factory/.claude \
  feed-digester --check
```
Fix anything it reports before starting the persistent container.
