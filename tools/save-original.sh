#!/bin/bash
# Keep a copy of the unpatched OurTaiko.Runtime.dll so later checks and restores work.
# Run this right after installing or updating the app, BEFORE the first patched install.
#
#   save-original.sh [app] [backup-dir]
#
# Safety rules:
#   * an existing *.original.dll is never overwritten; a differing copy is kept as .pre-<stamp>
#   * if the app's DLL looks patched (no matching shipped build), the file is only kept as a
#     .pre-<stamp> snapshot so a real original is never replaced by a patched build
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
APP=${1:-/Applications/OurTaikoPlay.app}
BACKUP=${2:-$HERE/../backup}
DLL="$APP/Contents/Resources/Data/Managed/OurTaiko.Runtime.dll"
STAMP=$(date +%Y%m%d-%H%M%S)

[ -f "$DLL" ] || { echo "no $DLL" >&2; exit 1; }
mkdir -p "$BACKUP"
NAME=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)
DEST="$BACKUP/OurTaiko.Runtime.$NAME.original.dll"
HAVE=$(shasum -a 256 "$DLL" | cut -d' ' -f1)

if [ -f "$DEST" ]; then
  if [ "$HAVE" = "$(shasum -a 256 "$DEST" | cut -d' ' -f1)" ]; then
    echo "already saved -> $DEST"
    shasum -a 256 "$DEST"
    exit 0
  fi
  # Never replace an existing original: keep this copy beside it instead.
  KEEP="$BACKUP/OurTaiko.Runtime.$NAME.pre-$STAMP.dll"
  cp -p "$DLL" "$KEEP"
  echo "kept a differing copy -> $KEEP"
  echo "existing original untouched -> $DEST"
  shasum -a 256 "$DEST"
  echo
  echo "If the copy above is the real unpatched build, install it with:"
  echo "  cp -p \"$KEEP\" \"$DEST\""
  exit 0
fi

cp -p "$DLL" "$DEST"
echo "saved original -> $DEST"
shasum -a 256 "$DEST"
