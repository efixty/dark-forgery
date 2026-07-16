#!/usr/bin/env bash
# validate.sh — lint this repo as a well-formed Claude Code skill.
#
# Checks:
#   1. SKILL.md exists and has YAML frontmatter
#   2. frontmatter `name:` present, valid format, matches the folder name
#   3. frontmatter `description:` present, non-empty, within the 1024-char limit
#   4. every relative markdown link in *.md resolves to a real file
#   5. every backtick-quoted `references/...` or `examples/...` path exists
#   6. no orphaned .md files under references/ or examples/ (nothing links to them)
#   7. SKILL.md stays within the line budget (warn only)
#
# Exit code: 0 if no failures (warnings allowed), 1 otherwise.
# Compatible with macOS bash 3.2.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/SKILL.md"
LINE_BUDGET=500

ERRORS=0
WARNINGS=0

fail() { printf 'FAIL: %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { printf 'WARN: %s\n' "$*" >&2; WARNINGS=$((WARNINGS + 1)); }
ok()   { printf '  ok: %s\n' "$*"; }

# ── 1. SKILL.md exists ────────────────────────────────────────────────────────
if [ ! -f "$SKILL" ]; then
  fail "SKILL.md not found at repo root"
  echo "Result: $ERRORS failure(s) — cannot continue without SKILL.md." >&2
  exit 1
fi
ok "SKILL.md exists"

# ── 2–3. Frontmatter ─────────────────────────────────────────────────────────
if [ "$(head -n 1 "$SKILL")" != "---" ]; then
  fail "SKILL.md does not start with YAML frontmatter (---)"
else
  # Everything between the first and second `---` lines.
  FRONTMATTER="$(awk 'NR==1 && $0=="---" {inblock=1; next} inblock && $0=="---" {exit} inblock {print}' "$SKILL")"

  NAME="$(printf '%s\n' "$FRONTMATTER" | sed -n 's/^name:[[:space:]]*//p' | head -n 1)"
  DESC="$(printf '%s\n' "$FRONTMATTER" | sed -n 's/^description:[[:space:]]*//p' | head -n 1)"

  if [ -z "$NAME" ]; then
    fail "frontmatter is missing 'name:'"
  else
    if printf '%s' "$NAME" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && [ "${#NAME}" -le 64 ]; then
      ok "name '$NAME' is well-formed"
    else
      fail "name '$NAME' is invalid (must be lowercase alphanumeric + hyphens, <= 64 chars)"
    fi
    FOLDER="$(basename "$ROOT")"
    if [ "$NAME" = "$FOLDER" ]; then
      ok "name matches folder name ($FOLDER)"
    else
      warn "name '$NAME' != folder name '$FOLDER' — install path must be ~/.claude/skills/$NAME"
    fi
  fi

  if [ -z "$DESC" ]; then
    fail "frontmatter is missing 'description:'"
  elif [ "${#DESC}" -gt 1024 ]; then
    fail "description is ${#DESC} chars (limit 1024)"
  else
    ok "description present (${#DESC} chars)"
  fi
fi

# ── 4. Relative markdown links resolve ───────────────────────────────────────
# Scan every .md at root and under references/ and examples/.
MD_FILES="$SKILL"
for dir in references examples; do
  if [ -d "$ROOT/$dir" ]; then
    FOUND="$(find "$ROOT/$dir" -name '*.md' -type f 2>/dev/null)"
    [ -n "$FOUND" ] && MD_FILES="$MD_FILES
$FOUND"
  fi
done
[ -f "$ROOT/README.md" ] && MD_FILES="$MD_FILES
$ROOT/README.md"

LINK_FAILS=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  # Extract markdown link targets: [text](target)
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;      # external / in-page
      *'{'*) continue ;;                                 # template placeholder
    esac
    # Strip any #anchor suffix.
    path="${target%%#*}"
    [ -z "$path" ] && continue
    base_dir="$(dirname "$file")"
    if [ ! -e "$base_dir/$path" ] && [ ! -e "$ROOT/$path" ]; then
      fail "broken link in ${file#$ROOT/}: ($target)"
      LINK_FAILS=$((LINK_FAILS + 1))
    fi
  done <<EOF
$(grep -o '\[[^]]*\]([^)]*)' "$file" 2>/dev/null | sed 's/^\[[^]]*\](//; s/)$//')
EOF
done <<EOF
$MD_FILES
EOF
[ "$LINK_FAILS" -eq 0 ] && ok "all relative markdown links resolve"

# ── 5. Backtick-quoted repo-local paths exist ────────────────────────────────
# Only references/... and examples/... are repo-local namespaces; paths with {}
# placeholders belong to generated projects and are skipped.
PATH_FAILS=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in *'{'*) continue ;; esac
    if [ ! -e "$ROOT/$p" ]; then
      fail "path mentioned in ${file#$ROOT/} does not exist: $p"
      PATH_FAILS=$((PATH_FAILS + 1))
    fi
  done <<EOF
$(grep -o '`\(references\|examples\)/[^\`]*`' "$file" 2>/dev/null | tr -d '\`')
EOF
done <<EOF
$MD_FILES
EOF
[ "$PATH_FAILS" -eq 0 ] && ok "all backtick-quoted references/ and examples/ paths exist"

# ── 6. Orphaned reference/example files ──────────────────────────────────────
ORPHANS=0
for dir in references examples; do
  [ -d "$ROOT/$dir" ] || continue
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#$ROOT/}"
    if ! grep -q -- "$rel" $MD_FILES 2>/dev/null; then
      warn "orphaned file — nothing links to $rel"
      ORPHANS=$((ORPHANS + 1))
    fi
  done <<EOF
$(find "$ROOT/$dir" -name '*.md' -type f 2>/dev/null)
EOF
done
[ "$ORPHANS" -eq 0 ] && ok "no orphaned files under references/ or examples/"

# ── 7. SKILL.md line budget ──────────────────────────────────────────────────
LINES="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$LINES" -gt "$LINE_BUDGET" ]; then
  warn "SKILL.md is $LINES lines (budget $LINE_BUDGET) — consider splitting into references/"
else
  ok "SKILL.md is $LINES lines (budget $LINE_BUDGET)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "Validation complete: $ERRORS failure(s), $WARNINGS warning(s)."
[ "$ERRORS" -eq 0 ] || exit 1
exit 0
