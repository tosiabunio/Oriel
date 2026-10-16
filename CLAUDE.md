# Oriel — tosiabunio's fork of OriCmd

A two-panel file manager for macOS in the style of Total Commander. Since 2026-10-07
the fork's visible name is **Oriel** (see "Visible rename to Oriel" below); the
repository, project, target, module, executable, bundle ID and source keep OriCmd.
It is written in Swift and AppKit, without SwiftUI. The interface is in English and
Russian. See `README.md` for what the app does and which keys it uses.

The user intends this fork to remain an independent project. Selected changes
from `mmag/OriCmd` may be imported, but a merge of the fork back upstream is not
planned. Preserve upstream attribution and direct installation and contributions
to `tosiabunio/Oriel` (the fork's repository, named `tosiabunio/OriCmd` until
2026-10-07; GitHub redirects the old address, so older links below still work).

## This file

Since 2026-10-07 CLAUDE.md is part of the repository (the user's choice: Claude is
the fork's main contributor). It is public on GitHub, so keep secrets and personal
data out of it (key contents, email addresses, account names, home-folder paths).
The main checkout (the repository root) stays on `main`; update CLAUDE.md there and
commit it with the work it describes (it travels with `main` and `local-build`).
Feature branches still live in worktrees under `build/`. Releases run from the main
checkout, where `scripts/release.sh` finds the signing key at its default path; the
former `build/rel` worktree is gone. Entries below that say the primary checkout is
on `key-caps` or that releases ran from `build/rel` describe how it was then.

The fork uses calendar versions `YEAR.MONTH.RELEASE`, starting with `2026.10.0`.
Increment RELEASE for another release in the same month and start at 0 for the
first release of a new month. Use a four-digit year and an unpadded month (1–12).
Version changes are explicit, not based on the date of every build. Preserve this
numbering during upstream imports; record upstream versions/commits separately.
The app's internal build number and the local install counter keep increasing.

## Environment on this machine

- Xcode 27.0 is installed in `/Applications/Xcode.app`. It is the active developer
  directory (set with `xcode-select`) and its licence has been accepted.
- The project needs Xcode 16 or later (`objectVersion = 77`), macOS 14 or later
  (`MACOSX_DEPLOYMENT_TARGET = 14.0`) and Swift 6.0.
- Dependencies:
  - **SwiftTerm**, a Swift package pinned to an exact version. Xcode downloads it on
    the first build, which needs access to GitHub.
  - **libarchive**, the copy built into macOS (`/usr/lib/libarchive.2.dylib`).
    `CLibArchive/` holds the declarations OriCmd uses, because the SDK ships no
    headers for it. Nothing needs installing, and Homebrew's libarchive is not used.
- Signing is ad hoc (`CODE_SIGN_IDENTITY = "-"`) and needs no team or certificate.
- `sudo` cannot read a password through the `!` prefix. When a command needs admin
  rights, run it through
  `osascript -e 'do shell script "…" with administrator privileges'`, which shows the
  system password dialog.

## Building

`build/` is ignored by git. Put all build output in it.

```sh
# Debug build, the one the test scripts use
xcodebuild -project OriCmd.xcodeproj -scheme OriCmd -configuration Debug \
  -derivedDataPath build/DerivedData build
# → build/DerivedData/Build/Products/Debug/OriCmd.app

# Release build for both Apple Silicon and Intel, as scripts/make-dmg.sh makes it
xcodebuild -project OriCmd.xcodeproj -scheme OriCmd -configuration Release \
  -derivedDataPath build/release/DerivedData ONLY_ACTIVE_ARCH=NO build
# → build/release/DerivedData/Build/Products/Release/OriCmd.app
```

The output of `xcodebuild` is long. Send it to a log file and search the log for
`error:`, `warning:` and `BUILD (SUCCEEDED|FAILED)`. Two warnings are known and can be
ignored:
- a `weak var` that could be `let` in `Viewer/ListerWindowController.swift:489`
- "Metadata extraction skipped" from the App Intents step

## Installing the custom build

The user runs their own build from `/Applications/Oriel.app` (`OriCmd.app` before
2026-10-07) instead of the official release.
- The Homebrew cask `mmag/tap/oricmd` has been uninstalled so that `brew upgrade`
  does not replace the custom build.
- The user's settings are in `~/Library/Preferences/io.github.tosiabunio.oriel.plist`
  since fork build 39 (copied once from `ru.themmag.OriCmd.plist`, which stays). Do
  not delete either. Do not use `brew uninstall --zap`, because it deletes them.

`/Applications/Oriel.app` is built from the branch `local-build`, which is pushed
only to the fork, never sent upstream. It is a merge of the feature branches (see "Work in progress"), checked
out as a git worktree in `build/local-build`. After a feature branch changes, merge it
there (`git -C build/local-build merge <branch>`), then build and install from that
worktree. Install with `build/local-build/scripts/install-local.sh` (from the `fork-about`
branch). It makes the Release build, quits only the installed copy (`pkill -x OriCmd`
would also kill a test run's Debug app) and installs it. It also numbers the build:
the counter is in `.git/oricmd-fork-build`, shared by all worktrees, and goes up by one
on every install. About shows the calendar version with this number in
parentheses, and "OriCmd fork" below ("tosiabunio fork" before 2026-10-07). Its icon, app name, copyright and full
dependency notices remain visible, with clickable original-project, fork and
dependency links. The commit (with `+` for an uncommitted checkout) stays in
bundle metadata for diagnostics. While tests run, start the
installer with `nice -n 19`.

- The app's own updater (`App/Updater.swift`) checks the fork's GitHub Releases
  (`tosiabunio/Oriel`) once a day and asks before installing. It verifies an Ed25519
  manifest against `OriCmd/UpdateSigningPublicKey.txt`, then the image's size and
  SHA-256 before mounting. Unsigned releases offer their browser page instead.
  The check can be turned off in Settings → General.
- The private update publishing key is in the primary checkout at
  `build/update-signing/private.key` (0600), with a copy in the
  `build/review-updates` worktree. Both are ignored by Git. Preserve the key before
  cleaning build directories; never commit it or include it in the app. Publishing
  from another worktree needs `ORICMD_UPDATE_SIGNING_KEY` set to this path. See
  `docs/authenticated-updates.md` on `local-build`.
- To go back to the official app: `brew install --cask --force mmag/tap/oricmd`.
- `brew cat` turns on Homebrew's developer mode as a side effect. Run
  `brew developer off` afterwards.

## Code layout (`OriCmd/`)

- `App/`: the app delegate, main menu, `Settings.swift` (preferences),
  `AppDefaults.swift` (the settings store; test runs use a separate suite),
  `Updater.swift` and `DebugAutomation.swift` (key playback for tests).
- `Panel/`: the file panels. `FileListView.swift` draws the Full, Brief and Thumbnails
  views; `FileListView+Accessibility.swift` exposes their rows and actions.
  `FilePanelController.swift` handles panel lifecycle and loading folders; its
  `+Locations`, `+Tabs`, `+Archives` and `+Transfers` extensions group related state
  and operations. See `docs/panel-controller.md` on `local-build`.
- `FileSystem/`, `Archive/`, `Remote/` (FTP and SFTP), `Commands/` (`cm_` commands and
  key bindings), `Search/`, `Sync/`, `Rename/`, `Tools/`, `Viewer/` (the F3 Lister).
- `UI/`: windows and dialogs. `SettingsWindowController.swift` holds the Settings panes
  and `ColorSettings.swift` the panel colors.
- `Highlighter/`: the `OriCmdHighlighter` XPC service, a locked-down service built with
  the app. It does syntax highlighting with bundled minified JS libraries.
- `Localizable.xcstrings`: the string catalog. Strings are written in English in the
  code and translated into Russian (`ru`) in the catalog.

## Conventions

- **Adding a setting:**
  1. Add a key to `Settings.Key` and a property built on `bool(_:default:)` or
     `set(_:_:)`. Setting a value posts `Settings.didChange`, which redraws the panels
     through `MainViewController.settingsDidChange` → `FilePanelController` →
     `FileListView.settingsDidChange`.
  2. Add a control in the matching pane of `SettingsWindowController.swift`, using
     `row`, `checkbox` and `note`.
  - Example: `Settings.showsFolderBrackets` together with `Settings.panelName(_:isFolder:)`.
    Any code that shows a folder name in a panel should call `panelName` and not add
    the `[ ]` itself.
- **Localization:** every user-facing string goes through `String(localized:)`. After a
  build, `python3 scripts/test/loc.py` lists keys that are missing from the catalog.
  `python3 scripts/test/loc.py ru.json` adds Russian translations from a
  `{"English": "Русский"}` file. Its output must be `[]`.
- **Code style:** follow the existing code. Doc comments (`///`) are written as plain
  sentences, there are few inline comments, and access is `private` wherever possible.
- **Commit messages:** a single line written as a sentence that describes the change
  as the user sees it. The repo's history has many examples.
- **Docs:** the fork's README is English only (`README.md`). The user removed
  `README.ru.md` and `docs/screenshots/ru` on 2026-10-06 (branch `drop-ru-readme`);
  do not recreate them. Upstream still edits `README.ru.md`, so an import may show a
  modify/delete conflict there: keep it deleted. The app itself stays bilingual, so
  the Russian string catalog is still maintained.

## Testing

The Debug app can play keystrokes and save snapshots of its windows. It only does this
on throw-away folders in `build/testdata`, never on real files, and it uses a separate
settings suite, `ru.themmag.OriCmd.tests`. Details are in `scripts/test/README.md`.

```sh
scripts/test/mkdata.sh                    # recreate build/testdata/{left,right}
scripts/test/run.sh <name> "<keys>"       # e.g. "down space f5 wait enter" → build/shots/<name>.png
scripts/test/regress.sh                   # main file operations, checked on disk
```

- To test a setting, write it to the test suite before the run, for example
  `defaults write ru.themmag.OriCmd.tests ShowFolderBrackets -bool false`.
  `run.sh` deletes that suite when it finishes.
- To check a UI change, read the snapshot PNG. `<name>-names.txt` (from
  `extensions-with-names`) has the Name and Ext text of each cursor row as Full view
  draws it.
- Never run two test runs at the same time, even in different worktrees. They share
  the `ru.themmag.OriCmd.tests` settings suite, and `run.sh` deletes it after every
  step, so one run wipes or leaks settings into the other.

- `scripts/test/check.sh` runs the independent core tests and localization check.
  `scripts/test/update-auth.sh` uses disposable keys to test authentication and
  publishing. `scripts/test/accessibility.sh` exercises live row APIs and actions.
  These scripts are on their review branches and integrated into `local-build`.
  The shared UI launcher lock and fresh completion markers reject overlapping or
  incomplete runs; never run two UI suites together.

- `regress.sh` needs GNU `timeout`. It comes from Homebrew's `coreutils` (installed)
  as `/opt/homebrew/bin/timeout`. A full run takes well over 10 minutes, so run it
  in the background with a long time limit.

## Things not to do without asking

- Run `scripts/release.sh`. It sets the version, builds and signs the image,
  commits, tags, pushes and publishes a fork GitHub release with its manifest
  and signature.
- Push branches or open pull requests.

## GitHub

- The user is `tosiabunio` on GitHub. `origin` is the upstream source
  `mmag/OriCmd`; `fork` is the independently developed `tosiabunio/Oriel`
  (`https://github.com/tosiabunio/Oriel.git`; GitHub still lists it as a fork of
  `mmag/OriCmd`).
  Development and contributions target the fork. Existing upstream PR notes
  below describe earlier work; do not open a new upstream PR unless explicitly
  requested. An explicitly requested upstream PR needs its own branch from
  `origin/main` containing only the relevant commits.
- Since 2026-10-03 (the user's choice) the fork's `main` and the local `main` equal
  `local-build`: every feature branch plus `fork-about`, merged with upstream. They
  are no longer a copy of `mmag/OriCmd` main. New fork features and upstream import
  branches start from fork `main`, remain separate, and are integrated into
  `local-build`. Select upstream changes for compatibility with the fork instead
  of assuming that every upstream change must be imported. Test an import, then
  fast-forward `main` to the integration and push to `fork`. Preserve the fork's
  behavior, preferences, signing key and independent version policy.
- Upstream imports continue (the user's wish, 2026-10-07): integrate upstream
  changes that do not conflict with the fork's direction, even now that the fork
  has its own look. When asked to "integrate changes from upstream":
  `git fetch origin`, list `git log <last imported>..origin/main`, and if there is
  nothing new, say so and change nothing. Otherwise merge `origin/main` on a new
  `upstream-<version>` branch from `main` in a short worktree path (the path bar
  check fails in long ones: since phase 9 `build/up134` was already too long, so
  keep the whole path within 40 characters, e.g. `build/u4`), keep the fork's version and the higher internal build
  number, update the README's "latest imported upstream checkpoint" line, run the
  full tests, fast-forward `main` and `local-build`, install, and push to the fork
  once the user agrees (pushing still needs asking). Where an
  upstream change conflicts with the fork (its look, the Look setting, the sidebar,
  the bottom bar, dialogs restyled here), keep the fork's behavior and port the
  upstream fix into it rather than dropping either; ask only when the two cannot
  both be kept.
- Last upstream check: 2026-10-11. `origin/main` was `7fbc363` (0.13.4b,
  2026-10-08), merged on 2026-10-11 (see "Upstream 0.13.4b integrated" below).

## Work in progress

- Branch `folder-brackets-option` (from `main` at the 0.12b release) has commit
  `2b90976`. It adds an option to show folder names without `[ ]`: Settings → Panels →
  Window → "Folder names in [brackets]", on by default.
- Commit `dba61da` on the same branch makes windows keep their size between launches.
  `NSWindow.rememberFrame(as:)` in `App/AppDefaults.swift` must be called *after*
  `super.init(window:)`, because `NSWindowController` clears the window's autosave
  name. It also saves the window's real frame under `WindowFrame <name>`, because
  AppKit's autosave stores a filled or tiled window about 40 pt too short.
- The window fix alone is on branch `window-frame-fix` (cherry-picked from `main`) and
  open as https://github.com/mmag/OriCmd/pull/1.
- Branch `path-breadcrumbs` (from `main`) has commit `d1f37ca`: the path bar works as
  breadcrumbs. Open as https://github.com/mmag/OriCmd/pull/2.
- Branch `fork-about` (from `main`), commit `22b039c`, is fork-only and must never go
  into a PR to `mmag/OriCmd`. It adds the fork line in the About window (Info.plist
  keys `OriCmdFork*` from `Config/OriCmd-Info.plist`, filled from the build settings
  `ORICMD_FORK*`) and `scripts/install-local.sh`.
- Branch `extensions-with-names` (from `main`), commit `dfa357d`: Settings → Panels →
  File list → "File extensions: In their own column / After the name" (key
  `ExtensionDisplay`). Pushed to the fork, no PR yet.
- Branch `finder-menu-items` (from `main`): the context menu ends with Share and Tags,
  as in the Finder, and AppKit adds Services below. Open as https://github.com/mmag/OriCmd/pull/3.
  - Root cause of the missing and wrong Services: OriCmd never called
    `NSApp.registerServicesMenuSendTypes`. It now registers `.fileURL` +
    `NSFilenamesPboardType` (`AppDelegate`), as ForkLift does. AppKit then adds
    Services to the context menu by itself, filtered as in System Settings → Keyboard
    Shortcuts → Services → Files and Folders (SnailSVN included).
  - The earlier `ServicesLoan` (lending `NSApp.servicesMenu` to the context menu) was
    a workaround for the missing registration. It showed the wrong list, a second
    Services entry once registration was added, and was the suspect for the crash
    below. It has been removed.
  - Finder color tag names depend on the Finder's language (Polish here: "Czerwony"…).
    Writing an English "Red" makes a new uncoloured tag. `FinderTags.colorNames()`
    finds the real names by writing candidates to a scratch file.
  - Upstream bug: Services never received the files, not even from the menu bar.
    `writeSelection(to:types:)` was a plain `@objc` method, so Swift exported it as
    `writeSelectionTo:types:` instead of `writeSelectionToPasteboard:types:`. Fixed by
    `extension FileListView: NSServicesMenuRequestor` (commit `935ffa3`). Check a
    selector with `strings -a <binary> | grep '^writeSelection'`.
  - Services also get the files in every form: URLs, `NSFilenamesPboardType` and the
    path text. SnailSVN's service declares paths but reads the text.
  - The crashes after using the context menu were not caused by Services. They were
    caused by an upstream bug: see `fix-draw-range`.
  - Test runs stay in the background, where AppKit neither filters Services nor adds
    it to context menus. Check Services by hand in the installed app.
- Branch `fix-draw-range` (from `main`) fixes an upstream crash (on `main` since
  2026-09-27).
  - Cause: `FileListView.draw` built `max(first,0)...min(last,count-1)` before its
    guard. When only the empty area below the last row needed drawing (a menu
    closing over a short list), the range ran backwards and Swift trapped
    (SIGTRAP, "Range requires lowerBound <= upperBound").
  - Commit `a282cca` fixes it and adds a regression check (the `drawbelow` test
    action). Commit `2f6f2e1` makes test runs launch with
    `-ApplePersistenceIgnoreState YES`. After a crash, macOS asks "reopen windows?",
    and that alert stopped every test run, because test runs share the app's restore
    state.
  - Open as https://github.com/mmag/OriCmd/pull/4. Merged into `local-build`.
- The user runs the Mole cleaner (`~/Library/Logs/mole`). It seems to remove standard
  `~/Library` folders such as `Saved Application State` and `Logs/DiagnosticReports`.
- `~/Library/Logs/DiagnosticReports` was missing, so macOS could not save crash
  reports ("destination is unavailable"). It was created on 2026-10-02; read new
  `.ips` reports there.
- In Release builds, `NSLog` text appears as `<private>` in `log show`. For temporary
  diagnostics use `Logger` with `privacy: .public`.
- Branch `folder-tag-colors` (from `main`), commit `cce069b`: folders are drawn in
  their Finder tag color (`labelNumberKey`, read with the listing into
  `FileItem.tagColor`; `FileIcons.folder(tagColor:size:)` tints the icon). Pushed to
  the fork. Full regression suite passed (166 checks) on 2026-10-02. No PR for now;
  the user decides when.
  - The folder watcher (kqueue: write/delete/rename/link) does not see tag changes,
    so tags changed in the Finder show after a refresh.
  - In `local-build` only (the merge commit `ec768f3`), the context menu's Tags item
    calls `reread()`, so the color shows at once. This needs both branches; add it
    when both are upstream.
- Branch `short-sizes` (from `main`), commit `e781c41`: Settings → Panels → File list →
  Sizes: Short (Finder-style decimal units through `ByteCountFormatter`, `.file`, no
  "Zero KB"; the default) or Exact. It applies to the Size column, the status line,
  the free space and the Synchronize window. `Settings.formattedSize` /
  `Settings.shortSize` (nonisolated). The listing carries `VolumeSpace`, not the text,
  so free space is formatted on the main thread. Pushed to the fork, no PR.
- UX changes modelled on ForkLift (chosen 2026-10-02). Each is a setting that is
  **on by default** (the user's choice), with the old TC look one click away:
  - `key-caps` (from `main`), commit `ac1975c`: the function key bar draws keys as
    key caps. `Settings.showsFunctionKeyCaps` (`FunctionKeyCaps`).
  - `mac-tabs` (from `main`), commit `8c2687d`: folder tabs with the folder's icon, a
    rounded selected card and a close button on hover. `Settings.macStyleTabs`
    (`MacStyleTabs`). Test actions `tabhover:N`, `tabclose:N`.
  - `compact-header` (from `path-breadcrumbs`, so it needs PR #2 first), commit
    `abfdad9`: no volume row; the path bar starts with a volume chip (menu of
    volumes), ends with the free space (only when the whole path fits) and shows the
    mask only as a filter chip. `Settings.compactPanelHeader` (`CompactPanelHeader`).
    Test action `volumemenu`. The free space text is the volume row's own, so it
    follows `short-sizes` once both are merged.
  - `status-summary` (from `short-sizes`), commit `48743e6`: Finder-style status line
    ("2 of 15 selected · 35 KB of 1,2 MB"). `Settings.plainStatusLine`
    (`PlainStatusLine`). The catalog's first plural variations (`%lld files`,
    `%lld folders`) were written into the JSON by hand; `loc.py` cannot add plurals.
  - `key-caps` has a second commit `0f2919c` (more padding, a 28 pt bar).
  - All four are pushed to the fork; none is in a PR yet.
- `local-build` = `folder-brackets-option` + `window-frame-fix` + `path-breadcrumbs`
  + `fork-about` + `extensions-with-names` + `finder-menu-items` + `fix-draw-range`
  + `folder-tag-colors` + `short-sizes` + `key-caps` + `mac-tabs` + `compact-header`
  + `status-summary`, merged with upstream 0.12.1b (`6078929`; the upstream
  middle-click tab closing was combined with the Mac-style tabs).
- `git merge` of the string catalog can conflict as text; merge it as JSON instead
  (take `git show :2:` and `:3:` of the file, union the `strings`, dump with
  `indent=2, sort_keys=True, ensure_ascii=False` like `loc.py`).
- When resolving "both sides added" conflicts by concatenating, check the shared
  closing lines: git keeps a common `}` outside the conflict block, so pasting both
  sides drops a brace (this broke the `short-sizes` merge build once). Merging `extensions-with-names` conflicted
  with the brackets option; it was resolved so folder names go through
  `Settings.panelName` in both modes.
  It is what `/Applications/OriCmd.app` is built from.
- All branches are pushed to the fork (`git push fork <branch>`; each tracks
  `fork/<branch>`).
- More changes are planned. Each feature gets its own branch from `main`, and is then
  merged into `local-build`.

## UX improvements installed on 2026-10-03

Fork build 18 (`384adbe`) is installed. Local `main` and `local-build` point to this
integration; the root checkout remains on `key-caps`. These new branches are local:

- `ux-copy-dialog` (`810ae88`): source, destination, names and marked/cursor scope;
  explicit Copy/Move buttons and an always-visible overwrite summary.
- `ux-selection-markers` (`898f777`): checkmarks in Full, Brief and Thumbnails;
  Settings → Panels → Show checkmarks on marked items, on by default.
- `ux-operations` (`7dc9269`): shared Operations window, panel indicator, pending-job
  cancellation, live progress and session results (most recent 100 finished jobs).
  Cancelling from Operations also dismisses an outstanding overwrite question.
- `ux-filter-indicators` (`ff317c7`): text and mask rules together, match count,
  clear button and accessible clear action in either header style.
- `ux-command-palette` (`fb72b3a`): Commands → Run Command… (Shift+Cmd+P), localized
  names or cm_* search, current keys including aliases, validated execution,
  recent commands and focus restoration. Exact title matches ignore trailing
  ellipses; a customized plus key displays as +, not as its modifier prefix.

All five feature branches started from `main` at `07a05fb`, and remain separate.
English/Russian README and catalog updates are included on each branch.

Validation: 13 core tests, the first 78 existing file-operation regression checks
(before the Associations section), 11 live accessibility checks, all five
`scripts/test/ux-*.sh` suites, and English/Russian and light/dark visual checks.
The installed app matches the universal Release bundle and passes deep strict
codesign verification. Nothing was pushed or published for these UX branches.

Run UI suites serially. Finish rebuilding the Debug app before testing it; never
replace the tested Debug bundle during a running UI suite. A Release build with a
separate DerivedData directory can run alongside the Debug UI tests.

## Clickable drive capacity installed on 2026-10-03

Fork build 19 (`64325cb`) includes local branch `clickable-drive-space` (`47a0aab`).
Clicking the free-space or total-capacity readout opens Finder's information window
for the clicked panel's current volume, in either compact or classic headers.
The readout has a hand cursor, a localized Drive Information tooltip and an
accessible button. Server panels do not offer a local-drive information action.

Validation: Debug build, localization check, capacity clicks and accessible Press
in both headers, inactive-panel activation, Russian UI, snapshots, and the existing
`ux-filters.sh` suite. Test Get Info requests are recorded by DebugAutomation instead
of opening Finder windows. The universal Release build was installed from
`local-build`; local `main` matches that integration. Nothing was pushed.

## Recent branches pushed on 2026-10-03

The user authorized pushing all recent changes to the fork. All 11 new
review, UX and drive-capacity branches were pushed to `fork`, along with
`main` and `local-build` at `64325cb`. All local branches now track the
matching fork branches, including `main` (previously `origin/main`).
The push was atomic, with no force push, tags, releases or pull requests.

## Upstream 0.13b integrated on 2026-10-03

Fork build 20 (`3821c37`, version `0.13b`) is installed in `/Applications/OriCmd.app`.
The 38 new upstream commits through `origin/main` at `096ccd3` were merged on the
separate `upstream-0.13b` branch. Merge `c73f00e` preserves the fork's panel-controller
split, authenticated updates, accessibility, custom headers, tabs, selection markers,
filter indicators, operations window, command palette, and clickable drive capacity.
Upstream's selected-only filter participates in the filter summary and clear action;
custom column sets without an Ext column still show complete filenames.

Commit `3821c37` renames the breadcrumb test depth variable so upstream's search
fixtures cannot overwrite it. `main`, `local-build`, and `upstream-0.13b` were pushed
atomically to the fork at this revision and track their matching fork branches.
Existing feature branches remain separate. The primary checkout remains on `key-caps`.

Validation: 13 core tests, 5 launcher contract tests, 11 live accessibility checks,
all five UX suites, capacity-click checks, signed-update checks, localization, and
335 passing regression checks. The initial regression invocation could not advertise
its Bonjour service inside the sandbox; both checks passed when rerun with discovery
access. After the test-variable fix, the remaining nine checks passed separately.
Optional DjVu page-rendering checks were skipped because this worktree has no
`build/djvulibre/bin/ddjvu`. The installed app matches the universal Release bundle
and passes deep strict codesign verification. No pull request or release was created.

## Independent fork README updated on 2026-10-03

Branch `fork-readme` (`0e586d4`) updates both READMEs with the independent fork's
identity, selected upstream imports, fork additions, installation, contributions
and upstream attribution. The fork has no packaged GitHub releases yet and its
GitHub issue tracker is disabled; the README links source builds, fork releases
and fork pull requests. The original Homebrew cask is identified as upstream.
Inherited screenshots are identified as such.

Documentation integration `8ea9e35` is on `main` and `local-build`; these and
`fork-readme` were pushed atomically and track their fork branches. Only the two
README files changed. Local links, installation targets, code fences, translations
and `git diff --check` were reviewed. The installed app remains build 20 at
`3821c37`; this documentation-only change did not rebuild or install the app.

At that point version numbering was a proposal: `YEAR.MONTH.RELEASE`, starting
with `2026.10.0`, then `2026.10.1` for the next release that month and `2026.11.0`
for November's first release. Plain numeric dotted versions fit the current
updater, version validator and release script. Record upstream versions/commits
separately in release notes and retain the local build counter independently.
The user had not yet chosen a scheme; app metadata then reported `0.13b`.

## Calendar numbering implemented on 2026-10-03

The user accepted the proposed numbering and requested implementation. Branch
`calendar-versioning` (`e48afeb`) sets `MARKETING_VERSION = 2026.10.0` and
`CURRENT_PROJECT_VERSION = 15` in both configurations of the app and its XPC
helper. The updater's existing numerical comparison supports calendar versions
and upgrades from legacy `0.13b`; its behavior did not need changing.

`scripts/release.sh` requires canonical YEAR.MONTH.RELEASE, rejects older versions,
and allows the current version for its first publication if its tag does not
exist. Both READMEs and the authenticated-update guide describe the scheme and
calendar asset names. Signature and publishing tests now use disposable
`2026.10.0` fixtures. Running release.sh still requires an explicit publication
request; implementation did not create a tag or GitHub release.

Integration `908c1d5` is on `main` and `local-build`; these and `calendar-versioning`
were pushed atomically to the fork and track their matching fork branches.
The installed app is universal fork build 21 (`908c1d5`), version `2026.10.0`,
internal build 15. It matches the Release bundle and passes deep strict codesign
verification; the app and helper both have Intel and Apple Silicon architectures.

Validation: 13 core tests, 5 launcher contract checks, localization, 22 signed-update
checks, 11 isolated updater checks (including calendar counters, month/year rollover,
legacy migration and release asset lookup), and 16 release-preflight checks without
publishing. The About window visibly shows `2026.10.0 (15)` and fork attribution.
The primary checkout remains on `key-caps`.

## Two-line About installed on 2026-10-03

The version/fork display request was initially interpreted as limiting the entire
window to the calendar version with the fork build number in parentheses and
"tosiabunio fork" below. The user later clarified that other app information and
dependency credits should remain; the next section records that correction.
Branch `compact-about` (`c11331f`) replaces the standard About panel with
`UI/AboutWindowController.swift`: a compact window containing exactly those two
labels. The window's title is hidden visually but retained for accessibility.
The fork identity remains "tosiabunio fork" in both interface languages.

The parenthesized number prefers `OriCmdForkBuild`, falling back to
`CFBundleVersion` for builds without a local install counter. Revisions remain
in metadata, never in About. Credits remain bundled as `Credits.rtf`; both
READMEs now link the notices and describe the two-line format.

Integration `ff96fac` is on `main` and `local-build`; these and `compact-about`
were pushed atomically to the fork. The installed universal app is fork build
22 (`ff96fac`), so its About text is "2026.10.0 (22)" and "tosiabunio fork".
The build number increased from 21 when installing this update.

Validation: Debug builds, localization, six isolated About runs (internal-number
fallback, local build precedence with a diagnostic revision present, Escape,
reopening, Russian, light mode), English/Russian and light/dark visual checks,
universal Release build, matching installed bundle, and deep strict codesign.
The app and XPC helper have both Intel and Apple Silicon architectures.

## About credits restored on 2026-10-03

The user clarified that the compact two-line instruction applies only to version
and fork information. Keep the app icon, name, copyright and full dependency
notices in About. Branch `about-credits` (`12cf092`) restores these in the custom
window while retaining the version/build and "tosiabunio fork" lines, without
commit revisions. A scrollable, selectable text view loads the original bundled
`Credits.rtf` verbatim, adds clickable fork/original repository links and makes
the dependency URLs clickable. Labels are localized in English and Russian;
original license notice text is unchanged. Both READMEs describe the restored
information and notices.

Integration `7c533f2` is on `main` and `local-build`; these and `about-credits`
were pushed atomically to the fork and track their matching branches. The
installed universal app is fork build 23 (`7c533f2`), version `2026.10.0`. Its
version and fork lines read "2026.10.0 (23)" and "tosiabunio fork".

Validation: Debug build, localization, five isolated UI checks (English, Russian,
Escape, reopening and app-selected light appearance), visual checks in light and
dark mode, and a disposable AppKit probe against the actual controller. The probe
verifies the entire original credits text is preserved, all six dependencies have
links, all 12 links deliver their URL through native link handling without opening
the browser, the final notice is reachable by scrolling, and no diagnostic
revision appears. Universal Release build, matching installed bundle, deep strict
codesign and both architectures in the app/helper passed. Installed Credits.rtf
matches the source byte for byte. The primary checkout remains on `key-caps`.

## Upstream 0.13.2b integrated on 2026-10-04

Fork build 24 (`8fe3090`, version `2026.10.0`, internal build 16) is installed.
Branch `upstream-0.13.2b` (worktree `build/upstream-0.13.2b`) merges upstream
0.13.1b and 0.13.2b through `origin/main` at `1cd4881`: SFTP non-ASCII names,
.DS_Store skipped by default (F5/F6 options and Settings → Operations), refused
NAS names explained, and Skip/Skip All/Retry/Cancel for failed items through
`TransferPrompts`. Merge `ad1a45f` keeps the fork's version, takes the higher
internal build number (16), ports the transfer API change into
`FilePanelController+Transfers.swift`, and adds "Copy .DS_Store" to the copy
dialog's options summary when skipping is off. Commit `8fe3090` updates
`Tests/CoreTests.swift` for `TransferPrompts`. Both READMEs name 0.13.2b/`1cd4881`
as the latest imported upstream checkpoint. `main`, `local-build` and
`upstream-0.13.2b` were pushed atomically to the fork and track their branches.

Validation: 13 core tests, 5 launcher contract checks, localization, 348 of 349
regression checks (all new upstream checks included), a copy dialog snapshot,
universal Release build, matching installed bundle and deep strict codesign.
- "/ in the path bar goes to the root" fails only because the worktree path
  (`build/upstream-0.13.2b`) is long enough that the path bar hides the root
  crumb; the same commit passes it in `build/local-build`. Keep worktree names
  short or run that check from a shorter path.
- The `scripts/test/ux-*.sh` suites call `rg`. It was missing on PATH at first
  (Claude Code's `rg` is only an interactive shell function); on 2026-10-05 the
  user had Homebrew's `ripgrep` installed (`/opt/homebrew/bin/rg`), and all five
  UX suites and all 11 live accessibility checks passed on `local-build` at
  `d5b2e26` (this import plus the release and screenshot commits).
- Rerun from `build/local-build` on 2026-10-05 at `d5b2e26`: the full regression
  suite passed 349 of 349 (the path bar check included); only the optional DjVu
  page checks were skipped.

## First fork release 2026.10.1 published on 2026-10-04

At the user's request, `scripts/release.sh 2026.10.1` (the user wrote "2016.10.01",
taken as the canonical 2026.10.1; 2026.10.0 was never published) ran from a
`main` worktree in `build/rel` with `ORICMD_UPDATE_SIGNING_KEY` pointing to the
primary checkout's key. Commit `860a564` first updated both READMEs' installation
sections to point at the downloadable DMG. Release commit `a0cbf35` (internal
build 17) and tag `v2026.10.1` are on the fork; `local-build` was fast-forwarded
and pushed, so `main` = `local-build` = `a0cbf35`.

https://github.com/tosiabunio/OriCmd/releases/tag/v2026.10.1 has
`OriCmd-2026.10.1.dmg` (7,690,774 bytes, SHA-256 `bd4e42bb…5fbd08`), the signed
manifest and its signature. The notes record upstream base 0.13.2b (`1cd4881`).
The downloaded manifest verifies against `OriCmd/UpdateSigningPublicKey.txt`; the
DMG matches its size and checksum; the app inside passes deep strict codesign and
reports 2026.10.1 (17). Afterwards the user asked to reinstall from `local-build`:
the installed app is now fork build 25 (`a0cbf35`), so About reads
"2026.10.1 (25)" and the updater does not offer the release over it.

## Fork README screenshots on 2026-10-04

Branch `fork-screenshots` (worktree `build/scr`) replaces all 14 README screenshots
(`docs/screenshots/{en,ru}`) with the fork's default look, regenerated by
`scripts/screenshots.sh`. Commit `8c5135f` changes the tooling: shots are light unless
`THEME=dark` (the system here is dark), each language has its own region
(`-AppleLocale en_GB` / `ru_RU`), and with `ORICMD_DEMO` the Debug app replaces each
window picture with a ScreenCaptureKit capture of its own window
(`SCShareableContent.currentProcess`, no Screen Recording permission needed).
`cacheDisplay` paints the macOS 26 toolbar glass as blank white pills (invisible
icons in dark mode). Commit `d5b2e26` has the images and README notes ("show this
fork's interface with its default settings"). `main`, `local-build` and
`fork-screenshots` were pushed atomically to the fork at `d5b2e26` and track their
fork branches. The Release app is unchanged (Debug-only code), so nothing was
reinstalled.

## Upstream 0.13.3b integrated on 2026-10-06

Branch `upstream-0.13.3b` (worktree `build/up133`, kept short for the path bar
check) merges upstream through `origin/main` at `a7cda51`: `ProcessRunner` no longer
leaves pipe handlers spinning at 200% CPU after a cancelled server command, and a
failed command-line command reports its stderr. Merge `6663361` keeps the fork's
version 2026.10.1 (internal build 17 on both sides) and names 0.13.3b/`a7cda51` in
the README. Branch `drop-ru-readme` (`069eff0`, from that merge) removes `README.ru.md`
and `docs/screenshots/ru`; `scripts/screenshots.sh` makes only the English set.
`main` = `local-build` = `069eff0`; these and both new branches were pushed
atomically to the fork and track their fork branches. Fork build 26 (`069eff0`) is
installed.

Validation: Debug build, 13 core tests, 5 launcher contract checks, localization,
352 of 352 regression checks (the three new upstream checks included; DjVu skipped),
universal Release build, matching installed bundle and deep strict codesign.

## Release 2026.10.2 published on 2026-10-06

At the user's request, `scripts/release.sh 2026.10.2 <notes>` ran from the `main`
worktree `build/rel` with `ORICMD_UPDATE_SIGNING_KEY` pointing to the primary
checkout's key. Release commit `ed2c25f` (internal build 18) and tag `v2026.10.2`
are on the fork; `local-build` was fast-forwarded and pushed, so `main` =
`local-build` = `ed2c25f`. https://github.com/tosiabunio/OriCmd/releases/tag/v2026.10.2
has `OriCmd-2026.10.2.dmg` (7,701,665 bytes, SHA-256 `0e424334…9ceb26`), the signed
manifest and its signature. The notes name upstream base 0.13.3b (`a7cda51`) and
its two fixes, and the English-only README.

Verification: the downloaded manifest passes `UpdateVerification.manifest` (the
app's own code, compiled with a small driver) against
`OriCmd/UpdateSigningPublicKey.txt`; the DMG matches its size and checksum; the app
inside reports 2026.10.2 (18), passes deep strict codesign, and the app and helper
are universal. The installed app was then rebuilt from `local-build`: fork build 27
(`ed2c25f`), so About reads "2026.10.2 (27)".

## Visual refresh plan accepted on 2026-10-06

The user accepted the visual refresh proposal. It is public as
`docs/visual-refresh.md` (commit `61b5aa7`, branch `visual-refresh-plan`, linked
from README → Development), with an interactive Today/Proposed mockup at
https://claude.ai/artifact/CBd66sFhHtoyH7Bkzt2BeP (its source is a scratchpad file;
republish by `url` from another session). `main` = `local-build` = `61b5aa7`,
pushed to the fork. Docs only, so the app was not rebuilt (installed: build 27).
- Phase 1 (macOS 14+, drawing only): rounded focus-aware cursor, neutral path bar
  with an accent strip, no brackets/`--`/medium dates/Attr hidden/dim secondary
  columns, modern column header, density setting and no list frames.
- Phase 2 (macOS 26 APIs behind `#available`): full-size content, split-view
  accessories, optional sidebar, one bottom bar, macOS 27 menu image visibility.
- Phase 3: Compare/Sync toolbars, HIG button order in the copy dialog, Settings
  split, Icon Composer icon, Increase Contrast colors.
- One Look setting (Modern default / Classic) sets the existing look switches;
  test runs pin Classic where checks expect `[name]` or `<DIR>`.
- Next step: build phase 1 on `modern-panels` and compare light/dark snapshots.
- Remember `PanelPreview` in `SettingsWindowController.swift` duplicates the list
  drawing. On macOS 27, AppKit hides menu item images unless
  `preferredImageVisibility = .visible`.

## Visual refresh phase 1 installed on 2026-10-07

Branch `modern-panels` (worktree `build/mp`), commit `375cd4a`: phase 1 of
`docs/visual-refresh.md`. `main` = `local-build` = `375cd4a`, pushed atomically to
the fork with `modern-panels`. Installed: fork build 28 (version 2026.10.2).
- `Settings.look` (`Look`: modern default / classic). Setting it writes
  `ShowFolderBrackets`, `MacStyleTabs`, `CompactPanelHeader`, `FunctionKeyCaps`,
  `PlainStatusLine`, `SelectionMarkers` and `PanelDensity`; unset switches follow
  the look (their `default:` is `isModern`). `Settings.density` (standard 13 pt /
  22 pt rows, compact 12 / 19); `defaultFontSize` follows it. Alternating rows
  default to on in modern; High contrast records whether it found them off (1) or
  unset (2) in `AlternatingRowsByPreset`, and other presets restore exactly that.
- Drawing: `Theme.rowInset`/`contentInset`/`rowPath`/`dateText`; `FileListView`
  rounded focus-aware cursor (`showsFocusedCursor`: key window; test runs count as
  focused), marked-row tint, grey detail columns, `--` for folders/packages (Classic
  keeps `<DIR>`/`<PKG>`); `ColumnLayout(width:columns:inset:)`, dragged widths in
  `ColumnWidths` (global); header modern style, hover/pressed, resizing; `PathBar`
  accent strip, semibold current folder, info line (`status`, free space) when
  modern + compact, and `PanelView` then folds the status row except during quick
  search (`isQuickSearching`). Divider 1 pt with 3 pt grab slop (delegate
  `effectiveRect`). Modern default columns omit Attr (`ColumnSet.standard`).
- Tests: `columns`, `headerdrag:col:DX`, `headerdoubleclick:col`, `headerclick:col`
  (do not use a bare `header` prefix: `headermenu:` exists). New regress checks for
  looks, widths and preset stripes; column-set checks now expect no Attr.
- Validation: 355 regression checks passed on the first run; its 5 failures (the
  preset stripes bug, Attr expectations) were fixed and their sections (17 checks)
  rerun green; 13 core tests, localization, 5 UX suites, 11 accessibility checks.
  Lesson: never edit `regress.sh` while it runs (zsh reads it as it goes); keep
  changes aside until the run ends.
- The user's own prefs use Monaco 15 pt and already had brackets off, so the
  installed app shows the modern look with their font.
- Follow-up `51af228` (build 29, installed and pushed to the fork): the user found the
  relative/medium dates ("Today at 09:12") visually uneven and wants one uniform
  date/time format, so both looks use `Theme.dateText` = short date + short time
  on every row; no relative form, no narrow-column fallback.

## Visual refresh phase 2 installed on 2026-10-07

Branch `window-shell` (worktree `build/ws`), `main` = `local-build` = `a818e6c`,
pushed to the fork; installed as fork build 30.
- `9771b28`: `NSMenuItem.keepsImageVisible()` (`UI/MenuItemImages.swift`) keeps tag
  colors, Open With apps and volume icons on macOS 27.
- `33af8b2`: Modern bottom bar: `MainViewController.layoutBottom()` re-parents the
  command line, `FunctionKeyBar` (compact hints mode) and Operations into one
  `NSStackView` (34 pt); Classic keeps the stacked rows.
- `c1846dd`: `RootSplitViewController` (sidebar item + `MainViewController`) is the
  window's content; `NSWindow.mainViewController` replaces
  `contentViewController as? MainViewController` everywhere. `SidebarViewController`
  (Devices with free space, Favorites, Hotlist; `Hotlist.didChange`). Window has
  `.fullSizeContentView`; panels start at the safe area. Toolbar gets
  `.toggleSidebar` + `.sidebarTrackingSeparator` (once for saved toolbars,
  `ToolbarHasSidebarButton`). `Settings.showsSidebar` (`ShowSidebar`, follows the
  look) hides the drive bar; width in `SidebarWidth`. `DirectoryTreePanel.panelInsets`
  aligns the tree/Quick View headers. Test actions `sidebar`, `sidebarpick:Title`.
- `a818e6c`: drive-button checks set `ShowSidebar false` (the drive bar is hidden
  with the sidebar, so `drivemenu:` finds no buttons).
- 2.2 (split-item accessories) deferred: no visible gain with opaque headers.
- Test snapshots draw the glass sidebar blank; capture with `ORICMD_DEMO=1` (SCK)
  to see it, as `scripts/screenshots.sh` does.
- Validation: 360 + 5 regression checks, 5 UX suites, 11 accessibility checks, core
  tests, localization.

## Visual refresh phase 3 installed on 2026-10-07

Branch `secondary-windows` (worktree `build/p3`), `main` = `local-build` = `c7ac224`,
pushed to the fork with `window-shell` (`44a1ddd`); installed as fork build 31. The
user asked to continue the phases unsupervised (test, install, push; no release).
- `fdc33a5`: copy dialog buttons in Mac order (Options >> and Tree left; F2 Queue,
  Cancel, default Copy/Move right); advanced options in a rounded custom `NSBox`.
- `e78bcc9`: `ToolWindowToolbar` (fixed symbol toolbar, items enabled by the window)
  for Compare (previous/next, copy left/right, edit, save; ⌘S in `handleKey`);
  Synchronize keeps its form with Compare and Synchronize… at the right edges.
  Test `click:` also presses toolbar items by label (only when enabled).
- `98941a7`: `SettingsPane` builds one grid per section inside a rounded group
  (`quinarySystemFill`); panes keep their topics (no Appearance/File List split).
- `24e748b`: stronger marked tint with Increase Contrast; panels redraw on
  `accessibilityDisplayOptionsDidChangeNotification`. Custom cursor colors stay as
  chosen in dark mode (their text color is chosen with them).
- `44a1ddd` (window-shell): the user asked for the function key hints to be
  centered when they are alone in the bottom bar (command line hidden): they move
  to the stack's center gravity area, Operations to the trailing one.
- Not done: the layered Icon Composer app icon (needs design work).
- Validation: 365 regression checks, 5 UX suites, 11 accessibility checks, core
  tests, localization; the command-line checks again after the centering merge.

## Release 2026.10.3 published on 2026-10-07

At the user's request, `scripts/release.sh 2026.10.3 <notes>` ran from `build/rel`
(main) with the primary checkout's signing key. Release commit `f87ecf2` (internal
build 19) and tag `v2026.10.3` are on the fork; `main` = `local-build` = `f87ecf2`.
https://github.com/tosiabunio/OriCmd/releases/tag/v2026.10.3 has
`OriCmd-2026.10.3.dmg` (7,844,059 bytes, SHA-256 `9db07634…1b7f`), the signed
manifest and its signature. The notes cover all three visual refresh phases, the
Look setting and how to return to Classic; upstream base still 0.13.3b (`a7cda51`).
Verified like 2026.10.2 (app's `UpdateVerification` against the public key, size
and checksum, deep strict codesign, universal app and helper). Reinstalled from
`local-build` as fork build 32, so About reads "2026.10.3 (32)".
- README screenshots regenerated afterwards on branch `readme-screenshots`
  (`a33993c`, worktree `build/rs`); `main` = `local-build` = `a33993c`, pushed.
  `scripts/screenshots.sh` now passes `ORICMD_DEMO=<demo folder>` and a demo
  hotlist; in Debug the sidebar then shows the demo folder as "Home" and its
  Downloads, so the account name is never pictured. Release app unchanged (Debug-only
  code), so nothing was reinstalled; installed is still build 32.

## Liquid Glass app icon on 2026-10-07

Branch `app-icon` (worktree `build/ai`), commit `484a5d4`; `main` = `local-build` =
`484a5d4`, pushed to the fork with `app-icon`; installed as fork build 33.
- `OriCmd/AppIcon.icon` is an Icon Composer document written by hand: `icon.json`
  (automatic blue gradient fill; group "Cursor" = `cursor.svg`, opaque, shadow 0.65;
  group "Panes" = `lines.svg` over `panes.svg`, translucency 0.4) and SVG layers on a
  1024 canvas. Groups are listed front first. The old `AppIcon.appiconset` was
  removed; Xcode compiles the `.icon` into `Assets.car` and an `AppIcon.icns`
  fallback for macOS 14/15 (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` unchanged).
- Render without the GUI: `"$(xcode-select -p)/../Applications/Icon Composer.app/
  Contents/Executables/ictool" OriCmd/AppIcon.icon --export-image --output-file x.png
  --platform macOS --rendition Default|Dark|ClearLight|ClearDark|TintedLight|TintedDark
  --width 512 --height 512 --scale 1`. `scripts/mkdemo.sh` now renders its sample
  pictures this way. Upstream's `scripts/make-icon.swift` (the old generated icon) is
  left untouched and unused.

## CI failures from the macOS 27 SDK (2026-10-07)

GitHub Actions on the fork ("Checks" and "File panel accessibility") failed on every
push from phase 2 (`a818e6c`) on: the runners use the `macos-26-arm64` image, whose
Xcode has the macOS 26 SDK, and `NSMenuItem.preferredImageVisibility` (macOS 27 SDK)
did not compile there ("cannot find 'preferredImageVisibility' in scope"). The
accessibility workflow's error is only in its uploaded log artifact
(`gh run download <id>`). `if #available` guards running, not compiling: wrap
macOS 27 SDK APIs in `#if compiler(>=6.4)` (Swift 6.4 = Xcode 27) as well. Fix on
branch `fix-ci-build` (worktree `build/ci`). The locally built apps and releases
(Xcode 27) were never affected. Check `gh run list --repo tosiabunio/Oriel` after
pushing.
- Pushed `9b974ab` (`main` = `local-build` = `fix-ci-build`): all 9 runs passed
  (Checks, File panel accessibility, Update signatures on each branch). Scheduled
  runs (the nightly `interface` job) have never run on the fork: GitHub disables
  schedules on forks by default, so the "Run failed" emails came from push runs.
  When watching runs, match the full commit (`git rev-parse`), not a typed prefix.
  The shell is zsh: `for s in $shas` does not split a string of commits (the whole
  string becomes one value and matches no run), so name each commit in its own
  variable, or split with `${=shas}`. Have a watcher print what it watches first.

## Release 2026.10.4 published on 2026-10-07

The user asked to publish once CI passed; CI was green for `9b974ab` (the CI build
fix plus the new icon). `scripts/release.sh 2026.10.4 <notes>` (from `build/rel`, its
last use) made release commit `df28945` (internal build 19 → 20) and tag
`v2026.10.4`. https://github.com/tosiabunio/OriCmd/releases/tag/v2026.10.4 has
`OriCmd-2026.10.4.dmg` (8,782,513 bytes, SHA-256 `68202b76…04343f`), the signed
manifest and signature, verified as before (signature, size and checksum, codesign,
universal, `AppIcon.icns` and `Assets.car` present). The notes describe the new
icon and the regenerated README screenshots; upstream base still 0.13.3b.
`local-build` fast-forwarded and pushed; reinstalled as fork build 34, so About
reads "2026.10.4 (34)". CLAUDE.md was then committed to the repository (see "This
file" at the top) and the main checkout moved to `main`.

## Settings split to fit the screen on 2026-10-07

The user reported (urgently) that Settings → Panels was taller than their screen:
1,436 pt against 1,027 pt of visible height on a 16" MacBook Pro (1728×1117), after
phase 3's rounded groups. Branch `settings-fit` (worktree `build/sf`), commit
`714bb7b`; `main` = `local-build` = `714bb7b`.
- New **Window** pane (`WindowPane`, symbol `macwindow`) after Panels: "Main window"
  (command line, function keys, key caps, sidebar, drive buttons, Customize
  Toolbar…) and "Tabs and header" (Mac-style tabs, compact header). It refreshes on
  `Settings.didChange`, so the Look popup (in Panels) and ⌃⌘S update it.
- **Panels** keeps Look, Font, File list (folder brackets and the optional-columns
  note moved here) and Mouse; its preview was dropped (Colors has the same one).
  Heights now: General 342, Panels 838 (Russian 894), Window 474, Colors 902,
  Operations 636, Keyboard 484 pt. `ORICMD_SETTINGS_TAB`: 0 General, 1 Panels,
  2 Window, 3 Colors, 4 Operations, 5 Keyboard.
- `SettingsPane` puts its content in a flipped view inside an `NSScrollView`; its
  `preferredContentSize` height is capped at the screen's visible height − 100
  (title bar and toolbar), the rest scrolls, and it is recomputed on
  `Settings.didChange` (the preview's height follows the look and density).
  `naturalWidth` gives the width for the common one. Debug: `ORICMD_SETTINGS_HEIGHT`
  overrides the cap.
- `SettingsTabs.tabView(_:willSelect:)` moves the window up before a taller pane
  would grow past the bottom of the visible frame (NSTabViewController keeps the
  top edge when it resizes).
- Test snapshots from `run.sh` are scaled to fit 1100 pixels, so compare their
  proportions, not heights (`tallness` in `regress.sh`). Two new checks: the cap
  scrolls, and the Colors pane shrinks when rows become compact.
- The README Settings screenshot now shows Colors (with the preview);
  `scripts/screenshots.sh` uses `ORICMD_SETTINGS_TAB=3`.
- Installed as fork build 35 (`714bb7b`, About "2026.10.4 (35)"); pushed to the fork
  with `settings-fit` at the user's request once the tests passed.
- Validation: 367 of 367 regression checks (the two new ones included), 13 core
  tests, localization, snapshots of every pane in English and Russian, and a low
  window moved up when switching to Colors. Two steps of this run (test data setup
  after the SMB-cancel and promise-paste checks) each stalled about 16 minutes
  outside the app, which earlier runs did in seconds; the cause is unknown.

## Visible rename to Oriel on 2026-10-07

The user wanted a name that sets the fork apart from upstream and chose **Oriel**
(suggested after checking for clashes: "OriCmdr" sat next to Cmdr, an existing
two-pane macOS file manager). Only the visible name changed, so upstream imports
and earlier installs' updates keep working; the identity (bundle ID
`ru.themmag.OriCmd`, settings, Keychain service) is a later, separate step. Branch
`oriel-name` (worktree `build/on`): `4691c08` (the rename), `ba5110e` (README: Dock
labels), `fc70a00` (About: "OriCmd fork"); `main` = `local-build` = `fc70a00`, pushed
to the fork with `oriel-name` at the user's request once the tests passed. Fork
build 36 (`4691c08`) renamed `/Applications/OriCmd.app` to `/Applications/Oriel.app`
(a rename keeps the Dock item); fork build 37 (`fc70a00`) is installed.
- `CFBundleDisplayName = Oriel` (build setting) and `OriCmd/InfoPlist.xcstrings`
  (CFBundleName and CFBundleDisplayName = Oriel for en and ru): Xcode's generated
  Info.plist always writes `CFBundleName = $(PRODUCT_NAME)`, ignoring the key in
  `Config/OriCmd-Info.plist` and `INFOPLIST_KEY_CFBundleName`, so the localized
  InfoPlist.strings carry the menu bar name. `PRODUCT_NAME`, the executable
  (`Contents/MacOS/OriCmd`) and the built `OriCmd.app` stay, so test scripts are
  unchanged.
- `Bundle.appName` (`App/AppName.swift`) is the name in code: the app menu (About,
  Hide, Quit), the main window title, About, update alerts, the archive messages,
  Settings → General notes, the SFTP password dialog title and new Keychain item
  labels. Catalog keys now take it as `%@` (Russian keeps the Latin name).
- Updates: release assets keep `OriCmd-<version>.dmg/.manifest.json/.manifest.sig`
  (2026.10.4 and earlier look for exactly those). `scripts/make-dmg.sh` puts
  `Oriel.app` in the image (volume "Oriel <version>"), `release.sh` titles releases
  "Oriel <version>". The updater accepts any `.app` in the image with the same
  bundle ID; `Updater.destination(replacing:with:)` installs it as
  `<its name>.app` when the current file is still named `OriCmd` or the app's own
  name and nothing else has that name, so an `OriCmd.app` updated by 2026.10.4 is
  renamed by the following update. The swap script takes the target as `$5`.
- `scripts/install-local.sh` quits `/Applications/(Oriel|OriCmd).app/Contents/MacOS/
  OriCmd`, renames the fork's own `OriCmd.app` (checked by `OriCmdFork = tosiabunio`)
  and installs `Oriel.app`.
- About's copyright line ("OriCmd contributors") is unchanged. At the user's request
  the line under the version reads "OriCmd fork" (fixed text, not translated) instead
  of "tosiabunio fork"; the `OriCmdFork` Info.plist value stays `tosiabunio`, which
  `install-local.sh` uses to recognise the fork's own `OriCmd.app`.
- The README calls the app Oriel and keeps OriCmd for upstream, file names and code
  paths. It also says the Dock keeps the label an icon had when it was pinned: the
  user's Dock tooltip still said OriCmd after the rename (`file-label` in
  `com.apple.dock` persistent-apps); Options → Keep in Dock off and on refreshes it.
- Validation: 366 of 367 regression checks; the one failure, "the context menu ends
  with Share and Tags", opens a real menu and wrote nothing while the new Oriel had
  just launched and the user was looking at its menu bar; rerun alone it passed. 13
  core tests, signed-update checks, localization, the swap script on disposable
  folders (rename, in place, failure keeps the old app), About and Settings →
  General snapshots in English and Russian.

## Oriel's own identity: bridge and switch (2026-10-07)

The user asked to continue with the plan after the visible rename: first a "bridge"
release whose updater accepts the fork's own identity, then the switch itself.
- Bridge, branch `id-bridge` (worktree `build/ib`): `e2b5183` + `0d81e7a` (guide),
  on `main` and `local-build`. `UpdateVerification.assetPrefixes` (`Oriel`,
  `OriCmd`) and `forkBundleIdentifier` (`io.github.tosiabunio.oriel`); `manifest(…,
  bundleIdentifiers:)` takes a set (the running app's and the fork's); the app in
  the image must have the manifest's identifier; `Release` finds `Oriel-` or
  `OriCmd-` files. `update-signer sign` takes the bundle identifier as a 7th argument
  and `release.sh` passes the one of the app it built.
- 2026.10.5 should publish the bridge (with the rename, Settings fit and About
  line); notes in `build/notes-2026.10.5.md`. Running `scripts/release.sh` from this
  session was refused by Claude Code's auto-mode classifier ("Create Public
  Surface"): a release needs the user's explicit go-ahead in that session, or the
  user runs it (`! scripts/release.sh 2026.10.5 build/notes-2026.10.5.md`).
- Switch, branch `oriel-id` (worktree `build/oi`), `95b70fd`, deliberately NOT on
  `main`/`local-build` until 2026.10.5 is out (a release ships whatever `main` is):
  bundle IDs `io.github.tosiabunio.oriel` (+ `.Highlighter`, `.CoreTests`); the XPC
  service name follows the app's identifier; `AppDefaults.moveOriginalSettings()`
  (first thing in `main.swift`) copies the keys of `ru.themmag.OriCmd` not set in the
  new domain once (marker `SettingsMovedFrom`) and never deletes the original's file;
  Keychain service stays `ru.themmag.OriCmd`; release files become `Oriel-<v>…`.
  Test runs copy only from `ORICMD_SETTINGS_FROM` (regress check "settings kept under
  the original's identifier move…" uses `ru.themmag.OriCmd.tests-original`).
  Copies before 2026.10.5 open the release page for it (no signed files they know).
- Order: publish 2026.10.5 → merge `oriel-id` into `main`/`local-build` → install
  locally (the user's settings then live in `io.github.tosiabunio.oriel.plist`; keep
  `ru.themmag.OriCmd.plist` too) → publish the switch some days later, so copies
  reach the bridge first.
- Done on 2026-10-07: 2026.10.5 was published at the user's explicit "publish
  2026.10.5" (release commit `a22488a`, internal build 21,
  https://github.com/tosiabunio/OriCmd/releases/tag/v2026.10.5, `OriCmd-2026.10.5.dmg`
  8,800,755 bytes, SHA-256 `b40b7fc8…79d0e`); verified with the app's
  `UpdateVerification` (driver `build/verify-driver.swift`), size, checksum, codesign,
  universal app and helper, `Oriel.app` inside with `ru.themmag.OriCmd`. All 9 CI runs
  passed. Installed as fork build 38.
- Then `oriel-id` was rebased onto the release (`90b0bf7`; the helper's
  `MARKETING_VERSION` and bundle ID lines conflicted) and `main` = `local-build` =
  `90b0bf7` locally, not pushed. Installed as fork build 39: its first launch copied
  all 35 keys of `ru.themmag.OriCmd` unchanged into `io.github.tosiabunio.oriel`
  (plus `SettingsMovedFrom`); the original's file kept its 35 keys.
- Validation of the switch: 367 of 368 regression checks (the new settings-move check
  included); "SFTP: a cancelled download leaves the app idle" failed under load and
  passed alone (CPU time flat at 2.00 s). 13 core tests, 25 signed-update checks,
  localization, the Look and Settings section after the rebase.
- Next: push `main`, `local-build` and `oriel-id` when the user agrees; publish the
  switch (2026.10.6 if still October) only some days after 2026.10.5.
- Pushed at the user's request: `main` = `local-build` = `39ce953`, with `oriel-id`
  and `id-bridge`; all 12 CI runs passed. The switch is not published yet.

## Release 2026.10.6: Oriel's own identity and repository (2026-10-07)

The user said they are the fork's only user, so the switch and the repository rename
went out at once instead of days after the bridge.
- Branch `oriel-repo` (worktree `build/or`), `87df426`: `Updater.repository`,
  `release.sh`'s `REPOSITORY`, About's fork link, README, the guides and the update
  tests name `tosiabunio/Oriel`. Then `gh repo rename Oriel` (the repository is still
  a GitHub fork of `mmag/OriCmd`; the old git and API addresses redirect, the API with
  a 301), and the `fork` remote was set to `tosiabunio/Oriel.git`.
- `scripts/release.sh 2026.10.6` (release commit `7fd94fc`, internal build 22, tag
  `v2026.10.6`): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.6 has
  `Oriel-2026.10.6.dmg` (8,803,638 bytes, SHA-256 `54f922b7…10e9d0`), its manifest and
  signature. Verified with the app's `UpdateVerification` for `tosiabunio/Oriel` and
  `io.github.tosiabunio.oriel`, size and checksum, codesign, universal app and helper
  (`io.github.tosiabunio.oriel.Highlighter`). The notes tell users of 2026.10.5 and
  earlier to install it by hand once: their updaters expect the old repository in
  the signed manifest (and, up to 2026.10.4, the old bundle ID and file names).
- `main` = `local-build` = `7fd94fc`, pushed. Installed as fork build 40, "2026.10.6
  (40)", `io.github.tosiabunio.oriel`; the settings copy did not run again (the
  `SettingsMovedFrom` marker was already set by build 39).
- Worktrees tidied on 2026-10-07 at the user's request: all 37 finished ones under
  `build/` were removed (every branch was pushed and clean; the branches remain,
  locally and on the fork), freeing about 13 GB. Only `build/local-build` and
  `build/review-updates` (it holds the second copy of the signing key, identical to
  `build/update-signing/private.key`) remain. Worktree paths named in the entries
  above no longer exist; start new work in a new short-named worktree from `main`.

## Visual refresh phase 4 installed on 2026-10-07

The user asked to continue the visual plan; phase 4 built what phases 1 and 2 left
over. Branch `ops-badge` (worktree `build/ob`): `a1dbd25`, `e5e8ab3`, `28fba44`,
`8799b3b` (plan and README), `c40ca71`; `main` = `local-build` = `c40ca71`, not pushed.
Installed as fork build 41 ("2026.10.6 (41)").
- 4.1 `a1dbd25`: `ButtonBar` has an Operations button (`cm_Operations`, symbol
  `arrow.up.arrow.down.circle`) at the end of the default bar, added once to saved
  toolbars (`ToolbarHasOperationsButton`, after a flexible space). On macOS 26 its
  `badge` (`NSItemBadge.count`) is running + waiting operations, updated on
  `OperationsStore.didChange`. `MainViewController.operationsInToolbar`: the Modern
  bottom bar hides its Operations button while the toolbar is visible with that
  button (refreshed on toolbar add/remove notifications and `MainWindow.
  toggleToolbarShown`); Classic, a hidden toolbar and macOS 14–15 keep it. Test action
  `toolbar` writes the items ("cm_Operations badge 1") and "bottom: …" to
  `<snapshot>-toolbar.txt`. A copy onto an existing file waits on its question and
  counts as running. `cmd:` adds the colon itself (`cmd:toggleToolbarShown`).
- 4.2 `e5e8ab3`: a Tags section at the end of the sidebar: the seven colors in
  `FinderTags.colors` order under `FinderTags.colorNames()` (the Finder's names,
  Polish here: Czerwony…), dots in `NSWorkspace.fileLabelColors`. `Node.tag`,
  `isSection`; `onTag` → `MainViewController.showTagged` → `FinderTags.files(
  taggedWith:in:)` (`mdfind -0 kMDItemUserTags == "…"`) → `showSearchResults`
  titled "Tagged %@" (ru "С тегом %@"), [..] back to the folder shown (home for a
  server or archive). Test runs search only the test folders; Spotlight indexes
  `build/testdata` in about 3 s. `sidebarpick:` picks tags too.
- 4.3 `28fba44`: `PathBar.place` (folder, archive, server, search results, set in
  `updatePathBar`) draws `folder.fill` / `archivebox.fill` / `server.rack` /
  `magnifyingglass` before the path in the Modern look: accent in the active panel,
  `secondaryLabelColor` in the other (tertiary was too faint in light mode).
- `c40ca71`: `regress.sh` runs `caffeinate -i -w $$`. The "16–17 minute stalls" of
  earlier runs were the Mac in deep idle sleep while the user was away (pmset log:
  DarkWake at the gaps); Claude Code's own caffeinate asserts only 300 s at a time.
- Still deferred (recorded in the plan): lists under the glass toolbar (2.1) and
  split-view accessories (2.2).
- Validation: 371 of 371 regression checks (three new), the five UX suites, 11
  accessibility checks, core tests, localization, captures of the badge, the Tags
  section and the header symbols in light and dark.
- Pushed at the user's request (`main` = `local-build` = `0682d50`, with `ops-badge`),
  then `scripts/release.sh 2026.10.7` (release commit `ff06624`, internal build 23):
  https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.7 has
  `Oriel-2026.10.7.dmg` (8,811,180 bytes, SHA-256 `2b7ff1f2…d1d431`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 42, "2026.10.7 (42)". The notes present phase 4; upstream base still
  0.13.3b.

## Visual refresh phase 5 on 2026-10-07: the tool windows

The user asked to continue the visual upgrades. A survey of every window in the
Modern look (Debug app, demo folders, `ORICMD_DEMO` captures) found the panels
current and the tool windows dated. Branch `modern-polish` (worktree `build/p5`):
`a88744f` (lists), `0ab3e48` (Lister), `9373fa6` (tree, search field), `03e2638`
(plan and README), `983d1cd` (two checks fixed); `main` = `local-build` = this, plus
this entry. The user asked to install and push once the tests passed, then release.
- 5.1 `UI/ListBox.swift`: `ListBox(table, buttons:)` is a rounded box (layer corner
  8, `separatorColor` border, set in `viewDidChangeEffectiveAppearance`) around a
  borderless scroll view; it sets `table.style = .inset`. `ListBox.button(.add /
  .remove / .moveUp / .moveDown, target:selector:)` is a borderless symbol button
  that keeps its title (`imagePosition = .imageOnly`), so `click:Add` and VoiceOver
  still find it. `ListTableView` reports reloads; `placeholder` is an NSTextField
  shown (its text set) only while the table is empty, so window dumps contain it.
  The box has no fill: an inset table draws no background, the window's shows
  (AppKit tints `NSColor` fills in dark mode, but not a layer's `cgColor`, so a
  layer fill did not match). Used by the hotlist, file colors, Start menu,
  connections (+ replaces New), associations, column sets, shortcuts, Operations
  ("No operations this session" moved into the list), Find Files (results and
  templates), Multi-Rename, Synchronize, the network browser and the command palette
  (no header, shortcuts right-aligned grey, `EmphasizedRowView` keeps the chosen row
  in the accent color while the search field has the focus). Compare, the Finder-like
  Connect to Server sheet and the text views in alerts are unchanged. Find Files and
  Multi-Rename put their buttons in the stack's trailing gravity area.
- 5.2 Lister: title = file name, `subtitle` = folder (`~`) — detail (encoding,
  book, model); `representedURL` for local files. Toolbar (unified, both looks):
  `filesControl` (momentary P/N), `modeControl` (1/3/7; segment 2's symbol and
  tooltip follow `richMode`: Quick Look, Table, Book, 3D Model, Page),
  `optionsControl` (`.selectAny` W/H/F; the clicked segment is the one whose state
  differs from `optionStates`), `NSMenuToolbarItem` of encodings, Find. Tooltips are
  "Title (key)". `updateToolbar()` runs from `updateTitle()` and the toggles. Text
  inset 10 × 8.
- 5.3 Tree: Modern sets `.inset` and keeps the outline column at the panel's width
  (`autoresizesOutlineColumn = false`), else the column grows with deep folders and
  the rounded ends leave the view. The tree cannot show folders under `/tmp`
  (`/private` is hidden, symlinks are left out). Quick search: `PanelView.
  quickSearchField` is an `NSSearchField` in both looks (`FilePanelController` is its
  `NSSearchFieldDelegate`; doCommandBy still gets Escape/Return/arrows first).
- Test harness: a window dump's first line is "title — subtitle"; `toolbar` lists the
  frontmost window's toolbar (a sheet's owner), segmented controls as
  "tooltip ✓ (off), …". `cmd:cm_InternalAssociate` opens Associations. New checks:
  the Lister's title and toolbar in text and hex (on `cp1251.txt`: the test data's
  `readme.txt` is random bytes and opens in hex), an empty hotlist's placeholder,
  the Start menu's + (`click:Add`).
- Left for later (in the plan): the Thumbnails `..` tile, Compare's text frames.
- Validation: 374 of 376 regression checks on the first run; the two failures were
  the tests' (the hang check still expected `spin2.swift]` of the old title; the
  toolbar dump marked buttons a sheet disables, so `cm_Operations badge 1` no longer
  matched exactly). Fixed and rerun with the new checks on the final build: all pass.
  Five UX suites, 11 accessibility checks, 13 core tests, localization; captures of
  every changed window in light and dark.
- When rerunning a few checks, a copy of regress.sh's header must `cd` to the
  worktree: its `cd "$(dirname $0)/../.."` is relative to where the copy lies.
- Installed as fork build 43 and pushed (`main` = `local-build` = `6849e36`, with
  `modern-polish`), then, at the user's request, `scripts/release.sh 2026.10.8`
  (release commit `16d4d90`, internal build 24):
  https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.8 has
  `Oriel-2026.10.8.dmg` (8,847,142 bytes, SHA-256 `f35fee3b…f78c9a`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 44, "2026.10.8 (44)". The notes present phase 5; upstream base still
  0.13.3b.

## Visual refresh phase 6 on 2026-10-08: thumbnails and copying

The user asked to continue the visual upgrades after 2026.10.8. A second survey
(including the copy progress, caught with `speed:5_MB/s` and `CopyAttributes` off,
since a copy on one APFS volume is an instant clone) found four dated spots. Branch
`modern-details` (worktree `build/p6`): `be0c33f` (thumbnails), `1c5c73f` (progress
and overwrite question), `108bee3` (Compare), `993c32d` (plan and README).
- Thumbnails (Modern only): `ThumbnailCache.thumbnail(for:size:asIcon:ready:)` sets
  `QLThumbnailGenerator.Request.iconMode` (pages with an edge, pictures with a
  border); the cache key holds the URL and the mode. `FileListView.parentThumbnail`:
  the folder icon at the thumbnail size, faded to 0.55, with a white
  `arrow.turn.left.up`. Classic keeps both as before.
- Copy progress: `TransferEngine.copyFile(_:to:showing:size:)` reports the final
  target, not `.oricmd-….part`. `TransferController` has `fileDetail` ("x of y") and
  `totalDetail` ("x of y · speed/s · About N seconds remaining", a
  `DateComponentsFormatter` with the approximation and time-remaining phrases; speed
  from `samples` of the last 3 s, none while paused or before 1 s).
- Overwrite question: title "A file named “x” already exists" (the existing string
  of the folder-replacing alert), the file type's icon, and `comparison(existing:new:)`
  as the accessory (size via `Settings.formattedSize`, bytes when two short sizes read
  the same; `Theme.dateText`; the folder; " · newer" in the accent color).
  `alert.layout()` after adding the buttons, or the two-line title showed one line.
- Compare: `ListBox(table, style: .plain)` and a `ListBox` around the detail text view.
- Test snapshots of an NSAlert in dark mode come out white with the white text
  missing (`cacheDisplay` and the alert's glass); only light ones are readable.
- Checks: "a copy under way names its target…" (climit), "the overwrite question
  compares the two files…" (overwriteq); the SFTP "No Resume" check now expects the
  new title.
- Validation: 378 of 378 regression checks (the two new ones included), the five UX
  suites, 11 accessibility checks, 13 core tests, localization, captures in light and
  dark. The user asked to install, push and release 2026.10.9 once the tests passed.
- Installed as fork build 45 and pushed (`main` = `local-build` = `5ba6d98`, with
  `modern-details`), then `scripts/release.sh 2026.10.9` (release commit `06f7582`,
  internal build 25): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.9 has
  `Oriel-2026.10.9.dmg` (8,872,329 bytes, SHA-256 `84759eb3…b20fe9`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 46, "2026.10.9 (46)". The notes present phase 6; upstream base still
  0.13.3b.

## Visual refresh phase 7 on 2026-10-08: dialogs

The user asked to continue the visual upgrades after 2026.10.9. A third survey
(scratchpad `survey7.sh`: copy/move/unpack dialogs, the delete questions, tabs, branch
view, the simple prompts, Connect to Server, the network browser, Quick View, the
Lister's table and pictures) found the dialogs dated. Branch `modern-dialogs`
(worktree `build/p7`): `42e9245` (copy dialog, questions), `065c345` (Connect to
Server), `cf0b63c` (Lister table, key hints), `901604f` (plan, README, all seven
README screenshots regenerated). The user asked to install, push and release
2026.10.10 once the tests passed.
- Copy/move dialog, Modern only (`CopyDialog.heading`): `FileIcons.icon(for:)` (the
  item's icon, a folder for several folders, the Finder's document stack for several
  files) beside "Copy “x”" / "Copy 2 folders" (ru "Копирование: 2 папки"), the names
  (`Prompt.names`) and From. `CopyDialog.mask` is "" in Modern, so the target is
  the folder alone (`resolveTarget` treats "dir/" as "dir/*.*"). The F7/F8 buttons
  are a star (`star.fill` + accent when listed; hidden title "Add to the Target
  List") and `line.3.horizontal.decrease.circle` ("Filters"); the filter's
  placeholder "All files"; `OverwriteMode.plainTitle` drops TC's "1. " (Settings →
  Operations too); buttons sized to their titles (min 84): Options (a chevron,
  shows and hides the options), Choose…, Queue (F2). Classic unchanged.
- Questions: "Move “x” / 2 items to the Trash?", "Delete … immediately?", names of
  several under the title, `Prompt.confirm(icon:)` with the items' icon; "%lld items"
  (plural, ru объект/объекта/объектов) replaces "%lld files/folders" everywhere;
  several existing items: "%lld items already exist. Replace them?". The unused
  old keys were removed from the catalog.
- `ServerAddressSheet`: `ListTableView` in a `ListBox` with `ListBox.button(.remove)`
  and "No recent servers". The network browser's Connect… is in the trailing area.
- `TableGridView`: `columnAutoresizingStyle = .noColumnAutoresizing`.
  `FunctionKeyBar.Item.modernTitle`: "New Folder", "Quit" in Modern.
- Tests: `click:Options` (was `Options_>>`) in regress.sh and screenshots.sh;
  ux-copy.sh checks the new heading, the bare target and Russian; new regress
  checks copyhead, copyclassic (Look classic keeps `*.*` and "Marked selection"),
  trashq, norecent.
- Validation: 382 of 382 regression checks (four new), the five UX suites, 11
  accessibility checks, 13 core tests, localization, captures in light and dark, the
  Russian copy dialog, the Classic dialog unchanged.
- Installed as fork build 47 and pushed (`main` = `local-build` = `2350ef0`, with
  `modern-dialogs`), then `scripts/release.sh 2026.10.10` (release commit `be8c227`,
  internal build 26): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.10 has
  `Oriel-2026.10.10.dmg` (8,880,689 bytes, SHA-256 `d4b9f92d…079d9d`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release (the first
  with a two-digit RELEASE: `release.sh` and the updater compare each part as a
  number). Reinstalled as fork build 48, "2026.10.10 (48)". The notes present phase 7;
  upstream base still 0.13.3b.

## Visual refresh phase 8 on 2026-10-08: the rest of the tools

The user asked to continue the visual upgrades after 2026.10.10. A fourth survey
(scratchpad `survey8.sh`: every tool window and dialog the earlier phases left, all
Settings panes) found six spots. Branch `modern-tools` (worktree `build/p8`):
`fc4a448` (Find Files), `4006087` (hex), `dfd5612` (attributes), `fd78973` (Compare),
`6d0504f` (Pack), `2383946` (Synchronize, Settings note), `c8b43e9` (plan, README,
screenshots: Compare, Synchronize and others recaptured). The user asked to install, push and release 2026.10.11 once the tests
passed.
- Find Files results stay a cell-based table whose value is the full path (window
  dumps and every `[row]` check read it); `FoundFileCell` (`column.dataCell`, filled
  in `willDisplayCell`) draws the icon (cached per path in `icons`, cleared on a new
  search; by extension for archive entries), the name and the folder relative to
  `query.root` in grey (white-ish on the emphasized selection).
- Hex view: `shadeHexDump()` after `makePlain()` colors columns 0–7 secondary and,
  in the text column (59), each "." whose byte is not 2E tertiary. The text and its
  76-character lines are unchanged, so `findBytes` still maps offsets. A hex window
  dump now has "[text colors: 3]".
- Change Attributes (still an NSAlert): `alert.icon = FileIcons.icon(for:)`, grid
  column 0 leading, the date picker on its own line at least as wide as a short
  date + medium time in its font + 44.
- Compare: `DifferenceRowView` (`rowViewForRow`): `interiorBackgroundStyle .normal`,
  a 2 pt accent outline and a 4 pt leading bar (alpha 0.55 when not emphasized). A
  translucent band was tried first: over the yellow of a changed line it read grey.
- Pack: rows 5–6 (password, repeat) hidden unless Encrypt is on, row 7 (hint) while
  empty; on a change `grid.frame.size = fittingSize` and `alert.layout()` resize the
  open sheet.
- Synchronize: `Settings.shortSize` and " · " separators; the Settings → Operations
  note says "its options" (the old keys were removed from the catalog).
- Checks: hex colors (3, on the existing listerhexbar run), syncsum (the summary's
  form). Window dumps include hidden text fields, so Pack's hidden rows cannot be
  checked by text.
- Validation: 384 of 384 regression checks (two new), the five UX suites, 11
  accessibility checks, 13 core tests, localization, captures in light and dark.
- Installed as fork build 49 and pushed (`main` = `local-build` = `61e876a`, with
  `modern-tools`), then `scripts/release.sh 2026.10.11` (release commit `c429d0a`,
  internal build 27): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.11 has
  `Oriel-2026.10.11.dmg` (8,901,317 bytes, SHA-256 `53c5b2cb…3eb5f5`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 50, "2026.10.11 (50)". The notes present phase 8; upstream base still
  0.13.3b.

## Visual refresh phase 9 on 2026-10-09: the panel header's type

The user found the panel header clumsy ("different fonts, small size"): the path was
drawn in the list's font (their Monaco 15) and the volume chip, counts, free space,
column titles and tab titles in 11 pt SF. Branch `modern-header` (worktree `build/p9`):
`87ad71e` (the header), `5de4ded` (plan, README, screenshots). The user asked to
install, push and release 2026.10.12 once the tests passed.
- `Theme.headerTitleSize` = the list font's size rounded, 12–18; `headerTitleFont`
  (system), `headerChipFont` (−1), `headerDetailFont` (−2, at least 11),
  `Theme.lineHeight(_:)`. Modern only; Classic keeps `Theme.panelFont` in the path and
  `chromeFont` elsewhere.
- `PathBar`: path and its edit field in `headerTitleFont`, the current folder in a
  semibold system font (no more bold Monaco); `chipFont`/`chipIconSize` instance
  properties; the info line and an info-line free space in `infoAttributes` (detail
  font); `pathLineHeight` = line + 6, `infoLineHeight` = line + 1, heights 4 + path +
  (info + 3 | 2): still 28/44 at 13 pt. `PathBar.pathLineCenter` places the loading
  spinner (was 15/11).
- `FileListHeaderView.height` = detail line + 8 (22 at 13 pt), titles in the detail
  font, the chevron at size − 3. `FolderTabBar`: `font`, `height` = max(24, line +
  10) for Mac-style tabs, `iconSize` = font + 3, `sideRoom` (room for icon or close
  button) so large titles do not run into the icon.
- The Settings → Colors preview's column titles use the same font and height.
- Captures: scratchpad `survey9.sh` with `FONT=Monaco FSIZE=15` (writes
  `PanelFontName`/`PanelFontSize` to the test suite).
- Validation: 384 of 384 regression checks, the five UX suites, 11 accessibility
  checks, 13 core tests, localization; captures at 12, 13, 15 and 18 pt, light and
  dark, and the Classic look unchanged.
- Installed as fork build 51 and pushed (`main` = `local-build` = `08e03f1`, with
  `modern-header`), then `scripts/release.sh 2026.10.12` (release commit `23ebeca`,
  internal build 28): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.12 has
  `Oriel-2026.10.12.dmg` (8,909,880 bytes, SHA-256 `e4778513…69c671`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 52, "2026.10.12 (52)". The notes present phase 9; upstream base still
  0.13.3b.

## Visual refresh phase 10 on 2026-10-09: the bottom bar

The user asked to continue after 2026.10.12. With their Monaco 15 the bottom bar had
the header's mismatch (prompt, command and hints at 11 pt), and plan 2.4's modifier
hints were never built. Branch `modern-bottom` (worktree `build/p10`): `d6c2ffb`
(the bar and the hints), `62cda9d` (plan, README, screenshots). The user asked to
install, push and release 2026.10.13 once the tests passed.
- `CommandLineView.applyLook()` (from init and `applyLayoutSettings`): Modern prompt
  in `Theme.headerDetailFont`, `secondaryLabelColor`; field in
  `monospacedSystemFont(ofSize: detail size)`, regular control size from 13 pt;
  `CommandLineView.height` = max(26, line + 12) in Modern.
- `FunctionKeyBar`: `hintFont`/`hintKeyFont` = detail font, `keyCapFont` = detail − 1
  in Modern (10 in Classic), `hintCapHeight` = line + 4, `compactHeight` = max(24,
  cap + 8); `MainViewController.bottomBarHeight` = max(34, compactHeight + 10) and the
  fixed 24 pt key bar constraint was dropped (the intrinsic height serves).
- Modifier hints: `FunctionKeyBar.modifiers` (a local `.flagsChanged` monitor while in
  a window; [] when its window resigns key or while `firstResponder is NSText`),
  `shownItems` = `items(for:)`: commands whose `KeyBindings.shortcut` is F1–F12 with
  exactly the held ⇧⌥⌃⌘, by key, titled by `Command.hintTitle` (short words); plain
  items when none. Drawing, widths and clicks use `shownItems`; the compact
  intrinsic width is max(plain, shown) so the command line never jumps.
- Test action `hints:shift|option|control|none` → `<snapshot>-hints.txt` ("⇧F5 Copy
  Here"), through `MainViewController.keyHints(holding:)` (DEBUG). Checks hintshift,
  hintcontrol, hintnone.
- 3.1's segmented options for Compare/Synchronize were dropped (recorded in the plan).
- Validation: 387 of 387 regression checks (three new), the five UX suites, 11
  accessibility checks, 13 core tests, localization; captures at 13 and 15 pt, the
  three modifier sets and the Classic look.
- Installed as fork build 53 and pushed (`main` = `local-build` = `5f5bbad`, with
  `modern-bottom`), then `scripts/release.sh 2026.10.13` (release commit `9f4d7d7`,
  internal build 29): https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.13 has
  `Oriel-2026.10.13.dmg` (8,925,333 bytes, SHA-256 `2a2d01a5…ec2b0c`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 54, "2026.10.13 (54)". The notes present phase 10; upstream base still
  0.13.3b.

## Visual refresh phase 11 on 2026-10-09: the rows' icons

The user asked to continue after 2026.10.13. With their Monaco 15 (25 pt rows) the
16 pt icons looked a size too small next to the larger header and bottom bar. Branch
`modern-rows` (worktree `build/p11`): `8f073a0` (the icons), `38dff60` (plan, README).
The user asked to install, push and release 2026.10.14 once the tests passed.
- `Theme.rowIconSize`: Modern = row height − 6, rounded, 16–24 (16 for the standard
  22 pt and compact rows, so the README screenshots are unchanged); Classic 16.
  `FileListView` uses it for the icon rect (the checkmark at 0.69 of it), the room
  before the name in Full and Brief (`rowIconSize + 4`), the inline rename field's
  indent and the Brief column's width.
- Captures: scratchpad `survey11.sh` (`FONT=Monaco FSIZE=15`, 18 pt, Brief, rename,
  Classic).
- Validation: 387 of 387 regression checks, the five UX suites, 11 accessibility
  checks, 13 core tests, localization. "Dragging the edge of Name widens the next
  column" first failed (Ext 4–5 pt wider than asked), also with phase 10's released
  build; the user's mouse pointer rested over the test window (a toolbar tooltip
  showed in captures). With the pointer moved off it, both header-drag checks passed.
  A real pointer over the test window can disturb synthetic header drags.
- Installed as fork build 55 (`38dff60`).
- Pushed (`main` = `local-build` = `f211bac`, with `modern-rows`), then
  `scripts/release.sh 2026.10.14` (release commit `e98575b`, internal build 30):
  https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.14 has
  `Oriel-2026.10.14.dmg` (8,926,046 bytes, SHA-256 `fbb7ca19…0593ce`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 56, "2026.10.14 (56)". The notes present phase 11; upstream base still
  0.13.3b.

## Upstream 0.13.4b integrated on 2026-10-11

Branch `upstream-0.13.4b` (worktree `build/u4`; first `build/up134`, moved because
its path hid the root crumb) merges upstream through `origin/main` at `7fbc363`:
dragging between the panels moves with ⌥ as well as ⌘ (`dropOperation` returns
`.move` for a `FileListView` source with either key; other apps' files keep ⌥ as
copying), ⌘ no longer leaves a drop between the panels with nothing to do, and the
"+" of a copy shows from the start (no `.generic` in the in-app source mask). Merge
`09d17c2` keeps the fork's project file (version 2026.10.14, internal build 30, the
Oriel bundle IDs; upstream only bumped to 0.13.4b/18), keeps `README.ru.md` deleted,
adds the ⌥ sentence to the fork's README Mouse section and names 0.13.4b/`7fbc363`
as the latest imported upstream checkpoint. The drag change has no automated check
(synthetic drags with modifiers are not in the test harness).
- Validation: Debug build, 13 core tests, localization, 383 of 387 regression checks
  on the full run, the other four passed when rerun: "/ in the path bar goes to the
  root" (path length, passed from `build/u4`), "Combine: a damaged piece is said so"
  (the sheet had not appeared yet; passed alone) and the two Bonjour checks (`dns-sd`
  cannot register inside Claude Code's sandbox; passed with it off). The five UX
  suites and 11 accessibility checks passed.
- Installed as fork build 57 (`2bd1c15`) and pushed (`main` = `local-build` =
  `2bd1c15`, with `upstream-0.13.4b`), then, at the user's request,
  `scripts/release.sh 2026.10.15` (release commit `b6a4497`, internal build 31):
  https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.15 has
  `Oriel-2026.10.15.dmg` (8,930,370 bytes, SHA-256 `599a937e…9adfea`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 58, "2026.10.15 (58)". The notes present the drag change; upstream
  base 0.13.4b (`7fbc363`).

## Date sorting starts with the newest: release 2026.10.16

The user asked that a new sort by date show the newest files first (it started with
the oldest). Branch `date-newest` (worktree `build/dn`), commit `914e315`:
`SortColumn.startsDescending` (`.date` and `.created`) and `FilePanelController.
sort(by:)` starts such a column descending; the same key or title again reverses it
as before. Ctrl+F5, `⌃⌥⌘3`, Show → Sort by Date and a click on the Date (or Created)
title all go through `sort(by:)`. README key table says "date (newest first)".
- Checks (after "a click on the Name title reverses the order"): datesort, dateback,
  dateclick, on a `dated` folder of three files with `touch -t` times.
- Validation: those three and the two existing sort checks, 13 core tests. The full
  regression suite was not run (nothing else sorts by date).
- Installed as fork build 59 and pushed (`main` = `local-build` = `7615f29`, with
  `date-newest`), then, at the user's request, `scripts/release.sh 2026.10.16`
  (release commit `3d88cf9`, internal build 32):
  https://github.com/tosiabunio/Oriel/releases/tag/v2026.10.16 has
  `Oriel-2026.10.16.dmg` (8,930,614 bytes, SHA-256 `e8521ab2…a5e40d`), verified with
  `build/verify-driver` for `tosiabunio/Oriel` and `io.github.tosiabunio.oriel`, size,
  checksum, codesign, universal app and helper; it is the latest release. Reinstalled
  as fork build 60, "2026.10.16 (60)". Upstream base still 0.13.4b (`7fbc363`).
