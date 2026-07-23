# Feed Digester — Status

## Active
*(none — factory not yet started)*

## Backlog
The pipeline ladder, ordered so each item builds on the previous. The Editor takes the top
unblocked item each cycle.

- [ ] **config-loader** — load and validate `config/feeds.yaml` (feeds, schedule, clustering); fail loudly on a malformed config
- [ ] **rss-ingest** — pull each configured RSS feed, parse entries, normalize to the `Item` schema
- [ ] **newsletter-ingest** — pull the IMAP inbox, parse newsletter emails, normalize to the `Item` schema
- [ ] **dedupe-by-id** — collapse items sharing an `id` (sha256 of source_url+guid) to one
- [ ] **cluster-by-topic** — deterministic TF-IDF clustering; singletons below `min_cluster_size` collapse into "Misc"
- [ ] **render-digest** — render clustered items to the Digest format contract; archive to `archive/digest-YYYY-MM-DD.md`
- [ ] **deliver-telegram** — send the digest via Telegram, splitting on `##` boundaries when over 4096 chars
- [ ] **scheduler** — run the full pipeline daily at `schedule.hour_utc`; support `DIGEST_RUN_ONCE=1` for one-shot runs
- [ ] **empty-day-handling** — a zero-item day sends a short "no items today" note, never crashes or sends an empty digest

## Completed
*(none)*

## Blocked
*(none)*

## Active PRs
*(none)*
