import AppKit
import os

@MainActor
protocol FilePanelControllerDelegate: AnyObject {
    func filePanelDidBecomeActive(_ panel: FilePanelController)
    func filePanelSwitchPanel(_ panel: FilePanelController)
    func filePanelDidChangeDirectory(_ panel: FilePanelController)
    func filePanelCursorDidMove(_ panel: FilePanelController)
    func filePanel(_ panel: FilePanelController, interceptKey event: NSEvent) -> Bool
    /// Whether a tab other than `panel`'s active one (in either panel) shows `server`.
    func filePanel(_ panel: FilePanelController, otherTabsShow server: String) -> Bool
    /// A server address typed into the path bar: connect to it, as Connect to Server.
    func filePanel(_ panel: FilePanelController, openAddress address: String)
    /// A drive button's "Open in Other Panel".
    func filePanel(_ panel: FilePanelController, openDriveInOtherPanel url: URL)
    /// A drive button's "Eject": the volume is left in both panels first.
    func filePanel(_ panel: FilePanelController, eject volume: URL)
    /// A tab of the other panel dropped on this one's tab bar: that tab, taken out of
    /// the other panel (or a copy of it, when it is the other panel's only one).
    func filePanel(_ panel: FilePanelController, takeTab id: UUID) -> FilePanelController.Tab?
}

/// Owns one panel: its current directory, listing, sort order and view.
///
/// As a view controller it sits in the responder chain right after its
/// panel view, so `cm_*` commands sent to the focused file list reach it.
final class FilePanelController: NSViewController {
    let panelView = PanelView()
    weak var delegate: FilePanelControllerDelegate?

    var directory: URL
    var entries: [FileItem] = []
    /// The order `entries` are already sorted in (big folders are sorted in the background).
    var entriesOrder: SortOrder?

    /// Set while the panel shows the inside of an archive (read-only).
    var archive: ArchiveLocation?
    private var lastMask = "*.*"
    var watcher: DirectoryWatcher?
    var loadTask: Task<Void, Never>?
    var loadGeneration = 0

    private static let historyLimit = 50
    var backHistory: [HistoryEntry] = []
    var forwardHistory: [HistoryEntry] = []

    var tabs: [Tab]
    var activeTabIndex: Int

    /// Shows the tab bar even for a single tab, so both panels line up
    /// when the other one has tabs.
    var alwaysShowsTabBar = false {
        didSet { if alwaysShowsTabBar != oldValue { updateTabBar() } }
    }

    var sortOrder = SortOrder() {
        didSet {
            panelView.headerView.sortOrder = sortOrder
            if sortOrder.column.needsMetadata && entries.count > 100 && entriesOrder != sortOrder {
                sortInBackground()
            } else {
                refreshList(selecting: listView.currentItem?.name)
            }
        }
    }

    /// Sorting by a metadata column reads every file; for bigger folders that
    /// happens in the background and the list is re-sorted when done.
    private func sortInBackground() {
        let order = sortOrder
        let entries = self.entries
        let generation = loadGeneration
        Task {
            let sorted = await Self.sort(entries, by: order)
            // Dropped if the folder was reloaded or another order chosen meanwhile.
            guard generation == loadGeneration, sortOrder == order else { return }
            self.entries = sorted
            entriesOrder = order
            refreshList(selecting: listView.currentItem?.name)
        }
    }

    @concurrent
    private nonisolated static func sort(_ entries: [FileItem], by order: SortOrder) async -> [FileItem] {
        order.sorted(entries)
    }

    var showsHidden = false {
        didSet { refreshList(selecting: listView.currentItem?.name) }
    }

    /// Ctrl+B: lists all files of the folder and its subfolders, with relative names.
    var isBranchView = false

    /// Find Files → "Feed to Panel": the found files, listed instead of the folder.
    var searchResults: (title: String, urls: [URL])?

    /// A server (SFTP, FTP) shown in the panel.
    struct RemoteLocation {
        let fileSystem: any RemoteFileSystem
        var path: String

        var displayPath: String { fileSystem.displayName + (path.hasPrefix("/") ? path : "/" + path) }

        func path(of name: String) -> String {
            RemotePath.join(path, name)
        }
    }

    var remote: RemoteLocation?

    var searchResultsShown: Bool { searchResults != nil }

    /// Show → Filter: only files matching this mask are listed (folders always are).
    private var filterMask: String? {
        didSet {
            updatePathMask()
            refreshList(selecting: listView.currentItem?.name)
        }
    }

    /// Ctrl+S quick filter: only names containing this text are listed.
    var quickFilter: String? {
        didSet {
            guard quickFilter != oldValue else { return }
            updatePathMask()
            refreshList(selecting: listView.currentItem?.name)
        }
    }

    /// The size display the status line and the free space were written in.
    private var shownSizeDisplay = Settings.sizeDisplay
    /// The column set chosen for this panel (nil: the Default view); folders that
    /// match a set's masks show that set anyway.
    var chosenColumnSet: String? {
        didSet { applyColumnSet() }
    }

    /// cm_ShowOnlySelected: only these names are listed, until another folder is
    /// shown or All Files is chosen.
    var onlyNames: Set<String>? {
        didSet {
            guard onlyNames != oldValue else { return }
            updatePathMask()
            refreshList(selecting: listView.currentItem?.name)
        }
    }

    /// Whether the quick search box currently edits the quick filter.
    private var quickSearchFilters = false

    private func updatePathMask() {
        let mask = quickFilter.map { "*\($0)*" } ?? filterMask ?? "*.*"
        panelView.pathBar.mask = onlyNames == nil ? mask : mask + " " + String(localized: "[selected only]")
    }

    var listView: FileListView { panelView.listView }

    var viewMode: FileListView.ViewMode {
        get { listView.viewMode }
        set { panelView.setViewMode(newValue) }
    }

    var isActive: Bool {
        get { panelView.isActive }
        set { panelView.isActive = newValue }
    }

    /// Creates a panel with a tab for each directory.
    convenience init(tabDirectories: [URL], activeTab: Int = 0) {
        self.init(tabs: tabDirectories.map { Tab(directory: $0, sortOrder: SortOrder()) }, activeTab: activeTab)
    }

    init(tabs: [Tab], activeTab: Int = 0) {
        let tabs = tabs.isEmpty ? [Tab(directory: FileManager.default.homeDirectoryForCurrentUser, sortOrder: SortOrder())] : tabs
        let active = min(max(activeTab, 0), tabs.count - 1)
        directory = tabs[active].directory
        self.tabs = tabs
        activeTabIndex = active
        super.init(nibName: nil, bundle: nil)

        listView.delegate = self
        panelView.headerView.sortOrder = sortOrder
        panelView.headerView.onColumnClicked = { [weak self] column in self?.sort(by: column) }
        panelView.headerView.onChooseColumnSet = { [weak self] name in self?.chooseColumnSet(name) }
        panelView.pathBar.onClick = { [weak self] in self?.focus() }
        panelView.pathBar.editableText = { [weak self] in self?.editablePath ?? "" }
        panelView.pathBar.onCommit = { [weak self] text in self?.go(to: text) }
        panelView.pathBar.onCrumbClick = { [weak self] index in self?.goToPathPart(index) }
        panelView.pathBar.onClearFilters = { [weak self] in
            guard let self else { return }
            onlyNames = nil
            filterMask = nil
            quickFilter = nil
            endQuickSearch(openingItem: false)
        }
        panelView.pathBar.completions = { [weak self] text in await self?.completions(for: text) ?? [] }
        panelView.onGoToRoot = { [weak self] in self?.goToRoot() }
        panelView.onGoToParent = { [weak self] in self?.goToParent() }
        panelView.onVolumeSelected = { [weak self] volume in self?.openDrive(volume.url) }
        panelView.onDriveInformation = { [weak self] volume in
            self?.focus()
            self?.showInfo([volume.url])
        }
        panelView.driveBar.onSelect = { [weak self] url in self?.openDrive(url) }
        panelView.driveBar.menuProvider = { [weak self] url in self?.driveMenu(for: url) }
        panelView.setDriveBarVisible(Settings.showsDriveButtons && !Settings.showsSidebar)
        panelView.tabBar.onSelect = { [weak self] index in self?.selectTab(index) }
        panelView.tabBar.onClose = { [weak self] index in self?.closeTab(index) }
        panelView.tabBar.onContextMenu = { [weak self] index in self?.tabMenu(for: index) }
        panelView.tabBar.onNewTab = { [weak self] in self?.openNewTab(nil) }
        panelView.tabBar.onDropTab = { [weak self] id, index in self?.dropTab(id, at: index) ?? false }
        panelView.quickSearchField.delegate = self
        panelView.terminalPane.onFocus = { [weak self] in
            guard let self else { return }
            terminalWasFocused = true
            delegate?.filePanelDidBecomeActive(self)
        }
        panelView.terminalPane.onReconnect = { [weak self] in self?.openTerminal(focusing: true) }
        panelView.terminalPane.onEndedAtOnce = { [weak self] terminal in
            // An account without a shell (sftp only): the terminal opened by connecting hides again.
            guard let self, terminal.opensQuietly, terminal === panelView.terminalPane.terminal else { return }
            hideTerminal()
        }

        load(directory)
        updateTabBar()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = panelView
    }

    /// Marked entries, or the entry under the cursor when nothing is marked.
    var selectedItems: [FileItem] {
        let marked = listView.items.filter { listView.marked.contains($0.name) }
        if !marked.isEmpty { return marked }
        if let current = listView.currentItem, !current.isParent { return [current] }
        return []
    }

    /// Font or other appearance settings changed.
    func settingsDidChange() {
        applyColumnSet()
        panelView.setDriveBarVisible(Settings.showsDriveButtons && !Settings.showsSidebar)
        if Settings.sizeDisplay != shownSizeDisplay {
            shownSizeDisplay = Settings.sizeDisplay
            updateStatus()
            panelView.freeSpaceButton.title = VolumeSpace(for: directory)?.summary(short: shownSizeDisplay == .short) ?? ""
        }
        panelView.setCompactHeader(Settings.compactPanelHeader)
        updateStatus()
        // Setting the font clears the terminal's selection: only when it changed.
        for terminal in terminals where terminal.font != TerminalPane.font {
            terminal.font = TerminalPane.font
        }
        panelView.terminalPane.applyLook()
        listView.settingsDidChange()
        refreshList(selecting: listView.currentItem?.name, fallback: listView.cursor)
        panelView.pathBar.needsDisplay = true
        panelView.headerView.needsDisplay = true
        updateTabBar()
    }

    func focus() {
        panelView.window?.makeFirstResponder(listView)
    }

    // MARK: - Navigation

    /// Reads `directory` and shows it, placing the cursor on `name` if given.
    /// The folder is read in the background (a slow network volume must not
    /// freeze the window); only the latest request is shown. Esc cancels it.
    func load(_ directory: URL, selecting name: String? = nil, recordingHistory: Bool = true,
              then completion: (() -> Void)? = nil) {
        if remote != nil {
            leaveServer { [weak self] in
                self?.load(directory, selecting: name, recordingHistory: recordingHistory, then: completion)
            }
            return
        }
        let directory = directory.standardizedFileURL
        leaveLockedTab(for: directory)
        if directory != self.directory {
            isBranchView = false
        }
        let branch = isBranchView
        let includingHidden = showsHidden
        let sortOrder = sortOrder
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        loadTask = Task {
            let showsIndicator = Task {
                try? await Task.sleep(for: .milliseconds(200))
                if !Task.isCancelled && generation == loadGeneration { panelView.setLoading(true) }
            }
            let result = await Self.read(directory, branch: branch, includingHidden: includingHidden,
                                         sortOrder: sortOrder)
            showsIndicator.cancel()
            guard generation == loadGeneration else { return }
            panelView.setLoading(false)
            switch result {
            case .success(let listing):
                show(listing, of: directory, selecting: name, recordingHistory: recordingHistory)
                completion?()
            case .failure(let error):
                if !(error is CancellationError) {
                    present(error, reading: directory)
                }
            }
        }
    }

    /// Esc while a folder is being read: stops reading and keeps the old listing.
    override func cancelOperation(_ sender: Any?) {
        guard loadTask != nil else {
            quickFilter = nil
            return
        }
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        panelView.setLoading(false)
    }

    /// What a background read produces.
    private struct Listing: Sendable {
        let entries: [FileItem]
        let sortOrder: SortOrder
        let volumes: [Volume]
        let freeSpace: VolumeSpace?
    }

    @concurrent
    private nonisolated static func read(_ directory: URL, branch: Bool, includingHidden: Bool,
                                         sortOrder: SortOrder) async -> Result<Listing, Error> {
        do {
            var entries = try DirectoryListing.items(in: directory)
            if branch {
                entries = DirectoryListing.branchItems(in: directory, includingHidden: includingHidden)
            }
            try Task.checkCancellation()
            entries = sortOrder.sorted(entries)
            try Task.checkCancellation()
            return .success(Listing(entries: entries, sortOrder: sortOrder, volumes: Volume.mounted(),
                                    freeSpace: VolumeSpace(for: directory)))
        } catch {
            return .failure(error)
        }
    }

    private func show(_ listing: Listing, of directory: URL, selecting name: String?, recordingHistory: Bool) {
        loadTask = nil
        let entries = listing.entries
        if searchResults != nil {
            searchResults = nil
            panelView.pathBar.showsMask = true
            listView.setMarked([])
        }
        clearRemote()
        if archive != nil {
            archive = nil
            listView.setMarked([])
        }
        let isNewDirectory = directory != self.directory
        if isNewDirectory {
            listView.folderSizes = [:]
            quickFilter = nil
            onlyNames = nil
            if recordingHistory {
                backHistory.append(HistoryEntry(directory: self.directory, selectedName: listView.currentItem?.name))
                backHistory = Array(backHistory.suffix(Self.historyLimit))
                forwardHistory.removeAll()
            }
            listView.setMarked([])
        }
        self.directory = directory
        self.entries = entries
        entriesOrder = listing.sortOrder
        if isNewDirectory || watcher == nil {
            watcher = DirectoryWatcher(url: directory) { [weak self] in self?.reread() }
        }
        panelView.show(directory: directory, volumes: listing.volumes, freeSpace: listing.freeSpace)
        updatePathBar()
        applyColumnSet()
        refreshList(selecting: name, fallback: isNewDirectory ? 0 : listView.cursor)
        tabs[activeTabIndex].directory = directory
        updateTabBar()
        delegate?.filePanelDidChangeDirectory(self)
    }

    // MARK: - Servers

    /// Connects to a server and shows its first folder in this panel.
    func openRemote(_ fileSystem: any RemoteFileSystem, leftServer: Bool = false, onConnected: (() -> Void)? = nil) {
        leaveLockedTab(for: nil)
        if remote != nil {
            // Another server in this tab: the terminal of the one shown ends first.
            leaveServer { [weak self] in self?.openRemote(fileSystem, leftServer: true, onConnected: onConnected) }
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        panelView.setLoading(true)
        loadTask = Task {
            do {
                let path = try await fileSystem.connect()
                guard generation == loadGeneration else { return }
                listView.setMarked([])
                remote = RemoteLocation(fileSystem: fileSystem, path: path)
                onConnected?()
                loadTask = nil
                loadRemote(path, selecting: nil)
                updateTabBar()
                if fileSystem is SFTPFileSystem, Self.opensTerminal {
                    openTerminal(focusing: false)
                }
            } catch {
                panelView.setLoading(false)
                loadTask = nil
                // The server left for this one is gone: the tab shows its local folder again.
                if leftServer, generation == loadGeneration { load(directory) }
                if !(error is CancellationError) {
                    Prompt.error(String(localized: "Cannot connect to \u{201C}\(fileSystem.displayName)\u{201D}"), error,
                                 in: view.window)
                }
            }
        }
    }

    /// Lists a folder on the server in the background.
    func loadRemote(_ path: String, selecting name: String?) {
        guard let fileSystem = remote?.fileSystem else { return }
        loadGeneration += 1
        let generation = loadGeneration
        loadTask?.cancel()
        loadTask = Task {
            let indicator = Task {
                try? await Task.sleep(for: .milliseconds(200))
                if !Task.isCancelled && generation == loadGeneration { panelView.setLoading(true) }
            }
            defer {
                indicator.cancel()
                if generation == loadGeneration {
                    panelView.setLoading(false)
                    loadTask = nil
                }
            }
            do {
                let items = try await fileSystem.list(path)
                guard generation == loadGeneration, let current = remote, current.fileSystem === fileSystem else { return }
                let isNewFolder = path != current.path
                remote?.path = path
                if isNewFolder {
                    listView.setMarked([])
                    updateTabBar()
                }
                entries = items
                entriesOrder = nil
                panelView.pathBar.showsMask = false
                updatePathBar()
                refreshList(selecting: name, fallback: isNewFolder ? 0 : listView.cursor)
                delegate?.filePanelDidChangeDirectory(self)
            } catch {
                if !(error is CancellationError) {
                    presentUnreadableFolder((path as NSString).lastPathComponent,
                                            icon: NSWorkspace.shared.icon(for: .folder), because: error)
                }
            }
        }
    }

    /// Runs a change on the server, then lists the folder again.
    private func runOnServer(selecting name: String?, _ change: @escaping @Sendable () async throws -> Void) {
        guard let remote else { return }
        Task {
            do {
                try await change()
            } catch {
                Prompt.error(String(localized: "The server reported an error"), error, in: view.window)
            }
            loadRemote(remote.path, selecting: name)
        }
    }

    /// Net → Disconnect: leaves the server and shows the local folder again.
    @objc(cm_FtpDisconnect:)
    func ftpDisconnect(_ sender: Any?) {
        guard let fileSystem = remote?.fileSystem else {
            NSSound.beep()
            return
        }
        leaveServer { [weak self] in
            guard let self else { return }
            // The connection is shared by every tab of the server (in both panels): it
            // closes when no other tab shows the server.
            if delegate?.filePanel(self, otherTabsShow: fileSystem.displayName) != true {
                fileSystem.disconnect()
            }
            load(directory)
        }
    }

    /// A drive button (or the volume list) on a server tab opens the drive in a new
    /// tab: the server keeps its tab.
    func openDrive(_ url: URL) {
        if remote != nil {
            openTab(url)
        } else {
            load(url)
        }
    }

    /// Leaves the server shown in this tab: its terminal ends, after asking when a
    /// program still runs there. Without a server `proceed` runs at once.
    func leaveServer(then proceed: @escaping () -> Void) {
        guard remote != nil else {
            proceed()
            return
        }
        let fileSystem = remote?.fileSystem
        let tab = activeTabIndex
        confirmClosing([panelView.terminalPane.terminal].compactMap { $0 }) { [weak self] in
            // Nothing is left if the tab or its server changed meanwhile.
            guard let self, activeTabIndex == tab, remote?.fileSystem === fileSystem else { return }
            closeTerminal()
            clearRemote()
            proceed()
        }
    }

    /// The tab shows no server any more. The server's entries are dropped at once:
    /// until the local folder is listed they would stand for local paths.
    func clearRemote() {
        guard remote != nil else { return }
        remote = nil
        entries = []
        entriesOrder = nil
        panelView.pathBar.showsMask = true
        listView.setMarked([])
        refreshList(selecting: nil)
        updateTabBar()
    }

    /// Whether a tab of this panel shows the server named `name` ("sftp://user@host").
    func showsServer(_ name: String, excludingActiveTab: Bool) -> Bool {
        tabs.indices.contains { index in
            index == activeTabIndex
                ? !excludingActiveTab && remote?.fileSystem.displayName == name
                : tabs[index].remote?.fileSystem.displayName == name
        }
    }

    /// The local folder is going away (a volume was ejected): the panel goes to `url`,
    /// a server tab only changes the folder it goes back to.
    func leaveLocalFolder(for url: URL) {
        if remote != nil {
            directory = url
        } else {
            load(url)
        }
    }

    // MARK: - Server terminal

    private static let terminalShownKey = "ServerTerminalShown"

    /// Whether connecting to a server shows its terminal: the last choice made with ⌃`.
    private static var opensTerminal: Bool {
        get { AppDefaults.store.object(forKey: terminalShownKey) as? Bool ?? true }
        set { AppDefaults.store.set(newValue, forKey: terminalShownKey) }
    }

    /// The terminal had the focus: its commands may have changed the folder,
    /// which is read again when the files get the focus back.
    private var terminalWasFocused = false

    /// A session is being started; the focus goes to it when ready if asked for.
    var terminalStart: (fileSystem: SFTPFileSystem, focusing: Bool)?

    /// The terminals of the panel's tabs (the active tab's is the one shown).
    var terminals: [ShellTerminalView] {
        terminals(ofTabs: Array(tabs.indices))
    }

    /// Shows the terminal, starting a shell in the panel's folder unless one is running.
    func openTerminal(focusing: Bool) {
        guard let remote, let fileSystem = remote.fileSystem as? SFTPFileSystem else {
            NSSound.beep()
            return
        }
        let pane = panelView.terminalPane
        panelView.setTerminalVisible(true)
        if pane.isRunning {
            if focusing { pane.focus() }
            return
        }
        if let start = terminalStart, start.fileSystem === fileSystem {
            terminalStart?.focusing = start.focusing || focusing
            return
        }
        terminalStart = (fileSystem, focusing)
        Task {
            do {
                let command = try await fileSystem.shellCommand(in: remote.path)
                guard let start = terminalStart, start.fileSystem === fileSystem else { return }
                terminalStart = nil
                if let ended = pane.terminal { pane.close(ended) }
                let terminal = pane.start(command, over: fileSystem)
                terminal.opensQuietly = !start.focusing
                if start.focusing { pane.focus() }
            } catch {
                guard terminalStart?.fileSystem === fileSystem else { return }
                terminalStart = nil
                hideTerminal()
                Prompt.error(String(localized: "Cannot connect to \u{201C}\(fileSystem.displayName)\u{201D}"), error,
                             in: view.window)
            }
        }
    }

    /// Hides the terminal of the tab (its shell keeps running); the files get the focus.
    private func hideTerminal() {
        if panelView.terminalPane.hasFocus { focus() }
        panelView.setTerminalVisible(false)
    }

    /// Ends the terminal of the tab and hides it.
    private func closeTerminal() {
        terminalStart = nil
        hideTerminal()
        if let terminal = panelView.terminalPane.terminal {
            panelView.terminalPane.close(terminal)
        }
    }

    /// Runs `proceed` once `terminals` may be closed: when programs still run in
    /// them, the user is asked first.
    func confirmClosing(_ terminals: [ShellTerminalView], proceed: @escaping () -> Void) {
        guard terminals.contains(where: \.isRunning) else {
            proceed()
            return
        }
        Task {
            let programs = await Self.runningPrograms(in: terminals)
            guard !programs.isEmpty, let window = view.window else {
                proceed()
                return
            }
            Prompt.confirm(Self.runningTitle(programs),
                           message: programs.count == 1
                               ? String(localized: "Closing the terminal stops it on the server.")
                               : String(localized: "Closing the terminals stops them on the server."),
                           okTitle: String(localized: "Close Terminal"), in: window, completion: proceed)
        }
    }

    /// The programs running in `terminals` instead of their shells, asked of the servers at once.
    static func runningPrograms(in terminals: [ShellTerminalView]) async -> [String] {
        let checks = terminals.filter(\.isRunning).map { terminal in
            Task { await terminal.runningProgram() }
        }
        var programs: [String] = []
        for check in checks {
            if let program = await check.value { programs.append(program) }
        }
        return programs
    }

    /// "“apt” is still running in the terminal".
    /// The quotes are the language's own (“btop” in English, «btop» in Russian).
    static func runningTitle(_ programs: [String]) -> String {
        if programs.count == 1 {
            return programs[0] == ShellTerminalView.fullScreenProgram
                ? String(localized: "A full-screen program is still running in the terminal")
                : String(localized: "\u{201C}\(programs[0])\u{201D} is still running in the terminal")
        }
        let names = programs.map { name in
            name == ShellTerminalView.fullScreenProgram
                ? name : String(localized: "program.quoted", defaultValue: "\u{201C}\(name)\u{201D}")
        }
        return String(localized: "Programs are still running in terminals: \(names.joined(separator: ", "))")
    }

    /// ⌃`: shows the terminal of the server and moves the focus there; from the
    /// terminal, hides it and goes back to the files (the shell keeps running).
    @objc(cm_ServerTerminal:)
    func serverTerminal(_ sender: Any?) {
        if panelView.terminalPane.hasFocus {
            hideTerminal()
            Self.opensTerminal = false
        } else {
            Self.opensTerminal = true
            openTerminal(focusing: true)
        }
    }

    /// ⌃⌥`: goes to the panel's folder in the terminal. The `cd` is typed only at the
    /// shell's prompt, which is cleared first (⌃E ⌃U); a program running there would
    /// take it as input. The leading space keeps it out of the shell's history.
    @objc(cm_TerminalChangeDir:)
    func terminalChangeDir(_ sender: Any?) {
        let pane = panelView.terminalPane
        guard let remote, let terminal = pane.terminal, terminal.isRunning,
              !remote.path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else {
            NSSound.beep()
            return
        }
        panelView.setTerminalVisible(true)
        Task {
            if let program = await terminal.runningProgram() {
                Prompt.info(Self.runningTitle([program]),
                            message: String(localized: "The folder can be changed when it finishes."), in: view.window)
                return
            }
            guard terminal === pane.terminal, terminal.isRunning else { return }
            terminal.send(txt: "\u{05}\u{15} cd " + UserCommand.quoted(remote.path) + "\r")
        }
    }

    // MARK: - The path bar

    /// What a click on the path bar gives to edit: the folder, the server folder
    /// (sftp://…/folder), or the folder inside the archive.
    /// Where a part of the path bar leads.
    private enum PathTarget {
        case folder(URL)
        /// A folder of the archive shown, or of the archive `levelsUp` archives out of it.
        case archiveFolder(levelsUp: Int, folder: String)
        case serverFolder(String)
    }

    /// The parts of the path bar's text, from the root to the folder shown.
    private var pathParts: [(range: NSRange, name: String, target: PathTarget)] = []

    /// Shows where the panel is in the path bar, with the parts a click goes to.
    func updatePathBar() {
        var text = ""
        var parts: [(range: NSRange, name: String, target: PathTarget)] = []
        func add(_ piece: String, _ target: PathTarget? = nil) {
            if let target {
                parts.append((NSRange(location: text.utf16.count, length: piece.utf16.count), piece, target))
            }
            text += piece
        }
        func addSeparator() {
            if !text.hasSuffix("/") { add("/") }
        }
        func addFolders(of url: URL) {
            var folder = URL(filePath: "/")
            add("/", .folder(folder))
            for name in url.pathComponents.dropFirst() {
                folder.append(path: name, directoryHint: .isDirectory)
                addSeparator()
                add(name, .folder(folder))
            }
        }
        func addArchive(_ location: ArchiveLocation, levelsUp: Int) {
            if let outer = location.outer {
                addArchive(outer.location, levelsUp: levelsUp + 1)
                addSeparator()
                add(outer.name, .archiveFolder(levelsUp: levelsUp, folder: ""))
            } else {
                addFolders(of: location.url.deletingLastPathComponent())
                addSeparator()
                add(location.url.lastPathComponent, .archiveFolder(levelsUp: levelsUp, folder: ""))
            }
            var folder = ""
            for name in location.folder.split(separator: "/").map(String.init) {
                folder = folder.isEmpty ? name : folder + "/" + name
                addSeparator()
                add(name, .archiveFolder(levelsUp: levelsUp, folder: folder))
            }
        }

        let shown: String
        if let searchResults {
            shown = searchResults.title
        } else if let remote {
            shown = remote.displayPath
            add(remote.fileSystem.displayName, .serverFolder("/"))
            var folder = ""
            for name in remote.path.split(separator: "/").map(String.init) {
                folder = folder.isEmpty && !remote.path.hasPrefix("/") ? name : folder + "/" + name
                addSeparator()
                add(name, .serverFolder(folder))
            }
            if remote.path.hasSuffix("/") { addSeparator() }
        } else if let archive {
            shown = archive.displayPath
            addArchive(archive, levelsUp: 0)
        } else {
            shown = directory.path
            addFolders(of: directory)
        }
        // Only a path taken apart exactly has parts to click; any other is edited on a click.
        pathParts = text == shown ? parts : []
        panelView.pathBar.path = shown
        panelView.pathBar.place = searchResults != nil ? .searchResults : remote != nil ? .server : archive != nil ? .archive : .folder
        panelView.pathBar.crumbs = pathParts.dropLast().map { PathBar.Crumb(range: $0.range, name: $0.name) }
        panelView.showsVolume = remote == nil
    }

    /// A click on a part of the path bar: goes there, the cursor on the folder it came from.
    private func goToPathPart(_ index: Int) {
        guard pathParts.indices.contains(index + 1) else { return }
        let cameFrom = pathParts[index + 1].name
        switch pathParts[index].target {
        case .folder(let url):
            load(url, selecting: cameFrom)
        case .serverFolder(let path):
            loadRemote(path, selecting: cameFrom)
        case .archiveFolder(let levelsUp, let folder):
            for _ in 0..<levelsUp {
                // Back to the outer archive; the temporary copy of this one goes, as with [..].
                guard let archive, let outer = archive.outer else { return }
                try? FileManager.default.removeItem(at: archive.url.deletingLastPathComponent())
                self.archive = outer.location
            }
            archive?.folder = folder
            showArchiveFolder(selecting: cameFrom)
        }
    }

    private var editablePath: String {
        if let remote { return remote.displayPath }
        if let archive { return archive.displayPath }
        return directory.path
    }

    /// Goes to the text typed into the path bar: a folder on this Mac (a file is shown
    /// selected in its folder, an archive opens), a folder on the server or in the
    /// archive shown, or another server's address.
    func go(to typed: String) {
        focus()
        let text = typed.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if let remote {
            let server = remote.fileSystem.displayName
            if Self.isOnServer(text, server) {
                let path = String(text.dropFirst(server.count))
                loadRemote(path.isEmpty ? "/" : path, selecting: nil)
                return
            }
            if text.hasPrefix("/") {
                loadRemote(text, selecting: nil)
                return
            }
        }
        if text.contains("://") {
            delegate?.filePanel(self, openAddress: text)
            return
        }
        if let archive, text == archive.rootPath || text.hasPrefix(archive.rootPath + "/") {
            let inner = String(text.dropFirst(archive.rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard inner.isEmpty || archive.entries.contains(where: { $0.path == inner || $0.path.hasPrefix(inner + "/") }) else {
                NSSound.beep()
                return
            }
            self.archive?.folder = inner
            showArchiveFolder(selecting: nil)
            return
        }
        let url = URL(filePath: (text as NSString).expandingTildeInPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            Prompt.info(String(localized: "\u{201C}\(text)\u{201D} was not found"), message: "", in: view.window)
            return
        }
        if isDirectory.boolValue {
            load(url)
        } else if ArchiveReader.isArchive(url.lastPathComponent) {
            openArchive(url)
        } else {
            load(url.deletingLastPathComponent(), selecting: url.lastPathComponent)
        }
    }

    /// "sftp://me@host/x" is on "sftp://me@host"; "sftp://me@host2/x" is not.
    private static func isOnServer(_ text: String, _ server: String) -> Bool {
        text == server || text.hasPrefix(server + "/")
    }

    /// Tab in the path bar: the entries of the folder typed whose names start with what
    /// follows the last "/" (full texts, folders ending in "/").
    private func completions(for text: String) async -> [String] {
        guard let slash = text.lastIndex(of: "/") else { return [] }
        let folderText = String(text[...slash])
        let start = String(text[text.index(after: slash)...]).lowercased()
        let includesHidden = showsHidden || start.hasPrefix(".")
        func matching(_ names: [(name: String, isFolder: Bool)]) -> [String] {
            names.filter { $0.name.lowercased().hasPrefix(start) && (includesHidden || !$0.name.hasPrefix(".")) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { folderText + $0.name + ($0.isFolder ? "/" : "") }
        }
        if let remote, Self.isOnServer(text, remote.fileSystem.displayName) || text.hasPrefix("/") {
            let server = remote.fileSystem.displayName
            let folder = Self.isOnServer(text, server) ? String(folderText.dropFirst(server.count)) : folderText
            guard let items = try? await remote.fileSystem.list(folder.isEmpty ? "/" : folder) else { return [] }
            return matching(items.filter { !$0.isParent }.map { ($0.name, $0.isDirectory) })
        }
        if let archive, text.hasPrefix(archive.rootPath + "/") {
            let inner = String(folderText.dropFirst(archive.rootPath.count + 1))
            var children: [String: Bool] = [:]
            for entry in archive.entries where entry.path.hasPrefix(inner) && entry.path.count > inner.count {
                let rest = entry.path.dropFirst(inner.count)
                let name = String(rest.prefix { $0 != "/" })
                children[name] = (children[name] ?? false) || rest.contains("/") || entry.isDirectory
            }
            return matching(children.map { ($0.key, $0.value) })
        }
        guard !text.contains("://") else { return [] }
        let folder = URL(filePath: (folderText as NSString).expandingTildeInPath)
        let names = await Task.detached {
            ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
                .map { ($0.lastPathComponent, (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true) }
        }.value
        return matching(names.map { (name: $0.0, isFolder: $0.1) })
    }

    // MARK: - Search results

    /// Shows found files (named relative to `root` where possible) as the panel's
    /// listing; everything works on the real files, [..] returns to `root`.
    func showSearchResults(_ urls: [URL], root: URL, title: String, selecting name: String? = nil) {
        leaveLockedTab(for: nil)
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let items = urls.compactMap { url -> FileItem? in
            let path = url.standardizedFileURL.path
            let shown = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
            return DirectoryListing.item(atPath: path, named: shown)
        }
        if archive != nil {
            archive = nil
        }
        if searchResults == nil || directory != root.standardizedFileURL {
            listView.setMarked([])
        }
        directory = root.standardizedFileURL
        watcher = nil
        searchResults = (title, items.map(\.url))
        entries = items
        entriesOrder = nil
        panelView.show(directory: directory, volumes: Volume.mounted())
        panelView.pathBar.showsMask = false
        updatePathBar()
        refreshList(selecting: name, fallback: 0)
        delegate?.filePanelDidChangeDirectory(self)
    }

    /// Reloads the current directory keeping cursor and marks, or moves up
    /// to the nearest existing folder if it has been removed.
    func reread() {
        if let remote {
            loadRemote(remote.path, selecting: listView.currentItem?.name)
            return
        }
        if let archive {
            reopenArchive(archive)
            return
        }
        if let searchResults {
            showSearchResults(searchResults.urls, root: directory, title: searchResults.title,
                              selecting: listView.currentItem?.name)
            return
        }
        var directory = self.directory
        while !FileManager.default.fileExists(atPath: directory.path) && directory.path != "/" {
            directory = directory.deletingLastPathComponent()
        }
        load(directory, selecting: listView.currentItem?.name)
    }

    /// Mounted volumes changed: refresh the volume list, leave a vanished volume.
    /// A volume was renamed: its mount point moved, and a folder shown on it moves
    /// along. Whether it did.
    func volumeWasRenamed(from old: URL, to new: URL) -> Bool {
        let path = directory.path, oldPath = old.path
        guard remote == nil, path == oldPath || path.hasPrefix(oldPath.hasSuffix("/") ? oldPath : oldPath + "/")
        else { return false }
        let rest = String(path.dropFirst(oldPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let moved = rest.isEmpty ? new : new.appending(path: rest)
        if let archive, archive.outer == nil {
            let inside = archive.url.path.dropFirst(oldPath.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let url = new.appending(path: inside)
            let folder = archive.folder
            load(moved, selecting: url.lastPathComponent, recordingHistory: false) { [weak self] in
                self?.openArchive(url, folder: folder)
            }
        } else {
            load(moved, selecting: listView.currentItem?.name, recordingHistory: false)
        }
        return true
    }

    func volumesDidChange() {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            leaveLocalFolder(for: FileManager.default.homeDirectoryForCurrentUser)
            return
        }
        panelView.show(directory: directory, volumes: Volume.mounted())
        updatePathBar()
    }

    func goToParent() {
        if let remote {
            if remote.path == "/" {
                load(directory)
            } else {
                loadRemote(RemotePath.parent(of: remote.path), selecting: (remote.path as NSString).lastPathComponent)
            }
            return
        }
        if archive != nil {
            archiveGoUp()
            return
        }
        if searchResults != nil {
            load(directory)
            return
        }
        guard directory.path != "/" else { return }
        load(directory.deletingLastPathComponent(), selecting: directory.lastPathComponent)
    }

    func goToRoot() {
        if remote != nil {
            loadRemote("/", selecting: nil)
            return
        }
        if archive != nil {
            archive?.folder = ""
            showArchiveFolder(selecting: nil)
            return
        }
        let root = Volume.containing(directory, in: Volume.mounted())?.url ?? URL(filePath: "/")
        load(root)
    }

    func sort(by column: SortColumn) {
        if sortOrder.column == column, !sortOrder.isUnsorted {
            sortOrder.ascending.toggle()
        } else {
            sortOrder = SortOrder(column: column, ascending: !column.startsDescending)
        }
    }

    func refreshList(selecting name: String?, fallback: Int = 0) {
        if entriesOrder != sortOrder {
            // Metadata sorts of big folders happen in the background; until then the
            // list keeps its previous order.
            if sortOrder.column.needsMetadata && entries.count > 100 {
                sortInBackground()
            } else {
                entries = sortOrder.sorted(entries)
                entriesOrder = sortOrder
            }
        }
        var items = showsHidden ? entries : entries.filter { !$0.isHidden }
        // The ignore list hides local entries only (a server's and an archive's stay).
        if Settings.usesIgnoreList, remote == nil, archive == nil {
            let list = Settings.ignoreList
            if !list.isEmpty {
                items = items.filter { !Settings.ignores(name: $0.name, path: $0.url.path, in: list) }
            }
        }
        let unfilteredCount = items.count
        if let filterMask {
            items = items.filter { $0.isFolder || FileMask.matches($0.name, filterMask) }
        }
        if let quickFilter {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(quickFilter) }
        }
        if let onlyNames {
            items = items.filter { onlyNames.contains($0.name) }
        }
        var rules: [String] = []
        if let quickFilter { rules.append(String(localized: "Text: \(quickFilter)")) }
        if let filterMask { rules.append(String(localized: "Mask: \(filterMask)")) }
        if onlyNames != nil { rules.append(Command.showOnlySelected.title) }
        panelView.pathBar.filterCriteria = rules.joined(separator: " · ")
        panelView.pathBar.filterCount = String(localized: "\(items.count) of \(unfilteredCount)")
        panelView.pathBar.filterSummary = rules.isEmpty ? nil :
            panelView.pathBar.filterCriteria + " · " + panelView.pathBar.filterCount
        if archive != nil || searchResults != nil || remote != nil || directory.path != "/" {
            items.insert(.parent(of: directory), at: 0)
        }
        let cursor = name.flatMap { name in items.firstIndex { $0.name == name } } ?? fallback
        listView.reload(items: items, cursor: cursor)
        updateStatus()
    }

    /// "12 files, 3 folders · 1,2 MB" or "2 of 15 selected · 35 KB of 1,2 MB", as the
    /// Finder words it; or "0 k / 1 234 k in 0 / 12 file(s), 0 / 3 dir(s)", as Total
    /// Commander does (Settings).
    func updateStatus() {
        let entries = listView.items.filter { !$0.isParent }
        let marked = listView.marked
        let files = entries.filter { !$0.isFolder }
        let markedFiles = files.filter { marked.contains($0.name) }
        let folders = entries.filter(\.isFolder)
        let markedFolderCount = folders.count { marked.contains($0.name) }
        // Calculated folder sizes count as well, as in Total Commander.
        let sizes = listView.folderSizes
        let markedFolderBytes = folders.filter { marked.contains($0.name) }.reduce(Int64(0)) { $0 + (sizes[$1.name] ?? 0) }
        let folderBytes = folders.reduce(Int64(0)) { $0 + (sizes[$1.name] ?? 0) }

        let markedBytes = markedFiles.reduce(markedFolderBytes) { $0 + $1.size }
        let totalBytes = files.reduce(folderBytes) { $0 + $1.size }
        defer { panelView.pathBar.status = panelView.statusLabel.stringValue }
        if Settings.plainStatusLine {
            panelView.statusLabel.stringValue = Self.plainStatus(
                files: files.count, folders: folders.count, marked: markedFiles.count + markedFolderCount,
                markedBytes: markedBytes, totalBytes: totalBytes)
        } else if Settings.sizeDisplay == .short {
            let markedSize = Settings.formattedSize(markedBytes)
            let totalSize = Settings.formattedSize(totalBytes)
            panelView.statusLabel.stringValue = String(localized:
                "\(markedSize) / \(totalSize) in \(markedFiles.count) / \(files.count) file(s), \(markedFolderCount) / \(folders.count) dir(s)")
        } else {
            let markedSize = ((markedBytes + 1023) / 1024).formatted(.number.grouping(.automatic))
            let totalSize = ((totalBytes + 1023) / 1024).formatted(.number.grouping(.automatic))
            panelView.statusLabel.stringValue = String(localized:
                "\(markedSize) k / \(totalSize) k in \(markedFiles.count) / \(files.count) file(s), \(markedFolderCount) / \(folders.count) dir(s)")
        }
    }

    private static func plainStatus(files: Int, folders: Int, marked: Int, markedBytes: Int64, totalBytes: Int64) -> String {
        func size(_ bytes: Int64) -> String {
            Settings.sizeDisplay == .short ? Settings.shortSize(bytes) : String(localized: "\(bytes.formatted()) B")
        }
        if marked > 0 {
            let count = String(localized: "\(marked) of \(files + folders) selected")
            return count + " · " + String(localized: "\(size(markedBytes)) of \(size(totalBytes))")
        }
        guard files > 0 || folders > 0 else { return String(localized: "Empty folder") }
        var counts: [String] = []
        if files > 0 { counts.append(String(localized: "\(files) files")) }
        if folders > 0 { counts.append(String(localized: "\(folders) folders")) }
        let summary = counts.joined(separator: ", ")
        return files > 0 || totalBytes > 0 ? summary + " · " + size(totalBytes) : summary
    }

    private func askForMask(marking: Bool) {
        guard let window = view.window else { return }
        Prompt.text(marking ? String(localized: "Select files") : String(localized: "Unselect files"),
                    message: String(localized: "File mask, e.g. *.txt;*.md"),
                    initial: lastMask, in: window) { [weak self] mask in
            guard let self else { return }
            lastMask = mask
            let names = listView.items
                .filter { !$0.isParent && !$0.isFolder && FileMask.matches($0.name, mask) }
                .map(\.name)
            listView.setMarked(marking ? listView.marked.union(names) : listView.marked.subtracting(names))
        }
    }

    func open(_ item: FileItem, enteringPackages: Bool) {
        if let remote {
            if item.isParent {
                goToParent()
            } else if item.isDirectory || item.isSymlink {
                loadRemote(remote.path(of: item.name), selecting: nil)
            } else if enteringPackages {
                // Ctrl+PgDn never starts a file; a server's archives are not browsed.
                NSSound.beep()
            } else {
                Task {
                    if let url = await downloadToTemporaryFolder(item) {
                        openFile(url)
                    }
                }
            }
        } else if archive != nil {
            openInArchive(item, asArchive: enteringPackages)
        } else if item.isParent {
            goToParent()
        } else if !item.isDirectory && (ArchiveReader.isArchive(item.name) || enteringPackages) {
            // Ctrl+PgDn tries any file as an archive (a .docx, a .jar, a zip named
            // otherwise) and never starts it; a file that is none stays as it is.
            openArchive(item.url, quietly: !ArchiveReader.isArchive(item.name))
        } else if item.isFolder || (enteringPackages && item.isDirectory) {
            load(item.url)
        } else {
            openFile(item.url)
        }
    }

    /// Enter on a file: its associated program, or the one macOS opens it with.
    func openFile(_ url: URL) {
        if !FileAssociations.perform(.open, on: url, window: view.window) {
            NSWorkspace.shared.open(url)
        }
    }

    private func present(_ error: Error, reading directory: URL) {
        let exists = FileManager.default.fileExists(atPath: directory.path)
        presentUnreadableFolder(FileManager.default.displayName(atPath: directory.path),
                                icon: exists ? FileIcons.icon(for: [directory]) : NSWorkspace.shared.icon(for: .folder),
                                because: error)
    }

    /// "The folder “x” can’t be opened." with its icon, as the Finder says it, and why:
    /// in plain words when permission is missing or the folder is gone.
    private func presentUnreadableFolder(_ name: String, icon: NSImage, because error: Error) {
        let reason = switch (error as? POSIXError)?.code {
        case .EACCES?, .EPERM?: String(localized: "You don’t have permission to see its contents.")
        case .ENOENT?: String(localized: "The folder no longer exists.")
        default: error.localizedDescription
        }
        Prompt.info(String(localized: "The folder \u{201C}\(name)\u{201D} can’t be opened."), message: reason, icon: icon,
                    in: view.window)
    }
}

// MARK: - Commands

extension FilePanelController: NSMenuItemValidation {
    @objc(cm_RereadSource:)
    func rereadSource(_ sender: Any?) {
        reread()
    }

    @objc(cm_GoToParent:)
    func goToParentCommand(_ sender: Any?) {
        goToParent()
    }

    @objc(cm_GoToRoot:)
    func goToRootCommand(_ sender: Any?) {
        goToRoot()
    }

    /// Brief view: names only, in columns.
    @objc(cm_SrcShort:)
    func srcShort(_ sender: Any?) {
        viewMode = .brief
        delegate?.filePanelDidChangeDirectory(self)
    }

    /// Thumbnails view: Quick Look previews in a grid.
    @objc(cm_SrcThumbs:)
    func srcThumbs(_ sender: Any?) {
        viewMode = .thumbnails
        delegate?.filePanelDidChangeDirectory(self)
    }

    /// Full view: one row per entry with size, date and attributes.
    @objc(cm_SrcLong:)
    func srcLong(_ sender: Any?) {
        viewMode = .full
        delegate?.filePanelDidChangeDirectory(self)
    }

    @objc(cm_OpenNewTab:)
    func openNewTab(_ sender: Any?) {
        openTab(directory)
    }

    /// Ctrl+Up: opens the folder under the cursor in a new tab. A server stays in its
    /// own tab: its folders are not opened in others.
    @objc(cm_OpenDirInNewTab:)
    func openDirInNewTab(_ sender: Any?) {
        guard remote == nil else {
            NSSound.beep()
            return
        }
        guard let item = listView.currentItem, item.isFolder else {
            openTab(directory)
            return
        }
        openTab(item.isParent ? directory.deletingLastPathComponent() : item.url)
    }

    @objc(cm_CloseCurrentTab:)
    func closeCurrentTab(_ sender: Any?) {
        closeTab(activeTabIndex)
    }

    @objc(cm_SwitchToNextTab:)
    func switchToNextTab(_ sender: Any?) {
        selectTab((activeTabIndex + 1) % tabs.count)
    }

    @objc(cm_SwitchToPreviousTab:)
    func switchToPreviousTab(_ sender: Any?) {
        selectTab((activeTabIndex + tabs.count - 1) % tabs.count)
    }

    /// Ctrl+D: pops up the favourite folders, with add/remove for the current one.
    @objc(cm_DirectoryHotlist:)
    func directoryHotlist(_ sender: Any?) {
        let menu = NSMenu()
        for path in Hotlist.directories {
            let item = NSMenuItem(title: (path as NSString).abbreviatingWithTildeInPath,
                                  action: #selector(historyItemChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = URL(filePath: path)
            menu.addItem(item)
        }
        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        let current = directory.path
        let isListed = Hotlist.directories.contains(current)
        let name = tabs[activeTabIndex].title
        let toggle = NSMenuItem(title: isListed ? String(localized: "Remove \u{201C}\(name)\u{201D}") : String(localized: "Add \u{201C}\(name)\u{201D}"),
                                action: #selector(toggleHotlistEntry(_:)), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let configure = NSMenuItem(title: String(localized: "Configure…"), action: #selector(configureHotlist(_:)),
                                   keyEquivalent: "")
        configure.target = self
        menu.addItem(configure)
        let bar = panelView.pathBar
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bar.bounds.maxY), in: bar)
    }

    @objc private func configureHotlist(_ sender: Any?) {
        HotlistWindowController.shared.showWindow(sender)
    }

    @objc private func toggleHotlistEntry(_ sender: NSMenuItem) {
        Hotlist.toggle(directory.path)
    }

    @objc(cm_GoToPrevDir:)
    func goToPrevDir(_ sender: Any?) {
        goBack()
    }

    @objc(cm_GoToNextDir:)
    func goToNextDir(_ sender: Any?) {
        goForward()
    }

    /// Alt+Down: pops up the recently visited folders under the path bar.
    @objc(cm_DirectoryHistory:)
    func directoryHistory(_ sender: Any?) {
        let menu = NSMenu()
        for url in recentDirectories {
            let item = NSMenuItem(title: url.path, action: #selector(historyItemChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            menu.addItem(item)
        }
        guard !menu.items.isEmpty else {
            NSSound.beep()
            return
        }
        let bar = panelView.pathBar
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bar.bounds.maxY), in: bar)
    }

    @objc private func historyItemChosen(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            load(url)
        }
    }

    /// Ctrl+M: renames the selected files with the Multi-Rename Tool.
    @objc(cm_MultiRenameFiles:)
    func multiRenameFiles(_ sender: Any?) {
        guard !refuseInsideArchive() else { return }
        let items = selectedItems
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        // In branch view and search results names carry their folder ("sub/file.txt"):
        // the tool works on the file names themselves.
        let plain = items.map { item in
            FileItem(name: item.url.lastPathComponent, url: item.url, isDirectory: item.isDirectory,
                     isPackage: item.isPackage, isSymlink: item.isSymlink, isHidden: item.isHidden,
                     size: item.size, modified: item.modified, mode: item.mode)
        }
        MultiRenameWindowController.show(for: plain) { [weak self] in self?.reread() }
    }

    // MARK: - Attributes

    /// ⌘I: changes permissions, hidden/locked flags and the date of the selection.
    /// Only what the user changes in the dialog is applied.
    @objc(cm_SetAttrib:)
    func setAttrib(_ sender: Any?) {
        guard !refuseInsideArchive(), let window = view.window else { return }
        let items = selectedItems
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let infos: [stat] = items.map { item in
            var info = stat()
            lstat(item.url.path, &info)
            return info
        }
        func initialState(_ test: (stat) -> Bool) -> NSControl.StateValue {
            let values = Set(infos.map(test))
            return values.count > 1 ? .mixed : (values.first == true ? .on : .off)
        }
        func checkbox(_ title: String, _ state: NSControl.StateValue) -> NSButton {
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.allowsMixedState = true
            box.state = state
            return box
        }

        let bits = AttributeChange.permissionBits
        let permissionBoxes = bits.map { bit in checkbox("", initialState { $0.st_mode & bit != 0 }) }
        let hiddenBox = checkbox(String(localized: "Hidden"), initialState { $0.st_flags & UInt32(UF_HIDDEN) != 0 })
        let lockedBox = checkbox(String(localized: "Locked"), initialState { $0.st_flags & UInt32(UF_IMMUTABLE) != 0 })
        let dateBox = NSButton(checkboxWithTitle: String(localized: "Modification date:"), target: nil, action: nil)
        let datePicker = NSDatePicker()
        datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
        datePicker.dateValue = items[0].modified
        let subfoldersBox = NSButton(checkboxWithTitle: String(localized: "Include subfolders"), target: nil, action: nil)
        subfoldersBox.isEnabled = items.contains(where: \.isFolder)
        let initialStates = permissionBoxes.map(\.state) + [hiddenBox.state, lockedBox.state]

        let columnTitles = [String(localized: "Read"), String(localized: "Write"), String(localized: "Execute")]
        var rows: [[NSView]] = [[NSGridCell.emptyContentView] + columnTitles.map { NSTextField(labelWithString: $0) }]
        let rowTitles = [String(localized: "Owner"), String(localized: "Group"), String(localized: "Others")]
        for (row, title) in rowTitles.enumerated() {
            let boxes: [NSView] = Array(permissionBoxes[(row * 3)..<(row * 3 + 3)])
            rows.append([NSTextField(labelWithString: title)] + boxes)
        }
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .leading
        for column in 1..<4 { grid.column(at: column).xPlacement = .center }
        grid.columnSpacing = 16
        grid.rowSpacing = 6
        // The date on a line of its own, as wide as its text with the seconds.
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let dateWidth = (formatter.string(from: datePicker.dateValue) as NSString)
            .size(withAttributes: [.font: datePicker.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)]).width
        datePicker.widthAnchor.constraint(greaterThanOrEqualToConstant: ceil(dateWidth) + 44).isActive = true
        let dateLine = NSStackView(views: [datePicker])
        dateLine.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 0)
        let flags = NSStackView(views: [hiddenBox, lockedBox])
        flags.spacing = 16
        let stack = NSStackView(views: [grid, flags, dateBox, dateLine, subfoldersBox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(16, after: grid)
        stack.setCustomSpacing(4, after: dateBox)
        stack.frame.size = stack.fittingSize

        let alert = NSAlert()
        alert.icon = FileIcons.icon(for: items.map(\.url))
        alert.messageText = items.count == 1
            ? String(localized: "Change attributes of \u{201C}\(items[0].name)\u{201D}")
            : String(localized: "Change attributes of \(items.count) items")
        alert.accessoryView = stack
        alert.addButton(withTitle: String(localized: "Apply"))
        alert.addCancelButton()
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn else { return }
            var change = AttributeChange()
            for (index, box) in permissionBoxes.enumerated() where box.state != initialStates[index] && box.state != .mixed {
                change.permissions[bits[index]] = box.state == .on
            }
            if hiddenBox.state != initialStates[9] && hiddenBox.state != .mixed { change.hidden = hiddenBox.state == .on }
            if lockedBox.state != initialStates[10] && lockedBox.state != .mixed { change.locked = lockedBox.state == .on }
            if dateBox.state == .on { change.modified = datePicker.dateValue }
            change.includesSubfolders = subfoldersBox.state == .on
            let finalChange = change
            let urls = items.map(\.url)
            Task {
                let controller = TransferController(title: String(localized: "Changing attributes"),
                                                    failureTitle: String(localized: "Cannot change attributes"),
                                                    window: window)
                _ = await controller.run(source: urls[0].path, target: "") { progress, _ in
                    try await finalChange.apply(to: urls, progress: progress)
                    return urls
                }
                self.reread()
            }
        }
    }

    // MARK: - Checksums

    /// Creates a checksum file (MD5, SHA-1, SHA-256 or SHA-512) for the selection.
    @objc(cm_CRCcreate:)
    func crcCreate(_ sender: Any?) {
        guard !refuseInsideArchive(), let window = view.window else { return }
        let items = selectedItems
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let algorithms = ChecksumAlgorithm.allCases
        Prompt.choice(String(localized: "Create Checksum File"),
                      message: String(localized: "Algorithm for the checksum file:"),
                      options: algorithms.map(\.title), selected: 2,
                      okTitle: String(localized: "Create"), in: window) { [weak self] index in
            guard let self else { return }
            let algorithm = algorithms[index]
            let baseName = items.count == 1 ? items[0].name : (tabs[activeTabIndex].title)
            let output = directory.appending(path: baseName + "." + algorithm.rawValue)
            let directory = directory
            Task {
                let controller = TransferController(title: String(localized: "Calculating checksums"),
                                                    failureTitle: String(localized: "Cannot create checksums"),
                                                    window: window)
                _ = await controller.run(source: directory.path, target: output.path) { progress, _ in
                    try await Checksums.create(for: items.map(\.url), relativeTo: directory, algorithm: algorithm,
                                               output: output, progress: progress)
                    return [output]
                }
                self.load(self.directory, selecting: output.lastPathComponent)
            }
        }
    }

    /// Verifies the checksum file under the cursor and reports the result.
    @objc(cm_CRCcheck:)
    func crcCheck(_ sender: Any?) {
        guard !refuseInsideArchive(), let window = view.window,
              let item = listView.currentItem, !item.isFolder,
              Checksums.fileExtensions.contains(item.fileExtension.lowercased()) else {
            NSSound.beep()
            return
        }
        let result = ChecksumVerification()
        Task {
            let controller = TransferController(title: String(localized: "Verifying checksums"),
                                                failureTitle: String(localized: "Cannot verify checksums"),
                                                window: window)
            let done = await controller.run(source: item.url.path, target: directory.path) { progress, _ in
                try await Checksums.verify(item.url, into: result, progress: progress)
                return [item.url]
            }
            guard !done.isEmpty else { return }
            let state = result.snapshot
            let problems = state.failed.map { String(localized: "Mismatch: \($0)") }
                + state.missing.map { String(localized: "Missing: \($0)") }
            let summary = String(localized:
                "\(state.passed) OK, \(state.failed.count) mismatched, \(state.missing.count) missing")
            Prompt.info(problems.isEmpty ? String(localized: "All checksums match") : summary,
                        message: problems.isEmpty ? summary : problems.prefix(30).joined(separator: "\n"),
                        in: window)
        }
    }

    // MARK: - Selection by extension, filter

    /// Ctrl+B: toggles the branch view (all files in all subfolders).
    @objc(cm_BranchView:)
    func branchView(_ sender: Any?) {
        guard !refuseInsideArchive() else { return }
        isBranchView.toggle()
        listView.setMarked([])
        load(directory, selecting: listView.currentItem?.name)
    }

    /// Alt+Num+: marks all files with the extension of the file under the cursor.
    @objc(cm_SelectCurrentExtension:)
    func selectCurrentExtension(_ sender: Any?) {
        markCurrentExtension(true)
    }

    /// Alt+Num−: unmarks all files with the extension of the file under the cursor.
    @objc(cm_UnselectCurrentExtension:)
    func unselectCurrentExtension(_ sender: Any?) {
        markCurrentExtension(false)
    }

    private func markCurrentExtension(_ mark: Bool) {
        guard let current = listView.currentItem, !current.isParent, !current.isFolder else {
            NSSound.beep()
            return
        }
        let ext = current.fileExtension.lowercased()
        let names = listView.items.filter { !$0.isFolder && $0.fileExtension.lowercased() == ext }.map(\.name)
        listView.setMarked(mark ? listView.marked.union(names) : listView.marked.subtracting(names))
    }

    /// Show → Filter: lists only files matching a mask, e.g. "*.jpg;*.png".
    @objc(cm_SrcUserSpec:)
    func srcUserSpec(_ sender: Any?) {
        guard let window = view.window else { return }
        Prompt.text(String(localized: "Filter"), message: String(localized: "Show only files matching (e.g. *.jpg;*.png):"),
                    initial: filterMask ?? "*.*", okTitle: String(localized: "Filter"), in: window) { [weak self] mask in
            let mask = mask.trimmingCharacters(in: .whitespaces)
            self?.filterMask = mask.isEmpty || mask == "*" || mask == "*.*" ? nil : mask
        }
    }

    // MARK: - Column sets

    /// The Full view columns for the folder shown (a server's: the chosen set).
    func applyColumnSet() {
        let set = ColumnSet.set(for: remote == nil ? directory : nil, chosen: chosenColumnSet)
        listView.columns = set.columns
        panelView.headerView.columns = set.columns
        panelView.headerView.columnSet = set.name
    }

    private func chooseColumnSet(_ name: String) {
        chosenColumnSet = name.isEmpty ? nil : name
    }

    /// Show → Columns: a set chosen in the menu (its name in the item).
    @objc func chooseColumnSetFromMenu(_ sender: Any?) {
        chooseColumnSet((sender as? NSMenuItem)?.representedObject as? String ?? "")
    }

    /// The set the panel shows ("" the Default view), for the menu's check mark.
    var columnSetShown: String { panelView.headerView.columnSet }

    /// Show → Unsorted (Ctrl+F7): the entries in the order the folder is read in;
    /// the folder is read again, since the order shown is a sorted one.
    @objc(cm_SrcUnsorted:)
    func srcUnsorted(_ sender: Any?) {
        guard !sortOrder.isUnsorted else { return }
        sortOrder = SortOrder(column: .name, ascending: true, isUnsorted: true)
        if archive != nil, let location = archive {
            reopenArchive(location, selecting: listView.currentItem?.name, force: true)
        } else {
            reread()
        }
    }

    /// Show → All Files: removes the filter (and Only Selected Files).
    @objc(cm_SrcAllFiles:)
    func srcAllFiles(_ sender: Any?) {
        onlyNames = nil
        filterMask = nil
    }

    /// Show → Only Selected Files: the others are hidden (again: all are shown).
    @objc(cm_ShowOnlySelected:)
    func showOnlySelected(_ sender: Any?) {
        if onlyNames != nil {
            onlyNames = nil
            return
        }
        let names = selectedItems.map(\.name)
        guard !names.isEmpty else {
            NSSound.beep()
            return
        }
        onlyNames = Set(names)
    }

    // MARK: - Context menu

    /// Context menu of applications: a button on the bar that starts them.
    @objc private func addToButtonBar(_ sender: Any?) {
        let apps = selectedItems.map(\.url).filter(ToolbarApps.isApplication)
        (view.window?.windowController as? MainWindowController)?.addApplications(apps)
    }

    private func contextMenu(for items: [FileItem]) -> NSMenu {
        let menu = NSMenu()
        @discardableResult
        func add(_ title: String, _ action: Selector, target: AnyObject? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = target
            menu.addItem(item)
            return item
        }
        if let first = items.first {
            add(String(localized: "Open"), #selector(openSelection(_:)), target: self)
            if items.count == 1, !first.isFolder, archive == nil {
                let openWith = NSMenuItem(title: String(localized: "Open With"), action: nil, keyEquivalent: "")
                openWith.submenu = openWithMenu(for: first.url)
                menu.addItem(openWith)
            }
            add(Command.list.title, Command.list.selector)
            if archive == nil {
                add(String(localized: "Show in Finder"), #selector(revealInFinder(_:)), target: self)
            }
            if archive == nil, remote == nil, items.contains(where: { ToolbarApps.isApplication($0.url) }) {
                add(String(localized: "Add to Button Bar"), #selector(addToButtonBar(_:)), target: self)
            }
            menu.addItem(.separator())
            if archive == nil {
                add(String(localized: "edit.copy", defaultValue: "Copy"), #selector(copy(_:)))
                add(String(localized: "Cut"), #selector(cut(_:)))
            }
        }
        add(String(localized: "Paste"), #selector(paste(_:)))
        if !items.isEmpty {
            add(Command.copyFullNamesToClip.title, Command.copyFullNamesToClip.selector)
            menu.addItem(.separator())
            add(Command.renameOnly.title, Command.renameOnly.selector)
            // Holding Shift turns Delete into Delete Permanently.
            add(Command.delete.title, Command.delete.selector).keyEquivalentModifierMask = []
            let permanently = add(Command.deletePermanently.title, Command.deletePermanently.selector)
            permanently.keyEquivalentModifierMask = .shift
            permanently.isAlternate = true
            if archive == nil {
                menu.addItem(.separator())
                add(Command.packFiles.title, Command.packFiles.selector)
                if items.contains(where: { !$0.isDirectory && ArchiveReader.isArchive($0.name) }) {
                    add(Command.unpackFiles.title, Command.unpackFiles.selector)
                }
            }
        }
        // The files' Get Info windows, or the folder's on [..] and empty space.
        if archive == nil, remote == nil {
            menu.addItem(.separator())
            add(Command.properties.title, Command.properties.selector)
        }
        // As in the Finder: Share and the files' tags. AppKit adds Services (Quick Actions
        // among them) below, as the app sends files to them (see AppDelegate).
        if !items.isEmpty, archive == nil, remote == nil {
            menu.addItem(.separator())
            menu.addItem(NSSharingServicePicker(items: items.map(\.url)).standardShareMenuItem)
            menu.addItem(tagsMenuItem(for: items))
        }
        return menu
    }

    /// What a tag item does: the tag, and the files it is added to or taken from.
    private final class TagChange {
        let name: String
        let urls: [URL]

        init(name: String, urls: [URL]) {
            self.name = name
            self.urls = urls
        }
    }

    /// The Finder's tags: its seven colors under the Finder's names, then the files'
    /// other tags; checked when all the files have one, with a dash when some do.
    private func tagsMenuItem(for items: [FileItem]) -> NSMenuItem {
        let urls = items.map(\.url)
        let tagsOfFiles = urls.map(FinderTags.tags(of:))
        let colorNames = FinderTags.colorNames()
        let standard = FinderTags.colors.compactMap { color in colorNames[color].map { ($0, color) } }
        var others: [String: Int] = [:]
        for (name, color) in tagsOfFiles.joined() where !standard.contains(where: { $0.0 == name }) {
            others[name] = color
        }
        let otherTags = others.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }.map { ($0.key, $0.value) }
        let menu = NSMenu()
        for (name, color) in standard + otherTags {
            if name == otherTags.first?.0 { menu.addItem(.separator()) }
            let item = NSMenuItem(title: name, action: #selector(toggleTag(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = TagChange(name: name, urls: urls)
            let count = tagsOfFiles.filter { $0.contains { $0.name == name } }.count
            item.state = count == urls.count ? .on : (count > 0 ? .mixed : .off)
            if color > 0, color < NSWorkspace.shared.fileLabelColors.count {
                let fill = NSWorkspace.shared.fileLabelColors[color]
                item.image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
                    fill.setFill()
                    NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                    return true
                }
                item.keepsImageVisible()
            }
            menu.addItem(item)
        }
        let item = NSMenuItem(title: String(localized: "Tags"), action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// A tag that all the files have is taken from them; otherwise it is added to all.
    @objc private func toggleTag(_ sender: NSMenuItem) {
        guard let change = sender.representedObject as? TagChange else { return }
        let adding = sender.state != .on
        for url in change.urls {
            var tags = FinderTags.tags(of: url).map(\.name)
            if adding {
                if !tags.contains(change.name) { tags.append(change.name) }
            } else {
                tags.removeAll { $0 == change.name }
            }
            do {
                try FinderTags.setTags(tags, of: url)
            } catch {
                Prompt.error(String(localized: "Cannot change the tags of \u{201C}\(url.lastPathComponent)\u{201D}"), error,
                             in: view.window)
                break
            }
        }
        MetadataCache.shared.forget(change.urls, column: .tags)
        // Read again: folders are drawn in their tags' color, read with the listing.
        reread()
    }

    // MARK: - Drive buttons

    /// A drive button's context menu, as the Finder's for a volume (the sidebar's for a
    /// folder: without ejecting and renaming).
    func driveMenu(for url: URL, isVolume: Bool = true) -> NSMenu {
        let menu = NSMenu()
        @discardableResult
        func add(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = url
            menu.addItem(item)
            return item
        }
        let isHome = url.path == FileManager.default.homeDirectoryForCurrentUser.path
        let values = try? url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeSupportsRenamingKey])
        let name = values?.volumeLocalizedName ?? url.lastPathComponent
        add(String(localized: "Open"), #selector(openDriveItem(_:)))
        add(String(localized: "Open in New Tab"), #selector(openDriveInNewTab(_:)))
        add(String(localized: "Open in Other Panel"), #selector(openDriveInOtherPanel(_:)))
        add(String(localized: "Show in Finder"), #selector(showDriveInFinder(_:)))
        if isVolume, !isHome, Volume.isEjectable(url) {
            menu.addItem(.separator())
            add(String(localized: "Eject \u{201C}\(name)\u{201D}"), #selector(ejectDrive(_:)))
        }
        menu.addItem(.separator())
        add(Command.properties.title, #selector(showDriveInfo(_:)))
        if isVolume, !isHome, values?.volumeSupportsRenaming == true {
            add(String(localized: "Rename \u{201C}\(name)\u{201D}…"), #selector(renameDrive(_:)))
        }
        add(Command.copyFullNamesToClip.title, #selector(copyDrivePath(_:)))
        return menu
    }

    @objc private func openDriveItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        focus()
        openDrive(url)
    }

    @objc private func openDriveInNewTab(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        focus()
        openTab(url)
    }

    @objc private func openDriveInOtherPanel(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        delegate?.filePanel(self, openDriveInOtherPanel: url)
    }

    @objc private func showDriveInFinder(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    @objc private func ejectDrive(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        delegate?.filePanel(self, eject: url)
    }

    @objc private func showDriveInfo(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        showInfo([url])
    }

    @objc private func copyDrivePath(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        copyToClipboard([url.path])
    }

    /// Renames a volume (its mount point follows; the panels go along, see
    /// `volumeWasRenamed`).
    @objc private func renameDrive(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL, let window = view.window else { return }
        let name = (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? url.lastPathComponent
        Prompt.text(String(localized: "Rename \u{201C}\(name)\u{201D}"), message: String(localized: "New name:"),
                    initial: name, okTitle: String(localized: "Rename"), in: window) { newName in
            guard !newName.isEmpty, newName != name else { return }
            var values = URLResourceValues()
            values.volumeName = newName
            var volume = url
            do {
                try volume.setResourceValues(values)
            } catch {
                Prompt.error(String(localized: "Cannot rename \u{201C}\(name)\u{201D}"), error, in: window)
            }
        }
    }

    private func openWithMenu(for url: URL) -> NSMenu {
        let menu = NSMenu()
        let defaultApplication = NSWorkspace.shared.urlForApplication(toOpen: url)
        var applications = NSWorkspace.shared.urlsForApplications(toOpen: url)
        if let defaultApplication {
            applications.removeAll { $0 == defaultApplication }
            applications.insert(defaultApplication, at: 0)
        }
        for application in applications.prefix(25) {
            var title = FileManager.default.displayName(atPath: application.path)
            if title.hasSuffix(".app") {
                title = (title as NSString).deletingPathExtension
            }
            if application == defaultApplication {
                title = String(localized: "\(title) (default)")
            }
            let item = NSMenuItem(title: title, action: #selector(openWithApplication(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = application
            let icon = NSWorkspace.shared.icon(forFile: application.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            item.keepsImageVisible()
            menu.addItem(item)
            if application == defaultApplication && applications.count > 1 {
                menu.addItem(.separator())
            }
        }
        return menu
    }

    @objc private func openSelection(_ sender: Any?) {
        fileList(listView, openItemAt: listView.cursor)
    }

    @objc private func openWithApplication(_ sender: NSMenuItem) {
        guard let application = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(selectedItems.map(\.url), withApplicationAt: application,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func revealInFinder(_ sender: Any?) {
        NSWorkspace.shared.activateFileViewerSelecting(selectedItems.map(\.url))
    }

    /// Alt+Enter: the Finder's Get Info windows of the marked files, the file under the
    /// cursor, or the folder shown (through the Finder's "Show Info" service).
    @objc(cm_Properties:)
    func properties(_ sender: Any?) {
        guard archive == nil, remote == nil else {
            NSSound.beep()
            return
        }
        showInfo(selectedItems.isEmpty ? [directory] : selectedItems.map(\.url))
    }

    private func showInfo(_ urls: [URL]) {
        #if DEBUG
        if DebugAutomation.recordInformationRequest(urls) { return }
        #endif
        let filenames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ru.themmag.OriCmd.ShowInfo"))
        pasteboard.declareTypes([filenames], owner: nil)
        pasteboard.setPropertyList(urls.map(\.path), forType: filenames)
        if !NSPerformService("Finder/Show Info", pasteboard) {
            NSSound.beep()
        }
    }

    /// Alt+Shift+Enter: calculates the sizes of all folders in the panel.
    @objc(cm_CountDirContent:)
    func countDirContent(_ sender: Any?) {
        calculateSizes(of: listView.items.filter { $0.isFolder && !$0.isParent })
    }

    /// Calculates folder sizes in the background and shows them as they arrive.
    private func calculateSizes(of folders: [FileItem]) {
        guard archive == nil, remote == nil else { return }
        let directory = directory
        for folder in folders {
            let url = folder.url
            Task {
                let size = await Self.folderSize(url)
                guard self.directory == directory else { return }
                listView.folderSizes[folder.name] = size
                updateStatus()
            }
        }
    }

    @concurrent
    private nonisolated static func folderSize(_ url: URL) async -> Int64 {
        TransferEngine.totalSize(of: url)
    }

    /// Shift+F4: asks for a file name, creates the file if needed and edits it.
    @objc(cm_EditNewFile:)
    func editNewFile(_ sender: Any?) {
        guard !refuseInsideArchive(), let window = view.window else { return }
        let initial = listView.currentItem.flatMap { $0.isFolder ? nil : $0.name } ?? "new.txt"
        Prompt.text(String(localized: "Edit new file"), message: String(localized: "File name:"),
                    initial: initial, okTitle: String(localized: "Edit"), in: window) { [weak self] name in
            guard let self, !name.isEmpty, !name.contains("/") else { return }
            let url = directory.appending(path: name)
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                    Prompt.error(String(localized: "Cannot create \u{201C}\(name)\u{201D}"),
                                 CocoaError(.fileWriteUnknown), in: window)
                    return
                }
            }
            load(directory, selecting: name)
            openInEditor(url)
        }
    }

    private func openInEditor(_ url: URL) {
        if FileAssociations.perform(.edit, on: url, window: view.window) {
            return
        }
        if let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) {
            NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Shift+F5: copies the entry under the cursor within the same folder, under a new name.
    @objc(cm_CopySamepanel:)
    func copySamePanel(_ sender: Any?) {
        guard !refuseInsideArchive(), let item = listView.currentItem, !item.isParent,
              let window = view.window else {
            NSSound.beep()
            return
        }
        let selection = NSRange(location: 0, length: (item.isFolder ? item.name : item.baseName).utf16.count)
        Prompt.text(String(localized: "copy.title", defaultValue: "Copy"),
                    message: String(localized: "Copy \u{201C}\(item.name)\u{201D} as:"),
                    initial: item.name, selection: selection,
                    okTitle: String(localized: "copy.button", defaultValue: "Copy"), in: window) { [weak self] name in
            guard let self, !name.isEmpty, name != item.name, !name.contains("/") else { return }
            var job = TransferJob(kind: .copy, sources: [item.url], destination: directory, newName: name)
            job.options.skipsDSStore = Settings.copySkipsDSStore
            Task {
                _ = await TransferController.run(job, in: window)
                self.load(self.directory, selecting: name)
            }
        }
    }

    /// F3: opens the file under the cursor in the Lister window (or its associated viewer).
    @objc(cm_List:)
    func list(_ sender: Any?) {
        guard let item = listView.currentItem, !item.isParent, !item.isFolder else {
            NSSound.beep()
            return
        }
        if archive != nil || remote != nil {
            let title = remote.map { $0.displayPath + "/" + item.name }
                ?? archive.map { $0.displayPath + "/" + item.name }
            Task {
                let url = remote != nil ? await downloadToTemporaryFolder(item) : await extractToTemporaryFolder(item)
                if let url, !FileAssociations.perform(.view, on: url, window: view.window) {
                    ListerWindowController.show(url, title: title)
                }
            }
            return
        }
        if FileAssociations.perform(.view, on: item.url, window: view.window) {
            return
        }
        let files = listView.items.filter { !$0.isParent && !$0.isFolder }.map(\.url)
        ListerWindowController.show(item.url, siblings: files)
    }

    /// F4: opens the file under the cursor in its associated editor or the default text editor.
    @objc(cm_Edit:)
    func edit(_ sender: Any?) {
        guard !refuseInsideArchive() else { return }
        guard let item = listView.currentItem, !item.isParent, !item.isFolder else {
            NSSound.beep()
            return
        }
        openInEditor(item.url)
    }

    /// F7: asks for a name (prefilled with the entry under the cursor, as TC does).
    @objc(cm_MkDir:)
    func mkDir(_ sender: Any?) {
        guard remote != nil || !refuseReadOnlyArchive() else { return }
        guard let window = view.window else { return }
        let initial = listView.currentItem.flatMap { $0.isParent ? nil : $0.name } ?? ""
        Prompt.text(String(localized: "New folder"), message: String(localized: "Folder name (use / for nested folders):"),
                    initial: initial, okTitle: String(localized: "Create"), in: window) { [weak self] name in
            guard let self, !name.isEmpty else { return }
            let topLevel = name.split(separator: "/").first.map(String.init) ?? name
            if let remote {
                runOnServer(selecting: topLevel) { try await remote.fileSystem.makeDirectory(remote.path(of: name)) }
                return
            }
            if let archive {
                applyArchiveEdit(.makeFolder(archive.path(of: name)), selecting: topLevel)
                return
            }
            do {
                _ = try FileOperations.createDirectory(named: name, in: directory)
                load(directory, selecting: topLevel)
            } catch {
                Prompt.error(String(localized: "Cannot create folder \u{201C}\(name)\u{201D}"), error, in: view.window)
            }
        }
    }

    /// F8 / Del / ⌘⌫: moves the selection to the Trash after confirmation.
    @objc(cm_Delete:)
    func delete(_ sender: Any?) {
        guard !refuseReadOnlyArchive() else { return }
        confirmDelete(permanently: false)
    }

    /// ⇧F8 / ⇧Del: deletes the selection permanently after confirmation.
    @objc(cm_DeletePermanently:)
    func deletePermanently(_ sender: Any?) {
        guard !refuseReadOnlyArchive() else { return }
        confirmDelete(permanently: true)
    }

    /// ⇧F6: renames the entry under the cursor in place.
    @objc(cm_RenameOnly:)
    func renameOnly(_ sender: Any?) {
        if listView.isRenaming {
            listView.selectNextPartOfName()
            return
        }
        guard !refuseReadOnlyArchive() else { return }
        guard let item = listView.currentItem, !item.isParent else {
            NSSound.beep()
            return
        }
        focus()
        listView.beginRenaming()
    }

    private func confirmDelete(permanently: Bool) {
        let items = selectedItems
        guard !items.isEmpty, let window = view.window else {
            NSSound.beep()
            return
        }
        let what = items.count == 1
            ? String(localized: "\u{201C}\(items[0].name)\u{201D}")
            : String(localized: "\(items.count) items")
        // The names of several under the question, before what it says.
        func message(_ text: String = "") -> String {
            [items.count > 1 ? Prompt.names(items.map(\.name)) : "", text].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        let icon = remote == nil && archive == nil ? FileIcons.icon(for: items.map(\.url)) : nil
        if let remote {
            Prompt.confirm(String(localized: "Delete \(what) from the server?"),
                           message: message(String(localized: "This cannot be undone.")),
                           okTitle: String(localized: "Delete"), destructive: true, in: window) { [weak self] in
                self?.runOnServer(selecting: nil) { try await remote.fileSystem.delete(items, in: remote.path) }
            }
        } else if let archive {
            Prompt.confirm(String(localized: "Delete \(what) from the archive?"),
                           message: message(String(localized: "This cannot be undone.")),
                           okTitle: String(localized: "Delete"), destructive: true, in: window) { [weak self] in
                self?.applyArchiveEdit(.delete(items.map { archive.path(of: $0.name) }))
            }
        } else if permanently {
            Prompt.confirm(String(localized: "Delete \(what) immediately?"),
                           message: message(String(localized: "Nothing goes to the Trash: this cannot be undone.")),
                           okTitle: String(localized: "Delete"), destructive: true, icon: icon, in: window) { [weak self] in
                self?.performDelete(items.map(\.url), permanently: true)
            }
        } else if !Settings.confirmsMoveToTrash {
            performDelete(items.map(\.url), permanently: false)
        } else {
            Prompt.confirm(String(localized: "Move \(what) to the Trash?"), message: message(),
                           okTitle: String(localized: "Move to Trash"), icon: icon, in: window) { [weak self] in
                self?.performDelete(items.map(\.url), permanently: false)
            }
        }
    }

    private func performDelete(_ urls: [URL], permanently: Bool) {
        Task {
            do {
                if permanently {
                    try await FileOperations.deletePermanently(urls)
                } else {
                    try await FileOperations.moveToTrash(urls)
                }
            } catch {
                Prompt.error(String(localized: "Cannot delete"), error, in: view.window)
            }
            // The cursor stays at the same row, i.e. on the next remaining entry.
            reread()
        }
    }

    @objc(cm_SrcByName:)
    func sortByName(_ sender: Any?) {
        sort(by: .name)
    }

    @objc(cm_SrcByExt:)
    func sortByExt(_ sender: Any?) {
        sort(by: .ext)
    }

    @objc(cm_SrcByDateTime:)
    func sortByDateTime(_ sender: Any?) {
        sort(by: .date)
    }

    @objc(cm_SrcBySize:)
    func sortBySize(_ sender: Any?) {
        sort(by: .size)
    }

    @objc(cm_SrcNegOrder:)
    func reverseOrder(_ sender: Any?) {
        sortOrder.ascending.toggle()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(chooseColumnSetFromMenu(_:)):
            menuItem.state = (menuItem.representedObject as? String) == columnSetShown ? .on : .off
            return true
        case #selector(copy(_:)), #selector(cut(_:)):
            return archive == nil && !selectedItems.isEmpty
        case #selector(paste(_:)), #selector(moveItemsHere(_:)):
            return !clipboardFiles.isEmpty || PromisedFiles.areOffered(on: AppDefaults.pasteboard)
        default:
            break
        }
        guard let action = menuItem.action, let command = Command(selector: action) else { return true }
        let sortColumn: SortColumn? = switch command {
        case .sortByName: .name
        case .sortByExt: .ext
        case .sortByDateTime: .date
        case .sortBySize: .size
        default: nil
        }
        if let sortColumn {
            menuItem.state = sortOrder.column == sortColumn && !sortOrder.isUnsorted ? .on : .off
        } else if command == .unsorted {
            menuItem.state = sortOrder.isUnsorted ? .on : .off
        } else if command == .reverseOrder {
            menuItem.state = sortOrder.ascending ? .off : .on
        } else if command == .goToParent {
            return directory.path != "/"
        } else if command == .properties {
            return archive == nil && remote == nil
        } else if command == .branchView {
            menuItem.state = isBranchView ? .on : .off
        } else if command == .srcAllFiles || command == .srcUserSpec {
            menuItem.state = (filterMask == nil && (command == .srcUserSpec || onlyNames == nil)) == (command == .srcAllFiles)
                ? .on : .off
        } else if command == .showOnlySelected {
            menuItem.state = onlyNames == nil ? .off : .on
        } else if command == .srcShort || command == .srcLong || command == .srcThumbs {
            let mode: FileListView.ViewMode = command == .srcShort ? .brief : (command == .srcLong ? .full : .thumbnails)
            menuItem.state = viewMode == mode ? .on : .off
        } else if [.closeCurrentTab, .switchToNextTab, .switchToPreviousTab].contains(command) {
            return tabs.count > 1
        } else if command == .serverTerminal {
            menuItem.state = panelView.isTerminalVisible ? .on : .off
            return remote?.fileSystem is SFTPFileSystem
        } else if command == .terminalChangeDir {
            return remote != nil && panelView.terminalPane.isRunning
        }
        return true
    }
}

// MARK: - Quick search

extension FilePanelController: NSSearchFieldDelegate {
    /// Ctrl+S: shows the box as a quick filter (Enter keeps the filter, Esc removes it).
    @objc(cm_QuickFilter:)
    func quickFilterCommand(_ sender: Any?) {
        beginQuickSearch(quickFilter ?? "", filtering: true)
    }

    func beginQuickSearch(_ text: String, filtering: Bool = false) {
        quickSearchFilters = filtering
        let field = panelView.quickSearchField
        field.placeholderString = filtering ? String(localized: "Quick filter") : String(localized: "Quick search")
        field.stringValue = text
        field.isHidden = false
        panelView.isQuickSearching = true
        view.window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        if !filtering {
            jumpToMatch(from: 0, forward: true)
        }
    }

    private func endQuickSearch(openingItem: Bool) {
        let field = panelView.quickSearchField
        guard !field.isHidden else { return }
        field.isHidden = true
        panelView.isQuickSearching = false
        focus()
        if openingItem {
            fileList(listView, openItemAt: listView.cursor)
        }
    }

    /// Names starting with the typed text match; a leading "*" matches anywhere.
    private func matches(_ item: FileItem, _ text: String) -> Bool {
        guard !item.isParent, !text.isEmpty else { return false }
        if text.hasPrefix("*") {
            let rest = String(text.dropFirst())
            return rest.isEmpty || item.name.localizedCaseInsensitiveContains(rest)
        }
        return item.name.range(of: text, options: [.caseInsensitive, .anchored, .diacriticInsensitive]) != nil
    }

    private func jumpToMatch(from start: Int, forward: Bool) {
        let text = panelView.quickSearchField.stringValue
        let items = listView.items
        guard !items.isEmpty else { return }
        for step in 0..<items.count {
            let index = forward
                ? (start + step) % items.count
                : (start - step + items.count) % items.count
            if matches(items[index], text) {
                listView.moveCursor(to: index)
                return
            }
        }
        NSSound.beep()
    }

    func controlTextDidChange(_ notification: Notification) {
        if quickSearchFilters {
            let text = panelView.quickSearchField.stringValue
            quickFilter = text.isEmpty ? nil : text
        } else {
            jumpToMatch(from: listView.cursor, forward: true)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if quickSearchFilters {
            switch selector {
            case #selector(NSResponder.moveDown(_:)):
                listView.moveCursor(to: listView.cursor + 1)
            case #selector(NSResponder.moveUp(_:)):
                listView.moveCursor(to: listView.cursor - 1)
            case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                endQuickSearch(openingItem: false)
            case #selector(NSResponder.cancelOperation(_:)):
                quickFilter = nil
                endQuickSearch(openingItem: false)
            default:
                return false
            }
            return true
        }
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            jumpToMatch(from: listView.cursor + 1, forward: true)
        case #selector(NSResponder.moveUp(_:)):
            jumpToMatch(from: listView.cursor - 1 + listView.items.count, forward: false)
        case #selector(NSResponder.insertNewline(_:)):
            endQuickSearch(openingItem: true)
        case #selector(NSResponder.cancelOperation(_:)), #selector(NSResponder.insertTab(_:)):
            endQuickSearch(openingItem: false)
        default:
            return false
        }
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        endQuickSearch(openingItem: false)
    }
}

extension FilePanelController: FileListViewDelegate {
    func fileListDidBecomeActive(_ list: FileListView) {
        delegate?.filePanelDidBecomeActive(self)
        if terminalWasFocused {
            terminalWasFocused = false
            if remote != nil { reread() }
        }
    }

    func fileList(_ list: FileListView, openItemAt index: Int) {
        guard list.items.indices.contains(index) else { return }
        open(list.items[index], enteringPackages: false)
    }

    func fileList(_ list: FileListView, enterItemAt index: Int) {
        guard list.items.indices.contains(index) else { return }
        open(list.items[index], enteringPackages: true)
    }

    func fileListGoToParent(_ list: FileListView) {
        goToParent()
    }

    func fileListSwitchPanel(_ list: FileListView) {
        delegate?.filePanelSwitchPanel(self)
    }

    func fileList(_ list: FileListView, rename item: FileItem, to newName: String) {
        guard newName != item.name else { return }
        if let remote {
            // Servers would replace an existing entry of that name.
            if listView.items.contains(where: { $0.name == newName && !$0.isParent }) {
                Prompt.error(String(localized: "Cannot rename \u{201C}\(item.name)\u{201D}"),
                             RemoteError(String(localized: "\u{201C}\(newName)\u{201D} already exists.")), in: view.window)
                return
            }
            runOnServer(selecting: newName) {
                try await remote.fileSystem.rename(remote.path(of: item.name), to: remote.path(of: newName))
            }
            return
        }
        if let archive {
            applyArchiveEdit(.rename(archive.path(of: item.name), to: newName), selecting: newName)
            return
        }
        // Branch view and search results show "sub/file.txt": the folder part stays.
        var newName = newName
        if let slash = item.name.lastIndex(of: "/") {
            let folderPart = String(item.name[...slash])
            if newName.hasPrefix(folderPart) { newName.removeFirst(folderPart.count) }
        }
        do {
            let url = try FileOperations.rename(item.url, to: newName)
            if let results = searchResults {
                let urls = results.urls.map { $0 == item.url ? url : $0 }
                let shown = (item.name as NSString).deletingLastPathComponent
                showSearchResults(urls, root: directory, title: results.title,
                                  selecting: shown.isEmpty ? newName : shown + "/" + newName)
                return
            }
            load(directory, selecting: url.lastPathComponent)
        } catch {
            Prompt.error(String(localized: "Cannot rename \u{201C}\(item.name)\u{201D}"), error, in: view.window)
        }
    }

    func fileListMarksDidChange(_ list: FileListView) {
        updateStatus()
    }

    func fileListCursorDidMove(_ list: FileListView) {
        delegate?.filePanelCursorDidMove(self)
    }

    func fileList(_ list: FileListView, contextMenuFor items: [FileItem]) -> NSMenu? {
        contextMenu(for: items)
    }

    func fileListCanDragItems(_ list: FileListView) -> Bool {
        archive == nil && remote == nil
    }

    func fileList(_ list: FileListView, drop urls: [URL], into folder: FileItem?, moving: Bool) -> Bool {
        // Files dragged from another program may not be written yet (see FileCoordination).
        whenWritten(urls) { [weak self] in self?.drop(urls, into: folder, moving: moving) }
        return true
    }

    /// Whether files dropped onto `folder` would go into a read-only archive; says so.
    private func refusesDrop(into folder: FileItem?) -> Bool {
        guard let archive else { return false }
        // [..] at an archive's root is the folder beside it; inside an archive inside
        // an archive, it is the outer archive.
        if archive.outer == nil, archive.folder.isEmpty, folder?.isParent == true { return false }
        return refuseReadOnlyArchive()
    }

    func drop(_ urls: [URL], into folder: FileItem?, moving: Bool) {
        guard !refusesDrop(into: folder) else { return }
        if let remote {
            let target = folder.map { $0.isParent ? RemotePath.parent(of: remote.path) : remote.path(of: $0.name) }
            upload(urls, to: target, moving: moving)
            return
        }
        if let archive, !(folder?.isParent == true && archive.folder.isEmpty) {
            let target: String
            if let folder {
                target = folder.isParent ? (archive.folder as NSString).deletingLastPathComponent : archive.path(of: folder.name)
            } else {
                target = archive.folder
            }
            applyArchiveEdit(.add(urls, folder: target), selecting: urls.first?.lastPathComponent) { succeeded in
                guard succeeded, moving else { return }
                Task { try? await FileOperations.deletePermanently(urls) }
            }
            return
        }
        let destination = archive != nil ? directory : (folder?.url ?? directory)
        transfer(urls, to: destination, moving: moving)
    }

    /// Dragged files another program promised: it writes them into a private folder on
    /// this folder's volume, then they go where they were dropped.
    func fileList(_ list: FileListView, dropPromises receivers: [NSFilePromiseReceiver], into folder: FileItem?) -> Bool {
        // Refused before receiving, so no received files are left behind.
        guard let window = view.window, !refusesDrop(into: folder) else { return false }
        let base = remote == nil && archive == nil ? directory : FileManager.default.temporaryDirectory
        guard let privateFolder = try? FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                                appropriateFor: base, create: true) else { return false }
        let received = OSAllocatedUnfairLock(initialState: [URL]())
        let group = DispatchGroup()
        let queue = OperationQueue()
        for receiver in receivers {
            // One wait per promise: its file names are known only once receiving began,
            // and the reader is called once per file.
            group.enter()
            nonisolated(unsafe) let receiver = receiver
            let calls = OSAllocatedUnfairLock(initialState: (count: 0, done: false))
            receiver.receivePromisedFiles(atDestination: privateFolder, options: [:], operationQueue: queue) { url, error in
                if error == nil { received.withLock { $0.append(url) } }
                let finished = calls.withLock { state -> Bool in
                    state.count += 1
                    guard !state.done, state.count >= max(receiver.fileNames.count, 1) else { return false }
                    state.done = true
                    return true
                }
                if finished { group.leave() }
            }
        }
        var cancelled = false
        let closeProgress = Prompt.progress(String(localized: "Receiving Files…"),
                                            in: window) { cancelled = true }
        group.notify(queue: .main) { [weak self] in
            MainActor.assumeIsolated {
                closeProgress()
                let files = received.withLock { $0 }
                guard let self, !cancelled, !files.isEmpty else {
                    try? FileManager.default.removeItem(at: privateFolder)
                    return
                }
                _ = self.fileList(list, drop: files, into: folder, moving: true)
            }
        }
        return true
    }

    func fileList(_ list: FileListView, calculateSizeOf item: FileItem) {
        calculateSizes(of: [item])
    }

    func fileList(_ list: FileListView, beginQuickSearchWith text: String) {
        beginQuickSearch(text)
    }

    func fileList(_ list: FileListView, interceptKey event: NSEvent) -> Bool {
        delegate?.filePanel(self, interceptKey: event) ?? false
    }

    func fileList(_ list: FileListView, markGroup mark: Bool) {
        askForMask(marking: mark)
    }
}
