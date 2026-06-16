#!/bin/bash
# dav_vault_backup.sh
# Tägliches Auto-Backup des Work-Vaults nach GitHub.
# Wird von launchd täglich um 23:00 Uhr aufgerufen.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

VAULT="$HOME/vault/work"
LOG="/tmp/dav-vault-backup.out"

cd "$VAULT" || exit 1

# Nichts zu tun wenn keine Änderungen
git add -A
if git diff --cached --quiet; then
    echo "$(date): no changes, nothing to commit" >> "$LOG"
    exit 0
fi

DATE=$(date +%Y-%m-%d)
git commit -m "auto: daily backup $DATE" >> "$LOG" 2>&1

if git push >> "$LOG" 2>&1; then
    echo "$(date): backup pushed successfully" >> "$LOG"
    osascript -e 'display notification "Vault erfolgreich gesichert" with title "DAV Backup"' 2>/dev/null
else
    echo "$(date): push failed — check /tmp/dav-vault-backup.err" >> "$LOG"
    osascript -e 'display notification "Backup fehlgeschlagen — Git-Push prüfen" with title "DAV Backup"' 2>/dev/null
fi
