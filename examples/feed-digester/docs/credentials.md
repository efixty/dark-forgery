# Credentials

Every secret the factory and product need. Values are filled into your private `.env` (never
committed). This table is names + sources only.

| Name | Purpose | Where to get it |
|---|---|---|
| `IMAP_HOST` | Newsletter inbox host to poll (e.g. `imap.gmail.com`) | Your email provider's IMAP settings |
| `IMAP_USER` | Newsletter inbox username / address | Your email account |
| `IMAP_PASSWORD` | Newsletter inbox password or app password | Provider account settings — use an **app password**, not your main password |
| `TELEGRAM_BOT_TOKEN` | Auth for the bot that sends digests + Editor alerts | Talk to [@BotFather](https://t.me/BotFather) → `/newbot` → copy the token |
| `TELEGRAM_CHAT_ID` | The chat the bot sends to (you) | Message your bot, then `GET https://api.telegram.org/bot<token>/getUpdates` and read `chat.id` |
| `GITHUB_TOKEN` | Clone the repo and drive the PR workflow via `gh` | GitHub → Settings → Developer settings → **Fine-grained PAT** with Contents + Pull requests: read/write on this repo |

## Claude Code authentication

This factory uses **OAuth session (Claude Max)**, not an API key. There is **no**
`ANTHROPIC_API_KEY` — setting it would override OAuth and bill separately.

One-time host setup before the first `docker run`:
```bash
CLAUDE_CONFIG_DIR=~/.claude-feed-digester claude   # run /login inside the session
```
Then mount it read-write into the container (see `docs/environment.md` for the full command).
When the factory reports "Not logged in", re-run the `/login` above; the refreshed token is
picked up on the next container start via the volume mount.
