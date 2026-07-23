#!/usr/bin/env bash
# Send a plain-text message to the configured Telegram chat.
# Usage: scripts/telegram_notify.sh "message text"
# Requires: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID in the environment.
set -euo pipefail

MSG="${1:-}"
if [ -z "$MSG" ]; then
  echo "usage: $0 \"message\"" >&2
  exit 2
fi
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set}"

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}")"

if [ "$HTTP_CODE" != "200" ]; then
  echo "telegram_notify: send failed (HTTP $HTTP_CODE)" >&2
  exit 1
fi
