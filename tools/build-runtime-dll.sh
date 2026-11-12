#!/bin/bash
# Rebuild OurTaiko.Runtime.dll from a patched source tree, using the Unity managed
# assemblies that ship inside an installed OurTaikoPlay.app (no Unity Editor needed).
#
#   build-runtime-dll.sh [source-tree] [app] [output-dir]
#
# Defaults: source tree  = ../OurTaikoPlay
#           app          = /Applications/OurTaikoPlay.app
#           output dir   = <script dir>/build
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$HERE/../OurTaikoPlay}
APP=${2:-/Applications/OurTaikoPlay.app}
OUT=${3:-$HERE/build}
MANAGED="$APP/Contents/Resources/Data/Managed"

[ -d "$SRC/Assets/OurTaiko/Runtime" ] || { echo "no Assets/OurTaiko/Runtime in $SRC" >&2; exit 1; }
[ -d "$MANAGED" ] || { echo "no Managed assemblies in $APP" >&2; exit 1; }

CSC=$(find "${DOTNET_ROOT:-/opt/homebrew/Cellar/dotnet}" -path '*/Roslyn/bincore/csc.dll' 2>/dev/null | sort | tail -1)
if [ -z "$CSC" ]; then
  CSC=$(find /usr/local/share/dotnet /opt/homebrew/share/dotnet -path '*/Roslyn/bincore/csc.dll' 2>/dev/null | sort | tail -1)
fi
[ -n "$CSC" ] || { echo "csc.dll not found; install the .NET SDK" >&2; exit 1; }

mkdir -p "$OUT"
RSP="$OUT/runtime.rsp"
{
  # OurTaiko.Runtime itself must not be referenced: it is what gets rebuilt.
  find "$MANAGED" -maxdepth 1 -name '*.dll' ! -name 'OurTaiko.Runtime.dll' | sort | sed 's/^/-r:/'
  find "$SRC/Assets/OurTaiko/Runtime" -name '*.cs' | sort
} > "$RSP"

# The result board paints its difficulty tabs and judge labels into sprites that the runtime
# swaps for Simplified/Traditional copies in FOT-OedKtr Std E. Simplified and Traditional text
# also use that font, so both the art and the font are embedded in the DLL.
ART="$OUT/art"
rm -rf "$ART"
mkdir -p "$ART"
[ -f "$SRC/Assets/OurTaiko/Runtime/Scenes/ResultArt.cs" ] \
  && "$HERE/make-result-art.py" "$SRC" "$ART" >/dev/null
# 段位道場's 合格条件 labels and tab are painted art too (simplified/traditional copies).
[ -f "$SRC/Assets/OurTaiko/Runtime/Scenes/DanExamArt.cs" ] \
  && "$HERE/make-dan-exam-art.py" "$SRC" "$ART" >/dev/null
FONT="$HERE/../FOT-OedKtrStdE.otf"
RESOURCES=()
for art in difficulty judge score clear clear_dark; do
  for lang in zh zh_tw; do
    [ -f "$ART/$art.$lang.png" ] \
      && RESOURCES+=("-resource:$ART/$art.$lang.png,OurTaiko.Art.$art.$lang.png")
  done
done
if [ -f "$SRC/Assets/OurTaiko/Runtime/Core/InGameFont.cs" ]; then
  [ -f "$FONT" ] || { echo "FOT-OedKtrStdE.otf is required; put it next to tools/" >&2; exit 1; }
  RESOURCES+=("-resource:$FONT,OurTaiko.Art.OedKtrStdE.otf")
  echo "font   $FONT"
fi
for art in "$ART"/exam_*.png "$ART"/confirm_*.png; do
  [ -f "$art" ] && RESOURCES+=("-resource:$art,OurTaiko.Art.$(basename "$art")")
done

# A stale DLL from an earlier build must never pass for a successful one.
rm -f "$OUT/OurTaiko.Runtime.dll"
set +e
dotnet "$CSC" -nologo -target:library -langversion:9 -nostdlib -optimize+ -debug- \
  -define:UNITY_2023_3_OR_NEWER -define:UNITY_6000_0_OR_NEWER \
  -define:UNITY_STANDALONE -define:UNITY_STANDALONE_OSX -define:ENABLE_MONO \
  ${RESOURCES[@]+"${RESOURCES[@]}"} \
  -out:"$OUT/OurTaiko.Runtime.dll" "@$RSP" > "$OUT/compile.log" 2>&1
STATUS=$?
set -e
grep -v 'warning CS' "$OUT/compile.log" | grep -E 'error|warning CS8' || true
if [ "$STATUS" -ne 0 ] || [ ! -f "$OUT/OurTaiko.Runtime.dll" ]; then
  echo "build failed (csc exit $STATUS); see $OUT/compile.log" >&2
  exit 1
fi
shasum -a 256 "$OUT/OurTaiko.Runtime.dll"
echo "built $OUT/OurTaiko.Runtime.dll"
