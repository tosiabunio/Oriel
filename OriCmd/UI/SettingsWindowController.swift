import AppKit

/// The Settings window (⌘,), the counterpart of Total Commander's Options
/// dialog: one pane per topic, chosen in the toolbar as in the system apps.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let tabs = SettingsTabs()

    private init() {
        tabs.tabStyle = .toolbar
        let panes: [(SettingsPane, String, String)] = [
            (GeneralPane(), String(localized: "General"), "gearshape"),
            (PanelsPane(), String(localized: "Panels"), "rectangle.split.2x1"),
            (WindowPane(), String(localized: "Window"), "macwindow"),
            (ColorsPane(), String(localized: "Colors"), "paintpalette"),
            (OperationsPane(), String(localized: "Operations"), "doc.on.doc"),
            (KeyboardPane(), String(localized: "Keyboard"), "keyboard"),
        ]
        for (pane, title, symbol) in panes {
            pane.title = title
            let item = NSTabViewItem(viewController: pane)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        // One width for all panes (that of the widest): switching panes only
        // changes the height, as in the system's settings windows.
        let width = panes.map { $0.0.naturalWidth }.max() ?? 0
        for (pane, _, _) in panes {
            pane.fix(width: width)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        super.init(window: window)
        #if DEBUG
        if let tab = ProcessInfo.processInfo.environment["ORICMD_SETTINGS_TAB"].flatMap(Int.init),
           tabs.tabViewItems.indices.contains(tab) {
            tabs.selectedTabViewItemIndex = tab
        }
        #endif
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

/// The panes, chosen in the toolbar.
private final class SettingsTabs: NSTabViewController {
    /// A pane grows the window downwards: first moves it up as far as the pane
    /// would reach below the screen.
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
        guard let window = view.window, let visible = window.screen?.visibleFrame,
              let content = window.contentView, let pane = tabViewItem?.viewController else { return }
        let height = window.frame.height - content.frame.height + pane.preferredContentSize.height
        if window.frame.maxY - height < visible.minY {
            window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: min(visible.maxY, visible.minY + height)))
        }
    }
}

// MARK: - Building blocks

/// A pane: sections with bold titles, each a rounded group of labelled controls and
/// grey explanations, as System Settings groups its options. A pane taller than the
/// screen scrolls.
class SettingsPane: NSViewController {
    private struct Group {
        var title: String?
        var rows: [[NSView]] = []
        var fullWidthRows: [Int] = []
        /// Rows whose control has no text baseline (color wells): centered instead.
        var centeredRows: [Int] = []
    }

    private var groups: [Group] = []
    private let content = FlippedView()
    static let noteWidth: CGFloat = 400

    override func loadView() {
        build()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        // One column of labels for the whole pane, so the controls of every group start
        // on one line.
        let labelWidth = groups.flatMap { group in
            group.rows.enumerated().filter { !group.fullWidthRows.contains($0.offset) }.map { $0.element[0] }
        }.compactMap { ($0 as? NSTextField)?.fittingSize.width }.max() ?? 0
        for group in groups where !group.rows.isEmpty {
            if let title = group.title {
                let label = NSTextField(labelWithString: title)
                label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
                stack.addArrangedSubview(label)
                if stack.arrangedSubviews.count > 1 {
                    stack.setCustomSpacing(18, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
                }
            }
            let box = Self.groupBox(around: grid(for: group, labelWidth: labelWidth))
            stack.addArrangedSubview(box)
            box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
        ])
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = content
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        view = scroll
        preferredContentSize = content.fittingSize
        // The preview grows and shrinks with the look and the row density.
        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fitHeight() }
        }
    }

    /// The width the pane needs.
    var naturalWidth: CGFloat {
        loadViewIfNeeded()
        return content.fittingSize.width
    }

    /// The height of the window's content leaves room on the screen for its title
    /// bar and toolbar of panes; the rest scrolls.
    private var maxHeight: CGFloat {
        #if DEBUG
        // Test runs: a screen this tall.
        if let height = ProcessInfo.processInfo.environment["ORICMD_SETTINGS_HEIGHT"].flatMap(Double.init) {
            return height
        }
        #endif
        let screen = view.window?.screen ?? NSScreen.main
        return (screen?.visibleFrame.height ?? 800) - 100
    }

    private func fitHeight() {
        let width = preferredContentSize.width
        guard width > 0 else { return }
        let height = min(content.fittingSize.height, maxHeight)
        if height != preferredContentSize.height {
            preferredContentSize = NSSize(width: width, height: height)
        }
    }

    private func grid(for group: Group, labelWidth: CGFloat) -> NSGridView {
        let grid = NSGridView(views: group.rows)
        grid.column(at: 0).xPlacement = .trailing
        // A group of full-width rows alone (the preview) has no label column to keep.
        if group.fullWidthRows.count < group.rows.count {
            grid.column(at: 0).width = labelWidth
        }
        grid.rowAlignment = .firstBaseline
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        for index in group.fullWidthRows {
            grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2), verticalRange: NSRange(location: index, length: 1))
            grid.row(at: index).cell(at: 0).xPlacement = .leading
        }
        for index in group.centeredRows {
            grid.row(at: index).rowAlignment = .none
            grid.row(at: index).yPlacement = .center
        }
        return grid
    }

    /// A rounded, lightly filled group around `content`.
    private static func groupBox(around content: NSView) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderWidth = 0
        box.cornerRadius = 10
        box.fillColor = .quaternarySystemFill
        box.contentViewMargins = .zero
        content.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(content)
        if let inside = box.contentView {
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: inside.topAnchor, constant: 12),
                content.leadingAnchor.constraint(equalTo: inside.leadingAnchor, constant: 14),
                content.trailingAnchor.constraint(lessThanOrEqualTo: inside.trailingAnchor, constant: -14),
                content.bottomAnchor.constraint(equalTo: inside.bottomAnchor, constant: -12),
            ])
        }
        return box
    }

    private var current: Group {
        get { groups.last ?? Group() }
        set {
            if groups.isEmpty { groups.append(newValue) } else { groups[groups.count - 1] = newValue }
        }
    }

    /// Adds the rows of the pane.
    func build() {}

    /// Lays the pane out at `width`; its height follows from that, up to the screen's.
    func fix(width: CGFloat) {
        preferredContentSize = NSSize(width: width, height: 0)
        fitHeight()
    }

    func section(_ title: String) {
        groups.append(Group(title: title))
    }

    func row(_ label: String?, _ views: NSView...) {
        let content: NSView = views.count == 1 ? views[0] : {
            let stack = NSStackView(views: views)
            stack.spacing = 8
            return stack
        }()
        var group = current
        if content is NSColorWell {
            group.centeredRows.append(group.rows.count)
        }
        group.rows.append([label.map { NSTextField(labelWithString: $0) } ?? NSGridCell.emptyContentView, content])
        current = group
    }

    func note(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = Self.noteWidth
        label.widthAnchor.constraint(lessThanOrEqualToConstant: Self.noteWidth).isActive = true
        var group = current
        group.rows.append([NSGridCell.emptyContentView, label])
        current = group
    }

    /// A note about the whole group, from its leading edge, not under one control.
    func groupNote(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = Self.noteWidth + 120
        label.widthAnchor.constraint(lessThanOrEqualToConstant: Self.noteWidth + 120).isActive = true
        fullWidth(label)
    }

    func fullWidth(_ view: NSView) {
        var group = current
        group.fullWidthRows.append(group.rows.count)
        group.rows.append([view, NSGridCell.emptyContentView])
        current = group
    }

    func checkbox(_ title: String, _ value: Bool, _ action: Selector) -> NSButton {
        let box = NSButton(checkboxWithTitle: title, target: self, action: action)
        box.state = value ? .on : .off
        return box
    }

    func button(_ title: String, _ action: Selector, target: AnyObject? = nil) -> NSButton {
        NSButton(title: title, target: target ?? self, action: action)
    }
}

/// Lays the pane's sections out from the top.
private final class FlippedView: NSView {
    nonisolated override var isFlipped: Bool { true }
}

// MARK: - General

private final class GeneralPane: SettingsPane {
    private let languagePopUp = NSPopUpButton()
    private let restartButton = NSButton()
    private let restartNote = NSTextField(labelWithString: "")

    override func build() {
        section(String(localized: "Language"))
        let running = Settings.runningLanguage == .russian ? "Русский" : "English"
        languagePopUp.addItems(withTitles: [String(localized: "As in the system (\(running))"), "English", "Русский"])
        languagePopUp.selectItem(at: Settings.Language.allCases.firstIndex(of: Settings.language) ?? 0)
        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged(_:))
        row(String(localized: "Interface language:"), languagePopUp)
        restartButton.title = String(localized: "Restart Now")
        restartButton.target = self
        restartButton.action = #selector(restart(_:))
        restartNote.stringValue = String(localized: "\(Bundle.main.appName) shows the new language after a restart.")
        restartNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        restartNote.textColor = .secondaryLabelColor
        row(nil, restartNote, restartButton)
        updateRestart()

        section(String(localized: "Updates"))
        row(nil, checkbox(String(localized: "Check for updates automatically"), Settings.checksForUpdates,
                          #selector(updatesChanged(_:))))
        note(String(localized: "Once a day \(Bundle.main.appName) looks for a new release on GitHub and offers to install it."))
        row(nil, button(String(localized: "Check Now"), #selector(AppDelegate.checkForUpdates(_:)), target: NSApp.delegate),
            NSTextField(labelWithString: String(localized: "Version \(Updater.currentVersion)")))
    }

    /// The restart button shows while the chosen language differs from the running one.
    private func updateRestart() {
        let chosen = Settings.language
        let effective: Settings.Language = chosen == .system ? systemLanguage : chosen
        let differs = effective != Settings.runningLanguage
        restartButton.isHidden = !differs
        restartNote.isHidden = !differs
    }

    private var systemLanguage: Settings.Language {
        let preferred = Bundle.preferredLocalizations(from: Bundle.main.localizations,
                                                      forPreferences: UserDefaults(suiteName: UserDefaults.globalDomain)?
                                                        .stringArray(forKey: "AppleLanguages"))
        return preferred.first?.hasPrefix("ru") == true ? .russian : .english
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        Settings.language = Settings.Language.allCases[sender.indexOfSelectedItem]
        updateRestart()
    }

    @objc private func restart(_ sender: Any?) {
        Relaunch.now()
    }

    @objc private func updatesChanged(_ sender: NSButton) {
        Settings.checksForUpdates = sender.state == .on
    }
}

// MARK: - Panels

private final class PanelsPane: SettingsPane {
    private let fontLabel = NSTextField(labelWithString: "")
    private let lookPopUp = NSPopUpButton()
    private let densityPopUp = NSPopUpButton()
    private let statusPopUp = NSPopUpButton()
    private var bracketsBox: NSButton!
    private var markersBox: NSButton!

    override func build() {
        section(String(localized: "Look"))
        lookPopUp.addItems(withTitles: [String(localized: "Modern"), String(localized: "Classic (Total Commander)")])
        lookPopUp.target = self
        lookPopUp.action = #selector(lookChanged(_:))
        lookPopUp.identifier = NSUserInterfaceItemIdentifier("look")
        row(String(localized: "Look:"), lookPopUp)
        note(String(localized: "Modern draws the panels as Mac lists are drawn: a rounded cursor, quieter columns, the counts in the header. Choosing a look sets the options below and in Window; each can still be changed."))

        section(String(localized: "Font"))
        row(String(localized: "Panel font:"), fontLabel, button(String(localized: "Choose…"), #selector(chooseFont(_:))),
            button(String(localized: "Default"), #selector(resetFont(_:))))
        updateFontLabel()

        section(String(localized: "File list"))
        densityPopUp.addItems(withTitles: [String(localized: "Standard (13 pt, as in the Finder)"),
                                           String(localized: "Compact (12 pt, more files)")])
        densityPopUp.target = self
        densityPopUp.action = #selector(densityChanged(_:))
        densityPopUp.identifier = NSUserInterfaceItemIdentifier("density")
        row(String(localized: "Rows:"), densityPopUp)
        note(String(localized: "A font chosen above keeps its own size; the rows still follow this choice."))
        markersBox = checkbox(String(localized: "Show checkmarks on marked items"), Settings.showsSelectionMarkers,
                              #selector(selectionMarkersChanged(_:)))
        row(nil, markersBox)
        bracketsBox = checkbox(String(localized: "Folder names in [brackets]"), Settings.showsFolderBrackets,
                               #selector(folderBracketsChanged(_:)))
        row(nil, bracketsBox)
        let extensions = NSPopUpButton()
        extensions.addItems(withTitles: [String(localized: "In their own column"), String(localized: "After the name")])
        extensions.selectItem(at: Settings.extensionDisplay == .column ? 0 : 1)
        extensions.target = self
        extensions.action = #selector(extensionDisplayChanged(_:))
        row(String(localized: "File extensions:"), extensions)
        note(String(localized: "Full view. After the name, the Ext column title still sorts by extension; a long name is cut short before its extension."))
        let sizes = NSPopUpButton()
        sizes.addItems(withTitles: [String(localized: "Short (KB, MB, GB)"), String(localized: "Exact (12 345 678)")])
        sizes.selectItem(at: Settings.sizeDisplay == .short ? 0 : 1)
        sizes.target = self
        sizes.action = #selector(sizeDisplayChanged(_:))
        row(String(localized: "Sizes:"), sizes)
        note(String(localized: "Short sizes count as the Finder does (1 KB = 1000 bytes), in the panels, the status line, the free space and when synchronizing folders."))
        statusPopUp.addItems(withTitles: [String(localized: "As in the Finder (2 of 15 selected · 35 KB of 1,2 MB)"),
                                          String(localized: "As in Total Commander (35 k / 1 234 k in 2 / 12 file(s), 0 / 3 dir(s))")])
        statusPopUp.target = self
        statusPopUp.action = #selector(statusLineChanged(_:))
        row(String(localized: "Status line:"), statusPopUp)
        groupNote(String(localized: "Optional columns (kind, created, dimensions, duration, tags) are chosen by right-clicking a panel's column headers."))

        section(String(localized: "Mouse"))
        let rightButton = NSPopUpButton()
        rightButton.addItems(withTitles: [
            String(localized: "Shows the context menu"),
            String(localized: "Marks files, held down shows the context menu"),
        ])
        rightButton.selectItem(at: Settings.rightButton == .menu ? 0 : 1)
        rightButton.target = self
        rightButton.action = #selector(rightButtonChanged(_:))
        row(String(localized: "Right button:"), rightButton)
        note(String(localized: "Marking: a click marks or unmarks a file, a drag over files makes them all as the first one became; hold the button still for the context menu. On [..] and with Control-click the menu opens at once."))
        refresh()
    }

    /// The controls a look sets, as they are now.
    private func refresh() {
        lookPopUp.selectItem(at: Settings.isModern ? 0 : 1)
        densityPopUp.selectItem(at: Settings.density == .standard ? 0 : 1)
        statusPopUp.selectItem(at: Settings.plainStatusLine ? 0 : 1)
        bracketsBox.state = Settings.showsFolderBrackets ? .on : .off
        markersBox.state = Settings.showsSelectionMarkers ? .on : .off
        updateFontLabel()
    }

    @objc private func lookChanged(_ sender: NSPopUpButton) {
        Settings.look = sender.indexOfSelectedItem == 0 ? .modern : .classic
        refresh()
    }

    @objc private func densityChanged(_ sender: NSPopUpButton) {
        Settings.density = sender.indexOfSelectedItem == 0 ? .standard : .compact
        updateFontLabel()
    }

    @objc private func extensionDisplayChanged(_ sender: NSPopUpButton) {
        Settings.extensionDisplay = sender.indexOfSelectedItem == 0 ? .column : .withName
    }

    @objc private func selectionMarkersChanged(_ sender: NSButton) { Settings.showsSelectionMarkers = sender.state == .on }
    @objc private func statusLineChanged(_ sender: NSPopUpButton) { Settings.plainStatusLine = sender.indexOfSelectedItem == 0 }

    @objc private func sizeDisplayChanged(_ sender: NSPopUpButton) {
        Settings.sizeDisplay = sender.indexOfSelectedItem == 0 ? .short : .exact
    }

    @objc private func rightButtonChanged(_ sender: NSPopUpButton) {
        Settings.rightButton = sender.indexOfSelectedItem == 0 ? .menu : .marks
    }

    private func updateFontLabel() {
        let font = Settings.panelFont
        fontLabel.stringValue = "\(font.displayName ?? font.fontName), \(Int(font.pointSize)) pt"
    }

    @objc private func chooseFont(_ sender: Any?) {
        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(Settings.panelFont, isMultiple: false)
        // Right next to the Settings window (or inside the screen), not wherever it was last.
        let panel = manager.fontPanel(true)
        if let panel, let window = view.window, let screen = window.screen?.visibleFrame {
            var origin = NSPoint(x: window.frame.maxX + 12, y: window.frame.maxY - panel.frame.height)
            if origin.x + panel.frame.width > screen.maxX {
                origin.x = window.frame.minX - panel.frame.width - 12
            }
            origin.x = min(max(origin.x, screen.minX), screen.maxX - panel.frame.width)
            origin.y = min(max(origin.y, screen.minY), screen.maxY - panel.frame.height)
            panel.setFrameOrigin(origin)
        }
        manager.orderFrontFontPanel(self)
        panel?.makeKeyAndOrderFront(self)
    }

    /// Sent by the font panel.
    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        Settings.panelFont = sender.convert(Settings.panelFont)
        updateFontLabel()
    }

    @objc private func resetFont(_ sender: Any?) {
        Settings.resetPanelFont()
        updateFontLabel()
    }

    @objc private func folderBracketsChanged(_ sender: NSButton) { Settings.showsFolderBrackets = sender.state == .on }
}

// MARK: - Window

/// What the main window shows around the panels.
private final class WindowPane: SettingsPane {
    private var commandLineBox: NSButton!
    private var functionKeysBox: NSButton!
    private var keyCapsBox: NSButton!
    private var sidebarBox: NSButton!
    private var driveButtonsBox: NSButton!
    private var macTabsBox: NSButton!
    private var compactHeaderBox: NSButton!

    override func build() {
        section(String(localized: "Main window"))
        commandLineBox = checkbox(String(localized: "Command line"), Settings.showsCommandLine,
                                  #selector(commandLineChanged(_:)))
        row(String(localized: "Show:"), commandLineBox)
        functionKeysBox = checkbox(String(localized: "Function key buttons (F3 View … F8 Delete)"), Settings.showsFunctionKeys,
                                   #selector(functionKeysChanged(_:)))
        row(nil, functionKeysBox)
        keyCapsBox = checkbox(String(localized: "Function keys drawn as key caps"), Settings.showsFunctionKeyCaps,
                              #selector(functionKeyCapsChanged(_:)))
        row(nil, keyCapsBox)
        sidebarBox = checkbox(String(localized: "Sidebar: devices, favorites and the hotlist (⌃⌘S)"), Settings.showsSidebar,
                              #selector(sidebarChanged(_:)))
        row(nil, sidebarBox)
        driveButtonsBox = checkbox(String(localized: "Drive buttons (while there is no sidebar)"), Settings.showsDriveButtons,
                                   #selector(driveButtonsChanged(_:)))
        row(nil, driveButtonsBox)
        row(String(localized: "Button bar:"), button(String(localized: "Customize Toolbar…"), #selector(customizeToolbar(_:))))

        section(String(localized: "Tabs and header"))
        macTabsBox = checkbox(String(localized: "Mac style, with icons and close buttons"), Settings.macStyleTabs,
                              #selector(macStyleTabsChanged(_:)))
        row(String(localized: "Folder tabs:"), macTabsBox)
        compactHeaderBox = checkbox(String(localized: "Compact: the volume and free space in the path bar"),
                                    Settings.compactPanelHeader, #selector(compactHeaderChanged(_:)))
        row(String(localized: "Panel header:"), compactHeaderBox)
        note(String(localized: "Without the row of the volume selector and the / and .. buttons: a click on the volume lists the others, a click on a folder of the path goes there. The mask (*.*) shows only when it filters."))
        // The look in Panels and ⌃⌘S change these too.
        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        commandLineBox.state = Settings.showsCommandLine ? .on : .off
        functionKeysBox.state = Settings.showsFunctionKeys ? .on : .off
        keyCapsBox.state = Settings.showsFunctionKeyCaps ? .on : .off
        sidebarBox.state = Settings.showsSidebar ? .on : .off
        driveButtonsBox.state = Settings.showsDriveButtons ? .on : .off
        macTabsBox.state = Settings.macStyleTabs ? .on : .off
        compactHeaderBox.state = Settings.compactPanelHeader ? .on : .off
    }

    @objc private func commandLineChanged(_ sender: NSButton) { Settings.showsCommandLine = sender.state == .on }
    @objc private func functionKeysChanged(_ sender: NSButton) { Settings.showsFunctionKeys = sender.state == .on }
    @objc private func functionKeyCapsChanged(_ sender: NSButton) { Settings.showsFunctionKeyCaps = sender.state == .on }
    @objc private func driveButtonsChanged(_ sender: NSButton) { Settings.showsDriveButtons = sender.state == .on }
    @objc private func sidebarChanged(_ sender: NSButton) { Settings.showsSidebar = sender.state == .on }
    @objc private func macStyleTabsChanged(_ sender: NSButton) { Settings.macStyleTabs = sender.state == .on }
    @objc private func compactHeaderChanged(_ sender: NSButton) { Settings.compactPanelHeader = sender.state == .on }

    @objc private func customizeToolbar(_ sender: Any?) {
        NSApp.windows.first { $0.windowController is MainWindowController }?.runToolbarCustomizationPalette(sender)
    }
}

// MARK: - Colors

private final class ColorsPane: SettingsPane {
    private let markedWell = NSColorWell(style: .default)
    private let cursorWell = NSColorWell(style: .default)
    private let cursorTextWell = NSColorWell(style: .default)
    private let alternatingBox = NSButton()
    private let boldMarkedBox = NSButton()
    private let presetsButton = NSPopUpButton(frame: .zero, pullsDown: true)

    override func build() {
        section(String(localized: "Theme"))
        let themes = NSSegmentedControl(labels: [String(localized: "As in the system"), String(localized: "Light"),
                                                 String(localized: "Dark")],
                                        trackingMode: .selectOne, target: self, action: #selector(themeChanged(_:)))
        themes.selectedSegment = Settings.Appearance.allCases.firstIndex(of: Settings.appearance) ?? 0
        row(String(localized: "Appearance:"), themes)

        section(String(localized: "Preview"))
        fullWidth(PanelPreview())

        section(String(localized: "Panel colors"))
        presetsButton.addItem(withTitle: String(localized: "Choose…"))
        for preset in ColorSettings.Preset.allCases {
            presetsButton.addItem(withTitle: preset.title)
        }
        presetsButton.target = self
        presetsButton.action = #selector(presetChosen(_:))
        row(String(localized: "Ready-made colors:"), presetsButton)
        note(String(localized: "Also for people who tell some colors apart with difficulty: marked files and file colors stay distinct."))
        for well in [markedWell, cursorWell, cursorTextWell] {
            well.target = self
            well.action = #selector(colorChanged(_:))
            well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
        row(String(localized: "Marked files:"), markedWell)
        row(String(localized: "Cursor:"), cursorWell)
        row(String(localized: "Cursor text:"), cursorTextWell)
        alternatingBox.setButtonType(.switch)
        alternatingBox.title = String(localized: "Alternating row background")
        alternatingBox.target = self
        alternatingBox.action = #selector(alternatingChanged(_:))
        row(nil, alternatingBox)
        boldMarkedBox.setButtonType(.switch)
        boldMarkedBox.title = String(localized: "Marked files in bold")
        boldMarkedBox.target = self
        boldMarkedBox.action = #selector(boldMarkedChanged(_:))
        row(nil, boldMarkedBox)
        row(nil, button(String(localized: "Default Colors"), #selector(resetColors(_:))))

        section(String(localized: "File colors"))
        row(nil, button(String(localized: "File Colors…"), #selector(showFileColors(_:))))
        note(String(localized: "Colors by file mask: archives, pictures, scripts and so on."))
        refresh()
        // The look decides the stripes unless they were chosen.
        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.alternatingBox.state = ColorSettings.alternatingRows ? .on : .off
            }
        }
    }

    private func refresh() {
        markedWell.color = ColorSettings.chosenMarkedColor ?? Theme.markedText
        cursorWell.color = Theme.cursorBackground
        cursorTextWell.color = Theme.cursorText
        alternatingBox.state = ColorSettings.alternatingRows ? .on : .off
        boldMarkedBox.state = ColorSettings.boldMarked ? .on : .off
    }

    /// A preset replaces the marked files' color and the file colors (asking first
    /// when they were changed).
    @objc private func presetChosen(_ sender: NSPopUpButton) {
        let presets = ColorSettings.Preset.allCases
        guard sender.indexOfSelectedItem > 0, presets.indices.contains(sender.indexOfSelectedItem - 1) else { return }
        let preset = presets[sender.indexOfSelectedItem - 1]
        let apply = { [weak self] in
            preset.apply()
            self?.refresh()
        }
        guard ColorSettings.areCustomized, let window = view.window else {
            apply()
            return
        }
        Prompt.confirm(String(localized: "Replace the colors with \u{201C}\(preset.title)\u{201D}?"),
                       message: String(localized: "The color of marked files and the file colors by mask are replaced."),
                       okTitle: String(localized: "Replace"), in: window, completion: apply)
    }

    @objc private func boldMarkedChanged(_ sender: NSButton) {
        ColorSettings.boldMarked = sender.state == .on
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        switch sender {
        case markedWell: ColorSettings.markedColor = sender.color
        case cursorWell: ColorSettings.cursorColor = sender.color
        default: ColorSettings.cursorTextColor = sender.color
        }
    }

    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        Settings.appearance = Settings.Appearance.allCases[sender.selectedSegment]
        refresh()
    }

    @objc private func alternatingChanged(_ sender: NSButton) {
        ColorSettings.alternatingRows = sender.state == .on
    }

    @objc private func resetColors(_ sender: Any?) {
        ColorSettings.resetPanelColors()
        refresh()
    }

    @objc private func showFileColors(_ sender: Any?) {
        FileColorsWindowController.shared.showWindow(sender)
    }
}

// MARK: - Operations

private final class OperationsPane: SettingsPane {
    private let overwritePopUp = NSPopUpButton()

    override func build() {
        section(String(localized: "Copy and move (F5 / F6)"))
        for mode in OverwriteMode.allCases {
            overwritePopUp.addItem(withTitle: Settings.isModern ? mode.plainTitle : mode.title)
        }
        overwritePopUp.selectItem(at: Settings.copyOverwriteMode.rawValue - 1)
        overwritePopUp.target = self
        overwritePopUp.action = #selector(overwriteChanged(_:))
        row(String(localized: "If a file exists:"), overwritePopUp)
        row(nil, checkbox(String(localized: "Verify copied files"), Settings.copyVerifies, #selector(verifyChanged(_:))))
        row(nil, checkbox(String(localized: "Copy extended attributes and ACLs"), Settings.copyAttributes,
                          #selector(attributesChanged(_:))))
        row(nil, checkbox(String(localized: "Skip all which cannot be opened for reading"), Settings.copySkipsUnreadable,
                          #selector(skipUnreadableChanged(_:))))
        row(nil, checkbox(String(localized: "Overwrite/delete locked files"), Settings.copyOverwritesLocked,
                          #selector(overwriteLockedChanged(_:))))
        row(nil, checkbox(String(localized: "Skip .DS_Store (Finder\u{2019}s folder view settings)"), Settings.copySkipsDSStore,
                          #selector(skipDSStoreChanged(_:))))
        note(String(localized: "These are the defaults of the copy dialog; its options change them for one operation."))

        section(String(localized: "Delete"))
        row(nil, checkbox(String(localized: "Confirm moving to the Trash"), Settings.confirmsMoveToTrash,
                          #selector(confirmTrashChanged(_:))))
        note(String(localized: "Shift+F8 deletes permanently and always asks."))

        section(String(localized: "Programs"))
        row(String(localized: "Files:"), button(String(localized: "Internal Associations…"),
                                                Command.internalAssociate.selector, target: NSApp.delegate))
        note(String(localized: "Which program opens, views (F3) or edits (F4) files of a given type."))
        row(String(localized: "Start menu:"), button(String(localized: "Change Start Menu…"),
                                                     #selector(AppDelegate.showStartMenuEditor(_:)), target: NSApp.delegate))
        note(String(localized: "Your own commands with %P, %N, %S parameters, in the menu and on the button bar."))
    }

    @objc private func overwriteChanged(_ sender: NSPopUpButton) {
        Settings.copyOverwriteMode = OverwriteMode(rawValue: sender.indexOfSelectedItem + 1) ?? .ask
    }

    @objc private func verifyChanged(_ sender: NSButton) { Settings.copyVerifies = sender.state == .on }
    @objc private func attributesChanged(_ sender: NSButton) { Settings.copyAttributes = sender.state == .on }
    @objc private func skipUnreadableChanged(_ sender: NSButton) { Settings.copySkipsUnreadable = sender.state == .on }
    @objc private func overwriteLockedChanged(_ sender: NSButton) { Settings.copyOverwritesLocked = sender.state == .on }
    @objc private func skipDSStoreChanged(_ sender: NSButton) { Settings.copySkipsDSStore = sender.state == .on }
    @objc private func confirmTrashChanged(_ sender: NSButton) { Settings.confirmsMoveToTrash = sender.state == .on }
}

// MARK: - Keyboard

private final class KeyboardPane: SettingsPane {
    override func build() {
        section(String(localized: "Quick search"))
        let popUp = NSPopUpButton()
        popUp.addItems(withTitles: [
            String(localized: "Option+letters (letters go to the command line)"),
            String(localized: "Letters (Option+letters go to the command line)"),
        ])
        popUp.selectItem(at: Settings.quickSearchMode == .optionLetters ? 0 : 1)
        popUp.target = self
        popUp.action = #selector(quickSearchChanged(_:))
        row(String(localized: "Search file names with:"), popUp)
        note(String(localized: "Option with letters jumps to a file by its name; plain letters type into the command line."))

        section(String(localized: "Shortcuts"))
        row(nil, button(String(localized: "Keyboard Shortcuts…"), #selector(showKeys(_:))))
        note(String(localized: "Any cm_ command can get its own keys; shortcuts can be imported from wincmd.ini. Keys work on any keyboard layout."))

        section(String(localized: "Function keys"))
        note(String(localized: "On a Mac F1–F12 control brightness and sound by default. Hold fn, or turn on \u{201C}Use F1, F2, etc. keys as standard function keys\u{201D}."))
        row(nil, button(String(localized: "Open Keyboard Settings"), #selector(openKeyboardSettings(_:))))
    }

    @objc private func quickSearchChanged(_ sender: NSPopUpButton) {
        Settings.quickSearchMode = sender.indexOfSelectedItem == 0 ? .optionLetters : .letters
    }

    @objc private func showKeys(_ sender: Any?) {
        KeyBindingsWindowController.shared.showWindow(sender)
    }

    @objc private func openKeyboardSettings(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

/// A small panel drawn with the current font and colors.
private final class PanelPreview: NSView {
    private struct Row {
        let name: String
        let ext: String
        /// Nil for folders.
        let bytes: Int64?
        var isFolder = false
        var isMarked = false
        var isCursor = false
    }

    private let rows = [
        Row(name: "..", ext: "", bytes: nil, isFolder: true),
        Row(name: "Documents", ext: "", bytes: nil, isFolder: true),
        Row(name: "notes", ext: "md", bytes: 12_345, isMarked: true),
        Row(name: "readme", ext: "txt", bytes: 4_096, isCursor: true),
        Row(name: "archive", ext: "zip", bytes: 88_000),
        Row(name: "photo", ext: "jpg", bytes: 2_048_000),
        Row(name: "movie", ext: "mp4", bytes: 9_876_543),
        Row(name: "report", ext: "pdf", bytes: 310_000, isMarked: true),
        Row(name: "script", ext: "sh", bytes: 1_024),
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 460).isActive = true
        heightConstraint = heightAnchor.constraint(equalToConstant: height)
        heightConstraint?.isActive = true
        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.heightConstraint?.constant = self.height
                self.needsDisplay = true
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private var heightConstraint: NSLayoutConstraint?
    private var headerHeight: CGFloat { Settings.isModern ? FileListHeaderView.height + 2 : 20 }
    private var height: CGFloat { headerHeight + CGFloat(rows.count) * Theme.rowHeight + (Settings.isModern ? 6 : 2) }

    nonisolated override var isFlipped: Bool { true }

    /// Drawn as the panels draw their rows, in the look chosen.
    override func draw(_ dirtyRect: NSRect) {
        let modern = Settings.isModern
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        Theme.panelBackground.setFill()
        bounds.fill()

        // Column headers.
        let header = NSRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        (modern ? Theme.panelBackground : Theme.chromeBackground).setFill()
        header.fill()
        let left = Theme.contentInset + 6
        let nameWidth = bounds.width - 190
        let columns: [(String, CGFloat, NSTextAlignment)] = [
            (String(localized: "Name"), left, .left), (String(localized: "Ext"), nameWidth, .left),
            (String(localized: "Size"), nameWidth + 50 - Theme.contentInset, .right),
        ]
        let titleFont = modern ? Theme.headerDetailFont : Theme.chromeFont
        let titleHeight = Theme.lineHeight(titleFont) + 2
        for (index, (title, x, alignment)) in columns.enumerated() {
            let sorted = modern && index == 0
            draw(title, in: NSRect(x: x, y: (headerHeight - titleHeight) / 2 + 1, width: alignment == .right ? 130 : 120,
                                   height: titleHeight),
                 font: sorted ? .systemFont(ofSize: titleFont.pointSize, weight: .semibold) : titleFont,
                 color: modern ? (sorted ? .labelColor : .secondaryLabelColor) : Theme.chromeText, alignment: alignment)
        }
        Theme.separator.setFill()
        NSRect(x: 0, y: headerHeight - 1, width: bounds.width, height: 1).fill()

        let font = Theme.panelFont
        let rowHeight = Theme.rowHeight
        for (index, row) in rows.enumerated() {
            let rect = NSRect(x: 0, y: headerHeight + (modern ? 3 : 0) + CGFloat(index) * rowHeight,
                              width: bounds.width, height: rowHeight)
            let background: NSColor? = if row.isCursor {
                Theme.cursorBackground
            } else if row.isMarked && modern {
                Theme.markedRowBackground
            } else if ColorSettings.alternatingRows && index % 2 == 1 {
                Theme.alternateRowBackground
            } else {
                nil
            }
            if let background {
                background.setFill()
                Theme.rowPath(rect).fill()
            }
            let fileName = row.ext.isEmpty ? row.name : row.name + "." + row.ext
            var color = ColorSettings.color(forName: fileName) ?? Theme.panelText
            if row.isMarked { color = Theme.markedText }
            if row.isCursor {
                color = row.isMarked && !(modern && Settings.showsSelectionMarkers) ? Theme.markedCursorText : Theme.cursorText
            }
            let detail = modern && !row.isCursor ? Theme.secondaryText : color
            let textY = rect.minY + (rowHeight - (font.ascender - font.descender)) / 2 - 1
            let textFont = Theme.font(marked: row.isMarked)
            if Settings.extensionDisplay == .withName {
                draw(row.isFolder ? Settings.panelName(row.name, isFolder: true) : fileName,
                     in: NSRect(x: left, y: textY, width: nameWidth + 38 - left, height: rowHeight),
                     font: textFont, color: color, alignment: .left)
            } else {
                draw(Settings.panelName(row.name, isFolder: row.isFolder),
                     in: NSRect(x: left, y: textY, width: nameWidth - 10 - left, height: rowHeight),
                     font: textFont, color: color, alignment: .left)
                draw(row.ext, in: NSRect(x: nameWidth, y: textY, width: 48, height: rowHeight), font: textFont, color: detail,
                     alignment: .left)
            }
            let folderSize = modern ? (row.name == ".." ? "" : "--") : "<DIR>"
            draw(row.bytes.map(Settings.formattedSize) ?? folderSize,
                 in: NSRect(x: nameWidth + 50 - Theme.contentInset, y: textY, width: 130, height: rowHeight),
                 font: Theme.panelNumberFont, color: detail, alignment: .right)
        }
        Theme.separator.setStroke()
        if modern {
            let outline = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
            outline.stroke()
        } else {
            NSBezierPath(rect: frame).stroke()
        }
    }

    private func draw(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
}

// MARK: - Restart

/// Quits and starts OriCmd again (for a new interface language).
enum Relaunch {
    static func now() {
        let script = "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; open \"$2\""
        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        NSApp.terminate(nil)
    }
}
