#!/bin/bash
# dav_inbox_watcher.sh
#
# Called by launchd whenever ~/vault/work/inbox/ changes.
# Converts any new .eml or .mbox files to Markdown and writes them
# directly to ~/vault/work/sources/emails/YYYY-MM/ (wikilink-ready).
# Originals are moved to inbox/.done/.

UV="/opt/homebrew/bin/uv"
SCRIPT="$HOME/projects/personal/dav/helper_scripts/python/dav_mbox_to_text.py"
INBOX="$HOME/vault/work/inbox"
DEST="$HOME/vault/work/sources/emails/inbox"
DONE="$INBOX/.done"
LOCK="/tmp/dav-inbox-watcher.lock"

# Prevent overlapping runs
[ -f "$LOCK" ] && exit 0
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT

mkdir -p "$DONE" "$DEST"

_notify() {
    /usr/bin/python3 "$HOME/vault/work/scripts/vault_notify.py" "DAV Inbox" "$1" 2>>/tmp/dav-inbox-watcher.err || \
        osascript -e "display notification \"$(printf '%s' "$1" | sed 's/"/\\"/g')\" with title \"DAV Inbox\" sound name \"Ping\"" 2>/dev/null || true
}

converted=0
failed=0

# Process .eml files
while IFS= read -r -d '' f; do
    output=$("$UV" run "$SCRIPT" "$f" --split-dir "$DEST" 2>&1)
    status=$?
    if [ $status -eq 0 ]; then
        count=$(printf '%s\n' "$output" | grep -c '→' 2>/dev/null || true)
        [ "$count" -eq 0 ] && count=1
        converted=$((converted + count))
        mv "$f" "$DONE/"
    else
        failed=$((failed + 1))
        printf '%s\n' "$output" >> /tmp/dav-inbox-watcher.err
    fi
done < <(find "$INBOX" -maxdepth 1 -name "*.eml" -print0 2>/dev/null)

# Process .mbox files / Apple Mail bundle directories
while IFS= read -r -d '' f; do
    output=$("$UV" run "$SCRIPT" "$f" --split-dir "$DEST" 2>&1)
    status=$?
    if [ $status -eq 0 ]; then
        count=$(printf '%s\n' "$output" | grep -c '→' 2>/dev/null || true)
        [ "$count" -eq 0 ] && count=1
        converted=$((converted + count))
        mv "$f" "$DONE/"
    else
        failed=$((failed + 1))
        printf '%s\n' "$output" >> /tmp/dav-inbox-watcher.err
    fi
done < <(find "$INBOX" -maxdepth 1 -name "*.mbox" -print0 2>/dev/null)

# Notify results
if [ "$converted" -gt 0 ]; then
    _notify "${converted} E-Mail(s) → sources/emails/ — Cursor öffnen, 'Inbox ingesten' sagen"
fi

if [ "$failed" -gt 0 ]; then
    _notify "Fehler bei ${failed} Datei(en) — /tmp/dav-inbox-watcher.err prüfen"
fi
