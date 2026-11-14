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
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")

FILE=${ARGS[0]:-}
if [ -z "$FILE" ]; then
  # Prefer the original of the version installed right now; another version's DLL
  # has a different layout and must not be copied over it.
  if [ -n "$VERSION" ] && [ -f "$HERE/../backup/OurTaiko.Runtime.$VERSION.original.dll" ]; then
    FILE="$HERE/../backup/OurTaiko.Runtime.$VERSION.original.dll"
  else
    FILE=$(ls -t "$HERE/../backup"/OurTaiko.Runtime.*.dll 2>/dev/null | grep -v 'pre-' | head -1)
  fi
fi
[ -f "$FILE" ] || { echo "no backup dll found" >&2; exit 1; }
case "$(basename "$FILE")" in
  *".$VERSION.original.dll") ;;
  *) echo "note: $FILE is not the original saved for $VERSION" >&2 ;;
esac

osascript -e 'quit app "OurTaikoPlay"' >/dev/null 2>&1 || true
sleep 2
if ! cmp -s "$FILE" "$TARGET"; then
  STAMP=$(date +%Y%m%d-%H%M%S)
  cp -p "$TARGET" "$HERE/../backup/OurTaiko.Runtime.pre-$STAMP.dll"
  echo "backed up patched dll -> $HERE/../backup/OurTaiko.Runtime.pre-$STAMP.dll"
fi
cp "$FILE" "$TARGET"
shasum -a 256 "$TARGET"
echo "restored from $FILE"
if [ "$LAUNCH" = "1" ]; then open -a "$APP"; else echo "app stays closed (pass --launch to open it)"; fi
