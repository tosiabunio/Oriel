# Visual refresh

**Status:** phase 1 built on branch `modern-panels` (2026-10-06); phase 2 on
branch `window-shell` (2026-10-07), except 2.2 and the lists under the toolbar,
deferred; phase 3 on branch `secondary-windows` (2026-10-07); the app icon on branch
`app-icon` (2026-10-07); phase 4, what phases 1 and 2 left over, on branch
`ops-badge` (2026-10-07); phase 5, the tool windows, on branch `modern-polish`
(2026-10-07); phase 6, thumbnails and copying, on branch `modern-details`
(2026-10-08); phase 7, dialogs, on branch `modern-dialogs` (2026-10-08); phase 8, the
rest of the tools, on branch `modern-tools` (2026-10-08); phase 9, the panel header's
type, on branch `modern-header` (2026-10-09); phase 10, the bottom bar, on branch
`modern-bottom` (2026-10-09); phase 11, the rows' icons, on branch `modern-rows`
(2026-10-09); phase 12, the terminal and folder errors, on branch `modern-terminal`
(2026-10-16).
**Mockup:** [Today and proposed main window, interactive](https://claude.ai/artifact/CBd66sFhHtoyH7Bkzt2BeP)
(light and dark).

OriCmd works like Total Commander, and that stays: keyboard first, two panels,
dense lists. What dates the app is the chrome around the lists. This document
records which parts look old on macOS 26 and 27, what Apple and other file
managers do instead, and a plan in three phases that keeps the classic look one
setting away.

Line references point to commit [`ed2c25f`][base] (release 2026.10.2).

## Why the app looks dated

Built with Xcode 27, OriCmd already shows the native controls in Liquid Glass:
the toolbar, buttons, pop-up menus, sheets and menus. There is no opt-out,
because macOS ignores `UIDesignRequiresCompatibility` for apps built for macOS 27.
None of this reaches the panels: the file list, column header, path bar, tabs,
drive buttons and function key bar are drawn by OriCmd's own `draw(_:)` code.
They keep the look of the Windows original:

- A path bar filled with the accent color marks the active panel.
- The cursor is a square, full-width band. In the inactive panel it is a dotted
  box, and the active one stays blue when the window loses focus.
- Each row shows `[folder]`, `<DIR>`, `rwxr-xr-x` and short numeric dates.
- File-type colors paint every column, so the list looks multicolored.
- Each list has a line border, a row of drive buttons sits above each panel, and
  the bottom of the window stacks three bars: the status lines, the command line
  and the function keys.

## What macOS 26 and 27 expect

macOS 27 shipped on 14 September 2026 and refined Tahoe's Liquid Glass. The API
availability below was checked against the macOS 27 SDK in Xcode 27.

- **Glass is for controls, not content.** Toolbars, sidebars, sheets and
  popovers float on glass; lists stay solid. The panels should not become glass,
  but their chrome should stop competing with the toolbar.
- **Selections are rounded and follow focus.** `NSTableView.Style.inset` rounds
  rows and selection. AppKit uses `selectedContentBackgroundColor` for a focused
  list and `unemphasizedSelectedContentBackgroundColor` for an unfocused one,
  which matches the active and inactive panel.
- **Content runs under the toolbar.** With a full-size content view, AppKit
  applies a scroll edge effect under the toolbar and under split-view
  accessories; the hard style is meant for pinned table headers.
  `NSSplitViewItemAccessoryViewController` needs macOS 26, and
  `preferredScrollEdgeEffectStyle` 26.1.
- **Controls are taller and rounder.** Dense layouts can keep the macOS 15 sizes
  with `prefersCompactControlSizeMetrics` (macOS 26).
- **Menus lose their icons on macOS 27.** AppKit typically hides menu item
  images there. Items that should keep theirs set
  `preferredImageVisibility = .visible` (macOS 27).
- **Corners.** All windows share a tighter radius on macOS 27. Custom drawing
  near the bottom corners stays inside
  `layoutGuide(for: .safeArea(cornerAdaptation:))` (macOS 26).
- **App icons** are layered, made in Icon Composer, with default, dark, clear and
  tinted versions.

## What other file managers do

From the vendors' current screenshots and release notes. Marketing screenshots
may not use the default settings.

| App | Active pane | Folders and dates | Drives | Bottom of the window |
| --- | --- | --- | --- | --- |
| ForkLift 4.7 | Thin accent line above the active pane; neutral headers | Icon only, sizes on demand, locale dates; permissions in the inspector | Sidebar: devices with free space, favorites, tags | Nothing; counts and free space under the breadcrumbs |
| Marta 0.8 | The inactive pane shows no cursor | `--` for folders, "Yesterday at 0:02"; rwx is an optional column | None; breadcrumbs from `/` | Status line per pane, shell prompt, dim F-key row with ⇧ and ⌘ variants |
| Nimble Commander 1.8 | Accent cursor in the active pane, gray in the other | "Folder" in Size; options for row padding and dimmed secondary columns | F1/F2 pop-up, filtered by typing | Footer per panel; F-keys work without a drawn bar |
| QSpace Pro 7 | Inactive pane can be dimmed | `--`, kind "Folder", optional relative dates, rounded alternating rows | Sidebar | Finder-like; capsule pane tabs |
| Commander One 3.18 | Square blue cursor, gray pane bands | `DIR`, `..` row, numeric dates | Drive buttons and a pop-up | Status line, command line, "View - F3" buttons |
| Finder 26/27 | — | `--` for folders; relative dates that shorten with the column | Sidebar | Optional path and status bars |

Reviews describe ForkLift as looking "like something that could have been
designed by Apple", and Commander One, the closest to OriCmd today, as "more
Windows than it is macOS". Marta keeps a function key row and a shell prompt and
still looks current, because both are drawn quietly.

## Element by element

| Element | Today | Proposed |
| --- | --- | --- |
| Active panel | Path bar filled with the accent color ([`PathBar.swift:233`][pathbar]) | Neutral header with a 3 pt accent strip and an accent-tinted folder icon |
| Cursor | Square full-width band; dotted box in the inactive panel; blue when the window is not key | Rounded inset row: `selectedContentBackgroundColor` when focused, `unemphasizedSelectedContentBackgroundColor` otherwise |
| Folders | `[name]` and `<DIR>` | Icon only; `--` in Size, or the size when calculated; packages show their kind |
| Dates | `10/09/2026, 12:00` | Kept: one short date-and-time format on every row (relative dates were tried and dropped as uneven) |
| Attributes | `rwxr-xr-x` column by default | Optional column; shown in Change Attributes and Get Info |
| File colors | The type color applies to every column | The type color applies to the name; Ext, Size and Date use secondary gray |
| Column header | Boxed separators, ▴ ▾ characters, fixed widths | No borders; sorted column in semibold with a chevron symbol; hover state; resizable columns |
| Density | 12 pt text, 18 pt rows | Compact (12/18) or Standard (13/22, close to Finder's list) |
| Frames | Line border around each list, 4 pt divider | No border; 1 pt divider |
| Drives | Row of drive buttons above each panel | Optional sidebar: devices with capacity, favorites from the Hotlist, tags; the volume chip stays |
| Bottom | Status line per panel, command line, function key bar (about 75 pt) | Counts in the panel header; one 34 pt bar with the command line, F-key hints as text and Operations |
| Other windows | Rows of text buttons (Compare: "Previous Difference", "Next Difference") | Toolbars with SF Symbols and grouped controls |

## Plan

Each phase can ship on its own, on its own branch from `main`, and every change
follows the Look setting described below. Effort: S is a day or less, M a few
days, L a week or more.

### Phase 1: restyle the panels (macOS 14 and later)

Custom drawing only, so it looks the same on every supported macOS. This is most
of the visible gain for the least risk.

1. **Rounded cursor that follows focus.** Inset the cursor row by 6 pt and round
   it to 5 pt. Fill it with `selectedContentBackgroundColor` while the panel is
   active and the window is key, otherwise with
   `unemphasizedSelectedContentBackgroundColor`, which replaces the dotted box.
   Thumbnails already round their cursor.
   [`FileListView.swift:464–520`][cursor], [`Theme.swift:39`][theme]. Effort S.
2. **Neutral headers with an accent cue.** The path bar uses the list background
   and shows the current folder in semibold. A thin accent strip and an
   accent-tinted folder icon mark the active panel. Counts and free space move to
   a second, secondary-gray line. The same bar heads the separate tree and Quick
   View. [`PathBar.swift:233–308`][pathbar]. Effort S–M.
3. **Quieter rows.** Folder brackets off; `--` instead of `<DIR>`; the Attr
   column hidden by default and kept in the header's column menu; Ext, Size and
   Date in secondary gray. Dates keep one short date-and-time format.
   [`FileListView.swift:616–673`][rows], [`Settings.swift:208`][brackets].
   Effort S.
4. **Column header.** No boxed separators, the sorted column in semibold with an
   SF Symbol chevron, hover and pressed states, columns resized by dragging.
   [`FileListHeaderView.swift:29–55`][header], [`ColumnLayout.swift`][columns].
   Effort M, mostly for resizing.
5. **Density and frames.** A density setting, Compact (12/18) or Standard
   (13/22). No line border around the lists and a 1 pt divider between the
   panels. [`Theme.swift:29–32`][rowheight], [`PanelView.swift:74`][border],
   [`PanelSplitView.swift`][split]. Effort S.

Settings has its own copy of the list drawing for its preview
([`SettingsWindowController.swift:558–667`][preview]), which must change too.
Regression checks that read `-names.txt` or expect `[name]` and `<DIR>` set the
Classic look or are updated.

**As built.** Settings → Panels → Look chooses Modern (the default) or Classic
(Total Commander). Choosing one writes the switches it is made of: folder
brackets, Mac-style tabs, the compact header, key caps, the Finder-style status
line, checkmarks and the row height; a switch never changed follows the look.
Alternating rows are on by default in Modern (Settings → Colors still decides).
Differences from the mockup: the path keeps `/` between folders rather than `›`;
dates keep one short date-and-time format on every row in both looks (the user
found relative dates such as "Today at 09:12" uneven); and the status line below
the list folds away only with the compact header, returning while quick search is
open. Column widths dragged in the header apply
to both looks and every panel. Test runs show the focused cursor although they
stay in the background, and gain `columns`, `headerdrag`, `headerdoubleclick` and
`headerclick` actions with regression checks.

### Phase 2: window layout (macOS 26 APIs behind availability checks)

New APIs go behind `if #available(macOS 26, *)`; macOS 14 and 15 keep the current
layout.

1. **Content under the toolbar.** `.fullSizeContentView` with layout against the
   safe area, so the lists scroll under the glass toolbar with a hard edge effect
   behind the column headers. Revisit `.unifiedCompact` once the panel chrome is
   lighter. [`MainWindowController.swift:8–18`][window]. Effort M.
2. **Panels as split-view items.** Host the panels in `NSSplitViewController`.
   Each panel's tabs and header become a top accessory and its status a bottom
   accessory (`NSSplitViewItemAccessoryViewController`), so the system draws the
   edge effects and spacing. [`MainViewController.swift:92–135`][root],
   [`PanelView.swift:91–172`][panel]. Effort L.
3. **Optional sidebar.** `NSSplitViewItem(sidebarWithViewController:)` with
   devices and their capacity, favorites from the Hotlist and Finder tags. It
   gets glass from the system, and macOS 27 extends it to the window edges.
   Turning it on hides the drive buttons; the volume chip stays for the
   keyboard. [`DriveBar.swift`][drives]. Effort L.
4. **One bottom bar.** The command line and the function keys share one row; the
   F-key hints become text, with ⇧ and ⌘ variants, and the key caps remain an
   option. Operations becomes a toolbar item with a count badge
   (`NSToolbarItem.badge`, macOS 26). [`FunctionKeyBar.swift`][fkeys],
   [`CommandLineView.swift`][cmdline], [`MainViewController.swift:103`][ops].
   Effort M.
5. **Menus on macOS 27.** Choose which context menu items keep their icons
   (Share, Tags) and set `preferredImageVisibility = .visible` on them. Effort S.

**As built.** 2.5: tag colors, applications under Open With and volumes keep their
menu images (`preferredImageVisibility = .visible` on macOS 27). 2.4: in the Modern
look the command line, the function keys (compact hints, keys only when the titles
do not fit) and Operations (only while there are any, named by what runs or waits)
share one 34 pt bar; Classic keeps its rows. 2.3 and 2.1: the window's content is a
`NSSplitViewController` with a system sidebar (glass on macOS 26, translucent on 14
and 15) of Devices with free space, Favorites and the hotlist; the window has a
full-size content view, the panels start at the safe area, and the toolbar gains
the sidebar button and a tracking separator (added once to saved toolbars). The
sidebar is on by default in Modern and hides the drive buttons; ⌃⌘S, the toolbar
and Settings → Window show or hide it, and its width is kept.

**2.2 deferred.** The panels' headers are opaque and the lists never scroll under
a bar, so split-item accessories would add little that shows (their scroll edge
effect needs content beneath them), while needing macOS 26 and a second layout
for macOS 14 and 15.

### Phase 3: other windows and identity (macOS 14 and later)

1. **Toolbars for Compare and Synchronize.** The rows of text buttons become
   toolbar items with SF Symbols (chevrons for differences, arrows for the copy
   direction); option checkboxes become a segmented control. The selected line in
   Compare uses the system selection colors. Effort M.
2. **Dialog button order.** The copy dialog reads Copy, F2 Queue, Tree, Cancel
   from the left. Apple's guidelines put the default button last on the trailing
   side with Cancel before it, and other actions on the leading side. A
   disclosure replaces the "Advanced options" box.
   [`CopyDialog.swift:148–251`][copy]. Effort S.
3. **Settings.** The long Panels pane splits into Appearance (Look, density,
   colors, tabs, header) and File List, with rounded group backgrounds
   (`NSColor.quinarySystemFill`) close to System Settings, without SwiftUI.
   [`SettingsWindowController.swift`][settings]. Effort S–M.
4. **Icon and accessibility.** A layered Icon Composer icon with dark, clear and
   tinted versions. Increase Contrast versions of the custom colors, and custom
   cursor colors adapted to dark mode the way marked and file colors already are
   ([`ColorSettings.swift:85–90`][colors]). Effort S, plus the icon design.

**As built (phase 3).** 3.1: the Compare window's commands are a toolbar of
symbols (previous/next difference, copy left/right, edit line, save at the far
end; ⌘S still saves), with "Ignore whitespace" and the summary in the window;
Synchronize keeps its form (Return compares) with Compare and Synchronize… at the
right edges. 3.2: the copy dialog's buttons follow Mac dialogs (Options >> and Tree
at the left; F2 Queue, Cancel and the default Copy/Move at the right) and its
advanced options are a rounded group. 3.3: every Settings pane shows its sections
as rounded groups, as System Settings does. The groups made the Panels pane taller
than a laptop screen, so it was split: Panels keeps the look, font and file list
(its preview is the one in Colors), and a new Window pane holds the bars, the
sidebar, the tabs and the panel header; a pane still taller than the screen
scrolls. 3.4:
marked rows are tinted more strongly with Increase Contrast, and the panels redraw
when the display's accessibility options change. Custom cursor colors stay as
chosen in dark mode, since their text color is chosen with them. The layered app
icon came separately (branch `app-icon`): `OriCmd/AppIcon.icon`, an Icon Composer
document of two glass groups over the system's blue gradient — two white panes with
lines of files, and an orange cursor that leaves the left pane as an arrow into the
right one (copying between panels). macOS draws its dark, clear and tinted versions;
Xcode makes the flat images for macOS 14 and 15. Open the document in Icon Composer
(part of Xcode) to change it; `ictool` renders it from the command line.

### Phase 4: what phases 1 and 2 left over

1. **Operations in the toolbar** (2.4). A toolbar button for Operations whose badge
   counts the operations running or waiting (`NSToolbarItem.badge`, macOS 26).
2. **Tags in the sidebar** (2.3). The Finder's color tags under the names the Finder
   gives them; a click lists the tagged files in the active panel.
3. **A symbol before the path** (the active panel row of the table). A folder
   symbol in the accent color in the active panel's header.

**As built (phase 4).** 4.1: Operations is a toolbar button at the end of the bar
(in new toolbars, and added once to saved ones); on macOS 26 its badge counts the
operations running and waiting, and the Modern bottom bar then leaves Operations to
it while the toolbar shows that button (hidden toolbar, Classic and macOS 14–15
keep the bottom bar's Operations). 4.2: a Tags section at the end of the sidebar
lists the seven color tags under the Finder's names for them (they depend on its
language) with their colors; a click finds the files with that tag through Spotlight
and lists them in the active panel as Feed to Panel does ([..] goes back). 4.3: in the
Modern look a symbol before the path says what the panel shows — a folder, an
archive, a server or search results — in the accent color in the active panel and
in grey in the other.

**Still deferred.** The lists do not scroll under the glass toolbar (2.1), and the
panels are not split-view items with accessories (2.2): with opaque panel headers
neither would show, and both need a second layout for macOS 14 and 15. They are
worth another look if the headers become translucent.

### Phase 5: the tool windows

A survey of every window in the Modern look (2026-10-07) found the panels current
and the dated parts elsewhere:

- **The Lister** (`F3`) was titled "Lister - [path] — encoding" as in Total
  Commander, had no toolbar (every command was a key to know), and set its text
  against the window's edge.
- **Lists in tool windows** (the hotlist, file colors, the Start menu, connections,
  associations, column sets, shortcuts, Operations, Find Files, Multi-Rename,
  Synchronize, the command palette) sat in sunken frames with square full-width
  selection, under rows of "Add / Remove / Move Up / Move Down" buttons; an empty
  list was a blank box. Find Files and Multi-Rename left their default button in the
  middle of the window.
- **The tree** (`Ctrl+F8`) kept the square full-width cursor and the list frame that
  the panels lost in phase 1, and **quick search** typed into a plain field.

1. **Lists.** One `ListBox` draws a list as System Settings does: a rounded box with
   a hairline edge, rows with rounded selection (`NSTableView.Style.inset`), and
   along its bottom edge small symbol buttons for adding, removing and moving
   entries. An empty list says so in its middle. Effort S–M.
2. **Lister toolbar and title.** The window's title is the file's name, its folder
   and encoding are the subtitle, and a local file's icon in the title bar can be
   dragged or ⌘-clicked. A toolbar shows the keys: previous and next file (`P`,
   `N`), text, hex or the rich view (`1`, `3`, `7`, with the symbol of what `7`
   shows), wrapping, highlighting and formatting (`W`, `H`, `F`), the encodings and
   Find. The text gets a margin. Effort M.
3. **Tree and quick search.** The tree's cursor is the panels' rounded,
   focus-following one in the Modern look; quick search becomes a search field.
   Effort S.

**As built (phase 5).** 5.1: every list in a tool window is a `ListBox`; + and −
(and the move chevrons) keep their old names for VoiceOver and the tooltip.
Placeholders: the hotlist, file colors, the Start menu, connections, associations,
shortcuts with no match, Operations ("No operations this session", now in the list
itself) and the command palette. The palette lost its column titles, shows the
shortcuts right-aligned in grey, and draws the chosen row in the accent color while
the search field keeps the focus, as Spotlight does. Find Files keeps Start Search
at the trailing edge, Multi-Rename Undo and Rename; Connections drops New for + and
keeps Save and the default Connect at the right. The box has no fill of its own: an
inset table draws none, and the window's background (tinted by the desktop picture
in dark mode) shows in the list and its bar alike. The Compare window keeps its full
width rows, and the text views in alerts their frames. 5.2: as planned, in both
looks; the toggles are a segmented control whose segments show which are on and turn
off where they do not apply (hex, Quick Look), and the encodings are a menu. 5.3:
the tree's column follows the panel's width, so the rounded ends stay in view
however deep the folders go. The search field is the same in both looks.

### Phase 6: thumbnails and copying

A second survey (2026-10-08) of what phase 5 left and of the windows it had not
pictured:

- **Thumbnails** showed text files as a few lines of tiny text floating on the
  background (Quick Look's bare page with no edge), and `..` as an empty tile with a
  small arrow in it.
- **The overwrite question** wrote both files as a path broken across lines and a
  size in bytes, under the title "File already exists"; which file was newer had
  to be read from the dates.
- **The copy progress** named the file being written by its temporary name
  (`.oricmd-….part`) and showed two bars with no numbers: no amounts, no speed, no
  time left.
- **Compare** still framed its lines and its detail in sunken boxes.

1. **Thumbnails as the Finder draws them.** In the Modern look Quick Look is asked
   for icon-style thumbnails (`QLThumbnailGenerator.Request.iconMode`): a document is
   a page with its edge and shadow, a picture has a border. `..` is a folder as large
   as the others, faded, with the arrow up to it. Effort S.
2. **The overwrite question** is titled with the file's name and compares the two
   files under it: size and date, the folder each is in, and which of them is newer.
   Its icon is the file type's. Effort S.
3. **The copy progress** names the target itself; under the file's bar how much of
   it is done, under the whole's the amounts, the speed and the time left, worded as
   the Finder words it ("About 2 minutes remaining"). Effort S.
4. **Compare** puts its lines and its detail in the rounded boxes of phase 5, its
   rows still edge to edge. Effort S.

**As built (phase 6).** As planned. The thumbnails cache keeps the plain and the
icon-style pictures apart, so switching the look redraws with the right ones; the
Classic look keeps both as before. Short sizes that read the same for two different
files show their bytes in the overwrite question. The speed is measured over the last
three seconds and left out while the copy is paused or before it has run a second.

### Phase 7: dialogs

A third survey (2026-10-08) pictured the windows and states the first two had not:
the copy and move dialog, the delete questions, unpacking, the branch view, tabs,
the simple prompts (select files, new file, hard link, encode), Connect to Server
and the network browser, Quick View, and the Lister's table and picture views.

- **The copy and move dialog** (`F5`/`F6`), the one opened most, was still Total
  Commander's: "Copy" over "Item under cursor · 1 file" and the name, the target
  ending in `*.*`, buttons titled "+ F7" and "+ F8", the overwrite modes numbered
  ("1. Ask user"), and five buttons of one width.
- **The delete questions** asked "Do you really want to move the selected 2
  files/folders to the Trash?", with no names and the app's icon; other questions
  said "2 files/folders" too.
- **Connect to Server** kept its recent servers in a sunken striped frame with a
  square − button, blank when there were none; the network browser put Connect…
  beside its status.
- **The Lister's table** stretched its last column over the window, so a number in
  it sat at the far edge. **The key hints** said "NewFolder" and "Exit".

The simple prompts are standard alerts and stay; Quick View is Quick Look's own.

1. **The copy and move dialog** in the Modern look: the icon of what is copied and
   "Copy “notes.txt”" or "Copy 2 folders" beside it, the names of several and the
   source folder under it; the target folder without `*.*` (a mask typed after it
   still renames); a star for the target list and a filter symbol for `F8`, "All
   files" in the empty filter; the modes without numbers; Options (showing and
   hiding the options), Choose… and Queue sized to their titles. Effort M.
2. **Questions that name their items**: "Move “notes.txt” to the Trash?", "Move 2
   items to the Trash?", "Delete … immediately?" with the names of several under the
   title and the items' icon; "2 items" wherever "2 files/folders" was. Effort S.
3. **Connect to Server** keeps its recent servers in a `ListBox` with − and "No
   recent servers"; the network browser's Connect… goes to the trailing edge. Effort S.
4. **The Lister's table** columns keep the width of their texts; **the key hints**
   say New Folder and Quit in the Modern look. Effort XS.

**As built (phase 7).** As planned. The Classic look keeps Total Commander's dialog
as it was: its wording, the mask, "+ F7", "+ F8", Options >>, Tree and F2 Queue at one
width, and the numbered modes. The questions and Connect to Server are the same in
both looks.

### Phase 8: the rest of the tools

A fourth survey (2026-10-08) went through every tool window and dialog the earlier
phases had left as they were: attributes, properties, counting, splitting,
checksums, links, comments, packing, Find Files and its results, Multi-Rename,
Synchronize, Compare, the Lister's text, hex and find bar, About, the command
palette, Operations, the quick filter, the horizontal panels, the tree and every
Settings pane.

- **Find Files** listed its results as bare full paths, without icons.
- **The Lister's hex view** drew the offsets, the bytes and the text alike, and
  showed a line break as a full stop.
- **Change Attributes** clipped its date (the seconds under the stepper) and set the
  permissions grid apart from the rest.
- **Compare** filled the chosen line with a solid blue in which the black text and
  the change highlights were hard to read.
- **Pack** kept two empty password fields and a gap under them while nothing was
  encrypted.
- **Synchronize** summed up as "4 → , 1 ← , 0 ≠ , 20 files compared; 341 bytes to copy",
  and Settings → Operations still named "Options >>".

1. **Find Files results** with each file's icon and name, and in grey the folder it
   is in under the one searched (the row's value stays the whole path). Effort S.
2. **The hex view**: the offsets in grey, and in the text column the dots that stand
   for bytes with no character fainter than real full stops. The layout of the dump
   (and finding bytes in it) is unchanged. Effort S.
3. **Change Attributes** with the items' icon, the grid at the left edge and the date
   on a line of its own, as wide as its text. Effort S.
4. **Compare** outlines the chosen line in the accent color with a bar at its edge,
   over the line's own color. Effort S.
5. **Pack** shows the password rows only while Encrypt is on, the hint only when it
   says something. Effort XS.
6. **Synchronize** sums up as "4 → · 1 ← · 0 ≠ · 20 files compared · 341 B to copy";
   the Settings note says "its options". Effort XS.

**As built (phase 8).** As planned, in both looks.

### Phase 9: the panel header's type

The user found the panel header clumsy: different fonts, small sizes. It drew the
path in the list's own font (Monaco 15 pt in the user's settings), and the volume,
the counts and free space, the column titles and the tab titles in an 11 pt system
font, so next to 15 pt rows the header mixed two families at two unrelated sizes.

1. **One family.** In the Modern look every part of the header is in the system
   font, whatever font the list uses; the list keeps its own.
2. **Sizes in proportion to the list.** The path takes the list's size (12–18 pt),
   the volume a point less, the tabs, the counts and free space and the column
   titles two points less (11 pt at least). For the default 13 pt list this is the
   old 13 and 11 pt, with the volume at 12 pt; for a 15 pt list, 15, 14 and 13 pt.
3. **Heights from the fonts.** The path line, the counts line, the column titles and
   the Mac-style tabs are as tall as their text needs (the same 22, 15, 22 and 24 pt
   as before at 13 pt), and a tab leaves room for an icon that grows with the text.

**As built (phase 9).** As planned; the Settings preview draws its column titles the
same way. The Classic look keeps the list's font in the path and 11 pt elsewhere.

### Phase 10: the bottom bar

After the header, the bar under the panels showed the same mismatch: the prompt, the
command typed and the key hints were 11 pt whatever the list's size, the command in a
proportional font. And 2.4's key hints with their modifiers had not been built.

1. **The bar's type follows the header's** (Modern): the prompt in grey and the key
   hints at the header's detail size (11 pt for a 13 pt list, 13 pt for a 15 pt one),
   the key caps a point smaller, the command in the system's monospaced font at that
   size; the field, the caps and the bar grow with them. Effort S.
2. **Modifier hints** (both looks): holding `⇧`, `⌥` or `⌃` the bar shows the
   commands those keys give the function keys, read from the key bindings (⇧F2
   Compare, ⇧F4 New File, ⇧F5 Copy Here, ⇧F6 Rename, ⇧F8 Delete Now; ⌥F1/F2 the
   drive menus, ⌥F5 Pack, ⌥F7 Find, ⌥F9 Unpack, ⌥F10 Tree; ⌃F3–F7 the sort orders),
   and a click runs them. Not while typing in a field, where Shift makes capitals.
   No function key has a ⌘ command, so ⌘ shows the plain keys. Effort S.

**As built (phase 10).** As planned. The bar keeps at least the plain keys' width,
so a modifier never moves the command line. 3.1's segmented options in Compare and
Synchronize were reconsidered and dropped: their checkboxes say what each option
does, which symbols in a segmented control would not.

### Phase 11: the rows' icons

The header and the bottom bar follow the list's font since phases 9 and 10; the rows'
icons did not. They stayed 16 pt beside the text, and with a 15 pt list (25 pt rows)
they looked a size too small, as the Finder's do when its text is made larger but its
icons are not.

1. **Icons as large as the row allows** (Modern): the row's height less 6 pt, from 16
   pt (the standard 22 pt rows, unchanged) to 24 pt, in the Full and Brief views; the
   room before the name, the inline rename field, the Brief column's width and the
   checkmark on a marked item follow. Effort S.

**As built (phase 11).** As planned; the Classic look keeps 16 pt icons.

### Phase 12: the terminal and folder errors

A fifth survey (2026-10-16) looked at what the earlier ones had not: the server
terminal, the menus, Reduce Transparency, and a panel that is empty, cannot be read,
is being read or waits for a server, in light and dark with Monaco 15. The menus need
nothing (macOS 27 hides menu images unless an item asks to keep them, and the items
that tell things apart already do), nor does Reduce Transparency (the app draws no
glass of its own; its tints lie on opaque panels), nor the empty folder (the info
line says "Empty folder"). The terminal and the folder errors were dated:

1. **ANSI colors for the background.** SwiftTerm's palette is Terminal.app's Basic,
   whose dark blue (folders in `ls -G`), red and magenta barely read on a dark
   panel. The 16 colors are made of the system's red, green, yellow, blue, purple and
   cyan: on a dark panel as they are, lightened for the bright set; on a light one
   darkened (contrast about 3.5–8 on white), the system's own for the bright set. The
   panel's background decides which, so custom panel colors count. Effort S.
2. **The panel's font and edge.** The terminal used the system's monospaced font
   whatever the panel's (Monaco beside SF Mono under one panel) and started 2 pt from
   the edge, left of the list's icons. It takes the panel's font when its letters all
   have one width, else the system's monospaced one at its size; in the Modern look
   its text starts where the list's icons do, with 4 pt under the divider and above
   the bottom, the margins in the panel's color. Effort S.
3. **The scroller as the system shows scroll bars.** SwiftTerm always draws a legacy
   scroller with its track. Where the system shows scroll bars only while scrolling,
   it becomes an overlay knob shown while the terminal is scrolled back into its
   output (Page Up, the wheel), hidden at the end of it. Effort S.
4. **Folder errors as the Finder words them.** "Cannot read folder “/the/whole/path”"
   over three lines and "The operation couldn’t be completed. Permission denied"
   became "The folder “locked” can’t be opened." with the folder's icon (macOS adds
   its no-entry badge) and "You don’t have permission to see its contents." (or
   "The folder no longer exists."); other errors keep the system's text. A server
   folder's error has the same title. Effort S.

Left open: the panels' scroll bar track shows even when nothing scrolls where the
system always shows scroll bars (hiding it would shift the columns by its width
between short and long folders), and folders that cannot be opened could carry the
Finder's no-entry badge in the list.

**As built (phase 12).** As planned. The colors, font and scroller apply in both
looks (the terminal has no Classic appearance of its own); the edge and margins only
in the Modern look. Views do not clip their drawing to their bounds (macOS 14), so
the pane fills only its bounds. The survey also found that a server folder that
cannot be read opens as an empty folder: the listing's `ls` fails after `cd`
succeeds, and the failure is not reported (a functional bug, not part of this phase).

## The Look setting

The fork already has eight appearance switches: folder brackets, Mac-style tabs,
the compact header, key caps, the Finder-style status line, extension display,
size display and checkmarks. This plan adds more. One **Look** setting at the top
of Settings → Panels chooses Modern (the default) or Classic. It sets all the
switches at once, and the individual switches stay below it. Test runs pin
`Look = Classic` where a check depends on the old text.

## Next step

The plan is built except the deferred 2.1 and 2.2. New visual work starts from what
using the Modern look shows, on its own branch from `main`, behind the Look setting
where it changes how the classic panels look. Phase 6 built what the phase 5
survey left; phase 7 what a third survey found in the dialogs; phase 8 what a fourth
found in the remaining tools; phase 9 the header's type, at the user's request;
phase 10 the bottom bar's type and the modifier hints; phase 11 the rows' icons;
phase 12 the terminal and folder errors a fifth survey found.

## Sources

- Apple: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass),
  [Build an AppKit app with the new design (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/310/),
  [WWDC26 session 289](https://developer.apple.com/videos/play/wwdc2026/289/),
  [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes),
  [`UIDesignRequiresCompatibility`](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility),
  [`NSTableView.Style.inset`](https://developer.apple.com/documentation/appkit/nstableview/style-swift.enum/inset),
  [`unemphasizedSelectedContentBackgroundColor`](https://developer.apple.com/documentation/appkit/nscolor/unemphasizedselectedcontentbackgroundcolor)
- Human Interface Guidelines: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials),
  [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables),
  [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars),
  [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- File managers: [ForkLift 4](https://binarynights.com/) and its
  [Tahoe update](https://blog.binarynights.com/2025/07/28/forklift-4-3-5-is-available/),
  [Marta](https://marta.sh/),
  [Nimble Commander help](https://github.com/mikekazakov/nimble-commander/blob/main/Docs/Help.md)
  and [what's new](https://github.com/mikekazakov/nimble-commander/blob/main/WHATS_NEW.md),
  [QSpace Pro changelog](https://qspace.awehunt.com/en-us/changelog.html),
  [Commander One](https://commander-one.com/)
- Reviews: [How-To Geek on Finder alternatives](https://tech.yahoo.com/apps/articles/4-best-finder-alternatives-macos-180016839.html),
  [Macworld on Commander One](https://www.macworld.com/article/226820/commander-one-pro-review-a-free-finder-alternative-for-power-users.html),
  [The Eclectic Light Company on Tahoe](https://eclecticlight.co/2025/12/28/last-year-on-my-mac-look-back-in-disbelief/)

[base]: https://github.com/tosiabunio/Oriel/tree/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4
[pathbar]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/PathBar.swift#L233-L308
[cursor]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/FileListView.swift#L464-L520
[theme]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/Theme.swift#L39
[rows]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/FileListView.swift#L616-L673
[brackets]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/App/Settings.swift#L208
[header]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/FileListHeaderView.swift#L29-L55
[columns]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/ColumnLayout.swift
[rowheight]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/Theme.swift#L29-L32
[border]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/PanelView.swift#L74
[split]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/PanelSplitView.swift
[preview]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/SettingsWindowController.swift#L558-L667
[window]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/App/MainWindowController.swift#L8-L18
[root]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/MainViewController.swift#L92-L135
[panel]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/PanelView.swift#L91-L172
[drives]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/Panel/DriveBar.swift
[fkeys]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/FunctionKeyBar.swift
[cmdline]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/CommandLineView.swift
[ops]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/MainViewController.swift#L103
[copy]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/CopyDialog.swift#L148-L251
[settings]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/SettingsWindowController.swift
[colors]: https://github.com/tosiabunio/Oriel/blob/ed2c25f89c38409ff0b6e4af1a6297d43ac214a4/OriCmd/UI/ColorSettings.swift#L85-L90
