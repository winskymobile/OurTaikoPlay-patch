#!/bin/bash
# Rebase the patch onto a newer upstream release and report what still conflicts.
#
#   update-source.sh [upstream-ref] [source-tree]
#
# Defaults: upstream ref = upstream/main
#           source tree  = ../OurTaikoPlay
#
# The patched branch is <branch-name> below; main is never touched.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REF=${1:-upstream/main}
SRC=${2:-$HERE/../OurTaikoPlay}
BRANCH=play-preferences
PATCH="$HERE/../play-preferences.patch"

cd "$SRC"
git fetch upstream --prune --tags 2>&1 | tail -3

echo "== upstream is now =="
git log --oneline -1 "$REF"

git checkout -B "$BRANCH" "$REF" >/dev/null 2>&1
if git apply --3way --check "$PATCH" 2>/dev/null; then
  git apply --3way "$PATCH"
  echo "patch applied cleanly onto $REF"
else
  echo "=== conflicts; resolve these files and re-run build-runtime-dll.sh ==="
  git apply --3way "$PATCH" || true
  git diff --name-only --diff-filter=U
  exit 2
fi
