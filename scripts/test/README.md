# Test scripts

Debug builds of OriCmd can play keystrokes and save window snapshots (see
`OriCmd/App/DebugAutomation.swift`). These scripts drive that on throw-away
folders in `build/testdata` only — never on real files. A test run starts in the
background and never takes the focus (`open -g`, no activation), and it ignores the
real keyboard and mouse, so working elsewhere meanwhile changes nothing.

- `mkdata.sh` — recreates `build/testdata/{left,right}` with sample files and archives.
- `run.sh <name> "<keys>"` — launches the Debug app on the test folders, plays the
  keys (e.g. `"down space f5 wait enter"`, `cmd:cm_SyncDirs`, `click:Background`)
  and writes `build/shots/<name>.png` (plus sheets and other windows, each with a
  `.txt` of its title and texts, and for a text view `[text colors: N]`; `menu` and
  `textmenu` write a context menu to `<name>-menu.txt`). In the Lister of a Debug
  build, test extensions drive the highlighting service: `*.oricmdhang` makes it hang
  (it must be killed), `*.oricmdexit` makes it quit, `*.oricmdoverlap` makes it reply
  overlapping ranges or `*.oricmdlongscope` a huge scope name (OriCmd must refuse
  both), `*.oricmdfiles` / `*.oricmdlookup` / `*.oricmdprefs` ask it to read the
  file / reach the service / write the preferences domain named inside (it must be
  refused); `<name>-highlighter.txt` counts the services killed and the texts sent. `rightmouse:click:N`, `hold:N`, `drag:N-M` and `ctrlclick:N`
  play the right button on panel rows. `crumb:N` / `othercrumb:N` click part N of the active / other
  panel's path (`/` is 0), `pathend` clicks right of it, and `crumbmenu` writes the
  parents a long path puts away into `…` to `<name>-menu.txt` (`crumbmenu:N` chooses one). `volumemenu` writes
  the volume menu of the compact path bar there (`✓ ` before the current volume).
  `drivespace:free` / `drivespace:total` click the capacity readout,
  `otherdrivespace:free` clicks the inactive panel's readout, and `axdrivespace`
  presses its accessible button. These write activation state to
  `<name>-drive-space.txt` and the requested volume paths to `<name>-info.txt`;
  test runs record Get Info requests instead of opening Finder windows.
  `tabhover:N` shows the active panel's tab N as under the mouse (its close button),
  `tabclose:N` clicks that button, and `tabbar` writes where its tabs are drawn
  ("index from to", `*` after the selected one) after the part of the bar they show in
  ("shown from to") to `<name>-tabbar.txt`. `columns` writes the active panel's Full view
  columns (`column x width`) to `<name>-columns.txt`; `headerdrag:size:-30` drags
  the edge right of a column title, `headerdoubleclick:size` double-clicks it (the
  measured width again) and `headerclick:date` clicks a title.
  `set:identifier=value` sets a control found by its
  identifier as the user would (a field, a pop-up item, a checkbox `on`/`off`/`mixed`,
  a date `2026-01-31`), `click:` also chooses a tab; the rows of a table drawn by
  cells (Find Files results) go to the window's `.txt` as `[row] …` lines.
  Modifiers: `cmd+`, `shift+`, `alt+`, `ctrl+`, `num+`; `ru+` types the key as the
  Russian layout would (`ru+ctrl+d` sends "в" with the D key code).
- `regress.sh` — plays the main file operations and checks the results on disk.
- `../screenshots.sh` — regenerates the README screenshots (`docs/screenshots/en`) on demo
  folders from `../mkdemo.sh`, in the dark theme and British region formats;
  `ORICMD_DEMO=<demo folder>` hides all volumes but the startup disk, puts the
  sidebar's home folder and Downloads in the demo folder, names the tags in English
  and pictures windows and sheets as the window server shows them, so the glass, the
  toolbar's icons and the sidebar appear. A window that cannot be pictured so leaves
  no picture and its reason in `build/shots/readme/capture.log`, and the script fails.
  Test runs never use or change the saved window frames.
- `loc.py [translations.json]` — lists localization keys missing from the catalog,
  or adds Russian translations from a JSON file.

Build the Debug app first (`xcodebuild … -derivedDataPath build/DerivedData build`).

## Core checks and continuous integration

`scripts/test/check.sh` builds the app, runs the independent `OriCmdCoreTests`
logic-test target, and checks for missing translations. The tests use temporary
folders and do not launch the file manager or use either settings suite. They
cover masks, filters, renaming masks, diff alignment, Unicode ranges, verified
copies, skipped moves, cancellation and self-copy protection.

Pushes and pull requests run these checks on macOS. Scheduled and manually
started workflows also run the full interface regressions and save their logs
and snapshots. Interface runs are sequential because they share the test suite.

`run.sh` refuses overlapping UI runs, removes all artifacts for that run's name,
and requires both a fresh snapshot and the completion marker written after key
playback. Launch failures, crashes, missing snapshots and timeouts fail the
regression run; the individual launcher logs are in `build/testlogs`. If a runner
is killed with SIGKILL, remove the stale `oricmd-ui-tests.lock` folder in the
user's temporary directory only after confirming no UI test is still running.

`accessibility.sh` exercises the file list's accessible rows in Full, Brief and
Thumbnails views, selection, refresh identity and stale-row safety, then uses Pick
and Press on disposable files and folders. `accessibilitycheck` writes its API
checks to `<name>-accessibility.txt`; `accessibilitydump` writes row descriptions
and selection there. `axpick:filename` selects a row and `axpress:filename` opens it.

`ux-copy.sh` verifies dialog scope, filename previews, overwrite summaries, file filters, F2 queue and the Russian interface.

`ux-selection.sh` captures checkmarks in Full, Brief and Thumbnails views and checks that accessible selection is preserved when markers are disabled.

`ux-filters.sh` checks combined text and mask rules, match counts, clearing and Escape, both header styles and Russian labels. `filterdump` writes the active summary; `clearfilters` clicks the header’s clear button.

`ux-operations.sh` checks session history, skips, cancellation from the Operations
window while an overwrite question is open, and clearing completed results. The
core test target also checks cancellation of a waiting job before execution,
continued queue processing, and retention of running jobs when history is cleared.
`tablepick:N` in the Debug harness selects a row in the frontmost window's table.

`ux-palette.sh` checks search, keyboard execution, Escape, empty results, imported shortcuts and Russian command names.
