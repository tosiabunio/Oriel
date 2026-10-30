import AppKit

/// Runs the same validated actions as the menus, in the originating window.
final class CommandPaletteController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let parent: NSWindow
    private let receiver: (Command) -> AnyObject?
    private let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                                styleMask: [.titled], backing: .buffered, defer: true)
    private let search = NSSearchField()
    private let table = ListTableView()
    private let runButton = NSButton(title: String(localized: "Run"), target: nil, action: nil)
    private var matches: [Command] = []
    private weak var previousResponder: NSResponder?
    private static let recentKey = "RecentPaletteCommands"

    init(parent: NSWindow, receiver: @escaping (Command) -> AnyObject?) {
        self.parent = parent
        self.receiver = receiver
        super.init()
        build()
    }

    func show() {
        previousResponder = parent.firstResponder
        reload()
        // The completion retains the controller for the lifetime of the sheet.
        parent.beginSheet(sheet) { [self] _ in parent.makeFirstResponder(previousResponder) }
        sheet.makeFirstResponder(search)
    }

    private func build() {
        sheet.title = String(localized: "Run Command…")
        search.placeholderString = String(localized: "Search commands")
        search.delegate = self
        search.sendsSearchStringImmediately = true
        let title = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        title.title = String(localized: "Command")
        title.width = 340
        title.resizingMask = .autoresizingMask
        let keys = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("keys"))
        keys.title = String(localized: "Shortcut")
        keys.width = 130
        table.addTableColumn(title)
        table.addTableColumn(keys)
        table.headerView = nil
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 25
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.target = self
        table.doubleAction = #selector(run(_:))
        let list = ListBox(table)
        list.placeholder = String(localized: "No matching commands")
        runButton.target = self
        runButton.action = #selector(run(_:))
        runButton.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView()
        buttons.addView(cancel, in: .trailing)
        buttons.addView(runButton, in: .trailing)
        let stack = NSStackView(views: [search, list, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        sheet.contentView = stack
        for view in [search, list, buttons] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        }
        stack.widthAnchor.constraint(equalToConstant: 560).isActive = true
        list.heightAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func menuItem(_ command: Command) -> NSMenuItem {
        NSMenuItem(title: command.title, action: command.selector, keyEquivalent: "")
    }

    private func isEnabled(_ command: Command) -> Bool {
        guard let target = receiver(command) else { return false }
        return (target as? NSMenuItemValidation)?.validateMenuItem(menuItem(command)) ?? true
    }

    private func reload() {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let recent = AppDefaults.store.stringArray(forKey: Self.recentKey) ?? []
        matches = Command.allCases.filter { command in
            guard command != .commandPalette, command != .exit, receiver(command) != nil else { return false }
            return words.allSatisfy { command.title.localizedStandardContains($0) || command.rawValue.localizedStandardContains($0) }
        }.sorted { a, b in
            @MainActor func rank(_ command: Command) -> Int {
                if !query.isEmpty {
                    let title = command.title.trimmingCharacters(in: CharacterSet(charactersIn: "…."))
                    if command.rawValue.caseInsensitiveCompare(query) == .orderedSame || title.caseInsensitiveCompare(query) == .orderedSame { return -2 }
                    return command.title.localizedLowercase.hasPrefix(query.localizedLowercase) ? -1 : 0
                }
                return recent.firstIndex(of: command.rawValue) ?? recent.count
            }
            let ar = rank(a), br = rank(b)
            return ar == br ? a.title.localizedStandardCompare(b.title) == .orderedAscending : ar < br
        }
        table.reloadData()
        if query.isEmpty { table.deselectAll(nil) }
        else if !matches.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
        updateRunButton()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { matches.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let command = matches[row]
        let shortcuts = ([command.shortcut].compactMap { $0 } + command.aliases + KeyBindings.extras(for: command))
            .reduce(into: [Shortcut]()) { if !$0.contains($1) { $0.append($1) } }
        let isKeys = tableColumn?.identifier.rawValue == "keys"
        let label = NSTextField(labelWithString: isKeys ? shortcuts.map(\.displayText).joined(separator: " / ") : command.title)
        label.lineBreakMode = .byTruncatingTail
        // The shortcuts quieter, at the end of the row, as menus show them.
        label.alignment = isKeys ? .right : .natural
        label.textColor = !isEnabled(command) ? .disabledControlTextColor : isKeys ? .secondaryLabelColor : .labelColor
        // In the middle of the row: a label alone is stretched over it and keeps its
        // text at the top.
        let cell = NSTableCellView()
        cell.textField = label
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    /// The chosen row in the accent color while the search field keeps the focus,
    /// as Spotlight shows it.
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { EmphasizedRowView() }

    func tableViewSelectionDidChange(_ notification: Notification) { updateRunButton() }
    func controlTextDidChange(_ notification: Notification) { reload() }

    private func updateRunButton() {
        runButton.isEnabled = matches.indices.contains(table.selectedRow) && isEnabled(matches[table.selectedRow])
    }

    @objc private func run(_ sender: Any?) {
        guard matches.indices.contains(table.selectedRow) else { return }
        let command = matches[table.selectedRow]
        guard isEnabled(command), let target = receiver(command) else { NSSound.beep(); reload(); return }
        var recent = AppDefaults.store.stringArray(forKey: Self.recentKey) ?? []
        recent.removeAll { $0 == command.rawValue }
        recent.insert(command.rawValue, at: 0)
        AppDefaults.store.set(Array(recent.prefix(10)), forKey: Self.recentKey)
        let item = menuItem(command)
        parent.endSheet(sheet)
        sheet.orderOut(nil)
        parent.makeFirstResponder(previousResponder)
        // Ending this sheet first lets the command open a dialog of its own.
        DispatchQueue.main.async { _ = NSApp.sendAction(command.selector, to: target, from: item) }
    }

    @objc private func cancel(_ sender: Any?) {
        parent.endSheet(sheet)
        sheet.orderOut(nil)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveUp(_:)):
            guard !matches.isEmpty else { return true }
            let step = selector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = table.selectedRow < 0 ? (step > 0 ? 0 : matches.count - 1) : min(max(0, table.selectedRow + step), matches.count - 1)
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
        case #selector(NSResponder.insertNewline(_:)): run(nil)
        case #selector(NSResponder.cancelOperation(_:)): cancel(nil)
        default: return false
        }
        return true
    }
}

/// A row drawn selected as in a focused list, whichever view has the focus.
private final class EmphasizedRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}
    }
}
