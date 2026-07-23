#!/usr/bin/env bash
# Write a feature/issue log note to docs/log/ (plain markdown, git-tracked — this repo IS the
# log destination for Feed Digester). The note is committed with the PR by the Engineer.
# Usage:
#   scripts/log_write.sh feature {slug} "{title}" "{body}"
#   scripts/log_write.sh issue   {id}   "{title}" "{body}"
set -euo pipefail

TYPE="${1:-}"; KEY="${2:-}"; TITLE="${3:-}"; BODY="${4:-}"
case "$TYPE" in
  feature|issue) ;;
  *) echo "usage: $0 <feature|issue> <slug-or-id> \"title\" \"body\"" >&2; exit 2 ;;
esac
[ -z "$KEY" ] && { echo "missing slug/id" >&2; exit 2; }

DEST="docs/log/${TYPE}-${KEY}.md"
mkdir -p docs/log
STATUS_INIT="open"

cat > "$DEST" <<EOF
# ${TITLE}
- Type: ${TYPE}
- Slug/ID: ${KEY}
- Status: ${STATUS_INIT}
- Date: $(date +%Y-%m-%d)

${BODY}
EOF

echo "Log note written: $DEST"
