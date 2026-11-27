import AppKit

/// User preferences (see the Settings window). Changes post `didChange`.
enum Settings {
    static let didChange = Notification.Name("OriCmdSettingsDidChange")

    /// How typed letters are used in a panel, as in Total Commander's options.
    enum QuickSearchMode: String {
        /// Option+letters search; plain letters go to the command line (TC default).
        case optionLetters
        /// Plain letters search; Option+letters go to the command line.
        case letters
    }

    private enum Key {
        static let fontName = "PanelFontName"
        static let fontSize = "PanelFontSize"
        static let quickSearch = "QuickSearchMode"
        static let commandLine = "ShowCommandLine"
        static let functionKeys = "ShowFunctionKeys"
        static let functionKeyCaps = "FunctionKeyCaps"
        static let driveButtons = "ShowDriveButtons"
        static let folderBrackets = "ShowFolderBrackets"
        static let macStyleTabs = "MacStyleTabs"
        static let compactHeader = "CompactPanelHeader"
        static let confirmTrash = "ConfirmMoveToTrash"
        static let extraColumns = "ExtraColumns"
        static let checkUpdates = "CheckForUpdates"
        static let appearance = "Appearance"
        static let languages = "AppleLanguages"
        static let copyOverwrite = "CopyOverwriteMode"
        static let copyVerify = "CopyVerify"
        static let copyAttributes = "CopyAttributes"
        static let copySkipUnreadable = "CopySkipUnreadable"
        static let copyOverwriteLocked = "CopyOverwriteLocked"
        static let copySkipDSStore = "CopySkipDSStore"
        static let rightButton = "RightMouseButton"
        static let clickToRename = "ClickToRename"
        static let extensionDisplay = "ExtensionDisplay"
        static let sizeDisplay = "SizeDisplay"
        static let plainStatus = "PlainStatusLine"
        static let selectionMarkers = "SelectionMarkers"
        static let look = "Look"
        static let density = "PanelDensity"
        static let sidebar = "ShowSidebar"

        static let separateTree = "SeparateTree"
        static let horizontalPanels = "HorizontalPanels"
        static let ignoreList = "IgnoreList"
        static let usesIgnoreList = "UsesIgnoreList"
    }

    /// The look of the panels: drawn as current Mac apps draw their lists, or as
    /// Total Commander draws its panels.
    enum Look: String {
        case modern, classic
    }

    /// Choosing a look sets the switches that make it up (folder brackets, tabs, the
    /// header, key caps, the status line, checkmarks, row height, the sidebar); each can
    /// still be changed afterwards. Switches never changed follow the look.
    static var look: Look {
        get { AppDefaults.store.string(forKey: Key.look).flatMap(Look.init) ?? .modern }
        set {
            let modern = newValue == .modern
            let store = AppDefaults.store
            store.set(newValue.rawValue, forKey: Key.look)
            store.set(!modern, forKey: Key.folderBrackets)
            for key in [Key.macStyleTabs, Key.compactHeader, Key.functionKeyCaps, Key.plainStatus, Key.selectionMarkers, Key.sidebar] {
                store.set(modern, forKey: key)
            }
            store.set((modern ? Density.standard : .compact).rawValue, forKey: Key.density)
            ColorSettings.lookDidChange()
            notify()
        }
    }

    static var isModern: Bool { look == .modern }

    /// How tall the rows of the file lists are.
    enum Density: String {
        /// 13 pt names on 22 pt rows, close to the Finder's list.
        case standard
        /// 12 pt names on 19 pt rows, as Total Commander fits many files.
        case compact
    }

    static var density: Density {
        get { AppDefaults.store.string(forKey: Key.density).flatMap(Density.init) ?? (isModern ? .standard : .compact) }
        set { set(newValue.rawValue, Key.density) }
    }

    static var showsSelectionMarkers: Bool {
        get { bool(Key.selectionMarkers, default: isModern) }
        set { set(newValue, Key.selectionMarkers) }
    }

    /// The size of the system font in the panels unless another is chosen.
    static var defaultFontSize: CGFloat { density == .standard ? 13 : 12 }

    static var panelFont: NSFont {
        get {
            let size = CGFloat(AppDefaults.store.double(forKey: Key.fontSize)).nonZero ?? defaultFontSize
            if let name = AppDefaults.store.string(forKey: Key.fontName), let font = NSFont(name: name, size: size) {
                return font
            }
            return .systemFont(ofSize: size)
        }
        set {
            let isSystem = newValue.familyName == NSFont.systemFont(ofSize: 12).familyName
            AppDefaults.store.set(isSystem ? nil : newValue.fontName, forKey: Key.fontName)
            AppDefaults.store.set(Double(newValue.pointSize), forKey: Key.fontSize)
            notify()
        }
    }

    static func resetPanelFont() {
        AppDefaults.store.removeObject(forKey: Key.fontName)
        AppDefaults.store.removeObject(forKey: Key.fontSize)
        notify()
    }

    static var quickSearchMode: QuickSearchMode {
        get { AppDefaults.store.string(forKey: Key.quickSearch).flatMap(QuickSearchMode.init) ?? .optionLetters }
        set { set(newValue.rawValue, Key.quickSearch) }
    }

    /// What the right mouse button does on a panel's files.
    enum RightButton: String {
        /// Shows the context menu, as in the Finder.
        case menu
        /// Marks and unmarks files (a drag over several marks them all); held still,
        /// shows the context menu.
        case marks
    }

    static var rightButton: RightButton {
        get { AppDefaults.store.string(forKey: Key.rightButton).flatMap(RightButton.init) ?? .menu }
        set { set(newValue.rawValue, Key.rightButton) }
    }

    /// A click on the name of the entry already under the cursor renames it in place,
    /// as in the Finder. Off by default: Total Commander does not.
    static var clickToRename: Bool {
        get { bool(Key.clickToRename, default: false) }
        set { set(newValue, Key.clickToRename) }
    }

    /// Where Full view shows file extensions.
    enum ExtensionDisplay: String {
        /// In the Ext column, apart from the name, as in Total Commander.
        case column
        /// After the name, as in the Finder; the Ext column title still sorts by them.
        case withName
    }

    static var extensionDisplay: ExtensionDisplay {
        get { AppDefaults.store.string(forKey: Key.extensionDisplay).flatMap(ExtensionDisplay.init) ?? .column }
        set { set(newValue.rawValue, Key.extensionDisplay) }
    }

    /// How sizes are shown: in the panels, the status line, the free space and when
    /// synchronizing folders.
    enum SizeDisplay: String {
        /// With units, as the Finder counts them: "1,3 MB" (1 kB = 1000 bytes).
        case short
        /// Every byte, as Total Commander shows them: "1 298 765".
        case exact
    }

    static var sizeDisplay: SizeDisplay {
        get { AppDefaults.store.string(forKey: Key.sizeDisplay).flatMap(SizeDisplay.init) ?? .short }
        set { set(newValue.rawValue, Key.sizeDisplay) }
    }

    /// The status line says "2 of 15 selected · 35 KB of 1,2 MB", as the Finder would,
    /// rather than "35 k / 1 234 k in 2 / 12 file(s), 0 / 3 dir(s)".
    static var plainStatusLine: Bool {
        get { bool(Key.plainStatus, default: isModern) }
        set { set(newValue, Key.plainStatus) }
    }

    /// A size as the panels show it (see `sizeDisplay`).
    static func formattedSize(_ bytes: Int64) -> String {
        sizeDisplay == .short ? shortSize(bytes) : bytes.formatted(.number.grouping(.automatic))
    }

    /// "1,3 MB", as the Finder counts (1 kB = 1000 bytes); below a kilobyte "512 B", as
    /// the other units are abbreviated, not "512 bytes" (nor "Zero KB").
    nonisolated static func shortSize(_ bytes: Int64) -> String {
        if bytes < 1000 { return String(localized: "\(bytes.formatted()) B") }
        return byteFormatter.string(fromByteCount: bytes)
    }

    /// Formatters format from any thread.
    nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    static var showsCommandLine: Bool {
        get { bool(Key.commandLine, default: true) }
        set { set(newValue, Key.commandLine) }
    }

    static var showsFunctionKeys: Bool {
        get { bool(Key.functionKeys, default: true) }
        set { set(newValue, Key.functionKeys) }
    }

    /// The function key buttons show their keys as key caps ("F5" in a small key,
    /// then "Copy"), rather than as plain text ("F5 Copy").
    static var showsFunctionKeyCaps: Bool {
        get { bool(Key.functionKeyCaps, default: isModern) }
        set { set(newValue, Key.functionKeyCaps) }
    }

    /// Total Commander's ignore list: names, masks (`*.bak`) or full paths of
    /// entries the panels leave out while it is used, one per line.
    static var ignoreList: [String] {
        get { (AppDefaults.store.string(forKey: Key.ignoreList) ?? "").split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { set(newValue.joined(separator: "\n"), Key.ignoreList) }
    }

    static var usesIgnoreList: Bool {
        get { bool(Key.usesIgnoreList, default: false) }
        set { set(newValue, Key.usesIgnoreList) }
    }

    /// Whether the ignore list hides the entry `name` at `path`.
    static func ignores(name: String, path: String, in list: [String]) -> Bool {
        list.contains { entry in
            entry.hasPrefix("/") || entry.hasPrefix("~")
                ? (entry as NSString).expandingTildeInPath == path
                : FileMask.matches(name, entry)
        }
    }

    /// Show → Horizontal Panels: the left panel above the right one.
    static var panelsOneAboveTheOther: Bool {
        get { bool(Key.horizontalPanels, default: false) }
        set { set(newValue, Key.horizontalPanels) }
    }

    /// Show → Separate Tree: one folder tree beside both panels.
    static var showsSeparateTree: Bool {
        get { bool(Key.separateTree, default: false) }
        set { set(newValue, Key.separateTree) }
    }

    /// The sidebar of devices, favorites and the hotlist (it hides the drive buttons).
    static var showsSidebar: Bool {
        get { bool(Key.sidebar, default: isModern) }
        set { set(newValue, Key.sidebar) }
    }

    static var showsDriveButtons: Bool {
        get { bool(Key.driveButtons, default: true) }
        set { set(newValue, Key.driveButtons) }
    }

    /// Folder names in square brackets, as in Total Commander.
    static var showsFolderBrackets: Bool {
        get { bool(Key.folderBrackets, default: !isModern) }
        set { set(newValue, Key.folderBrackets) }
    }

    /// `name` as the panels show it: a folder's in square brackets, unless turned off.
    static func panelName(_ name: String, isFolder: Bool) -> String {
        isFolder && showsFolderBrackets ? "[\(name)]" : name
    }

    /// Folder tabs drawn as Mac tabs (an icon, a close button under the mouse), or
    /// as flat Total Commander tabs.
    static var macStyleTabs: Bool {
        get { bool(Key.macStyleTabs, default: isModern) }
        set { set(newValue, Key.macStyleTabs) }
    }

    /// The panel's volume and free space are shown in its path bar, without the row of
    /// the volume selector and the / and .. buttons; the mask only when it filters.
    static var compactPanelHeader: Bool {
        get { bool(Key.compactHeader, default: isModern) }
        set { set(newValue, Key.compactHeader) }
    }

    /// Optional metadata columns shown in Full view, in this order.
    static var extraColumns: [SortColumn] {
        get { (AppDefaults.store.stringArray(forKey: Key.extraColumns) ?? []).compactMap(SortColumn.init(rawValue:)) }
        set { set(newValue.map(\.rawValue), Key.extraColumns) }
    }

    static var confirmsMoveToTrash: Bool {
        get { bool(Key.confirmTrash, default: true) }
        set { set(newValue, Key.confirmTrash) }
    }

    /// Light or dark look: the system's, or chosen for OriCmd only.
    enum Appearance: String, CaseIterable {
        case system, light, dark
    }

    static var appearance: Appearance {
        get { AppDefaults.store.string(forKey: Key.appearance).flatMap(Appearance.init) ?? .system }
        set {
            set(newValue.rawValue, Key.appearance)
            applyAppearance()
        }
    }

    /// Takes effect at once in every window.
    static func applyAppearance() {
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The interface language: the system's, or one chosen for OriCmd only.
    enum Language: String, CaseIterable {
        case system = "", english = "en", russian = "ru"
    }

    /// Takes effect after a restart (macOS reads AppleLanguages at launch).
    static var language: Language {
        get {
            let domain = AppDefaults.store.persistentDomain(forName: AppDefaults.domainName)
            guard let first = (domain?[Key.languages] as? [String])?.first else { return .system }
            return Language.allCases.first { !$0.rawValue.isEmpty && first.hasPrefix($0.rawValue) } ?? .system
        }
        set {
            if newValue == .system {
                AppDefaults.store.removeObject(forKey: Key.languages)
            } else {
                AppDefaults.store.set([newValue.rawValue], forKey: Key.languages)
            }
        }
    }

    /// The language the interface is shown in right now.
    static var runningLanguage: Language {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return code.hasPrefix("ru") ? .russian : .english
    }

    // Defaults of the F5 / F6 dialog (its save button writes them as well).

    static var copyOverwriteMode: OverwriteMode {
        get { OverwriteMode(rawValue: AppDefaults.store.integer(forKey: Key.copyOverwrite)) ?? .ask }
        set { set(newValue.rawValue, Key.copyOverwrite) }
    }

    static var copyVerifies: Bool {
        get { bool(Key.copyVerify, default: false) }
        set { set(newValue, Key.copyVerify) }
    }

    static var copyAttributes: Bool {
        get { bool(Key.copyAttributes, default: true) }
        set { set(newValue, Key.copyAttributes) }
    }

    static var copySkipsUnreadable: Bool {
        get { bool(Key.copySkipUnreadable, default: false) }
        set { set(newValue, Key.copySkipUnreadable) }
    }

    static var copyOverwritesLocked: Bool {
        get { bool(Key.copyOverwriteLocked, default: false) }
        set { set(newValue, Key.copyOverwriteLocked) }
    }

    static var copySkipsDSStore: Bool {
        get { bool(Key.copySkipDSStore, default: true) }
        set { set(newValue, Key.copySkipDSStore) }
    }

    /// Looks for a new release on GitHub once a day.
    static var checksForUpdates: Bool {
        get { bool(Key.checkUpdates, default: true) }
        set { set(newValue, Key.checkUpdates) }
    }

    private static func bool(_ key: String, default value: Bool) -> Bool {
        AppDefaults.store.object(forKey: key) == nil ? value : AppDefaults.store.bool(forKey: key)
    }

    /// Tells the windows to show settings changed elsewhere (column sets).
    static func notifyChange() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static func set(_ value: Any, _ key: String) {
        AppDefaults.store.set(value, forKey: key)
        notify()
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

private extension CGFloat {
    var nonZero: CGFloat? { self == 0 ? nil : self }
}
