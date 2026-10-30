import AppKit

@MainActor
protocol FileListViewDelegate: AnyObject {
    func fileListDidBecomeActive(_ list: FileListView)
    /// Enter / double click: enter a folder or open a file.
    func fileList(_ list: FileListView, openItemAt index: Int)
    /// Ctrl+PgDn: enter a folder or a package (e.g. an .app bundle).
    func fileList(_ list: FileListView, enterItemAt index: Int)
    func fileListGoToParent(_ list: FileListView)
    func fileListSwitchPanel(_ list: FileListView)
    /// ⇧F6 in-place rename was confirmed with Enter.
    func fileList(_ list: FileListView, rename item: FileItem, to newName: String)
    func fileListMarksDidChange(_ list: FileListView)
    func fileListCursorDidMove(_ list: FileListView)
    /// Num+ / Num−: ask for a mask, then mark or unmark matching files.
    func fileList(_ list: FileListView, markGroup mark: Bool)
    /// Lets the command line take typed characters first. Returns true if consumed.
    func fileList(_ list: FileListView, interceptKey event: NSEvent) -> Bool
    /// ⌥/⌃⌥ + letter: starts quick search with `text`.
    func fileList(_ list: FileListView, beginQuickSearchWith text: String)
    /// Space on a folder: its size should be calculated, as in Total Commander.
    func fileList(_ list: FileListView, calculateSizeOf item: FileItem)
    /// Right click: the context menu for the given entries.
    func fileList(_ list: FileListView, contextMenuFor items: [FileItem]) -> NSMenu?
    /// Whether entries may be dragged out (not from inside archives).
    func fileListCanDragItems(_ list: FileListView) -> Bool
    /// Files were dropped on the list, or on the folder entry `folder`.
    func fileList(_ list: FileListView, drop urls: [URL], into folder: FileItem?, moving: Bool) -> Bool
    /// Files promised by the program they are dragged from (Remote Desktop, Mail).
    func fileList(_ list: FileListView, dropPromises receivers: [NSFilePromiseReceiver], into folder: FileItem?) -> Bool
}

/// The file list of a panel, in Full view (one row per entry with details) or
/// Brief view (names only, in columns filled top to bottom). In the modern look the
/// cursor is a rounded highlight, in the accent color while the panel has the focus
/// and grey otherwise; in Total Commander's it is filled in the active panel and
/// outlined in the inactive one.
final class FileListView: NSView {
    enum ViewMode: String {
        case full, brief, thumbnails
    }

    weak var delegate: FileListViewDelegate?

    var viewMode = ViewMode.full {
        didSet {
            guard viewMode != oldValue else { return }
            updateBriefColumnWidth()
            updateFrameSize()
            needsDisplay = true
            scrollCursorToVisible()
            NSAccessibility.post(element: self, notification: .layoutChanged)
        }
    }

    private var briefColumnWidth: CGFloat = 160

    var fileAccessibilityRows: [FileAccessibilityRow]?
    private(set) var items: [FileItem] = []
    private(set) var cursor = 0
    /// Names of marked entries, drawn in red.
    private(set) var marked: Set<String> = []
    /// The Full view columns after Name (the panel's column set).
    var columns = ColumnSet.standard {
        didSet { if columns != oldValue { needsDisplay = true } }
    }

    /// Calculated folder sizes by name, shown instead of <DIR>.
    var folderSizes: [String: Int64] = [:] {
        didSet { needsDisplay = true }
    }

    var isActive = false {
        didSet { if isActive != oldValue { needsDisplay = true } }
    }

    private var rowHeight = Theme.rowHeight

    private var renameField: NSTextField?
    private var renamedItem: FileItem?

    /// Where a click started, for telling drags from clicks.
    var dragOrigin: (point: NSPoint, row: Int)?
    /// The folder entry highlighted as drop target.
    var dropTargetRow: Int? {
        didSet { if dropTargetRow != oldValue { needsDisplay = true } }
    }

    // Asked off the main thread too (AppKit places the images of a drag of many files concurrently).
    nonisolated override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL] + promiseTypes)
        NotificationCenter.default.addObserver(self, selector: #selector(columnWidthsDidChange(_:)),
                                               name: ColumnLayout.widthsDidChange, object: nil)
    }

    @objc private func columnWidthsDidChange(_ notification: Notification) {
        if viewMode == .full { needsDisplay = true }
    }

    /// The modern cursor turns grey while the window is not the key one.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            center.removeObserver(self, name: name, object: nil)
            if let window {
                center.addObserver(self, selector: #selector(windowKeyDidChange(_:)), name: name, object: window)
            }
        }
    }

    @objc private func windowKeyDidChange(_ notification: Notification) {
        if Settings.isModern, items.indices.contains(cursor) { setNeedsDisplay(rowRect(cursor)) }
    }

    /// Whether the cursor shows as focused: the active panel's, in the key window
    /// (the modern look; Total Commander's ignores the window). Test runs stay in the
    /// background, so their pictures show it as in front.
    private var showsFocusedCursor: Bool {
        guard isActive else { return false }
        #if DEBUG
        if DebugAutomation.isTestRun { return true }
        #endif
        return !Settings.isModern || window?.isKeyWindow != false
    }

    /// The Full view columns, inset from the list's edges in the modern look.
    var columnLayout: ColumnLayout {
        ColumnLayout(width: bounds.width, columns: columns, inset: Theme.contentInset)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func becomeFirstResponder() -> Bool {
        delegate?.fileListDidBecomeActive(self)
        accessibilitySelectionChanged()
        return true
    }

    // MARK: - Content

    /// Replaces the entries; marks survive for names that are still present.
    func reload(items: [FileItem], cursor: Int) {
        if let renamedItem, !items.contains(renamedItem) {
            endRenaming()
        }
        self.items = items
        marked.formIntersection(items.map(\.name))
        updateBriefColumnWidth()
        self.cursor = items.isEmpty ? 0 : min(max(cursor, 0), items.count - 1)
        updateFrameSize()
        needsDisplay = true
        scrollCursorToVisible()
        delegate?.fileListCursorDidMove(self)
        reloadAccessibilityRows()
    }

    var currentItem: FileItem? {
        items.indices.contains(cursor) ? items[cursor] : nil
    }

    func moveCursor(to index: Int) {
        guard !items.isEmpty else { return }
        let clamped = min(max(index, 0), items.count - 1)
        guard clamped != cursor else { return }
        setNeedsDisplay(rowRect(cursor))
        cursor = clamped
        setNeedsDisplay(rowRect(cursor))
        scrollCursorToVisible()
        delegate?.fileListCursorDidMove(self)
        accessibilitySelectionChanged()
    }

    /// Font or other settings changed: re-measure rows and redraw.
    func settingsDidChange() {
        rowHeight = Theme.rowHeight
        updateBriefColumnWidth()
        updateFrameSize()
        needsDisplay = true
        scrollCursorToVisible()
    }

    // MARK: - In-place rename

    /// Shows an editor over the Name and Ext columns of the cursor row,
    /// with the name selected but not the extension.
    func beginRenaming() {
        guard let item = currentItem, !item.isParent else { return }
        endRenaming()
        scrollCursorToVisible()

        let row = rowRect(cursor)
        var frame = row.insetBy(dx: 0, dy: -1)
        if viewMode == .full {
            let layout = columnLayout
            frame.origin.x = layout.rect(for: .name, y: 0, height: 0).minX
            frame.size.width = (layout.contains(.ext) ? layout.rect(for: .ext, y: 0, height: 0).maxX
                : layout.rect(for: .name, y: 0, height: 0).maxX) - frame.origin.x
        }
        if viewMode == .thumbnails {
            frame = NSRect(x: row.minX, y: row.minY + Self.thumbnailSize + 8, width: row.width, height: rowHeight + 2)
        } else if viewMode == .brief {
            let indent = (Settings.isModern ? 3 : 0) + Theme.rowIconSize + 4
            frame.origin.x += indent
            frame.size.width -= indent
        } else {
            frame.origin.x += Theme.rowIconSize + 4
            frame.size.width -= Theme.rowIconSize + 4
        }
        // An opaque field with an accent outline, its text where the row's name was: a
        // bezeled field lets the row's own name and extension show through.
        let height = Theme.lineHeight(Theme.panelFont) + 4
        frame = NSRect(x: frame.minX - 2, y: viewMode == .thumbnails ? frame.minY : row.midY - height / 2,
                       width: frame.width + 2, height: viewMode == .thumbnails ? frame.height : height)
        let field = NSTextField(frame: frame)
        field.stringValue = item.name
        field.font = Theme.panelFont
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = .textBackgroundColor
        field.wantsLayer = true
        field.layer?.cornerRadius = 4
        field.layer?.borderWidth = 1.5
        field.layer?.borderColor = NSColor.controlAccentColor.cgColor
        field.focusRingType = .none
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = self
        addSubview(field)
        renameField = field
        renamedItem = item

        window?.makeFirstResponder(field)
        let length = item.isFolder ? item.name.utf16.count : item.baseName.utf16.count
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: length)
    }

    var isRenaming: Bool { renameField != nil }

    /// F2 (or Shift+F6) again while renaming selects the next part of the name:
    /// the name, the extension, the whole name.
    func selectNextPartOfName() {
        guard let field = renameField, let editor = field.currentEditor() else { return }
        let text = field.stringValue as NSString
        let all = NSRange(location: 0, length: text.length)
        let dot = text.range(of: ".", options: .backwards)
        guard renamedItem?.isFolder == false, dot.location != NSNotFound, dot.location > 0 else {
            editor.selectedRange = all
            return
        }
        let name = NSRange(location: 0, length: dot.location)
        let ext = NSRange(location: dot.location + 1, length: text.length - dot.location - 1)
        let current = editor.selectedRange
        editor.selectedRange = current == name ? ext : (current == ext ? all : name)
    }

    private func endRenaming(commit: Bool = false) {
        guard let field = renameField, let item = renamedItem else { return }
        renameField = nil
        renamedItem = nil
        let newName = field.stringValue
        field.delegate = nil
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
        if commit {
            delegate?.fileList(self, rename: item, to: newName)
        }
    }

    // MARK: - Marking

    /// The last non-empty selection that was replaced, for "Restore selection".
    private(set) var previousMarks: Set<String> = []

    func setMarked(_ names: Set<String>) {
        if !marked.isEmpty && names != marked {
            previousMarks = marked
        }
        marked = names
        needsDisplay = true
        delegate?.fileListMarksDidChange(self)
        accessibilitySelectionChanged()
    }

    private func toggleMark(at row: Int) {
        guard items.indices.contains(row), !items[row].isParent else { return }
        let name = items[row].name
        if marked.remove(name) == nil {
            marked.insert(name)
        }
        setNeedsDisplay(rowRect(row))
        delegate?.fileListMarksDidChange(self)
        accessibilitySelectionChanged()
    }

    private func markRange(from start: Int, to end: Int) {
        guard !items.isEmpty else { return }
        let lower = max(min(start, end), 0)
        let upper = min(max(start, end), items.count - 1)
        guard lower <= upper else { return }
        setMarked(marked.union(items[lower...upper].filter { !$0.isParent }.map(\.name)))
    }

    private func toggleMarkAndMove(by offset: Int) {
        toggleMark(at: cursor)
        moveCursor(to: cursor + offset)
    }

    private func markRangeAndMove(to target: Int) {
        markRange(from: cursor, to: target)
        moveCursor(to: target)
    }

    override func selectAll(_ sender: Any?) {
        setMarked(Set(items.filter { !$0.isParent }.map(\.name)))
    }

    /// Num /: marks again what was marked before the last change.
    @objc(cm_RestoreSelection:)
    func restoreSelection(_ sender: Any?) {
        let names = Set(items.map(\.name))
        setMarked(previousMarks.intersection(names))
    }

    @objc(cm_ClearAll:)
    func clearAll(_ sender: Any?) {
        setMarked([])
    }

    /// Inverts the marks of files; marked folders stay marked.
    @objc(cm_ExchangeSelection:)
    func exchangeSelection(_ sender: Any?) {
        let files = Set(items.filter { !$0.isParent && !$0.isFolder }.map(\.name))
        setMarked(marked.subtracting(files).union(files.subtracting(marked)))
    }

    @objc(cm_SpreadSelection:)
    func spreadSelection(_ sender: Any?) {
        delegate?.fileList(self, markGroup: true)
    }

    @objc(cm_ShrinkSelection:)
    func shrinkSelection(_ sender: Any?) {
        delegate?.fileList(self, markGroup: false)
    }

    /// Entries per page: visible rows (Full) or visible columns × rows (Brief, Thumbnails).
    private var visibleRowCount: Int {
        switch viewMode {
        case .full:
            max(Int(visibleRect.height / rowHeight), 1)
        case .brief:
            max(Int(visibleRect.width / briefColumnWidth), 1) * briefRowsPerColumn
        case .thumbnails:
            max(Int(visibleRect.height / thumbnailCell.height), 1) * thumbnailColumns
        }
    }

    static let thumbnailSize: CGFloat = 112

    /// [..] among the thumbnails in the modern look: a folder as big as the others,
    /// faded, with the arrow up to it.
    private static let parentThumbnail: NSImage = {
        let size = NSSize(width: thumbnailSize, height: thumbnailSize)
        let folder = FileIcons.folder(tagColor: 0, size: size)
        let arrow = NSImage(systemSymbolName: "arrow.turn.left.up", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white])))
        return NSImage(size: size, flipped: false) { bounds in
            folder.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 0.55)
            if let arrow {
                // In the folder's body, below its tab.
                arrow.draw(in: NSRect(x: bounds.midX - arrow.size.width / 2, y: bounds.midY - arrow.size.height / 2 - 6,
                                      width: arrow.size.width, height: arrow.size.height))
            }
            return true
        }
    }()

    private var thumbnailCell: NSSize {
        NSSize(width: Self.thumbnailSize + 20, height: Self.thumbnailSize + rowHeight + 14)
    }

    private var thumbnailColumns: Int {
        max(Int((superview?.bounds.width ?? bounds.width) / thumbnailCell.width), 1)
    }

    private var briefRowsPerColumn: Int {
        max(Int((superview?.bounds.height ?? rowHeight) / rowHeight), 1)
    }

    func rowRect(_ row: Int) -> NSRect {
        switch viewMode {
        case .full:
            return NSRect(x: 0, y: CGFloat(row) * rowHeight, width: bounds.width, height: rowHeight)
        case .brief:
            let rows = briefRowsPerColumn
            return NSRect(x: CGFloat(row / rows) * briefColumnWidth, y: CGFloat(row % rows) * rowHeight,
                          width: briefColumnWidth, height: rowHeight)
        case .thumbnails:
            let cell = thumbnailCell
            let columns = thumbnailColumns
            return NSRect(x: CGFloat(row % columns) * cell.width, y: CGFloat(row / columns) * cell.height,
                          width: cell.width, height: cell.height)
        }
    }

    func index(at point: NSPoint) -> Int? {
        let row = Int(point.y / rowHeight)
        let index: Int
        switch viewMode {
        case .full:
            index = row
        case .brief:
            guard row < briefRowsPerColumn else { return nil }
            index = Int(point.x / briefColumnWidth) * briefRowsPerColumn + row
        case .thumbnails:
            let column = Int(point.x / thumbnailCell.width)
            guard column < thumbnailColumns else { return nil }
            index = Int(point.y / thumbnailCell.height) * thumbnailColumns + column
        }
        return items.indices.contains(index) ? index : nil
    }

    /// Brief columns are as wide as the longest name (within limits).
    private func updateBriefColumnWidth() {
        guard viewMode == .brief else { return }
        let longest = items.map(displayName).max { $0.count < $1.count } ?? ""
        let width = (longest as NSString).size(withAttributes: [.font: Theme.panelFont]).width + 16 + Theme.rowIconSize + 4
        briefColumnWidth = min(max(width, 100), 360).rounded()
    }

    private func displayName(_ item: FileItem) -> String {
        Settings.panelName(item.name, isFolder: item.isFolder)
    }

    private func scrollCursorToVisible() {
        guard !items.isEmpty else { return }
        scrollToVisible(rowRect(cursor))
    }

    // MARK: - Sizing

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
        guard let superview else { return }
        superview.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(superviewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification, object: superview
        )
        updateFrameSize()
    }

    @objc private func superviewFrameDidChange(_ notification: Notification) {
        updateFrameSize()
    }

    private func updateFrameSize() {
        guard let superview else { return }
        let size: NSSize
        switch viewMode {
        case .full:
            size = NSSize(width: superview.bounds.width,
                          height: max(CGFloat(items.count) * rowHeight, superview.bounds.height))
        case .brief:
            let columns = (items.count + briefRowsPerColumn - 1) / briefRowsPerColumn
            size = NSSize(width: max(CGFloat(columns) * briefColumnWidth, superview.bounds.width),
                          height: superview.bounds.height)
            needsDisplay = true
        case .thumbnails:
            let rows = (items.count + thumbnailColumns - 1) / thumbnailColumns
            size = NSSize(width: superview.bounds.width,
                          height: max(CGFloat(rows) * thumbnailCell.height, superview.bounds.height))
            needsDisplay = true
        }
        if frame.size != size { setFrameSize(size) }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Theme.panelBackground.setFill()
        dirtyRect.fill()
        guard !items.isEmpty else { return }

        let first: Int
        let last: Int
        switch viewMode {
        case .full:
            first = Int(dirtyRect.minY / rowHeight)
            last = Int(dirtyRect.maxY / rowHeight)
        case .brief:
            first = Int(dirtyRect.minX / briefColumnWidth) * briefRowsPerColumn
            last = (Int(dirtyRect.maxX / briefColumnWidth) + 1) * briefRowsPerColumn - 1
        case .thumbnails:
            first = Int(dirtyRect.minY / thumbnailCell.height) * thumbnailColumns
            last = (Int(dirtyRect.maxY / thumbnailCell.height) + 1) * thumbnailColumns - 1
        }
        // Only the area below the last row may need drawing (a menu closed over it): then
        // there is no row to draw, and a range from the first to the last would trap.
        let lowest = max(first, 0)
        let highest = min(last, items.count - 1)
        guard lowest <= highest else { return }
        let range = lowest...highest
        let layout = columnLayout
        for row in range {
            switch viewMode {
            case .full: drawRow(row, layout: layout)
            case .brief: drawBriefCell(row)
            case .thumbnails: drawThumbnailCell(row)
            }
        }
        if let dropTargetRow, items.indices.contains(dropTargetRow) {
            NSColor.controlAccentColor.setStroke()
            let inset = viewMode == .full ? max(Theme.rowInset, 1) : 1
            let outline = NSBezierPath(roundedRect: rowRect(dropTargetRow).insetBy(dx: inset, dy: 1), xRadius: 4, yRadius: 4)
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    /// Fills the cursor bar if needed and returns the text color for the entry.
    private func prepareCell(_ row: Int, in rect: NSRect) -> NSColor {
        let item = items[row]
        let isMarked = marked.contains(item.name)
        let filled = row == cursor && showsFocusedCursor
        let inset = viewMode == .full ? Theme.rowInset : 2
        if Settings.isModern {
            let background: NSColor? = if row == cursor {
                filled ? Theme.cursorBackground : Theme.unfocusedCursorBackground
            } else if isMarked {
                Theme.markedRowBackground
            } else if viewMode == .full && row % 2 == 1 && ColorSettings.alternatingRows {
                Theme.alternateRowBackground
            } else {
                nil
            }
            background?.setFill()
            if background != nil { Theme.rowPath(rect, inset: inset).fill() }
        } else {
            if !filled && viewMode == .full && row % 2 == 1 && ColorSettings.alternatingRows {
                Theme.alternateRowBackground.setFill()
                rect.fill()
            }
            if filled {
                Theme.cursorBackground.setFill()
                rect.fill()
            }
        }
        return switch (filled, isMarked) {
        // With checkmarks the modern cursor needs no second text color for marks.
        case (true, true): Settings.isModern && Settings.showsSelectionMarkers ? Theme.cursorText : Theme.markedCursorText
        case (true, false): Theme.cursorText
        case (false, true): Theme.markedText
        case (false, false): (item.isParent ? nil : ColorSettings.color(forName: item.name)) ?? Theme.panelText
        }
    }

    private func drawIcon(for item: FileItem, in rect: NSRect) {
        let size = Theme.rowIconSize
        let iconRect = NSRect(x: rect.minX + 3, y: rect.minY + ((rowHeight - size) / 2).rounded(), width: size, height: size)
        FileIcons.icon(for: item).draw(
            in: iconRect,
            from: .zero, operation: .sourceOver, fraction: item.isHidden ? 0.5 : 1,
            respectFlipped: true, hints: nil
        )
        drawSelectionMarker(for: item, in: iconRect, size: (size * 0.69).rounded())
    }

    /// A checkmark gives marked items a shape as well as a text color.
    private func drawSelectionMarker(for item: FileItem, in rect: NSRect, size: CGFloat = 11) {
        guard Settings.showsSelectionMarkers, !item.isParent, marked.contains(item.name) else { return }
        let badge = NSRect(x: rect.maxX - size + 2, y: rect.maxY - size + 1, width: size, height: size)
        let circle = NSBezierPath(ovalIn: badge)
        NSColor.controlAccentColor.setFill()
        circle.fill()
        NSColor.white.setStroke()
        circle.lineWidth = 0.7
        circle.stroke()
        let tick = NSBezierPath()
        tick.move(to: NSPoint(x: badge.minX + size * 0.23, y: badge.minY + size * 0.50))
        tick.line(to: NSPoint(x: badge.minX + size * 0.43, y: badge.minY + size * 0.69))
        tick.line(to: NSPoint(x: badge.minX + size * 0.78, y: badge.minY + size * 0.31))
        tick.lineWidth = 1.4
        tick.lineCapStyle = .round
        tick.lineJoinStyle = .round
        tick.stroke()
    }

    /// Total Commander's dotted cursor in the inactive panel.
    private func drawInactiveCursorFrame(_ row: Int, in rect: NSRect) {
        guard row == cursor, !isActive, !Settings.isModern else { return }
        Theme.inactiveCursorFrame.setStroke()
        let frame = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        frame.setLineDash([1, 1], count: 2, phase: 0)
        frame.stroke()
    }

    private func drawBriefCell(_ row: Int) {
        let item = items[row]
        let rect = rowRect(row)
        let color = prepareCell(row, in: rect)
        // Inside the rounded highlight of the modern look.
        let content = Settings.isModern ? rect.insetBy(dx: 3, dy: 0) : rect
        drawIcon(for: item, in: content)
        drawText(displayName(item), in: content.divided(atDistance: Theme.rowIconSize + 4, from: .minXEdge).remainder,
                 font: Theme.font(marked: marked.contains(item.name)), color: color)
        drawInactiveCursorFrame(row, in: rect)
    }

    /// A thumbnail with the name underneath; the cursor is a rounded highlight.
    private func drawThumbnailCell(_ row: Int) {
        let item = items[row]
        let rect = rowRect(row)
        let size = Self.thumbnailSize
        if row == cursor {
            let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6)
            if showsFocusedCursor {
                Theme.cursorBackground.withAlphaComponent(0.3).setFill()
                highlight.fill()
            } else if Settings.isModern {
                Theme.unfocusedCursorBackground.setFill()
                highlight.fill()
            } else {
                Theme.inactiveCursorFrame.setStroke()
                highlight.setLineDash([2, 2], count: 2, phase: 0)
                highlight.stroke()
            }
        }
        let imageArea = NSRect(x: rect.minX + (rect.width - size) / 2, y: rect.minY + 6, width: size, height: size)
        let image: NSImage
        if item.isParent, Settings.isModern {
            image = Self.parentThumbnail
        } else if item.isFolder, item.isUnreadable {
            image = FileIcons.unreadableFolder(item.url)
        } else if item.isParent || item.isFolder {
            image = item.isParent ? FileIcons.icon(for: item)
                : FileIcons.folder(tagColor: item.tagColor, size: NSSize(width: size, height: size))
        } else {
            image = ThumbnailCache.shared.thumbnail(for: item.url, size: size, asIcon: Settings.isModern) { [weak self] in
                self?.setNeedsDisplay(rect)
            } ?? NSWorkspace.shared.icon(forFile: item.url.path)
        }
        let scale = min(size / max(image.size.width, 1), size / max(image.size.height, 1),
                        item.isParent && !Settings.isModern ? 1 : 8)
        let drawn = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: imageArea.midX - drawn.width / 2, y: imageArea.maxY - drawn.height,
                              width: drawn.width, height: drawn.height),
                   from: .zero, operation: .sourceOver, fraction: item.isHidden ? 0.5 : 1,
                   respectFlipped: true, hints: nil)

        drawSelectionMarker(for: item, in: imageArea.insetBy(dx: 2, dy: 2), size: 18)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle
        let color = marked.contains(item.name) ? Theme.markedText
            : (item.isParent ? nil : ColorSettings.color(forName: item.name)) ?? Theme.panelText
        (displayName(item) as NSString).draw(
            with: NSRect(x: rect.minX + 4, y: imageArea.maxY + 4, width: rect.width - 8, height: rowHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: Theme.font(marked: marked.contains(item.name)), .foregroundColor: color,
                         .paragraphStyle: paragraph]
        )
    }

    private func drawRow(_ row: Int, layout: ColumnLayout) {
        let item = items[row]
        let rect = rowRect(row)
        let color = prepareCell(row, in: rect)
        let y = rect.minY
        let isMarked = marked.contains(item.name)
        let textFont = Theme.font(marked: isMarked)
        // Sizes and dates stay regular: in bold they would not fit their columns.
        let numberFont = Theme.panelNumberFont
        // The modern look leaves the colors to the name; the other columns are grey.
        let detail = Settings.isModern && !(row == cursor && showsFocusedCursor) ? Theme.secondaryText : color

        drawIcon(for: item, in: layout.rect(for: .name, y: y, height: rowHeight))
        let shown = nameAndExtension(of: item, layout: layout, y: y, font: textFont)
        drawText(shown.name, in: shown.nameRect, font: textFont, color: color)
        if layout.contains(.ext) {
            drawText(shown.ext, in: layout.rect(for: .ext, y: y, height: rowHeight), font: textFont, color: detail)
        }

        if layout.contains(.size) {
            drawText(sizeText(of: item), in: layout.rect(for: .size, y: y, height: rowHeight),
                     font: numberFont, color: detail, alignment: .right)
        }

        if !item.isParent {
            for column in layout.extraColumns {
                let value = MetadataCache.shared.cachedValue(for: item, column: column) { [weak self] in
                    self?.setNeedsDisplay(rect)
                }
                let numeric = column == .dimensions || column == .duration
                drawText(value?.display ?? "", in: layout.rect(for: column, y: y, height: rowHeight),
                         font: numeric || column == .created ? numberFont : textFont,
                         color: detail, alignment: numeric ? .right : .left)
            }
            if layout.contains(.date) {
                drawText(Theme.dateText(item.modified), in: layout.rect(for: .date, y: y, height: rowHeight),
                         font: numberFont, color: detail)
            }
            if layout.contains(.attr) {
                drawText(item.permissions, in: layout.rect(for: .attr, y: y, height: rowHeight),
                         font: numberFont, color: detail)
            }
        }

        drawInactiveCursorFrame(row, in: rect)
    }

    /// What Full view shows in the Name and Ext columns of an item, and where the name
    /// goes: with extensions after names (see Settings) it takes the Ext column too.
    private func nameAndExtension(of item: FileItem, layout: ColumnLayout, y: CGFloat,
                                  font: NSFont) -> (name: String, ext: String, nameRect: NSRect) {
        let nameRect = layout.rect(for: .name, y: y, height: rowHeight)
            .divided(atDistance: Theme.rowIconSize + 4, from: .minXEdge).remainder
        guard Settings.extensionDisplay == .withName || !layout.contains(.ext) else {
            return (Settings.panelName(item.baseName, isFolder: item.isFolder), item.fileExtension, nameRect)
        }
        let wideRect = layout.contains(.ext) ? nameRect.union(layout.rect(for: .ext, y: y, height: rowHeight)) : nameRect
        // drawText leaves 4 points on each side.
        let name = item.isFolder ? Settings.panelName(item.name, isFolder: true) : Self.fittedName(item, width: wideRect.width - 8, font: font)
        return (name, "", wideRect)
    }

    /// The whole name, or when it does not fit, its base name cut short before the
    /// extension ("a-long-repo….pdf"): sorted by extension, the extensions stay readable.
    private static func fittedName(_ item: FileItem, width: CGFloat, font: NSFont) -> String {
        func fits(_ text: String) -> Bool { (text as NSString).size(withAttributes: [.font: font]).width <= width }
        let ext = item.fileExtension
        guard !ext.isEmpty, !fits(item.name) else { return item.name }
        let base = Array(item.baseName)
        var low = 0
        var high = base.count
        while low < high {
            let middle = (low + high + 1) / 2
            if fits(String(base[..<middle]) + "…." + ext) { low = middle } else { high = middle - 1 }
        }
        return String(base[..<low]) + "…." + ext
    }

    /// The Name and Ext texts of the cursor row in Full view (for test runs).
    var cursorNameAndExtension: (name: String, ext: String)? {
        guard let item = currentItem else { return nil }
        let shown = nameAndExtension(of: item, layout: columnLayout, y: 0,
                                     font: Theme.font(marked: marked.contains(item.name)))
        return (shown.name, shown.ext)
    }

    /// What the Size column shows for an item: a folder's size once calculated, else
    /// "--" as in the Finder, or Total Commander's <DIR>.
    func sizeText(of item: FileItem) -> String {
        if item.isFolder, let folderSize = folderSizes[item.name] {
            return Settings.formattedSize(folderSize)
        } else if item.isFolder || item.isPackage, Settings.isModern {
            return item.isParent ? "" : "--"
        } else if item.isFolder {
            return "<DIR>"
        } else if item.isPackage {
            return "<PKG>"
        }
        return Settings.formattedSize(item.size)
    }

    private func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor,
                          alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        let textHeight = ceil(font.ascender - font.descender)
        let textRect = NSRect(x: rect.minX + 4, y: rect.minY + (rect.height - textHeight) / 2,
                              width: rect.width - 8, height: textHeight)
        (text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                attributes: attributes)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        dragOrigin = nil
        guard let row = index(at: point) else { return }
        dragOrigin = (point, row)
        if event.modifierFlags.contains(.command) {
            toggleMark(at: row)
            moveCursor(to: row)
            return
        }
        if event.modifierFlags.contains(.shift) {
            markRangeAndMove(to: row)
            return
        }
        moveCursor(to: row)
        if event.clickCount == 2 {
            delegate?.fileList(self, openItemAt: row)
        }
    }

    /// How long the right button is held still on a file for the context menu when
    /// it marks files.
    private static let menuHoldTime: TimeInterval = 0.5

    /// When the right button marks files (Settings → Panels): a click marks or unmarks
    /// the file, a drag over files makes them all as the first one became, holding the
    /// button still shows the context menu. Elsewhere, the menu at once.
    override func rightMouseDown(with event: NSEvent) {
        guard Settings.rightButton == .marks, let window,
              let row = index(at: convert(event.locationInWindow, from: nil)), !items[row].isParent else {
            super.rightMouseDown(with: event)
            return
        }
        window.makeFirstResponder(self)
        let mark = !marked.contains(items[row].name)
        let deadline = Date(timeIntervalSinceNow: Self.menuHoldTime)
        var last: Int?
        while true {
            guard let next = window.nextEvent(matching: [.rightMouseUp, .rightMouseDragged],
                                              until: last == nil ? deadline : .distantFuture,
                                              inMode: .eventTracking, dequeue: true) else {
                if let menu = menu(for: event) {
                    NSMenu.popUpContextMenu(menu, with: event, for: self)
                }
                return
            }
            if next.type == .rightMouseUp {
                if last == nil {
                    setMarks(mark, from: row, to: row)
                    moveCursor(to: row)
                }
                return
            }
            // Moving within the first file is still a click (or a hold).
            guard let current = index(at: convert(next.locationInWindow, from: nil)),
                  current != (last ?? row) else { continue }
            setMarks(mark, from: last ?? row, to: current)
            moveCursor(to: current)
            last = current
        }
    }

    private func setMarks(_ mark: Bool, from start: Int, to end: Int) {
        let names = items[min(start, end)...max(start, end)].filter { !$0.isParent }.map(\.name)
        if mark {
            marked.formUnion(names)
        } else {
            marked.subtract(names)
        }
        needsDisplay = true
        delegate?.fileListMarksDidChange(self)
        accessibilitySelectionChanged()
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if delegate?.fileList(self, interceptKey: event) == true { return }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad, .capsLock])

        switch (event.specialKey, modifiers) {
        case (.upArrow?, []) where viewMode == .thumbnails:
            moveCursor(to: cursor - thumbnailColumns)
        case (.downArrow?, []) where viewMode == .thumbnails:
            moveCursor(to: min(cursor + thumbnailColumns, items.count - 1))
        case (.leftArrow?, []) where viewMode == .thumbnails:
            moveCursor(to: cursor - 1)
        case (.rightArrow?, []) where viewMode == .thumbnails:
            moveCursor(to: cursor + 1)
        case (.upArrow?, []):
            moveCursor(to: cursor - 1)
        case (.downArrow?, []):
            moveCursor(to: cursor + 1)
        case (.pageUp?, []):
            moveCursor(to: cursor - (visibleRowCount - 1))
        case (.pageDown?, []):
            moveCursor(to: cursor + (visibleRowCount - 1))
        case (.home?, []):
            moveCursor(to: 0)
        case (.end?, []):
            moveCursor(to: items.count - 1)
        case (.leftArrow?, []) where viewMode == .brief:
            moveCursor(to: cursor - briefRowsPerColumn)
        case (.rightArrow?, []) where viewMode == .brief:
            moveCursor(to: min(cursor + briefRowsPerColumn, items.count - 1))
        case (.leftArrow?, [.shift]) where viewMode == .brief:
            markRangeAndMove(to: max(cursor - briefRowsPerColumn, 0))
        case (.rightArrow?, [.shift]) where viewMode == .brief:
            markRangeAndMove(to: min(cursor + briefRowsPerColumn, items.count - 1))
        case (.carriageReturn?, []), (.enter?, []), (.downArrow?, [.command]):
            delegate?.fileList(self, openItemAt: cursor)
        case (.pageDown?, [.control]):
            delegate?.fileList(self, enterItemAt: cursor)
        case (.delete?, []), (.upArrow?, [.command]), (.pageUp?, [.control]):
            delegate?.fileListGoToParent(self)
        case (.tab?, []), (.tab?, [.shift]), (.backTab?, _):
            delegate?.fileListSwitchPanel(self)
        // Option/Control arrows edit text elsewhere, so they are panel-only keys.
        case (.leftArrow?, [.option]):
            tryToPerform(Command.goToPrevDir.selector, with: self)
        case (.rightArrow?, [.option]):
            tryToPerform(Command.goToNextDir.selector, with: self)
        case (.downArrow?, [.option]):
            tryToPerform(Command.directoryHistory.selector, with: self)
        case (.upArrow?, [.control]), (.upArrow?, [.command, .option]):
            tryToPerform(Command.openDirInNewTab.selector, with: self)
        case (nil, [.option]) where ["+", "=", "-"].contains(event.charactersIgnoringModifiers ?? ""):
            // Total Commander's Alt+Num+ / Alt+Num−.
            let select = event.charactersIgnoringModifiers != "-"
            tryToPerform(select ? Command.selectCurrentExtension.selector : Command.unselectCurrentExtension.selector,
                         with: self)
        case (nil, [.option]), (nil, [.control, .option]):
            if let text = event.charactersIgnoringModifiers, !text.isEmpty,
               text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) {
                delegate?.fileList(self, beginQuickSearchWith: text)
            } else {
                super.keyDown(with: event)
            }
        case (nil, [.control]) where ["c", "x", "v"].contains(event.shortcutCharacters ?? ""):
            // Total Commander's Ctrl+C / Ctrl+X / Ctrl+V for files.
            let action = switch event.shortcutCharacters {
            case "c": #selector(NSText.copy(_:))
            case "x": #selector(NSText.cut(_:))
            default: #selector(NSText.paste(_:))
            }
            tryToPerform(action, with: self)
        case (nil, [.control]) where event.shortcutCharacters == "f":
            tryToPerform(Command.ftpConnect.selector, with: self)
        case (nil, [.control]) where event.shortcutCharacters == "b":
            tryToPerform(Command.branchView.selector, with: self)
        case (nil, [.control]) where event.shortcutCharacters == "d":
            tryToPerform(Command.directoryHotlist.selector, with: self)
        // macOS takes Ctrl+arrows for its spaces by default; Ctrl+Shift+arrows are left.
        case (.leftArrow?, [.control]), (.leftArrow?, [.control, .shift]), (.leftArrow?, [.command, .option]):
            tryToPerform(Command.transferLeft.selector, with: self)
        case (.rightArrow?, [.control]), (.rightArrow?, [.control, .shift]), (.rightArrow?, [.command, .option]):
            tryToPerform(Command.transferRight.selector, with: self)
        case (.deleteForward?, []), (.delete?, [.command]):
            tryToPerform(Command.delete.selector, with: self)
        // With Shift (or ⌥⌘⌫, the Finder's "Delete Immediately"): past the Trash.
        case (.deleteForward?, [.shift]), (.delete?, [.shift]), (.delete?, [.command, .shift]),
             (.delete?, [.command, .option]):
            tryToPerform(Command.deletePermanently.selector, with: self)
        case (.insert?, []), (.help?, []):
            toggleMarkAndMove(by: 1)
        case (.upArrow?, [.shift]):
            toggleMarkAndMove(by: -1)
        case (.downArrow?, [.shift]):
            toggleMarkAndMove(by: 1)
        case (.pageUp?, [.shift]):
            markRangeAndMove(to: max(cursor - (visibleRowCount - 1), 0))
        case (.pageDown?, [.shift]):
            markRangeAndMove(to: min(cursor + (visibleRowCount - 1), items.count - 1))
        case (.home?, [.shift]):
            markRangeAndMove(to: 0)
        case (.end?, [.shift]):
            markRangeAndMove(to: items.count - 1)
        case (nil, []), (nil, [.shift]):
            handleCharacter(event)
        default:
            super.keyDown(with: event)
        }
    }

    /// Space marks like Insert; "+", "-", "*" work like the numpad keys in Total Commander.
    private func handleCharacter(_ event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case " ":
            if let item = currentItem, item.isFolder, !item.isParent, folderSizes[item.name] == nil {
                delegate?.fileList(self, calculateSizeOf: item)
            }
            toggleMarkAndMove(by: 1)
        case "+": spreadSelection(nil)
        case "-": shrinkSelection(nil)
        case "*": exchangeSelection(nil)
        case "/": restoreSelection(nil)
        case "\u{1b}": tryToPerform(#selector(NSResponder.cancelOperation(_:)), with: self)
        case let text? where Settings.quickSearchMode == .letters && !text.isEmpty
            && text.unicodeScalars.allSatisfy({ $0.value >= 0x21 && $0.value != 0x7F && $0.value < 0xF700 }):
            delegate?.fileList(self, beginQuickSearchWith: text)
        default: super.keyDown(with: event)
        }
    }
}

extension FileListView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            endRenaming(commit: true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endRenaming()
            return true
        default:
            return false
        }
    }

    /// Leaving the editor (click elsewhere, Tab) cancels the rename.
    func controlTextDidEndEditing(_ notification: Notification) {
        endRenaming()
    }
}
