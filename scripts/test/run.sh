#!/bin/zsh
# Usage: scripts/test/run.sh <name> "<keys>"  — plays keys on test dirs, writes build/shots/<name>.png
# The interface is English here, whatever language is chosen in OriCmd (UI_LANGUAGE=ru for Russian).
# The app is started in the background (open -g) and never activates itself: the focus stays where it is.
# It restores no windows: after a crash (of a test run or of the user's OriCmd) macOS would ask
# whether to, and the question would stop the run.
set -euo pipefail
setopt nullglob extendedglob
cd "$(dirname $0)/../.."
mkdir -p build/shots
name=${1:?usage: scripts/test/run.sh <name> "<keys>"}; keys=${2:-}
[[ "$name" == [A-Za-z0-9_-]## ]] || { print -u2 "Invalid test name: $name"; exit 2; }
# All worktrees share the test settings suite, so only one UI run may use it.
lock=${TMPDIR:-/tmp}/oricmd-ui-tests.lock
mkdir "$lock" 2>/dev/null || { print -u2 "Another UI test is running ($lock)"; exit 1; }
cleanup() {
  defaults delete ru.themmag.OriCmd.tests 2>/dev/null || true
  rmdir "$lock" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
rm -f "build/shots/$name.png" "build/shots/$name.txt" "build/shots/$name.complete" build/shots/${name}-*
# RIGHT_PANEL: another folder for the right panel (e.g. a path through a symlink).
# ORICMD_DDJVU: the ddjvu that draws DjVu pages (none unless given, whatever is installed).
# ORICMD_UNAR_DIR: where lsar and unar are (for solid RAR 4; none unless given).
# ORICMD_VETO: names copies cannot create, as a server's "veto files" (/.DS_Store/Thumbs.db/).
# APP_ARGS: more arguments for the app, e.g. "-AppleShowScrollBars WhenScrolling" (system
# settings in the app's argument domain only, never written anywhere).
open -g -W -n --env ORICMD_LEFT=$PWD/build/testdata/left --env ORICMD_RIGHT=${RIGHT_PANEL:-$PWD/build/testdata/right} \
  --env ORICMD_SSH_CONFIG=$PWD/build/sshtest/ssh_config --env ORICMD_DDJVU=${ORICMD_DDJVU:-} \
  --env ORICMD_UNAR_DIR=${ORICMD_UNAR_DIR:-} --env ORICMD_VETO=${ORICMD_VETO:-} \
  --env "ORICMD_KEYS=$keys" --env ORICMD_SNAPSHOT=$PWD/build/shots/$name.png --env ORICMD_QUIT=1 \
  build/DerivedData/Build/Products/Debug/OriCmd.app --args -AppleLanguages "(${UI_LANGUAGE:-en})" \
  -ApplePersistenceIgnoreState YES ${=APP_ARGS:-}
[ -s "build/shots/$name.png" ] && [ -f "build/shots/$name.complete" ] || {
  print -u2 "Test $name did not finish and save its snapshot"
  exit 1
}
for f in "build/shots/$name.png" build/shots/${name}-*.png; do
  [ -f $f ] && sips -Z 1100 $f --out $f >/dev/null && echo "saved $f"
done
