#!/usr/bin/env bash
# install-backup-schedule.sh — run scripts/backup-memory.sh twice a day via
# macOS launchd (08:00 and 20:00, local time).
#
# Usage:
#   bash scripts/install-backup-schedule.sh             install / reinstall
#   bash scripts/install-backup-schedule.sh --dry-run   print the plist only
#   bash scripts/install-backup-schedule.sh --uninstall remove it
#
# launchd runs missed jobs when the Mac wakes, so a sleeping laptop still
# gets its backup at the next wake.
#
# macOS only. On Linux (or anything without launchd) it prints a crontab line
# to use instead and changes nothing. --dry-run works everywhere.

set -eu

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$(basename "$PROJECT_DIR")"
SAFE_NAME="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//')"
LABEL="com.claude-process.backup.${SAFE_NAME}"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/claude-process"
SCRIPT="$PROJECT_DIR/scripts/backup-memory.sh"

xml_escape() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

plist_content() {
cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(xml_escape "$SCRIPT")</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$(xml_escape "$PROJECT_DIR")</string>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>StandardOutPath</key>
  <string>$(xml_escape "$LOG_DIR/${SAFE_NAME}.out.log")</string>
  <key>StandardErrorPath</key>
  <string>$(xml_escape "$LOG_DIR/${SAFE_NAME}.err.log")</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST
}

case "${1:-}" in
  --dry-run)
    echo "# Would write: $PLIST"
    plist_content
    exit 0 ;;
  --uninstall)
    if [ "$(uname)" != "Darwin" ]; then
      echo "Nothing to uninstall: launchd scheduling is macOS-only. If you added a crontab line, remove it with: crontab -e"
      exit 0
    fi
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    [ -f "$PLIST" ] && rm -f "$PLIST"
    echo "Removed $LABEL. Output check: 'ls \"$PLIST\"' should say No such file."
    exit 0 ;;
  "") ;;
  *) echo "usage: $0 [--dry-run|--uninstall]" >&2; exit 1 ;;
esac

if [ "$(uname)" != "Darwin" ] || ! command -v launchctl >/dev/null 2>&1; then
  cat >&2 <<MSG
Not installed: this scheduler uses launchd, which is macOS-only. Nothing was changed.
On Linux, schedule it with cron instead — run 'crontab -e' and add this line:
  0 8,20 * * * /bin/bash "$SCRIPT"
Then check the OUTPUT the next day: ls -lt ~/claude-backups/${SAFE_NAME}/ | head -3
MSG
  exit 1
fi
[ -x "$SCRIPT" ] || chmod +x "$SCRIPT"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
plist_content > "$PLIST"
plutil -lint "$PLIST" >/dev/null || { echo "ERROR: generated plist failed plutil -lint" >&2; exit 1; }

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

cat <<MSG
Installed $LABEL — runs 08:00 and 20:00.
  plist: $PLIST
  logs:  $LOG_DIR/${SAFE_NAME}.{out,err}.log

"launchctl says loaded" is a MECHANISM check — it does not prove a backup exists.
Do the OUTPUT check:

1. Run it once now (by launchd itself, not by hand):
     launchctl kickstart "gui/$(id -u)/$LABEL"
2. Confirm a new archive landed in BOTH destinations, timestamped just now:
     ls -lt ~/claude-backups/${SAFE_NAME}/ | head -3     (or your BACKUP_DEST_1)
     ls -lt "<your BACKUP_DEST_2>" | head -3
3. Confirm it has real contents:
     tar -tzf "\$(ls -t ~/claude-backups/${SAFE_NAME}/*.tar.gz | head -1)" | head
4. Confirm the error log is empty and the out log ends with "2/2 destinations verified":
     tail -3 "$LOG_DIR/${SAFE_NAME}.out.log"; cat "$LOG_DIR/${SAFE_NAME}.err.log"
5. Tomorrow, repeat step 2 and check for archives stamped ~08:00 and ~20:00.

If the project is inside ~/Documents, ~/Desktop or ~/Downloads, macOS may block
launchd from reading it — grant /bin/bash Full Disk Access or move the project.
MSG
