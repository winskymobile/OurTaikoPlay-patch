#!/bin/bash
# Install a freshly built OurTaiko.Runtime.dll into an installed OurTaikoPlay.app,
# keeping a backup of the DLL it replaces and merging the new settings schema.
#
#   install.sh [dll] [app] [backup-dir] [--launch]
#
# Defaults: dll        = <script dir>/build/OurTaiko.Runtime.dll
#           app        = /Applications/OurTaikoPlay.app
#           backup dir = <script dir>/../backup
#
# The app is closed before copying and stays closed unless --launch is passed.
# Before installing, the serialized field layout is compared with the saved original
# DLL: a changed MonoBehaviour layout crashes Unity when a built scene loads.
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
DLL=${ARGS[0]:-$HERE/build/OurTaiko.Runtime.dll}
APP=${ARGS[1]:-/Applications/OurTaikoPlay.app}
BACKUP=${ARGS[2]:-$HERE/../backup}

TARGET="$APP/Contents/Resources/Data/Managed/OurTaiko.Runtime.dll"
DATA="$HOME/Library/Application Support/OurTaiko/OurTaikoPlay"
STAMP=$(date +%Y%m%d-%H%M%S)

[ -f "$DLL" ] || { echo "no built dll at $DLL (run build-runtime-dll.sh first)" >&2; exit 1; }
[ -f "$TARGET" ] || { echo "no $TARGET" >&2; exit 1; }
mkdir -p "$BACKUP"

ORIGINAL=$(ls "$BACKUP"/*.original.dll 2>/dev/null | tail -1 || true)
if [ -n "$ORIGINAL" ] && [ "${SKIP_LAYOUT_CHECK:-0}" != "1" ]; then
  echo "checking serialized layout against $(basename "$ORIGINAL")"
  "$HERE/check-layout.sh" "$ORIGINAL" "$DLL"
fi

osascript -e 'quit app "OurTaikoPlay"' >/dev/null 2>&1 || true
sleep 2

if ! cmp -s "$DLL" "$TARGET"; then
  cp -p "$TARGET" "$BACKUP/OurTaiko.Runtime.pre-$STAMP.dll"
  echo "backed up old dll -> $BACKUP/OurTaiko.Runtime.pre-$STAMP.dll"
  cp "$DLL" "$TARGET"
  echo "installed     -> $TARGET"
else
  echo "already up to date"
fi
shasum -a 256 "$TARGET"

# The patched game keeps its data in Application Support. Bring over anything the new
# build added (flying notes, background movie, …) without losing the player's values.
if [ -f "$DATA/settings.json" ]; then
  python3 - "$APP/settings.json" "$DATA/settings.json" "$STAMP" <<'PY'
import json, os, shutil, sys
bundle, data, stamp = sys.argv[1:4]
def merge(old, new):
    if isinstance(old, dict) and isinstance(new, dict):
        out = dict(old)
        for k, v in new.items():
            out[k] = merge(old[k], v) if k in old else v
        return out
    return new
src = {}
if os.path.exists(bundle):
    src = json.load(open(bundle))
old = json.load(open(data))
shutil.copy2(data, f"{data}.bak-{stamp}")
json.dump(merge(old, src), open(data, "w"), ensure_ascii=False, indent=2)
print("merged settings ->", data)
print("backup          ->", f"{data}.bak-{stamp}")
PY
fi

if [ "$LAUNCH" = "1" ]; then
  open -a "$APP"
  echo "launched $APP"
else
  echo "app stays closed (pass --launch to open it)"
fi
echo "done"
