#!/bin/bash
# Take OurTaikoPlay from "the app was updated" to "the selected patch modules are installed".
#
#   patch-app.sh [--app <bundle>] [--source <tree>] [--patchset <dir>]
#                [--preset <name>] [--with <ids>] [--without <ids>]
#                [--patch <file>] [--upstream <ref>] [--launch]
#                [--from-tree] [--no-fetch] [--no-install] [--list] [--yes]
#
# Patch sets live in patches/<app version>/manifest.txt. Each module is a normal
# git patch cut against the manifest's base commit, and modules are applied in
# manifest order. A module may require another module; --with adds dependencies.
#
#   --list        show the patch sets, presets and modules, then exit
#   --preset      core (default), full, data-only, language-only, or a name in the manifest
#   --with        add modules (comma or space separated)
#   --without     remove modules after dependencies are resolved
#   --patch       legacy single-patch mode (the old play-preferences-*.patch flow)
#   --from-tree   use the source tree as-is (after resolving conflicts by hand)
#
# Nothing is committed: the selected modules stay as a working-tree diff.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
BRANCH=

APP=/Applications/OurTaikoPlay.app
SRC=$ROOT/../OurTaikoPlay
SRC_EXPLICIT=0
REF=upstream/main
PATCHSET=
PATCH=
PRESET=
WITH=
WITHOUT=
LAUNCH=0
FROM_TREE=0
DO_FETCH=1
DO_INSTALL=1
DO_LIST=0
ASSUME_YES=0

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP=$2; shift 2 ;;
    --source) SRC=$2; SRC_EXPLICIT=1; shift 2 ;;
    --patchset) PATCHSET=$2; shift 2 ;;
    --patch) PATCH=$2; shift 2 ;;
    --preset) PRESET=$2; shift 2 ;;
    --with) WITH=$2; shift 2 ;;
    --without) WITHOUT=$2; shift 2 ;;
    --upstream) REF=$2; shift 2 ;;
    --launch) LAUNCH=1; shift ;;
    --from-tree) FROM_TREE=1; shift ;;
    --no-fetch) DO_FETCH=0; shift ;;
    --no-install) DO_INSTALL=0; shift ;;
    --list) DO_LIST=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

abspath() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(pwd)" "$1" ;; esac; }
APP=$(abspath "$APP")
SRC=$(abspath "$SRC")
[ -n "$PATCHSET" ] && PATCHSET=$(abspath "$PATCHSET")
[ -n "$PATCH" ] && PATCH=$(abspath "$PATCH")

split_words() { printf '%s\n' "$1" | tr ',' ' '; }

# A base is either "remote/ref" or a bare commit. Bare commits come from the
# upstream repository (the fork only carries patch work).
base_remote() {
  local base=$1 remote url
  case "$base" in
    */*) printf '%s' "${base%%/*}"; return ;;
  esac
  for remote in $(git remote); do
    url=$(git remote get-url "$remote" 2>/dev/null || true)
    case "$url" in
      *OurTaiko/OurTaikoPlay*) printf '%s' "$remote"; return ;;
    esac
  done
  if git remote get-url upstream >/dev/null 2>&1; then printf 'upstream'; return; fi
  printf 'origin'
}

# ---------------------------------------------------------------- preflight
step "preflight"

[ -d "$APP" ] || die "no app at $APP"
DLL="$APP/Contents/Resources/Data/Managed/OurTaiko.Runtime.dll"
[ -f "$DLL" ] || die "no $DLL"
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)
say "app       $APP ($VERSION)"
BRANCH="play-preferences-$VERSION"

# Prefer the version worktree over a checkout that is on another branch or has
# uncommitted edits. An explicit --source always wins.
if [ "$SRC_EXPLICIT" = 0 ]; then
  CANDIDATE="$ROOT/tools/build/source-$VERSION"
  if [ -d "$CANDIDATE" ] && git -C "$CANDIDATE" rev-parse --git-dir >/dev/null 2>&1; then
    if ! git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 \
      || [ -n "$(git -C "$SRC" status --porcelain 2>/dev/null)" ]; then
      SRC=$CANDIDATE
    fi
  fi
fi

git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || die "no git repository at $SRC"
say "source    $SRC"
command -v dotnet >/dev/null || die "dotnet not found; install the .NET SDK"
command -v git >/dev/null || die "git not found"

PY=
for candidate in python3 /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'import PIL' >/dev/null 2>&1; then PY=$(command -v "$candidate"); break; fi
done
[ -n "$PY" ] || die "no python3 with Pillow; try: /usr/local/bin/python3 -m pip install pillow"
export PATH="$(dirname "$PY"):$PATH"
say "python    $PY"

# --------------------------------------------------------------- patch sets
find_patchset() {
  [ "$FROM_TREE" = 1 ] && return
  if [ -n "$PATCHSET" ]; then
    [ -f "$PATCHSET/manifest.txt" ] || die "no manifest at $PATCHSET/manifest.txt"
    return
  fi
  if [ -d "$ROOT/patches/$VERSION" ] && [ -f "$ROOT/patches/$VERSION/manifest.txt" ]; then
    PATCHSET=$ROOT/patches/$VERSION
    return
  fi
  [ -n "$PATCH" ] && return
  local available
  available=$(find "$ROOT/patches" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -V | tr '\n' ' ')
  die "no patch set for $VERSION; available: ${available:-none}. Use --patchset <dir> or --patch <file>."
}

print_patchset() {
  local dir=$1 manifest=$1/manifest.txt
  local base id file req title pname pids
  base=$(awk -F'|' '$1=="base"{print $2; exit}' "$manifest")
  printf 'Patch set %s (base %s)\n' "$(basename "$dir")" "${base:-unknown}"
  printf '  presets:\n'
  while IFS='|' read -r kind pname pids; do
    [ "$kind" = "preset" ] || continue
    printf '    %-16s %s\n' "$pname" "$pids"
  done < "$manifest"
  printf '  modules:\n'
  while IFS='|' read -r kind id file req title; do
    [ "$kind" = "module" ] || continue
    printf '    %-18s %s' "$id" "$title"
    [ -n "$req" ] && printf '  (requires: %s)' "$req"
    printf '\n'
  done < "$manifest"
}

if [ "$DO_LIST" = 1 ]; then
  step "patch sets"
  if [ -n "$PATCHSET" ]; then
    print_patchset "$PATCHSET"
  elif [ -d "$ROOT/patches/$VERSION" ]; then
    print_patchset "$ROOT/patches/$VERSION"
  else
    for d in "$ROOT"/patches/*; do
      [ -d "$d" ] && print_patchset "$d" && printf '\n'
    done
  fi
  exit 0
fi

find_patchset

BASE=
MODULES=$TMP/modules
PRESETS=$TMP/presets
: > "$MODULES"
: > "$PRESETS"
if [ -n "$PATCHSET" ]; then
  MANIFEST=$PATCHSET/manifest.txt
  while IFS='|' read -r kind a b c d; do
    case "$kind" in
      ''|'#'*) continue ;;
      base) BASE=$a ;;
      preset) printf '%s|%s\n' "$a" "$b" >> "$PRESETS" ;;
      module) printf '%s|%s|%s|%s\n' "$a" "$b" "$c" "$d" >> "$MODULES" ;;
    esac
  done < "$MANIFEST"
else
  BASE=$REF
fi

module_file() { awk -F'|' -v id="$1" '$1==id{print $2; exit}' "$MODULES"; }
module_reqs() { awk -F'|' -v id="$1" '$1==id{print $3; exit}' "$MODULES"; }
module_title() { awk -F'|' -v id="$1" '$1==id{print $4; exit}' "$MODULES"; }
preset_ids() { awk -F'|' -v p="$1" '$1==p{print $2; exit}' "$PRESETS"; }

expand_ids() {
  local token ids
  for token in $1; do
    ids=$(preset_ids "$token")
    if [ -n "$ids" ]; then expand_ids "$ids"; else printf '%s\n' "$token"; fi
  done
}

print_selection() {
  local id file req title
  printf '  %-18s %s\n' "id" "module"
  while IFS='|' read -r id file req title; do
    grep -qx "$id" "$TMP/selected.ordered" || continue
    printf '  %-18s %s\n' "$id" "$title"
  done < "$MODULES"
}

if [ "$FROM_TREE" = 0 ]; then
if [ -n "$PATCH" ]; then
  [ -f "$PATCH" ] || die "no patch at $PATCH"
  printf '%s\n' legacy > "$TMP/selected.ordered"
else
  REQUESTED=$TMP/requested
  : > "$REQUESTED"
  if [ -n "$PRESET" ]; then
    ids=$(preset_ids "$PRESET")
    if [ -n "$ids" ]; then expand_ids "$ids" >> "$REQUESTED"; else expand_ids "$PRESET" >> "$REQUESTED"; fi
  fi
  if [ -n "$WITH" ]; then
    for id in $(split_words "$WITH"); do
      ids=$(preset_ids "$id")
      if [ -n "$ids" ]; then expand_ids "$ids" >> "$REQUESTED"; else printf '%s\n' "$id" >> "$REQUESTED"; fi
    done
  fi
  if [ ! -s "$REQUESTED" ]; then
    if [ "$ASSUME_YES" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
      printf '\nSelect modules:\n'
      print_patchset "$PATCHSET" | sed 's/^/  /'
      printf '\nPreset or module ids (comma separated), or Enter for core: '
      read -r answer
      [ -z "$answer" ] && answer=core
      ids=$(preset_ids "$answer")
      if [ -n "$ids" ]; then expand_ids "$ids" >> "$REQUESTED"; else expand_ids "$answer" >> "$REQUESTED"; fi
    else
      expand_ids "$(preset_ids core)" >> "$REQUESTED"
    fi
  fi

  # dependencies
  changed=1
  while [ "$changed" = 1 ]; do
    changed=0
    for id in $(sort -u "$REQUESTED"); do
      for req in $(module_reqs "$id"); do
        if ! grep -qx "$req" "$REQUESTED"; then printf '%s\n' "$req" >> "$REQUESTED"; changed=1; fi
      done
    done
  done

  # --without, then make sure nothing selected still needs a removed module
  : > "$TMP/removed"
  for id in $(split_words "$WITHOUT"); do printf '%s\n' "$id" >> "$TMP/removed"; done
  : > "$TMP/selected"
  for id in $(sort -u "$REQUESTED"); do
    grep -qx "$id" "$TMP/removed" || printf '%s\n' "$id" >> "$TMP/selected"
  done
  : > "$TMP/selected.ordered"
  while IFS='|' read -r id file req title; do
    grep -qx "$id" "$TMP/selected" || continue
    for r in $(module_reqs "$id"); do
      if grep -qx "$r" "$TMP/removed"; then
        die "$id needs $r; remove it from --without or remove $id too"
      fi
    done
    printf '%s\n' "$id" >> "$TMP/selected.ordered"
  done < "$MODULES"
  [ -s "$TMP/selected.ordered" ] || die "no modules selected"
fi
fi

step "selected"
if [ "$FROM_TREE" = 1 ]; then
  say "  source tree as-is  $SRC"
elif [ -n "$PATCH" ]; then
  say "  legacy single patch  $PATCH"
else
  print_selection
fi

# ------------------------------------------------------------------- backup
step "keep the shipped DLL"
ORIG="$ROOT/backup/OurTaiko.Runtime.$VERSION.original.dll"
if [ -f "$ORIG" ]; then
  say "already kept $ORIG"
else
  "$HERE/save-original.sh" "$APP" "$ROOT/backup"
  [ -f "$ORIG" ] || ORIG=$(ls -t "$ROOT"/backup/*.original.dll | head -1)
fi
say "original  $ORIG"

# -------------------------------------------------------------------- apply
cd "$SRC"
if [ "$FROM_TREE" = 0 ]; then
  step "apply patches on $BASE"
  if [ "$DO_FETCH" = 1 ]; then
    REMOTE=$(base_remote "$BASE")
    if ! git fetch "$REMOTE" --prune >/dev/null 2>"$TMP/fetch.err"; then
      PROXY=${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}
      if [ -n "$PROXY" ] && git -c http.proxy="$PROXY" fetch "$REMOTE" --prune >/dev/null 2>&1; then
        say "fetched through $PROXY"
      elif git -c http.proxy= fetch "$REMOTE" --prune >/dev/null 2>&1; then
        say "fetched without a proxy"
      else
        sed 's/^/  /' "$TMP/fetch.err" >&2
        die "could not fetch $REMOTE; fix the proxy or pass --no-fetch"
      fi
    fi
  fi
  git rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1 || die "unknown base $BASE"
  [ -z "$(git status --porcelain)" ] || die "the source tree has local changes; commit/stash them or use --from-tree"
  git checkout -B "$BRANCH" "$BASE" >/dev/null 2>&1
  say "base      $(git log --oneline -1)"

  if [ -n "$PATCH" ]; then
    if ! git apply --3way --whitespace=nowarn "$PATCH" >"$TMP/apply.log" 2>&1; then
      sed 's/^/  /' "$TMP/apply.log" >&2
      die "the single patch did not apply"
    fi
    say "applied   $(grep -c '^diff --git' "$PATCH") files"
  else
    while read -r id; do
      file=$(module_file "$id")
      [ -f "$PATCHSET/$file" ] || die "missing patch $PATCHSET/$file"
      if ! git apply --3way --whitespace=nowarn "$PATCHSET/$file" >"$TMP/apply.log" 2>&1; then
        sed 's/^/  /' "$TMP/apply.log" >&2
        die "$id did not apply; resolve in $SRC, then re-run with --from-tree"
      fi
      say "applied   $id"
    done < "$TMP/selected.ordered"
  fi
else
  step "use the source tree"
  say "adopted   $(git rev-parse --short HEAD) + working tree"
fi

# -------------------------------------------------------------------- build
step "build"
OUT="$ROOT/tools/build/$VERSION"
"$HERE/build-runtime-dll.sh" "$SRC" "$APP" "$OUT"
BUILT="$OUT/OurTaiko.Runtime.dll"

# -------------------------------------------------------------------- gates
step "gates"
if ! "$HERE/check-layout.sh" "$ORIG" "$BUILT" > "$TMP/gate.log" 2>&1; then
  tail -8 "$TMP/gate.log"
  say ""
  say "The layout gate failed. Rebase the patch set onto the commit the app was built from."
  say "Nothing was installed."
  exit 1
fi
tail -3 "$TMP/gate.log"
if [ -f "$SRC/Assets/OurTaiko/Runtime/Core/UiText.cs" ]; then
  "$PY" "$HERE/check-translations.py" "$SRC" | tail -2
else
  say "translations skipped (interface-language not selected)"
fi

# ------------------------------------------------------------------ install
if [ "$DO_INSTALL" = 1 ]; then
  step "install"
  was_open=0
  pgrep -f "$APP/Contents/MacOS" >/dev/null 2>&1 && was_open=1
  args=("$BUILT" "$APP" "$ROOT/backup")
  [ "$LAUNCH" = 1 ] && args+=(--launch)
  "$HERE/install.sh" "${args[@]}"
  if [ "$was_open" = 1 ] && pgrep -f "$APP/Contents/MacOS" >/dev/null 2>&1; then
    say "note: the game was already open and did not close; the new DLL applies next launch"
  fi
else
  say ""
  say "built $BUILT (not installed)"
fi

step "done"
say "version  $VERSION"
say "dll      $(shasum -a 256 "$BUILT" | cut -d' ' -f1)"
