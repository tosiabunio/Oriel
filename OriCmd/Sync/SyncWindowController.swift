import AppKit
import UniformTypeIdentifiers

/// "Synchronize directories": compares two folder trees and copies newer and
/// missing files in the chosen directions.
final class SyncWindowController: NSWindowController {
    private static var shared: SyncWindowController?

    private let leftField = NSTextField(string: "")
    private let rightField = NSTextField(string: "")
    private let subfoldersBox = NSButton(checkboxWithTitle: String(localized: "Subfolders"), target: nil, action: nil)
    private let contentBox = NSButton(checkboxWithTitle: String(localized: "By content"), target: nil, action: nil)
    private let equalBox = NSButton(checkboxWithTitle: String(localized: "Show equal files"), target: nil, action: nil)
    private let compareButton = NSButton(title: String(localized: "Compare"), target: nil, action: nil)
    private let syncButton = NSButton(title: String(localized: "Synchronize…"), target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let table = SyncTableView()

    private var items: [SyncItem] = []
    /// The folders the current `items` were compared in (the fields may change since).
    private var comparedRoots: (left: URL, right: URL)?
    private var visibleRows: [Int] = []
    private var comparison: TransferProgress?
    private var onFinish: (() -> Void)?
    /// The icons of the names' kinds, by extension ("/" for a folder).
    private var icons: [String: NSImage] = [:]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Shows the window for the two panels' folders; `finished` runs after copying.
    static func show(left: URL, right: URL, finished: @escaping () -> Void) {
        let controller = shared ?? SyncWindowController()
        shared = controller
        controller.leftField.stringValue = left.path
        controller.rightField.stringValue = right.path
        controller.onFinish = finished
        controller.showWindow(nil)
        controller.compare(nil)
    }

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Synchronize Directories")
        window.center()
        super.init(window: window)
        window.rememberFrame(as: "SyncDirectories")
        window.delegate = self
        buildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func buildContent() {
        subfoldersBox.state = .on
        leftField.delegate = self
        rightField.delegate = self
        for box in [contentBox] {
            box.target = self
            box.action = #selector(compare(_:))
        }
        subfoldersBox.target = self
        subfoldersBox.action = #selector(compare(_:))
        equalBox.target = self
        equalBox.action = #selector(filterChanged(_:))
        compareButton.target = self
        compareButton.action = #selector(compare(_:))
        compareButton.keyEquivalent = "\r"
        syncButton.target = self
        syncButton.action = #selector(synchronize(_:))

        let columns: [(String, String, CGFloat)] = [
            ("leftName", String(localized: "Left"), 200), ("leftSize", String(localized: "Size"), 76),
            ("leftDate", String(localized: "Date"), 124), ("action", "", 34),
            ("rightDate", String(localized: "Date"), 124), ("rightSize", String(localized: "Size"), 76),
            ("rightName", String(localized: "Right"), 200),
        ]
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            // The two names share what the window leaves; the details keep their width.
            let isName = identifier.hasSuffix("Name")
            column.resizingMask = isName ? [.autoresizingMask, .userResizingMask] : .userResizingMask
            column.minWidth = isName ? 120 : 30
            if isName {
                let cell = SyncNameCell(textCell: "")
                // A long path keeps its file's name instead of breaking after a folder.
                cell.lineBreakMode = .byTruncatingMiddle
                column.dataCell = cell
            } else if let cell = column.dataCell as? NSTextFieldCell {
                cell.alignment = identifier == "action" ? .center : identifier.hasSuffix("Size") ? .right : .left
                column.headerCell.alignment = cell.alignment
            }
            table.addTableColumn(column)
        }
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(toggleAction(_:))
        table.onToggle = { [weak self] in self?.toggleAction(nil) }
        let list = ListBox(table)

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: String(localized: "Left:")), leftField],
            [NSTextField(labelWithString: String(localized: "Right:")), rightField],
        ])
        grid.column(at: 0).xPlacement = .trailing
        // The actions at the right edge, as in Mac dialogs: Compare after the options,
        // Synchronize after the summary.
        let optionsGap = NSView(), bottomGap = NSView()
        for gap in [optionsGap, bottomGap] {
            gap.setContentHuggingPriority(.init(1), for: .horizontal)
        }
        let options = NSStackView(views: [subfoldersBox, contentBox, equalBox, optionsGap, compareButton])
        let bottom = NSStackView(views: [statusLabel, bottomGap, syncButton])
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [grid, options, list, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        for view in [grid, options, list, bottom] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        }
        list.setContentHuggingPriority(.defaultLow, for: .vertical)
        window?.contentView = stack
    }

    // MARK: - Comparing

    @objc private func compare(_ sender: Any?) {
        comparison?.cancel()
        let flag = TransferProgress()
        comparison = flag
        let left = URL(filePath: (leftField.stringValue as NSString).expandingTildeInPath)
        let right = URL(filePath: (rightField.stringValue as NSString).expandingTildeInPath)
        let subfolders = subfoldersBox.state == .on
        let byContent = contentBox.state == .on
        statusLabel.stringValue = String(localized: "Comparing…")
        syncButton.isEnabled = false
        Task {
            let result = await DirectoryComparison.compare(left: left, right: right, subfolders: subfolders,
                                                           byContent: byContent) { flag.isCancelled }
            guard comparison === flag else { return }
            comparison = nil
            items = result
            comparedRoots = (left, right)
            reloadRows()
        }
    }

    @objc private func filterChanged(_ sender: Any?) {
        reloadRows()
    }

    private func reloadRows() {
        let showEqual = equalBox.state == .on
        visibleRows = items.indices.filter { showEqual || items[$0].action != .equal }
        table.reloadData()
        updateStatus()
    }

    private func updateStatus() {
        let toRight = items.filter { $0.action == .toRight }
        let toLeft = items.filter { $0.action == .toLeft }
        let different = items.count { $0.action == .different }
        let bytes = (toRight.compactMap(\.left) + toLeft.compactMap(\.right)).reduce(Int64(0)) { $0 + $1.size }
        let size = Settings.shortSize(bytes)
        statusLabel.stringValue = String(localized:
            "\(toRight.count) → · \(toLeft.count) ← · \(different) ≠ · \(items.count) files compared · \(size) to copy")
        syncButton.isEnabled = !(toRight.isEmpty && toLeft.isEmpty)
    }

    /// Double click / Space: cycles the direction of the selected rows.
    @objc private func toggleAction(_ sender: Any?) {
        for row in table.selectedRowIndexes where visibleRows.indices.contains(row) {
            let index = visibleRows[row]
            let item = items[index]
            let initial: SyncAction = item.left == nil ? .toLeft : (item.right == nil ? .toRight : item.action)
            let cycle: [SyncAction] = switch (item.left != nil, item.right != nil) {
            case (true, false): [.toRight, .skip]
            case (false, true): [.toLeft, .skip]
            default: [.toRight, .toLeft, initial == .equal ? .equal : .different]
            }
            let position = cycle.firstIndex(of: item.action) ?? cycle.count - 1
            items[index].action = cycle[(position + 1) % cycle.count]
        }
        table.reloadData(forRowIndexes: table.selectedRowIndexes,
                         columnIndexes: IndexSet(integersIn: 0..<table.numberOfColumns))
        updateStatus()
    }

    // MARK: - Synchronizing

    @objc private func synchronize(_ sender: Any?) {
        guard let window, let (left, right) = comparedRoots else { return }
        let copies: [(source: URL, folder: URL, size: Int64)] = items.compactMap { item in
            switch item.action {
            case .toRight:
                (left.appending(path: item.path), right.appending(path: item.path).deletingLastPathComponent(),
                 item.left?.size ?? 0)
            case .toLeft:
                (right.appending(path: item.path), left.appending(path: item.path).deletingLastPathComponent(),
                 item.right?.size ?? 0)
            default:
                nil
            }
        }
        guard !copies.isEmpty else { return }
        Prompt.confirm(String(localized: "Copy \(copies.count) files?"),
                       message: String(localized: "Existing files in the target folders are replaced."),
                       okTitle: String(localized: "Synchronize"), in: window) { [weak self] in
            Task {
                let controller = TransferController(title: String(localized: "Synchronizing"),
                                                    failureTitle: String(localized: "Synchronization failed"), window: window)
                _ = await controller.run(source: left.path, target: right.path) { progress, prompts in
                    let total = copies.reduce(Int64(0)) { $0 + $1.size }
                    progress.update { $0.totalBytes = total }
                    // Files replace files without asking; a file meeting a folder is still asked about.
                    var options = TransferOptions()
                    options.overwrite = .overwriteAll
                    for copy in copies {
                        let job = TransferJob(kind: .copy, sources: [copy.source], destination: copy.folder, newName: nil,
                                              options: options)
                        _ = try await TransferEngine(job: job, progress: progress, reportsTotal: false,
                                                     prompts: prompts).run()
                    }
                    return copies.map(\.source)
                }
                self?.onFinish?()
                self?.compare(nil)
            }
        }
    }

    private func describe(_ file: ComparedFile?) -> (size: String, date: String) {
        guard let file else { return ("", "") }
        if file.isFolder { return ("<DIR>", "") }
        return (Settings.formattedSize(file.size), Self.dateFormatter.string(from: file.modified))
    }
}

extension SyncWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleRows.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let item = items[visibleRows[row]]
        let left = describe(item.left)
        let right = describe(item.right)
        switch tableColumn?.identifier.rawValue {
        case "leftName": return item.left == nil ? "" : item.path
        case "leftSize": return left.size
        case "leftDate": return left.date
        case "rightDate": return right.date
        case "rightSize": return right.size
        case "rightName": return item.right == nil ? "" : item.path
        default:
            return switch item.action {
            case .toRight: "→"
            case .toLeft: "←"
            case .equal: "="
            case .different: "≠"
            case .skip: ""
            }
        }
    }
}

extension SyncWindowController: NSTableViewDelegate {
    /// A name shows its kind's icon, the direction its color, sizes and dates stay
    /// quiet; the cells' values are unchanged.
    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        guard visibleRows.indices.contains(row), let identifier = tableColumn?.identifier.rawValue,
              let cell = cell as? NSTextFieldCell else { return }
        let item = items[visibleRows[row]]
        switch identifier {
        case "leftName", "rightName":
            let file = identifier == "leftName" ? item.left : item.right
            (cell as? SyncNameCell)?.icon = file.map { icon(for: item.path, isFolder: $0.isFolder) }
        case "action":
            cell.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            cell.textColor = switch item.action {
            case .toRight: .systemGreen
            case .toLeft: .systemBlue
            case .different: .systemOrange
            case .equal, .skip: .secondaryLabelColor
            }
        default:
            cell.textColor = .secondaryLabelColor
        }
    }

    private func icon(for path: String, isFolder: Bool) -> NSImage {
        let key = isFolder ? "/" : (path as NSString).pathExtension.lowercased()
        if let icon = icons[key] { return icon }
        let type = isFolder ? UTType.folder : UTType(filenameExtension: key) ?? .data
        let icon = NSWorkspace.shared.icon(for: type)
        icons[key] = icon
        return icon
    }
}

/// A name after the icon of its kind.
private final class SyncNameCell: NSTextFieldCell {
    var icon: NSImage?

    override func drawInterior(withFrame frame: NSRect, in view: NSView) {
        guard let icon else { return }
        // Beside the text, which starts at the top of the cell.
        let line = cellSize(forBounds: frame).height
        icon.draw(in: NSRect(x: frame.minX + 2, y: (frame.minY + (line - 16) / 2).rounded(), width: 16, height: 16), from: .zero,
                  operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        super.drawInterior(withFrame: NSRect(x: frame.minX + 22, y: frame.minY, width: frame.width - 22, height: frame.height),
                           in: view)
    }
}

/// Space toggles the direction of the selected rows.
private final class SyncTableView: NSTableView {
    var onToggle: (() -> Void)?
    private var isFitting = false

    /// The columns fill the list's width, the two names sharing what the others leave,
    /// instead of running past its right edge.
    override func tile() {
        super.tile()
        guard !isFitting, let width = enclosingScrollView?.contentSize.width, abs(frame.width - width) > 1 else { return }
        isFitting = true
        sizeToFit()
        isFitting = false
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            onToggle?()
        } else {
            super.keyDown(with: event)
        }
    }
}

extension SyncWindowController: NSTextFieldDelegate {
    /// Another folder typed in: the old comparison no longer applies to it.
    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === leftField || notification.object as? NSTextField === rightField else {
            return
        }
        comparison?.cancel()
        comparison = nil
        items = []
        comparedRoots = nil
        reloadRows()
        syncButton.isEnabled = false
        statusLabel.stringValue = String(localized: "Press Compare to compare these folders.")
    }
}

extension SyncWindowController: NSWindowDelegate {
    /// Closing the window (Esc) stops a comparison still running.
    func windowWillClose(_ notification: Notification) {
        comparison?.cancel()
        comparison = nil
    }
}
