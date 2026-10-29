#!/bin/bash
# Restore an unpatched OurTaiko.Runtime.dll from the backups taken by install.sh.
#
#   restore.sh [backup-file] [app] [--launch]
#
# The app stays closed unless --launch is passed.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LAUNCH=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --launch) LAUNCH=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
APP=${ARGS[1]:-/Applications/OurTaikoPlay.app}
TARGET="$APP/Contents/Resources/Data/Managed/OurTaiko.Runtime.dll"

FILE=${ARGS[0]:-}
if [ -z "$FILE" ]; then
  FILE=$(ls -t "$HERE/../backup"/OurTaiko.Runtime.*.dll 2>/dev/null | grep -v 'pre-' | head -1)
fi
[ -f "$FILE" ] || { echo "no backup dll found" >&2; exit 1; }

osascript -e 'quit app "OurTaikoPlay"' >/dev/null 2>&1 || true
sleep 2
cp "$FILE" "$TARGET"
shasum -a 256 "$TARGET"
echo "restored from $FILE"
if [ "$LAUNCH" = "1" ]; then open -a "$APP"; else echo "app stays closed (pass --launch to open it)"; fi
