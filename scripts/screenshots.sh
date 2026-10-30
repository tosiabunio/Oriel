#!/bin/zsh
# Regenerates the README screenshots in docs/screenshots/en: plays key scenarios
# on demo folders (/tmp/OriCmd, removed afterwards) in English with British region
# formats, in the dark theme. Windows are captured as the window server shows them;
# a window that cannot be captured so is reported and the script fails.
# Needs the Debug build (see scripts/test/README.md).
setopt nullglob
cd "$(dirname $0)/.."
D=/tmp/OriCmd
P=$D/Projects/OriCmd
OUT=docs/screenshots
SHOTS=build/shots/readme
APP=build/DerivedData/Build/Products/Debug/OriCmd.app/Contents/MacOS/OriCmd
LOG=$SHOTS/capture.log
mkdir -p $OUT $SHOTS
: > $LOG
FAILED=0
scripts/mkdemo.sh $D >/dev/null

# File colors by type, as in the examples of the File Colors window.
RULES=$(python3 -c 'import json; print(json.dumps([
  {"mask": "*.zip;*.dmg", "color": "#B7791F"},
  {"mask": "*.jpg;*.png;*.heic", "color": "#8E44AD"},
  {"mask": "*.mp3;*.mov", "color": "#2980B9"},
  {"mask": "*.sh", "color": "#27AE60"}]).encode().hex())')

# shot <name> <left> <right> <keys> [VAR=value…] — in the language $UI
shot() {
  local name=$1 left=$2 right=$3 keys=$4; shift 4
  rm -f $SHOTS/$name*.png
  defaults delete ru.themmag.OriCmd.tests 2>/dev/null
  defaults write ru.themmag.OriCmd.tests FileColorRules -data $RULES
  # Dark, whatever the system appearance.
  defaults write ru.themmag.OriCmd.tests Appearance dark
  # A hotlist of demo folders for the sidebar.
  defaults write ru.themmag.OriCmd.tests DirectoryHotlist -array "$P" "$D/Backup"
  env ORICMD_DEMO=$D ORICMD_LEFT=$left ORICMD_RIGHT=$right "ORICMD_KEYS=$keys" \
    ORICMD_SNAPSHOT=$PWD/$SHOTS/$name.png ORICMD_QUIT=1 "$@" $APP -AppleLanguages "($UI)" -AppleLocale $LOCALE 2>&1 >/dev/null |
    grep '^Window capture failed' >> $LOG
  defaults delete ru.themmag.OriCmd.tests 2>/dev/null
}

# publish <snapshot> <name> <width>
publish() {
  [ -f $SHOTS/$1 ] || { echo "missing $1"; FAILED=1; return }
  mkdir -p $OUT/$UI
  sips -Z $3 $SHOTS/$1 --out $OUT/$UI/$2 >/dev/null && echo "$OUT/$UI/$2"
}

# The English set for README.md.
for UI in en; do
  case $UI in
    en) LOCALE=en_GB; OPTIONS="Options"; COMPARE=Compare; MASK="Holiday_[C]" ;;
  esac
  shot main $P $D/Downloads \
    "cmd+t wait home down enter wait ctrl+tab wait alt+l wait text:ICENSE escape insert alt+p wait text:ackage escape insert alt+r wait text:EADME escape wait"
  shot copy $P $D/Downloads "alt+i wait text:con escape insert insert insert f5 wait click:$OPTIONS wait wait"
  shot compare $P $D/Backup/OriCmd \
    "alt+n wait text:otes escape tab alt+n wait text:otes escape tab cmd:cm_CompareFilesByContent wait wait wait"
  shot sync $P $D/Backup/OriCmd "cmd:cm_SyncDirs wait click:$COMPARE wait wait wait"
  shot rename $D/Downloads $P "alt+i wait text:MG escape insert insert insert insert insert insert ctrl+m wait text:$MASK wait wait"
  shot settings $P $D/Downloads "cmd:showSettings wait wait" ORICMD_SETTINGS_TAB=3
  shot thumbs $D/Downloads $P "cmd:cm_SrcThumbs wait wait wait"

  publish main.png main.png 1600
  publish copy-sheet.png copy-dialog.png 1100
  publish compare-win1.png compare.png 1400
  publish sync-win1.png sync.png 1400
  publish rename-win1.png multi-rename.png 1400
  publish settings-win1.png settings.png 1000
  publish thumbs.png thumbnails.png 1400
done
rm -rf $D
[ -s $LOG ] && { cat $LOG; FAILED=1 }
exit $FAILED
