# Oriel

Oriel is an independently maintained fork of [OriCmd by mmag](https://github.com/mmag/OriCmd),
developed in [tosiabunio/Oriel](https://github.com/tosiabunio/Oriel). Releases up to
2026.10.4 carried the original name, and up to 2026.10.5 the repository
(`tosiabunio/OriCmd`) and the disk image files did; the source keeps it. This fork
has its own interface improvements, development direction and release channel. Selected changes from the original project may be imported
after review and testing; the fork is intended to remain a separate project, with
no planned merge back upstream.

A two-panel file manager for macOS with a familiar look: two panels, function
key buttons at the bottom, a command line and full keyboard control — everything
in its usual place. The standard macOS shortcuts (`⌘C`, `⌘V`, `⌘Q`, `⌘W`, …)
keep working as always.

![Oriel main window](docs/screenshots/en/main.png)

## What this fork adds

- **Modern look:** the panels are drawn as Mac lists are — a rounded cursor in
  the accent color (grey in the other panel or while Oriel is in the
  background), rounded alternating rows, marked rows tinted lightly, Ext, Size and
  Date in grey, `--` for folder sizes, no
  `[brackets]` or Attr column by default, a thin accent strip over the active
  panel's path with its counts and free space below, and a hairline between the
  panels. Rows are 22 pt with 13 pt names, or compact. Settings → Panels → Look →
  Classic (Total Commander) brings back the traditional panels in one step; see
  the [visual refresh plan](docs/visual-refresh.md).
- **App icon:** a layered Liquid Glass icon (`OriCmd/AppIcon.icon`, made for Icon
  Composer) of two panes and a cursor that copies across, with the system's dark,
  clear and tinted versions; macOS 14 and 15 get flat images of it.
- **Sidebar and one bottom bar:** in the Modern look a sidebar lists devices (with
  free space where the whole name fits beside it), the usual folders, the directory hotlist and the Finder's color tags
  (a tag lists its files in the active panel; `⌃⌘S` or the toolbar button shows or
  hides the sidebar); the command line, the function keys as compact hints and
  Operations share one bar under the panels. Holding `⇧`, `⌥` or `⌃` the hints show
  what the function keys do with it (`⇧F5` Copy Here, `⌃F3` sort by name…). Operations also has a toolbar button
  whose badge counts what runs or waits (macOS 26), and the header shows a symbol
  for the folder, archive, server, search results or Quick View before the path.
- **Tool windows as Mac windows:** the Lister (`F3`) is titled with the file's name
  (its folder and encoding below it, the file's icon draggable) and its keys are
  also a toolbar: previous and next file, text, hex or Quick Look (or the table,
  book, page or model), wrapping, highlighting, formatting, the encoding and Find.
  Lists in tool windows (hotlist, Start menu, file colors, associations,
  connections, shortcuts, Operations, Find Files, Multi-Rename, Synchronize, the
  command palette) are rounded boxes with rounded rows, + and − below them, and
  say when they are empty. Quick search and the quick filter type into a search
  field, and in the Modern look the tree's cursor is rounded like the panels'.
- **Copying you can follow:** the progress shows the amounts, the speed and the time
  left; the overwrite question compares the two files (size, date, folder) and says
  which is newer. In the Modern look thumbnails are drawn as the Finder draws them,
  documents as pages and pictures with a border.
- **Dialogs that name what they act on:** in the Modern look the copy and move
  dialog shows the icon and name of what it copies ("Copy “notes.txt”", "Copy 2
  folders") and the target folder without the `*.*` mask, with a star for the
  target list and a filter button. The delete questions ask as the Finder does
  ("Move 2 items to the Trash?", "Delete “notes.txt” immediately?") with the items'
  icon and names. Connect to Server keeps its recent servers in a rounded list, the
  Lister's table columns are as wide as their texts, and the key hints say New Folder
  and Quit. A folder that cannot be opened is named with its icon, and the message
  says why in plain words ("You don’t have permission to see its contents.").
- **Tools that read at a glance:** Find Files lists its results with their icons,
  names and, in grey, their folders; the hex view greys the offsets and the dots that
  stand for bytes with no character; Compare outlines the chosen line, keeping its
  colors; Change Attributes shows the items' icon and the whole date; Pack shows the
  password fields only when encrypting.
- **Mac-style panels:** compact headers, folder icons and close buttons on tabs,
  key caps on function buttons, Finder-style sizes and status summaries, folder
  colors from Finder tags, and options for folder brackets and file extensions.
  Column widths can be dragged in the header. In the Modern look the header, the
  drive buttons, quick search and the status line are in the system font whatever
  font the list uses, their sizes in proportion to the list's, and the rows' icons
  grow with a larger list font. Tabs that do not fit become narrower, then scroll
  with the selected one in view; a narrow panel leaves out Date, then Size, before
  it shortens names; a folder that cannot be opened shows the Finder's no-entry
  badge; renaming in place edits in an opaque field outlined in the accent color.
- **Drive information:** click the free-space or total-capacity readout to open
  Finder's information window for the panel's volume, in either header layout.
- **Clear selection and filters:** checkmarks distinguish marked items from the
  cursor in Full, Brief and Thumbnails views. Filter indicators show text, masks
  and selected-only rules with match counts and a clear button. Counts exclude
  the parent-folder row; clearing keeps hidden-file and ignore-list preferences.
  Disable checkmarks in Settings → Panels → Show checkmarks on marked items.
- **Copy and move dialogs:** source, destination, affected names and marked/cursor
  scope are visible before confirming. Copy/Move buttons name the action, and
  overwrite rules stay visible when advanced options are collapsed.
- **Operations window:** Commands → Operations, the panel indicator and progress
  dialogs show queued and running work, progress, errors, cancellations and skipped
  local items. Cancel pending jobs or request cancellation of running jobs;
  Clear Finished keeps active and queued work.
  The most recent 100 results are kept until the app quits.
- **Command palette:** Commands → Run Command… (⇧⌘P) searches localized names and
  `cm_*` commands, displays current shortcuts and recent commands, and disables
  unavailable actions. Use ↑/↓ and Return to run a command, or Esc to dismiss.
- **Accessibility:** Full, Brief and Thumbnails panels expose file names, types,
  sizes, dates, selection and open actions to macOS accessibility and VoiceOver.
- **Authenticated updates:** this fork checks its own GitHub releases and verifies
  the publisher's signature and image checksum before installing an update.

## Features

- **Panels:** tabs, history, directory hotlist, tree, filters, quick search, a
  clickable path (breadcrumbs) that is also editable with `Tab` completion; full and
  brief views, thumbnails, optional columns, file colors by mask, folders in the
  color of their Finder tags, and ready-made colors for color vision deficiencies.
- **Copy and move:** queue and background operations, file type filter, name
  masks, overwrite modes, verification after copying.
- **Archives as folders:** zip, tar, 7z and more — browse, extract, pack and
  change files right inside an archive; archives inside archives open too.
- **Servers in a panel:** SFTP (through the system ssh, with keys and
  passwords) with the server's terminal under the files, FTP/FTPS, saved and
  recent connections; smb, afp, NFS and WebDAV as volumes.
- **Tools:** viewer (`F3`) for text (UTF-8, UTF-16, Windows-1251, DOS, KOI8-R
  and other encodings) with syntax highlighting of code in about 190 languages,
  tables (Excel 2003 XML, HTML exports, CSV), e-books (FB2, EPUB, MOBI/AZW3,
  DjVu), hex and Quick Look (office documents too), compare files by content, synchronize directories, multi-rename, find
  files, checksums, attributes, the Finder's Get Info.
- **Make it yours:** your own keyboard shortcuts (including import from
  `wincmd.ini`), a Start menu, programs for `Enter`/`F3`/`F4` by file mask, a
  customizable button bar, the right mouse button marking files.
- Light and dark themes, English and Russian interface, signed updates from this fork's GitHub releases.

## Screenshots

The screenshots show this fork's interface with its default settings in the dark theme.

| | |
|---|---|
| ![Copy dialog](docs/screenshots/en/copy-dialog.png)<br>Copy (`F5`): what is copied and from where, the target, a file type filter, overwrite modes | ![Settings](docs/screenshots/en/settings.png)<br>Settings with a panel preview |
| ![Compare by content](docs/screenshots/en/compare.png)<br>Compare files by content | ![Multi-Rename Tool](docs/screenshots/en/multi-rename.png)<br>Multi-Rename Tool (`Ctrl+M`) |
| ![Synchronize directories](docs/screenshots/en/sync.png)<br>Synchronize directories | ![Thumbnails view](docs/screenshots/en/thumbnails.png)<br>Thumbnails (`Ctrl+Shift+F1`) |

The screenshots are made by `scripts/screenshots.sh` on demo folders
(in `docs/screenshots/en`).

## Installation

Download `Oriel-<version>.dmg` (`OriCmd-<version>.dmg` up to 2026.10.5) from the
latest release on this fork's
[Releases](https://github.com/tosiabunio/Oriel/releases) page (a universal app for
Apple Silicon and Intel, macOS 14+). Or build the same image from this repository:

```sh
git clone https://github.com/tosiabunio/Oriel.git
cd Oriel
scripts/make-dmg.sh        # → build/Oriel-<version>.dmg
```

The Homebrew cask `mmag/tap/oricmd` distributes the original project's builds.

Open the image and drag Oriel to Applications. The app is ad-hoc signed,
without an Apple certificate, so macOS may require approval the first time: right-click
Oriel → Open → Open (or System Settings → Privacy & Security → Open Anyway).
Or remove the quarantine:

```sh
xattr -dr com.apple.quarantine /Applications/Oriel.app
```

This fork checks releases from [tosiabunio/Oriel](https://github.com/tosiabunio/Oriel/releases)
once a day (can be turned off in Settings) and with Oriel → Check for Updates….
It installs and relaunches only after verifying the publisher's signature and the
downloaded image's checksum. Unsigned releases open their release page instead.
See [authenticated updates](docs/authenticated-updates.md) for publishing signed
fork releases and managing the signing key. An install from 2026.10.4 or earlier is
`OriCmd.app`: updating it keeps that file name once, and the next update renames it
`Oriel.app` (or rename it in the Finder; settings are kept either way). The Dock
keeps the name an icon had when it was added: if its tooltip still says OriCmd,
right-click the icon → Options → Keep in Dock to turn it off and on again.

From 2026.10.6 Oriel has its own bundle identifier, `io.github.tosiabunio.oriel`,
and its own settings, so it can sit next to the original OriCmd. Its first launch
copies the settings it had under the original's identifier (`ru.themmag.OriCmd`),
which stay as they were for the original app; saved server passwords stay where
they are. macOS asks again for the permissions given to the earlier app (Full Disk
Access, access to folders). Installs of 2026.10.5 and earlier do not update to it
by themselves (the app's identity and the repository's name changed with it):
download it from the Releases page. If the Dock shows a second icon, keep the new
one in the Dock and remove the old one.

## Building

Requires macOS 14+ and Xcode.

```sh
xcodebuild -project OriCmd.xcodeproj -scheme OriCmd -configuration Debug build
```

The terminal is [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (a Swift
package; Xcode fetches it on the first build). Syntax highlighting is
[highlight.js](https://highlightjs.org), kept in `Highlighter/` (the
`OriCmdHighlighter` XPC service, locked down, built with the app);
`scripts/update-highlightjs.sh <version>` takes another version from npm,
checking the package's checksum.

The icon is drawn by `swift scripts/make-icon.swift`.

## Release versions

This fork uses `YEAR.MONTH.RELEASE` calendar versions, starting with `2026.10.0`.
The year has four digits, the month is 1–12 without a leading zero, and the release
counter starts at 0 each month. Each release in the same month increments that
counter: `2026.10.0` → `2026.10.1` → `2026.10.2`; the first release in November
is `2026.11.0`. Numbers advance when preparing a release, not automatically when
building or importing upstream changes.

Tags use `v2026.10.0`; disk images use `Oriel-2026.10.0.dmg` (`OriCmd-…` up to
2026.10.5) and hold `Oriel.app`.
The app's internal build number and the local install counter advance independently
of the calendar version. About shows the version and build, for example `2026.10.0 (21)`,
with `OriCmd fork` below. Builds installed with `scripts/install-local.sh`
use their local install counter in parentheses; other builds use the internal
build number. The window also shows the app icon, name, copyright and full
dependency notices, with clickable links to the original project, this fork
and the dependencies. Commit revisions are not displayed.

Imported upstream versions and commits are recorded separately in release notes.
The latest imported upstream checkpoint is
[OriCmd 0.13.4b, commit 7fbc363](https://github.com/mmag/OriCmd/commit/7fbc363).
Upstream imports preserve this fork's release numbering.

## Keys

On a Mac the F keys control brightness, sound and so on by default. Press them
with `fn`, or turn on "Use F1, F2, etc. keys as standard function keys" in
System Settings → Keyboard.

Commands have internal names (`cm_Copy`, `cm_RenMov`, …) compatible with
`wincmd.ini`; all of them are in the menus. Shortcuts in parentheses are
additional Mac-style ones.

Shortcuts are bound to physical keys: with a Russian (or any other) keyboard
layout `Ctrl+D`, `Ctrl+B`, `Ctrl+U` etc. work just like with the English one.

### Panels and navigation

| Key | Action |
|---|---|
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Move the cursor |
| `Enter`, double-click (`⌘↓`) | Open a folder / open a file |
| `Backspace`, `Ctrl+PgUp` (`⌘↑`) | Parent folder |
| `Ctrl+PgDn` | Go inside a package (`.app` etc.); on a file, open it as an archive whatever its name (`.docx`, `.jar`, a zip named otherwise); a file that is no archive stays as it is, it is never started |
| `Tab` | Switch panels |
| `Alt+←` / `Alt+→` (`⌘[` / `⌘]`) | Back / forward in the folder history |
| `Alt+↓` | Recent folders |
| `Ctrl+Shift+←` / `Ctrl+Shift+→`, `Ctrl+←` / `Ctrl+→` (`⌥⌘←` / `⌥⌘→`) | Show in the left / right panel what is under the cursor: a folder's or an archive's contents, the folder of a file (with the file selected) |
| `Alt+F1` / `Alt+F2` | Volume list of the left / right panel |
| `Ctrl+\` | Root of the volume |
| `Alt+F10` | A folder tree in a dialog: typing a folder's first letters finds it, `Enter` goes there |
| `⌘T` / `⌘W` | New tab (or a double click on the empty part of the tab bar) / close tab (or its × button, shown under the mouse, or a click on it with the mouse wheel) |
| Dragging a tab | To another place of its bar, or onto the other panel's tabs: it moves there, with its server and terminal (a panel's only tab is copied) |
| Commands → Lock Tab / Lock Tab, Allow Folder Changes (also in the tab's context menu) | A locked tab (marked `*`) keeps its folder: going elsewhere opens a new tab beside it; one locked with folder changes allowed comes back to its folder when chosen again. Locks and names given in the tab menu (Rename Tab…) are kept between launches |
| Commands → Favorite Tabs | The tabs of both panels saved under a name and shown again (locks and names too) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` (`⇧⌘]` / `⇧⌘[`) | Next / previous tab |
| `Ctrl+↑` (`⌥⌘↑`) | Open the folder under the cursor in a new tab |
| `Ctrl+D` (`⌘D`) | Directory hotlist: go, add or remove the current folder |
| `Alt`+letter, `Ctrl+Alt`+letter | Quick search by name (`↑`/`↓` — other matches, a leading `*` searches inside names) |
| `Alt+F7` (`⌘F`) | Find files by name, text, date, size and attributes, duplicates too (see [Find Files](#find-files-altf7)); "Feed to Panel" shows the results as a list in the panel, where all commands work on them, `[..]` returns to the search folder |
| `Ctrl+F1` / `Ctrl+F2` (`⌘1` / `⌘2`) | Brief / Full view |
| `Ctrl+Shift+F1` (`⌘4`) | Thumbnails (Quick Look previews) |
| Right-click on the column headers | The columns of the set shown: Ext, Size, Date, Attr and the optional ones — kind, date created, picture dimensions, duration, Finder tags, Finder comment (sortable like the others). Attr is shown by default in the Classic look only. A panel too narrow for them all leaves out Attr, the optional ones, Date and Size, in that order, so names stay readable |
| Drag the edge between two column titles | Resizes a column (the edge after Name resizes the column right of it; Name takes the rest), for every panel; a double click on the edge gives the column its measured width again |
| Show → Columns | Column sets: the Default columns or a set of your own for the panel; Column Sets… makes them, and a set can be used by itself in folders matching masks (`~/Pictures*;*/Photos`) |
| Settings → Panels → File list | File extensions in Full view: in their own column, or after the name (the Ext title still sorts by extension; a long name is cut short before its extension) |
| Settings → Panels → File list → Sizes | Short sizes as the Finder counts them (`1,3 MB`; the default) or every byte, as Total Commander shows them; in the panels, the status line, the free space and when synchronizing |
| Settings → Panels → File list → Status line | As the Finder words it (`2 of 15 selected · 35 KB of 1,2 MB`; the default) or as Total Commander (`35 k / 1 234 k in 2 / 12 file(s), 0 / 3 dir(s)`) |
| `Ctrl+F8` (`⌘3`) | Directory tree; the other panel shows the chosen folder |
| Show → Separate Tree | A folder tree left of both panels: a folder chosen there opens in the active panel, and the tree follows the active panel |
| `Shift+F2` | Compare directories: mark unique and newer files in both panels |
| Commands → Synchronous Directory Changes | Entering a subfolder or going up in one panel is repeated in the other (if it has such a folder) |
| Commands → Synchronize Directories… | Compare two folders recursively and copy in the chosen directions (double-click or `Space` changes the direction) |
| `Ctrl+U` | Swap panels |
| Show → Horizontal Panels | The left panel above the right one (and back); kept between launches |
| Commands → Left = Right / Right = Left | Show the folder of one panel in the other |
| `⌘R` (`Ctrl+R`) | Reread the folder (changes are also picked up automatically) |
| `⇧⌘.` | Show / hide hidden files |
| Show → Ignore List… / Use the Ignore List | Entries the panels leave out — a name, a mask (`*.bak`) or a full path (`~/Library`) per line — while the list is used |
| `Ctrl+F3` … `Ctrl+F6` (`⌃⌥⌘1` … `⌃⌥⌘4`) | Sort by name, extension, date (newest first), size; again — reverse order. Clicking a column header does the same |
| `Ctrl+F7` (`⌃⌥⌘5`) | Unsorted: the order the folder (or archive) has its entries in, folders first |

`Ctrl+F1`…`Ctrl+F8`, `Ctrl+↑` and `Ctrl+←/→` are taken by macOS by default
(focus on the Dock and the menu bar, Mission Control, switching Spaces). Turn
them off in System Settings → Keyboard → Keyboard Shortcuts, or use the
shortcuts in parentheses.

### Selection

| Key | Action |
|---|---|
| `Space`, `Insert` | Mark a file and move down; on a folder, also calculate its size |
| `Alt+Shift+Enter` | Calculate the size of all folders |
| `Shift+↑/↓`, `Shift+PgUp/PgDn/Home/End` | Mark a range |
| `⌘`-click, `Shift`-click | Mark with the mouse (or the right button, if it marks files: see Mouse) |
| `+` / `−` | Mark / unmark a group by mask (`*.txt;*.md`) |
| `*` | Invert the marking of files |
| `Num /` | Restore the previous selection |
| Mark → Copy Names with Details / Copy Full Paths with Details | The name (or full path), size, date and permissions, tab-separated, a line per file |
| Mark → Save Selection to File… / Load Selection from File… / Load Selection from Clipboard | The marked names, one per line (paths of this folder's files are taken too) |
| `⌘A` / `⌥⌘A` | Mark all / unmark all |
| `⌥+` / `⌥−` | Mark / unmark files with the extension of the one under the cursor |
| Show → Filter… | Show only files matching a mask (the mask is shown in the path bar) |
| Show → Only Selected Files | Only the marked files stay in the panel (`[selected only]` after the path) until All Files or another folder |
| `Ctrl+B` (`⌘B`) | Branch view: all files of the folder and its subfolders in one list |
| `Ctrl+S` | Quick filter: only names containing the typed text stay; `Enter` keeps the filter, `Esc` removes it |

### File operations

| Key | Action |
|---|---|
| `F3` | View (Lister): `1` text, `3` hex, `7` Quick Look (images, PDF, media and office documents — Word, Excel, PowerPoint, Pages, Numbers, Keynote, OpenDocument — open in it at once) or a table, an e-book, a web page, Markdown or a 3D model (see below), `W` word wrap; encodings: `8` UTF-8, `U` UTF-16, `A` Windows-1251, `S` DOS (866), `K` KOI8-R, all of them (and Automatically) in the text's context menu and the toolbar — the one used is under the title, kept for `N`/`P`; `H` syntax highlighting on/off, `F` formatting of JSON, XML and code (see below); `N`/`P` next/previous file, `F7`/`⌘F` find, `⇧F7` find with options (case, a regular expression, bytes in hex — found in the hex dump), `F3`/`⇧F3` find next/previous, `Esc` close |
| `F4` | Open in the default text editor (or the program from the associations) |
| `Shift+F4` | Create a new file and open it in the editor |
| `F5` | Copy (to the other panel by default) |
| `Shift+F5` | Copy within the same folder under another name |
| `F6` | Move / rename |
| `Shift+F6`, `F2` | Rename in place (the name is selected; `F2` again selects the extension, then the whole name) |
| `Ctrl+M` | Multi-Rename Tool: masks `[N]`, `[N2-5]`, `[E]`, `[C]`, `[P]`, `[YMD]`, `[hms]`, search and replace (including regular expressions), case, preview and undo; rules saved under a name; the new names given one by one — edited as a list (Edit Names…) or read from a text file, a line per file |
| `F7` (`⇧⌘N`) | New folder (`a/b/c` creates nested ones) |
| `F8`, `Del` (`⌘⌫`) | Move to the Trash |
| `Shift+F8`, `Shift+Del`, `Shift+⌫`, `⇧⌘⌫`, `⌥⌘⌫` | Delete permanently, past the Trash (in the context menu, Delete becomes Delete Permanently while Shift is held) |
| `Ctrl+Shift+F5` | Create a symbolic link (in the other panel by default) |
| Files → Create Hard Link… | Another name of the same file, on the same volume (in the other panel by default) |
| Files → Compare by Content | Two marked files, or the files under the cursors of both panels. The compare window aligns the lines: changed ones are yellow (with the differing part highlighted), removed ones red, added ones green; `N`/`P` (`⌥↓`/`⌥↑`, or the chevrons in the toolbar) — next/previous difference, "Ignore whitespace"; text files can be edited: the toolbar's copy-left and copy-right arrows put a difference on the other side, its pencil ("Edit Line…", or a double click) changes both lines of a row, `⌘S` (or its save button) saves in the file's own encoding and line breaks (closing with changes asks first); binary files are compared byte by byte in hex |
| `Ctrl+Z` | Edit the Finder comment of the file under the cursor (kept with the file, found by Spotlight); the Comment column shows it |
| `⌘I` | Change attributes: rwx permissions, hidden, locked, modification date (also recursively) |
| `Alt+Enter` (`⌥↩`) | Get Info: the Finder's info windows of the selected files (of the folder shown on `[..]`) |
| `Ctrl+Q` | Quick View in the other panel |
| `Esc` | Close a dialog or a window in front (Cancel): copying, questions, Find Files, synchronization, settings |
| `⌘C` / `⌘X` / `⌘V` (`Ctrl+C` / `Ctrl+X` / `Ctrl+V`) | Copy / cut / paste files (compatible with Finder); pasting into the same folder creates "name copy". Files copied or dragged from Microsoft Remote Desktop, virtual machines or Mail (promised files) arrive with their real contents |
| `⌥⌘V` | Move the files from the clipboard here |
| `⌥⌘C` | Copy the full paths of the selected files (Mark → Copy Names — names only) |
| `⌘K` | Connect to a server: `sftp://`, `ftp://`, `ftps://`, `ftpes://` open right in the panel; smb, afp, nfs and WebDAV are mounted as volumes (with a "Connecting…" window you can cancel; a server that does not answer is reported within seconds). The last ten servers connected to are listed under the address: a click picks one, a double click connects, `−` removes one; the window can be made taller |
| `Ctrl+F` (`⇧⌘K`) | Saved connections (passwords are kept in the Keychain) |
| Net → Disconnect | Close the server in the active panel |
| Net → Servers on the Network… | The file servers this Mac sees through Bonjour (SMB, AFP, SFTP/SSH, FTP, WebDAV, NFS); choosing one puts its address into Connect to Server |
| Net → Download from URL… | http(s) and ftp addresses, one per line (the one on the clipboard offered), downloaded into the active panel by the system curl |
| `⌘E` | Eject the removable or network volume of the active panel |
| `Alt+F5` | Pack into an archive (the format follows the extension: `.zip`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.7z`): the compression (normal, fastest, best, none), move to archive (the files are deleted once the archive reads back whole), one archive per file or folder, a password for zip archives (AES-256, or ZipCrypto for old programs) |
| `Alt+F9` | Unpack the selected archives |
| `Alt+Shift+F9` | Test the selected archives (or the one shown): they are read through, their checksums checked, and the damaged files named |
| Files → Create Checksum File… | MD5 / SHA-1 / SHA-256 / SHA-512 for the selection (`shasum`/`md5sum` format) |
| Files → Print File List… / with Subfolders… / Print File… | The entries shown (or marked) with sizes and dates, the files inside the folders too, or the text of the file under the cursor; `⌘P` in the Lister prints what it shows |
| Files → Encode File… / Decode File… | A file as text for mail — MIME (Base64, with headers), UUE or XXE — and such a text back to the file it holds, under its name |
| Files → Split File… / Combine Files… | A file cut into pieces of a size chosen (`name.001`, `name.002`… and `name.crc` with its name, size and CRC32, as Total Commander makes them); the pieces put together again from `name.001` or `name.crc`, checked against the .crc file |
| Files → Verify Checksums | Check the `.md5`/`.sha1`/`.sha256`/`.sha512` file under the cursor |

Long operations (copy, move, archives) show their progress; the "Background"
button moves it to a separate window so you can keep working with the panels.
"Pause" stops a copy (and a server transfer) until "Resume"; the speed pop-up limits
copying (1 to 100 MB/s; a clone on the same APFS disk is instant anyway). When a
server transfer meets a smaller file of the same name (a transfer cut off), "File
already exists" offers "Resume": the rest is sent or fetched and appended (SFTP
`reget`/`reput`, FTP `REST`/`APPE`).

#### E-books in the viewer

FB2 (also `.fb2.zip`), EPUB, MOBI, AZW, AZW3 and PRC books open to read: title and
author in the window title, chapters, epigraphs, verses, quotes, notes, lists,
emphasis, pictures and the cover, in a serif column in the middle of the window;
Contents in the context menu jumps to a chapter, `F7`/`⌘F` finds text, `1` shows
the file's text. Books protected by DRM are said so. DjVu documents show their
pages when DjVuLibre is installed (`brew install djvulibre`; its `ddjvu` draws
them in a sandbox that can read nothing but that file), and their hidden text
layer otherwise and with `F7`/`⌘F` (`7` shows the pages again). The books are read
by the same locked-down helper as syntax highlighting, pictures included, and what
it returns is checked.

#### Tables in the viewer

What Quick Look can't show as a table, the viewer can: Excel 2003 XML files (by
their contents, whatever the name: `.xlsx`, `.xls`, `.xml` — many programs export
them), HTML pages named `.xls`/`.xlsx` (another common export) and CSV/TSV (the
delimiter — `,` `;` tab — is found by itself). They open as a grid with column
letters and row numbers, the sheets to choose from above it; merged cells show
their value in the first one, dates as dates, numbers to the right. `⌘C` copies the
selected rows (tab-separated, as Excel and Numbers paste them), the encodings work
as for text, `1` shows the text and `7` the table again. The files are read by the
same locked-down helper as syntax highlighting, and what it returns is checked.

#### Web pages, Markdown and formatting in the viewer

HTML files open as pages and Markdown files as documents (tables, colored code,
task lists, pictures lying next to the file); `1` shows the source, `7` the page
again. Pages are shown locked: JavaScript is off, nothing is loaded from the
network (not even a picture, so a page can't tell anyone it was opened), only
files of the page's folder and its subfolders show in it, and a link opens in the
browser only when clicked. Markdown is made into a page by
[markdown-it](https://github.com/markdown-it/markdown-it) in the same locked-down
helper as syntax highlighting.

`F` (or Format in the context menu) lays out JSON, XML, JavaScript, TypeScript, CSS
and HTML for reading, and stays on for the next files: JSON and XML by Oriel
itself (comments, the order of keys and broken files kept),
JavaScript, CSS and HTML by [js-beautify](https://github.com/beautifier/js-beautify),
TypeScript by [Prettier](https://prettier.io), in the locked-down helper too.

#### 3D models in the viewer

STL files (binary or text) open as a model to turn with the mouse: drag to turn
it, the wheel or a pinch to come nearer, Option-drag or two fingers to move it, a
double click to see it as at first; its size and number of triangles are in the
window title. The file is read by the same locked-down helper as syntax
highlighting, and what it returns is checked.

#### Syntax highlighting in the viewer

The viewer colors program code with [highlight.js](https://highlightjs.org)
(about 190 languages). The language follows the file's extension or name
(`Makefile`, `Dockerfile`, `.zshrc`), or the program on its `#!` line (assembly by
its instructions: x86, ARM, MIPS, AVR); texts up to about 512 thousand characters
are highlighted, the context menu and `H` turn it on and off. highlight.js runs in
a separate helper, `OriCmdHighlighter`, which locks itself down before it reads
anything from Oriel: no files (not even system ones), no network, no pasteboard,
no opening of URLs, no starting or signalling other programs, no looking up other
services (the preferences daemon it met while starting checks the lockdown too).
Only texts in a language highlight.js knows are sent to it, never key, certificate
or signature files. A file made to attack the JavaScript engine could at most see
the texts shown in the viewer afterwards, see which programs run, post system
notifications, take up shared memory until a restart and send back a wrong
coloring, which Oriel checks; nothing can leave the Mac through it. A highlighting
that takes more than 5 seconds is stopped (the text stays plain).

#### Find Files (`Alt+F7`)

- **General:** masks (`*.txt;*.md`) or a regular expression for the name; the
  folder and how many levels of subfolders; the text — case-sensitive or not,
  whole words, a regular expression, or files *not* containing it — in UTF-8,
  UTF-16, Windows-1251, DOS (866), KOI8-R or all of them, or bytes in hex
  (`50 4B 03 04`).
- **Inside archives** (zip, tar.\*, 7z… by name): names, attributes and text of
  their files; Go to File opens the archive at the file, Feed to Panel shows the
  archive itself.
- **The Spotlight index:** files are taken by name from the index instead of going
  through the folders — faster, but Spotlight leaves out hidden files, packages and
  excluded folders (the other conditions are checked as usual).
- **Advanced:** the modification date (between two dates or not older than), the
  file size (`=` `<` `>`; "= 2 MB" takes 2 to 3 MB), attributes (folder, hidden,
  locked, symbolic link, executable: has it, does not have it, any); duplicates —
  files with the same name, size or contents (the beginning is compared first,
  then the rest; hard links to one file count once, empty files are left out),
  shown in groups. The tab's title says when a condition is set there.
- **Templates:** a search saved under a name (all conditions but the folder) and
  loaded back.

#### The copy and move dialog (`F5` / `F6`)

- **Target** with a name mask: `folder/*.*` keeps the names, `folder/*.bak`
  changes the extension, `folder/new_*.*` adds a prefix; without a mask and for a
  single file it is the new name. The Modern look shows the folder alone (the same
  as `*.*`) and names what is copied at the top, with its icon. The drop-down list
  holds the target list and recent paths; `F7` (the star, "+ F7" in the Classic
  look) adds the current folder to the target list or removes it, `⌃D` picks a
  folder from the directory hotlist, "Choose…" ("Tree") chooses a folder.
- **Only files of this type:** `*.jpg *.png` copies only such files (in
  subfolders too); exclusions come after `|`: `*.* | *.bak .git/ node_modules/`;
  a name ending in `/` is a folder at any depth (`src/` — only the `src` folders,
  with everything inside). Folders left empty by the filter are not created.
  `F8` (the filter button, "+ F8" in the Classic look) — saved filters and examples.
- **Copy extended attributes and ACLs** (tags, Finder comments, access
  rights); **Verify** compares every copied file with the original.
- Buttons, in the order of Mac dialogs: **Options** and **Choose…** at the left;
  **Queue** (`F2`) — the operation joins the queue and runs one at a time in its own
  progress window — **Cancel** (`Esc`) and **Copy**/**Move** (`Return`) at the
  right. The Classic look names them **Options >>**, **Tree** and **F2 Queue**. Right-click Copy or F2 Queue to move instead of copying (and the other
  way round).
- **Options**: overwrite mode (ask, overwrite all, skip all, overwrite older,
  auto-rename the copied or the existing files — `name(2).ext`, copy larger or
  smaller ones), skip unreadable files, overwrite/delete locked files, skip
  `.DS_Store` (on by default: Finder's view settings inside the folders are not
  copied; one chosen itself is), copy to all folders selected in the target
  panel. The pin keeps the options open, the save button makes them the default.
- A file or folder that cannot be copied or moved is asked about while the
  operation waits: **Skip** (`Return`), **Skip All** (the next failures of this
  operation without asking), **Retry**, **Cancel** (`Esc`) the rest. A file server
  that refuses some names (Samba's "veto files" on a NAS often keep out
  `.DS_Store`, `Thumbs.db`, `desktop.ini`) is named as the cause ("the server does
  not accept this name"); such Finder and Explorer files are left out without
  asking.

### Archives

`Enter` or `Ctrl+PgDn` on an archive (zip, tar.\*, 7z, rar, iso, cab, …) opens
it like a folder. Inside it navigation, selection, `F3`, `Enter` (the file is
extracted to a temporary folder and opened) and `F5` (extract the selection to
the other panel) work. Zip, tar, tar.gz, tar.bz2, tar.xz and 7z archives can
also be written: `F5`/`F6` into a panel showing an archive pack the files into
it, and `F7`, `F8` and `Shift+F6` work inside (the archive is rebuilt through a
temporary folder). rar, iso, cab and others are read-only. An archive inside an
archive opens the same way (`Enter`, `Ctrl+PgDn`; `[..]` goes back to the outer one);
it is read-only.

Encrypted zip archives (ZipCrypto or AES) ask for the password when something is
unpacked or viewed; it is checked before anything is written, asked for again while
it is wrong and remembered until Oriel quits. An encrypted zip is changed with its
password and stays encrypted the same way; encrypted 7z and RAR archives cannot be
unpacked (the system libarchive cannot decrypt them).

Solid RAR 4 archives (old ones, made with "Create solid archive") cannot be read by
the system libarchive either; with The Unarchiver's command line tools installed
(`brew install unar`) Oriel lists, views and unpacks them through `lsar` and `unar`.

### Button bar and drive buttons

Under the window title there is a button bar with frequent commands (reread,
views, history, hotlist, find, multi-rename, synchronize, archives, Terminal).
Right-click it → Customize Toolbar… to change it. Applications can go on it too:
drag an `.app` from Finder or from a panel onto the button bar (or right-click an
application → Add to Button Bar). A click on its button starts the application,
files dropped on the button open in it; right-click for Show in Finder and Remove
from Button Bar. Above each panel there are
drive buttons: the startup volume, the home folder and mounted volumes (can be
hidden in Settings). Right-click a drive button for the Finder's volume menu: open
(also in a new tab or the other panel), eject a disk or a disk image, rename, Get
Info. When the buttons do not fit, they scroll (wheel, trackpad, arrows at the ends).

In the Modern look the sidebar (Show → Show Sidebar, `⌃⌘S`, or the toolbar's
sidebar button) takes their place: Devices with their free space (left out rather
than shortening a name), Favorites (home,
Desktop, Documents, Downloads, Applications) and the directory hotlist. A click
opens the place in the active panel, whose place stays highlighted; right-click a
place for the same menu as a drive button's. While the sidebar is shown the drive
buttons are hidden. The command line, the function keys (as compact hints, only the
keys when the titles do not fit) and Operations then share one bar under the
panels, its text in proportion to the list's font as the header's is (the command in
the system's monospaced font). Holding a modifier key shows the function keys'
commands with it, as the key bindings have them (both looks).

### Servers (SFTP, FTP)

SFTP works through the system `ssh`/`sftp`: `~/.ssh/config` (aliases,
ProxyJump), keys and ssh-agent are used; there is one shared connection per
server, and a password or passphrase is asked for once. FTP/FTPS goes through the
system `curl`. On a server navigation, `F3`, `Enter`, `F5`/`F6` both ways
(download/upload), `F7`, `F8`, `Shift+F6`, paste from the clipboard and dropping
files onto the server panel work. Transfers go file by file with byte progress
(current file and total). SFTP keeps permissions and dates of files and folders,
FTP keeps the dates of downloaded files. With a server in both panels, `F5`/`F6`
copy or move from one to the other through this Mac (Total Commander's FXP).

#### Server terminal

An SFTP panel is split in two: the files on top, the server's shell below, opened
in the panel's folder over the same connection (nothing is asked again). Drag
the line above the terminal to resize it. It uses the panel's font when its letters
all have one width (Monaco, Menlo; otherwise the system's monospaced font) and the
panel's colors, with ANSI colors made of the system's colors for a light or a dark
panel; in the Modern look its text starts where the list's icons do. Where macOS
shows scroll bars only while scrolling, its scroller shows only while you scroll
back through its output.

| Key | Action |
|---|---|
| `` ⌃` `` | Go to the terminal (showing it); in the terminal, hide it and go back to the files |
| `` ⌃⌥` `` | Go to the panel's folder in the terminal (at the shell's prompt: what is typed there is cleared first) |

The keys are tied to the key that types `` ` `` on the Latin layout, on any
layout; on ISO keyboards the key under `Esc` (`§`, `ё` on Russian – PC) works
too. While the terminal has the focus, every key without `⌘` goes to the
shell — `Tab`, `Esc`, the function keys, `⌃C`; `⌘C`/`⌘V` copy and paste. When
you go back to the files, the server folder is read again. After `exit`,
`Return` connects again. Oriel remembers whether you hid the terminal and
opens the next connection the same way.

A server lives in its tab: switching tabs keeps the connection and the shell
(a command keeps running). A server tab is not duplicated: a drive button there
opens the drive in a new tab, and `⌘T` opens the local folder the tab came from.
The terminal ends when you leave the server in its tab, disconnect, close the
tab or quit; if a program is still running there (Oriel asks the server), you
are asked first. Disconnect keeps the connection while another tab (or the
other panel) shows the same server.

### Mouse

Right-click (or `Ctrl`-click) opens the context menu: open, open with, view,
show in Finder, clipboard, rename, delete, pack, Get Info (the Finder's window),
and as in the Finder, Share (AirDrop, Mail, Messages…), the Finder's tags (its
colors under the names it gives them, so tags set here are the Finder's own) and
Services, Quick Actions among them. Files can be dragged between the panels,
from Finder and to Finder; copying by default, moving with `⌘`, or with `⌥`
between the panels (the cursor loses its "+"; from Finder `⌥` copies, as there).
Dropping onto a folder row puts the files into it.

The right button can mark files instead (Settings → Panels → Mouse): a click
marks or unmarks a file, a drag over files makes them all as the first one
became, and holding the button still for half a second opens the context menu.
On `[..]`, on empty space and with `Ctrl`-click the menu opens at once.

The path above a panel works as breadcrumbs: a click on a parent folder in it goes
there, with the cursor on the folder you came from (in archives and on servers too).
When the path is too long, its start gives way to `…`, which lists the folders left
out.

By default the path bar also holds the volume, before the path (a click lists the
volumes), and its free space at the end when there is room; the mask shows there only
when a filter is on. This replaces the row with the volume selector and the `/` and
`..` buttons, which Settings → Window → "Panel header" can bring back.
Click the free-space or total-capacity readout in either header to open the current
drive's information window in Finder.

A click on the current folder, the mask or right of the path makes it editable:
type a folder (or a file: it is shown selected; an archive opens), a folder on the
server or in the archive shown, or another server's address, and press `Enter`;
`Esc` cancels. `Tab` completes names, as in a shell; pressed again it goes through
the choices (`Shift+Tab` back).

### Command line

Letters typed in a panel go to the command line while the cursor stays in the
panel.

| Key | Action |
|---|---|
| `Enter` | Run the command in the current folder (login shell, no window) |
| `Shift+Enter` | Run in Terminal, the window stays open |
| `cd <path>`, a folder path | Change the folder of the active panel |
| `Ctrl+Enter` / `Ctrl+Shift+Enter` | Insert the name / full path of the file under the cursor |
| `Esc` | Clear the command line |

## Colors

Settings → Colors: the theme — as in the system, light or dark (for Oriel only,
switches at once); the color of marked files, the cursor and the cursor text,
alternating row backgrounds (on by default in the Modern look); the panel preview
shows the result right away.
File Colors… colors names by mask (archives, pictures, scripts — examples
included); in the dark theme these colors are shown lighter, so they stay readable.

Ready-made colors set the marked files' color and the file colors at once:
standard, for red–green color blindness (protanopia, deuteranopia; Okabe–Ito
colors), for blue–yellow color blindness (tritanopia), and high contrast. "Marked
files in bold" makes marking independent of color; the presets other than the
standard one turn it on. High contrast also stripes the rows; another preset takes
those stripes away again (not ones you turned on yourself).

## Your own keys

Settings → Keyboard → Keyboard Shortcuts…: any `cm_*` command can get its own
shortcut (double-click a row and press the keys). The "Import wincmd.ini…"
button takes the assignments from the `[Shortcuts]` section of a `wincmd.ini`
file — they are added to the standard keys — and also the colors (`[Colors]`: file
colors by mask, marked files, the cursor) and the hotlist entries whose folders exist
on this Mac (`[DirMenu]`, `cd /path` or `cd ~/path`).

## Start menu

Your own commands: Start → Change Start Menu…. A command runs in the shell in the
folder of the active panel; the parameters `%P` (folder of the active panel),
`%N` (file under the cursor), `%S` (selected files), `%T` / `%M` (folder and
file under the cursor in the other panel) are inserted already quoted. A command
can have its own shortcut (`CM+E` is ⌃⌘E) and run in Terminal; Customize
Toolbar… puts commands on the button bar.

Commands with the same group make a submenu of Start; a group named like a menu
of the bar (Files, Commands, Net…) puts its commands at the end of that menu instead,
so the main menu gets commands of your own. On the button bar a group is one
button with its commands in a dropdown.

## Internal associations

Files → Internal Associations… (or the button in Settings): for a mask
(`*.swift;*.json`) you choose programs for `Enter`, `F3` and `F4`. A program is
an application (the Application… button) or a shell command: `%P` is the file's
folder, `%N` its name; without parameters the path is added at the end
(`code -g`, `qlmanage -p`). The first matching entry with a program for that key
wins; otherwise the standard behavior applies. A `*` mask at the end of the list
sets a program for all other files.

## Settings

Oriel → Settings… (`⌘,`) — a window with panes:

- **General** — interface language, automatic update checks.
- **Panels** — the look (Modern, or Classic as in Total Commander, which sets
  the switches here and in Window at once), font, row height (Standard 13 pt or
  Compact 12 pt), checkmarks, folder brackets, extensions, sizes, the status line,
  what the right mouse button does.
- **Window** — command line, function key and drive buttons, the sidebar, button
  bar setup, folder tabs and the panel header.
- **Colors** — light or dark theme (or as in the system), panel preview,
  ready-made colors, colors of marked files (and bold) and the cursor,
  alternating rows, colors by file mask.
- **Operations** — defaults of the copy dialog (overwrite mode, verification,
  attributes), confirmation of moving to the Trash, internal associations,
  Start menu.
- **Keyboard** — quick search mode, your own shortcuts, a note about the F keys
  on a Mac.

## Interface language

English and Russian. By default the system language is used; Settings → General
chooses the language for Oriel only (the Restart Now button applies it at once).

## Development

Development and contributions target this fork's `main` branch. Submit changes
through [this fork's pull requests](https://github.com/tosiabunio/Oriel/pulls).
Upstream imports are reviewed for compatibility with the fork's behavior,
preferences, release numbering and trusted update key.

Planned interface work is described in the [visual refresh](docs/visual-refresh.md)
plan.

A Debug build can play key scenarios and save window snapshots — see
`OriCmd/App/DebugAutomation.swift`. The scenarios only work on explicitly given
test folders (`ORICMD_LEFT`, `ORICMD_RIGHT`); `scripts/test/` has the test data,
the regression suite and local test servers.

The maintainer publishes with `scripts/release.sh <version> [notes.md]`. It sets
the fork version, builds the disk image, commits, tags `v<version>`, pushes to the
fork and publishes the image, signed manifest and signature. Publishing requires
`gh auth login` and the fork's local publishing key; see
[authenticated updates](docs/authenticated-updates.md).

## License

GPL-3.0 — see [LICENSE](LICENSE). The terminal uses
[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (MIT License), syntax
highlighting [highlight.js](https://highlightjs.org) (BSD 3-Clause License); DjVu
text layers are decompressed as [DjVuLibre](https://djvu.sourceforge.net) does
(GPL-2.0-or-later, used under version 3). Their [notices](OriCmd/Credits.rtf)
are displayed in About and bundled in `Oriel.app/Contents/Resources/Credits.rtf`.

Oriel, like OriCmd, is not affiliated with Ghisler Software GmbH. Total Commander is a
trademark of its owner.
