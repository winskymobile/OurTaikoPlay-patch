#!/bin/bash
# Compare the serialized field layout of two OurTaiko.Runtime.dll builds.
# Adding a serialized field to an existing MonoBehaviour shifts the layout of that
# component inside the shipped data.unity3d and crashes Unity when the scene loads
# ("The file 'level2' is corrupted"). This gate fails on any such change.
#
#   check-layout.sh [original.dll] [built.dll]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ORIG=${1:-$HERE/../backup/OurTaiko.Runtime.1.0-349.original.dll}
NEW=${2:-$HERE/build/OurTaiko.Runtime.dll}

[ -f "$ORIG" ] || { echo "no original dll at $ORIG" >&2; exit 1; }
[ -f "$NEW" ] || { echo "no built dll at $NEW (run build-runtime-dll.sh first)" >&2; exit 1; }

cd "$HERE/fieldcheck"
dotnet run -- "$ORIG" "$NEW"
