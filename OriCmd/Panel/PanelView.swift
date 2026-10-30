import AppKit

/// One of the two file panels, laid out top to bottom like in Total Commander:
/// volume selector with free space, path bar, file list, status line, and the
/// terminal of a server when one is connected. The compact header (Settings) puts
/// the volume and its free space into the path bar instead; in the modern look also
/// the counts, the status line then showing only for quick search.
final class PanelView: NSView {
    let driveBar = DriveBar()
    let volumeButton = NSPopUpButton(frame: .zero, pullsDown: false)
    let freeSpaceButton: NSButton = DriveSpaceButton(title: "", target: nil, action: nil)
    /// Spins while a slow folder is being read.
    let loadingIndicator = NSProgressIndicator()
    let rootButton = NSButton(title: "/", target: nil, action: nil)
    let parentButton = NSButton(title: "..", target: nil, action: nil)
    let tabBar = FolderTabBar()
    let pathBar = PathBar()
    let headerView = FileListHeaderView()
    let scrollView = NSScrollView()
    let listView = FileListView()
    let statusLabel = NSTextField(labelWithString: "")
    /// Quick search box shown over the status line.
    /// Quick search and the quick filter: a search field, with its magnifier and its
    /// button that clears the text.
    let quickSearchField = NSSearchField()
    let terminalPane = TerminalPane()

    var onVolumeSelected: ((Volume) -> Void)?
    var onDriveInformation: ((Volume) -> Void)?
    var onGoToRoot: (() -> Void)?
    var onGoToParent: (() -> Void)?

    var isActive = false {
        didSet {
            pathBar.isActive = isActive
            listView.isActive = isActive
        }
    }

    private var volumes: [Volume] = []
    private var tabBarHeight: NSLayoutConstraint!
    private var headerHeight: NSLayoutConstraint!
    private var driveBarHeight: NSLayoutConstraint!
    private var terminalHeight: NSLayoutConstraint!
    private var quickSearchWidth: NSLayoutConstraint!
    /// The tab bar and the spinner go under the volume row, or the spinner into the
    /// path bar when the header is compact.
    private var classicConstraints: [NSLayoutConstraint] = []
    private var compactConstraints: [NSLayoutConstraint] = []
    /// The spinner in the compact path bar, beside the path.
    private var spinnerCenter: NSLayoutConstraint!
    private var statusRowConstraints: [NSLayoutConstraint] = []
    private var collapsedStatusConstraint: NSLayoutConstraint!

    /// The quick search box shows in the status line's place (bringing the line back
    /// while the counts are in the path bar).
    var isQuickSearching = false {
        didSet { if isQuickSearching != oldValue { updateStatusRow() } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        volumeButton.controlSize = .small
        volumeButton.font = Theme.chromeFont
        volumeButton.target = self
        volumeButton.action = #selector(volumeChanged(_:))

        freeSpaceButton.isBordered = false
        freeSpaceButton.font = Theme.chromeFont
        freeSpaceButton.contentTintColor = .secondaryLabelColor
        freeSpaceButton.alignment = .left
        freeSpaceButton.cell?.lineBreakMode = .byTruncatingTail
        freeSpaceButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        freeSpaceButton.setAccessibilityLabel(String(localized: "Drive Information"))
        freeSpaceButton.target = self
        freeSpaceButton.action = #selector(driveInformationClicked(_:))

        for (button, action) in [(rootButton, #selector(rootClicked(_:))), (parentButton, #selector(parentClicked(_:)))] {
            button.controlSize = .small
            button.font = Theme.chromeFont
            button.bezelStyle = .smallSquare
            button.target = self
            button.action = action
        }

        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.panelBackground
        scrollView.documentView = listView

        statusLabel.font = Theme.chromeFont
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        quickSearchField.font = Theme.chromeFont
        quickSearchField.placeholderString = String(localized: "Quick search")
        quickSearchField.isHidden = true
        quickSearchField.sendsSearchStringImmediately = true

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isDisplayedWhenStopped = false

        let views: [NSView] = [driveBar, loadingIndicator, volumeButton, freeSpaceButton, rootButton, parentButton, tabBar, pathBar, headerView,
                               scrollView, statusLabel, quickSearchField, terminalPane]
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        headerHeight = headerView.heightAnchor.constraint(equalToConstant: headerView.intrinsicContentSize.height)
        quickSearchWidth = quickSearchField.widthAnchor.constraint(equalToConstant: 200)
        tabBarHeight = tabBar.heightAnchor.constraint(equalToConstant: 0)
        driveBarHeight = driveBar.heightAnchor.constraint(equalToConstant: DriveBar.height)
        tabBar.isHidden = true
        terminalHeight = terminalPane.heightAnchor.constraint(equalToConstant: 0)
        // A smaller window takes room from the terminal rather than from the file list.
        terminalHeight.priority = .init(998)
        let listMinimum = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: TerminalPane.minimumListHeight)
        listMinimum.priority = .init(999)
        terminalPane.heightConstraint = terminalHeight
        terminalPane.isHidden = true
        NSLayoutConstraint.activate([
            driveBar.topAnchor.constraint(equalTo: topAnchor),
            driveBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            driveBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            driveBarHeight,

            volumeButton.topAnchor.constraint(equalTo: driveBar.bottomAnchor, constant: 3),
            volumeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            volumeButton.widthAnchor.constraint(lessThanOrEqualToConstant: 180),

            freeSpaceButton.centerYAnchor.constraint(equalTo: volumeButton.centerYAnchor),
            freeSpaceButton.leadingAnchor.constraint(equalTo: volumeButton.trailingAnchor, constant: 6),
            freeSpaceButton.trailingAnchor.constraint(lessThanOrEqualTo: rootButton.leadingAnchor, constant: -6),

            parentButton.centerYAnchor.constraint(equalTo: volumeButton.centerYAnchor),
            parentButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            parentButton.widthAnchor.constraint(equalToConstant: 24),
            rootButton.centerYAnchor.constraint(equalTo: volumeButton.centerYAnchor),
            rootButton.trailingAnchor.constraint(equalTo: parentButton.leadingAnchor, constant: -2),
            rootButton.widthAnchor.constraint(equalToConstant: 24),

            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBarHeight,

            pathBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            pathBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            pathBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            headerView.topAnchor.constraint(equalTo: pathBar.bottomAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerHeight,

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            listMinimum,

            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),

            terminalPane.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminalPane.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminalPane.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminalHeight,

            quickSearchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            quickSearchWidth,
            quickSearchField.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
        ])
        classicConstraints = [
            tabBar.topAnchor.constraint(equalTo: volumeButton.bottomAnchor, constant: 3),
            loadingIndicator.centerYAnchor.constraint(equalTo: volumeButton.centerYAnchor),
            loadingIndicator.trailingAnchor.constraint(equalTo: rootButton.leadingAnchor, constant: -6),
        ]
        spinnerCenter = loadingIndicator.centerYAnchor.constraint(equalTo: pathBar.topAnchor)
        compactConstraints = [
            tabBar.topAnchor.constraint(equalTo: driveBar.bottomAnchor),
            spinnerCenter,
            loadingIndicator.trailingAnchor.constraint(equalTo: pathBar.trailingAnchor, constant: -4),
        ]
        statusRowConstraints = [
            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 3),
            statusLabel.bottomAnchor.constraint(equalTo: terminalPane.topAnchor, constant: -3),
        ]
        collapsedStatusConstraint = scrollView.bottomAnchor.constraint(equalTo: terminalPane.topAnchor)
        pathBar.showsInfoLine = true
        pathBar.onVolumeClick = { [weak self] in self?.showVolumeMenu() }
        pathBar.onDriveInformation = { [weak self] in self?.driveInformationClicked(nil) }
        setCompactHeader(Settings.compactPanelHeader)
    }

    /// The compact header has no volume row: the path bar shows the volume and its
    /// free space, and its parents replace the / and .. buttons.
    func setCompactHeader(_ compact: Bool) {
        for view in [volumeButton, freeSpaceButton, rootButton, parentButton] as [NSView] {
            view.isHidden = compact
        }
        NSLayoutConstraint.deactivate(compact ? classicConstraints : compactConstraints)
        NSLayoutConstraint.activate(compact ? compactConstraints : classicConstraints)
        pathBar.invalidateIntrinsicContentSize()
        pathBar.needsDisplay = true
        updatePathBarVolume()
        applyLook()
    }

    /// The modern look draws the list without a frame and its column titles taller,
    /// and the status line and quick search in the header's detail font.
    private func applyLook() {
        scrollView.borderType = Settings.isModern ? .noBorder : .lineBorder
        let font = Settings.isModern ? Theme.headerDetailFont : Theme.chromeFont
        statusLabel.font = font
        quickSearchField.font = font
        quickSearchWidth.constant = Settings.isModern ? max(200, 16 * font.pointSize) : 200
        if !headerView.isHidden {
            headerHeight.constant = FileListHeaderView.height
        }
        headerView.needsDisplay = true
        spinnerCenter.constant = PathBar.pathLineCenter
        updateStatusRow()
    }

    /// With the counts in the path bar, the status line takes no room unless quick
    /// search needs it.
    private func updateStatusRow() {
        let collapsed = pathBar.hasInfoLine && !isQuickSearching
        NSLayoutConstraint.deactivate(collapsed ? statusRowConstraints : [collapsedStatusConstraint])
        NSLayoutConstraint.activate(collapsed ? [collapsedStatusConstraint] : statusRowConstraints)
        statusLabel.isHidden = collapsed || isQuickSearching
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Full view shows column headers and scrolls vertically; Brief view has
    /// no headers and scrolls horizontally.
    func setViewMode(_ mode: FileListView.ViewMode) {
        headerView.isHidden = mode != .full
        headerHeight.constant = mode == .full ? FileListHeaderView.height : 0
        scrollView.hasVerticalScroller = mode != .brief
        scrollView.hasHorizontalScroller = mode == .brief
        listView.viewMode = mode
    }

    /// Shows the terminal under the status line at its last height, leaving the
    /// file list some room.
    func setTerminalVisible(_ visible: Bool) {
        terminalPane.isHidden = !visible
        terminalPane.isCollapsed = !visible
        let maximum = max(TerminalPane.minimumHeight, bounds.height - TerminalPane.minimumListHeight)
        terminalHeight.constant = visible ? min(TerminalPane.preferredHeight, maximum) : 0
    }

    var isTerminalVisible: Bool { !terminalPane.isHidden }

    func setDriveBarVisible(_ visible: Bool) {
        driveBar.isHidden = !visible
        driveBarHeight.constant = visible ? DriveBar.height : 0
    }

    /// Shows the folder tabs (the bar is hidden when `visible` is false).
    func setTabs(_ titles: [String], icons: [NSImage], identifiers: [UUID], selected: Int, visible: Bool) {
        tabBar.titles = titles
        tabBar.icons = icons
        tabBar.identifiers = identifiers
        tabBar.selectedIndex = selected
        tabBar.isHidden = !visible
        tabBarHeight.constant = visible ? FolderTabBar.height : 0
    }

    /// Updates the header for `directory`: path, current volume and free space.
    func setLoading(_ loading: Bool) {
        pathBar.isLoading = loading
        if loading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
    }

    /// `freeSpace` is computed here when not given (it can be slow on network volumes).
    func show(directory: URL, volumes: [Volume], freeSpace: VolumeSpace? = nil) {
        if volumes != self.volumes || driveBar.drives.isEmpty {
            driveBar.drives = DriveBar.drives(for: volumes)
        }
        self.volumes = volumes
        driveBar.currentPath = directory.path

        volumeButton.removeAllItems()
        volumeButton.addItems(withTitles: volumes.map(\.name))
        if let current = Volume.containing(directory, in: volumes),
           let index = volumes.firstIndex(of: current) {
            volumeButton.selectItem(at: index)
        }
        freeSpaceButton.title = (freeSpace ?? VolumeSpace(for: directory))?.summary(short: Settings.sizeDisplay == .short) ?? ""
        currentVolume = Volume.containing(directory, in: volumes)
    }

    /// The volume of the folder shown, which the compact path bar names.
    private var currentVolume: Volume? {
        didSet { updatePathBarVolume() }
    }

    /// Whether the path bar names the volume (not for a server, whose path is no local one).
    var showsVolume = true {
        didSet { if showsVolume != oldValue { updatePathBarVolume() } }
    }

    private func updatePathBarVolume() {
        let compact = Settings.compactPanelHeader && showsVolume
        pathBar.volume = compact ? currentVolume.map { ($0.name, DriveBar.icon(for: $0.url)) } : nil
        freeSpaceButton.isEnabled = showsVolume && currentVolume != nil && !freeSpaceButton.title.isEmpty
        freeSpaceButton.toolTip = freeSpaceButton.isEnabled ? String(localized: "Drive Information") : nil
        freeSpaceButton.setAccessibilityValue(freeSpaceButton.title)
        window?.invalidateCursorRects(for: freeSpaceButton)
        pathBar.freeSpace = compact && freeSpaceButton.isEnabled ? freeSpaceButton.title : ""
    }

    /// The mounted volumes, the current one checked, as the volume selector lists them.
    func volumeMenu() -> NSMenu {
        let menu = NSMenu()
        for (index, volume) in volumes.enumerated() {
            let item = NSMenuItem(title: volume.name, action: #selector(volumeChosen(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            let icon = DriveBar.icon(for: volume.url).copy() as? NSImage
            icon?.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.keepsImageVisible()
            item.state = volume == currentVolume ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func showVolumeMenu() {
        let rect = pathBar.volumeRect ?? pathBar.bounds
        volumeMenu().popUp(positioning: nil, at: NSPoint(x: rect.minX, y: rect.maxY + 2), in: pathBar)
    }

    @objc private func volumeChosen(_ sender: NSMenuItem) {
        guard volumes.indices.contains(sender.tag) else { return }
        onVolumeSelected?(volumes[sender.tag])
    }

    @objc private func volumeChanged(_ sender: NSPopUpButton) {
        guard volumes.indices.contains(sender.indexOfSelectedItem) else { return }
        onVolumeSelected?(volumes[sender.indexOfSelectedItem])
    }

    @objc private func rootClicked(_ sender: Any?) {
        onGoToRoot?()
    }

    @objc private func driveInformationClicked(_ sender: Any?) {
        guard freeSpaceButton.isEnabled, let currentVolume else { return }
        onDriveInformation?(currentVolume)
    }

    @objc private func parentClicked(_ sender: Any?) {
        onGoToParent?()
    }
}

/// The capacity readout keeps its plain appearance and behaves as a button.
private final class DriveSpaceButton: NSButton {
    override func resetCursorRects() {
        super.resetCursorRects()
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor else { return false }
        performClick(nil)
        return true
    }
}
