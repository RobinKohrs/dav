#!/bin/zsh
# Converts .eml/.mbox files to .md with YAML frontmatter, sorted into
# ~/vault/work/sources/emails/YYYY-MM/YYYY-MM-DD_slug.md
# Called from Finder Quick Action "Email to Wiki Inbox".

set -euo pipefail

SCRIPT="$HOME/projects/personal/dav/helper_scripts/python/dav_mbox_to_text.py"
DEST="$HOME/vault/work/sources/emails"
UV="/opt/homebrew/bin/uv"

mkdir -p "$DEST"

for file in "$@"; do
  [[ -f "$file" ]] || continue

  # Run conversion — stderr has "  [N] → path/to/file.md" lines
  output=$("$UV" run "$SCRIPT" "$file" --split-dir "$DEST" 2>&1 || true)
  count=$(printf '%s\n' "$output" | grep -c "→ " || true)

  osascript -e "display notification \"$count Mail(s) → sources/emails/\" with title \"Wiki Inbox ✓\""
done
