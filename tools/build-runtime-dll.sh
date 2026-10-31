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
"$HERE/make-result-art.py" "$SRC" "$ART" >/dev/null
FONT="$HERE/../FOT-OedKtrStdE.otf"
[ -f "$FONT" ] || { echo "FOT-OedKtrStdE.otf is required; put it next to tools/" >&2; exit 1; }
RESOURCES=(
  "-resource:$ART/difficulty.zh.png,OurTaiko.Art.difficulty.zh.png"
  "-resource:$ART/difficulty.zh_tw.png,OurTaiko.Art.difficulty.zh_tw.png"
  "-resource:$ART/judge.zh.png,OurTaiko.Art.judge.zh.png"
  "-resource:$ART/judge.zh_tw.png,OurTaiko.Art.judge.zh_tw.png"
  "-resource:$ART/score.zh.png,OurTaiko.Art.score.zh.png"
  "-resource:$ART/score.zh_tw.png,OurTaiko.Art.score.zh_tw.png"
  "-resource:$ART/clear.zh.png,OurTaiko.Art.clear.zh.png"
  "-resource:$ART/clear.zh_tw.png,OurTaiko.Art.clear.zh_tw.png"
  "-resource:$ART/clear_dark.zh.png,OurTaiko.Art.clear_dark.zh.png"
  "-resource:$ART/clear_dark.zh_tw.png,OurTaiko.Art.clear_dark.zh_tw.png"
  "-resource:$FONT,OurTaiko.Art.OedKtrStdE.otf"
)
echo "font   $FONT"

dotnet "$CSC" -nologo -target:library -langversion:9 -nostdlib -optimize+ -debug- \
  -define:UNITY_2023_3_OR_NEWER -define:UNITY_6000_0_OR_NEWER \
  -define:UNITY_STANDALONE -define:UNITY_STANDALONE_OSX -define:ENABLE_MONO \
  "${RESOURCES[@]}" \
  -out:"$OUT/OurTaiko.Runtime.dll" "@$RSP" 2>&1 | grep -v 'warning CS' || true

[ -f "$OUT/OurTaiko.Runtime.dll" ] || { echo "build failed" >&2; exit 1; }
shasum -a 256 "$OUT/OurTaiko.Runtime.dll"
echo "built $OUT/OurTaiko.Runtime.dll"
