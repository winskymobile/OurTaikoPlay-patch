#!/bin/bash
# Take the patch from "the app was updated" to "the patched app is installed".
#
#   patch-app.sh [--app <bundle>] [--source <tree>] [--patch <file>] [--upstream <ref>] [--launch]
#                [--from-tree] [--no-fetch] [--no-install]
#
# Steps:
#   1. preflight: the app and its DLL, git, dotnet, a python3 with Pillow
#   2. keep the shipped DLL as backup/OurTaiko.Runtime.<version>.original.dll
#   3. put play-preferences.patch on the current upstream (re-applies it when upstream moved)
#   4. build OurTaiko.Runtime.dll with the app's own Unity assemblies
#   5. gates: serialized field layout against the original, translation table
#   6. install: quit the game, back up, copy, merge settings.json
#
# --from-tree   adopt the source tree as the new patch (after resolving conflicts)
# --patch       patch file to apply and regenerate (default play-preferences.patch)
# --no-fetch    do not fetch upstream (offline, or the ref is already local)
# --no-install  build and check only
#
# Nothing is committed: the patch stays a working-tree diff in the source repo.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PATCH=$ROOT/play-preferences.patch
BRANCH=play-preferences

APP=/Applications/OurTaikoPlay.app
SRC=$ROOT/../OurTaikoPlay
REF=upstream/main
LAUNCH=0
FROM_TREE=0
DO_FETCH=1
DO_INSTALL=1

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --source) SRC=$2; shift 2 ;;
    --patch) PATCH=$2; shift 2 ;;
    --upstream) REF=$2; shift 2 ;;
    --launch) LAUNCH=1; shift ;;
    --from-tree) FROM_TREE=1; shift ;;
    --no-fetch) DO_FETCH=0; shift ;;
    --no-install) DO_INSTALL=0; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The script cds into the source tree later, so take absolute paths up front.
abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(pwd)" "$1" ;; esac; }
APP=$(abspath "$APP")
SRC=$(abspath "$SRC")
PATCH=$(abspath "$PATCH")

# ---------------------------------------------------------------- preflight
step "preflight"

[ -d "$APP" ] || die "no app at $APP"
DLL="$APP/Contents/Resources/Data/Managed/OurTaiko.Runtime.dll"
[ -f "$DLL" ] || die "no $DLL"
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)
say "app       $APP ($VERSION)"

[ -d "$SRC/.git" ] || die "no git repository at $SRC"
[ -f "$PATCH" ] || die "no patch at $PATCH"
command -v dotnet >/dev/null || die "dotnet not found; install the .NET SDK"
command -v git >/dev/null || die "git not found"

# make-result-art.py needs Pillow; pick the first python3 that has it and put it first
# on PATH so the build script's "#!/usr/bin/env python3" finds the same one.
PY=
for candidate in python3 /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import PIL' >/dev/null 2>&1; then PY=$(command -v "$candidate"); break; fi
done
[ -n "$PY" ] || die "no python3 with Pillow; try: /usr/local/bin/python3 -m pip install pillow"
export PATH="$(dirname "$PY"):$PATH"
say "python    $PY"

# ------------------------------------------------------------------- backup
step "keep the shipped DLL"
ORIG="$ROOT/backup/OurTaiko.Runtime.$VERSION.original.dll"
if [ -f "$ORIG" ]; then
  say "already kept $ORIG"
else
  # Only when this version has no original yet: the installed DLL may already be patched.
  "$HERE/save-original.sh" "$APP" "$ROOT/backup"
  [ -f "$ORIG" ] || ORIG=$(ls -t "$ROOT"/backup/*.original.dll | head -1)
fi
say "original  $ORIG"

# -------------------------------------------------------------------- patch
step "put the patch on $REF"

cd "$SRC"
# The tree's remote is "upstream" in the main development checkout and "origin" in the
# per-version shallow clones under tools/build/. Fetch whichever one backs $REF.
if ! git rev-parse --verify "$REF" >/dev/null 2>&1 && [ "${REF#upstream/}" != "$REF" ] \
   && git rev-parse --verify "origin/${REF#upstream/}" >/dev/null 2>&1; then
  say "no $REF here; using origin/${REF#upstream/}"
  REF="origin/${REF#upstream/}"
fi
REMOTE=$(printf '%s' "$REF" | cut -d/ -f1)
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then REMOTE=origin; fi
if [ "$DO_FETCH" = 1 ]; then
  # The repository's own http.proxy is the usual cause of a failed fetch; the shell's
  # proxy and a direct connection are tried in turn. Tags are left alone: an existing
  # release tag in the local clone would make --tags fail for no benefit.
  if ! git fetch "$REMOTE" --prune >/dev/null 2>"$TMP/fetch.err"; then
    PROXY=${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}
    if [ -n "$PROXY" ] && git -c http.proxy="$PROXY" fetch "$REMOTE" --prune >/dev/null 2>&1; then
      say "fetched through $PROXY (the repository's own http.proxy did not work)"
    elif git -c http.proxy= fetch "$REMOTE" --prune >/dev/null 2>&1; then
      say "fetched without a proxy"
    else
      sed 's/^/  /' "$TMP/fetch.err" >&2
      die "could not fetch $REMOTE; fix the proxy (git config http.proxy) or pass --no-fetch"
    fi
  fi
fi
git rev-parse --verify "$REF" >/dev/null 2>&1 || die "unknown ref $REF"
say "upstream  $(git log --oneline -1 "$REF")"

if git diff --quiet "$REF"; then
  say "the tree is clean; applying $PATCH"
  git checkout -B "$BRANCH" "$REF" >/dev/null 2>&1
  if git apply --3way --whitespace=nowarn "$PATCH" >"$TMP/apply.log" 2>&1; then
    say "applied cleanly"
  elif [ -n "$(git diff --name-only --diff-filter=U)" ]; then
    # The whole patch went in, some files with markers: the user resolves them.
    say "conflicts left in:"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    say "resolve them in $SRC, then re-run with --from-tree."
    exit 2
  else
    # Nothing was applied: go file by file so one ported file does not hide the rest.
    say "the patch does not apply as a whole; going file by file"
    grep '^diff --git' "$PATCH" | sed 's|diff --git a/||; s| b/.*||' > "$TMP/files"
    : > "$TMP/report"
    ok=0
    while IFS= read -r f; do
      # Applying 60-odd files in one second leaves stale stat data in the index; without
      # this git reports "does not match index" for files it has not touched.
      git update-index -q --refresh >/dev/null 2>&1 || true
      out=$(git apply --3way --whitespace=nowarn --include="$f" "$PATCH" 2>&1) && { ok=$((ok + 1)); continue; }
      if printf '%s' "$out" | grep -q 'does not match index'; then
        git update-index -q --refresh >/dev/null 2>&1 || true
        if out=$(git apply --3way --whitespace=nowarn --include="$f" "$PATCH" 2>&1); then
          ok=$((ok + 1)); continue
        fi
      fi
      if printf '%s' "$out" | grep -q 'does not exist in index'; then
        printf 'MISSING  %s\n' "$f" >> "$TMP/report"
      elif printf '%s' "$out" | grep -q 'with conflicts'; then
        printf 'CONFLICT %s\n' "$f" >> "$TMP/report"
      else
        printf 'FAILED   %s :: %s\n' "$f" "$(printf '%s' "$out" | head -1)" >> "$TMP/report"
      fi
    done < "$TMP/files"
    say "applied $ok file(s)"
    if [ -s "$TMP/report" ]; then
      say ""
      sed 's/^/  /' "$TMP/report"
      say ""
      say "MISSING  the file no longer exists upstream: port the change into its replacement"
      say "CONFLICT the file applied with markers: resolve them in $SRC"
      say "then re-run with --from-tree to adopt the resolved tree as the patch."
      exit 2
    fi
  fi
else
  # The tree's base is HEAD, not $REF: a fetch may have moved upstream on since the patch was
  # applied, and diffing against the new tip would undo its commits. Staging is what lets new
  # files into the diff; nothing is committed.
  git add -A >/dev/null 2>&1 || true
  git diff --cached HEAD > "$TMP/tree.patch"
  if cmp -s "$TMP/tree.patch" "$PATCH"; then
    say "the patch is already applied to $(git rev-parse --short HEAD)"
  elif [ "$FROM_TREE" = 1 ]; then
    cp "$TMP/tree.patch" "$PATCH"
    say "adopted the working tree as the patch ($(grep -c '^diff --git' "$PATCH") files)"
  else
    say "the working tree has edits that $PATCH does not have"
    die "run with --from-tree to adopt them as the patch (the file is regenerated), or regenerate it yourself"
  fi
fi

# -------------------------------------------------------------------- build
step "build"
"$HERE/build-runtime-dll.sh" "$SRC" "$APP" "$HERE/build"
BUILT="$HERE/build/OurTaiko.Runtime.dll"

# -------------------------------------------------------------------- gates
step "gates"
if ! "$HERE/check-layout.sh" "$ORIG" "$BUILT" > "$TMP/gate.log" 2>&1; then
  tail -6 "$TMP/gate.log"
  say ""
  say "The layout gate failed. If the app was updated since the patch was last rebased, the"
  say "patch is older than the app: fetch upstream, put the patch on the commit that app was"
  say "built from, and build again. Nothing was installed."
  exit 1
fi
tail -3 "$TMP/gate.log"
"$PY" "$HERE/check-translations.py" "$SRC" | tail -2

# ------------------------------------------------------------------ install
if [ "$DO_INSTALL" = 1 ]; then
  step "install"
  was_open=0
  pgrep -f "$APP/Contents/MacOS" >/dev/null 2>&1 && was_open=1
  args=("$BUILT" "$APP" "$ROOT/backup")
  [ "$LAUNCH" = 1 ] && args+=(--launch)
  "$HERE/install.sh" "${args[@]}"
  # Only a game that was already open and could not be closed keeps the old DLL loaded.
  if [ "$was_open" = 1 ] && pgrep -f "$APP/Contents/MacOS" >/dev/null 2>&1; then
    say "note: the game was already open and would not close; the new DLL applies next launch"
  fi
else
  say ""
  say "built $BUILT (not installed)"
fi

step "done"
say "version  $VERSION"
say "dll      $(shasum -a 256 "$BUILT" | cut -d' ' -f1)"
