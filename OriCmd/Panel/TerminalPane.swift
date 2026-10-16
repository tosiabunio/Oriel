import AppKit
import SwiftTerm

/// The command that opens a shell on a server, run in the terminal under a panel.
nonisolated struct ShellCommand: Sendable {
    /// The private escape sequence (OSC) in which the shell reports its process number.
    static let shellPIDCode = 7770

    let executable: String
    let arguments: [String]
}

/// The shell of a server under a panel: SwiftTerm's xterm emulator running
/// `ssh` over the panel's connection, below a divider that resizes it. Each
/// server tab has a terminal of its own; the pane shows the active tab's.
final class TerminalPane: NSView {
    private static let heightKey = "ServerTerminalHeight"
    static let minimumHeight: CGFloat = 60
    /// The file list keeps at least this much of the panel.
    static let minimumListHeight: CGFloat = 160

    /// Height of the pane (divider included) while shown, kept between launches.
    static var preferredHeight: CGFloat {
        get {
            let saved = AppDefaults.store.double(forKey: heightKey)
            return saved >= minimumHeight ? saved : 220
        }
        set { AppDefaults.store.set(Double(newValue), forKey: heightKey) }
    }

    /// The panel's font when its letters all have one width (Monaco, Menlo), else the
    /// system's monospaced font at its size.
    static var font: NSFont {
        let panel = Theme.panelFont
        return panel.isFixedPitch ? panel : NSFont.monospacedSystemFont(ofSize: panel.pointSize, weight: .regular)
    }

    /// The pane's height in the panel (set by the panel view).
    var heightConstraint: NSLayoutConstraint?
    /// The terminal got the keyboard focus.
    var onFocus: (() -> Void)?
    /// Return was pressed in a terminal whose session ended.
    var onReconnect: (() -> Void)?
    /// A session ended within seconds of its start (e.g. an account without a shell).
    var onEndedAtOnce: ((ShellTerminalView) -> Void)?

    private let divider = TerminalDivider()
    /// The terminal shown: the active tab's.
    private(set) var terminal: ShellTerminalView?
    /// The ANSI colors last installed in the terminal shown.
    private var palette: [SwiftTerm.Color] = []
    private var terminalTop: NSLayoutConstraint?
    private var terminalLeading: NSLayoutConstraint?
    private var terminalBottom: NSLayoutConstraint?
    private var keptHeight: NSLayoutConstraint?

    /// The shown terminal has a shell running (a session that ended waits for Return).
    var isRunning: Bool { terminal?.isRunning ?? false }
    var hasFocus: Bool { terminal.map { window?.firstResponder === $0 } ?? false }

    /// Hidden, the pane takes no room, while the terminal keeps its size: programs on
    /// the server are not squeezed to a single row meanwhile.
    var isCollapsed = true {
        didSet { updateTerminalHeight() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: TerminalDivider.height),
        ])
        divider.onDrag = { [weak self] delta in self?.resize(by: delta) }
        divider.onDragEnd = { [weak self] in
            if let height = self?.heightConstraint?.constant { Self.preferredHeight = height }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(scrollerStyleDidChange),
                                               name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Starts `command` in a new terminal and shows it.
    func start(_ command: ShellCommand, over fileSystem: SFTPFileSystem) -> ShellTerminalView {
        let view = ShellTerminalView(frame: NSRect(origin: .zero, size: bounds.size))
        view.fileSystem = fileSystem
        view.font = Self.font
        // Option types characters (as Terminal.app does by default), e.g. "[" or "|" on some layouts.
        view.optionAsMetaKey = false
        view.processDelegate = self
        view.onReconnect = { [weak self] in self?.onReconnect?() }
        attach(view)

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["LANG"] = Self.language
        view.startedAt = .now
        view.startProcess(executable: command.executable, args: command.arguments,
                          environment: environment.map { "\($0.key)=\($0.value)" })
        view.watchExit()
        return view
    }

    /// Shows `terminal` (another tab's, or none); the one shown before keeps running.
    func attach(_ terminal: ShellTerminalView?) {
        guard terminal !== self.terminal else { return }
        // The kept height is the view's own constraint: it would stay with the view.
        keptHeight?.isActive = false
        terminalBottom?.isActive = false
        self.terminal?.removeFromSuperview()
        self.terminal = terminal
        terminalBottom = nil
        keptHeight = nil
        guard let terminal else { return }
        // A terminal brought over with its tab from the other panel answers to this pane now.
        terminal.processDelegate = self
        terminal.onReconnect = { [weak self] in self?.onReconnect?() }
        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)
        let top = terminal.topAnchor.constraint(equalTo: divider.bottomAnchor)
        let leading = terminal.leadingAnchor.constraint(equalTo: leadingAnchor)
        NSLayoutConstraint.activate([top, leading, terminal.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)])
        terminalTop = top
        terminalLeading = leading
        terminalBottom = terminal.bottomAnchor.constraint(equalTo: bottomAnchor)
        keptHeight = terminal.heightAnchor.constraint(equalToConstant: 0)
        applyLook()
        updateTerminalHeight()
        terminal.fitScroller()
    }

    /// The room around the text (in the Modern look it starts where the list's icons
    /// do, with a little space under the divider) and the colors.
    func applyLook() {
        let modern = Settings.isModern
        terminalTop?.constant = modern ? 4 : 0
        terminalLeading?.constant = modern ? Theme.contentInset + 3 : 2
        terminalBottom?.constant = modern ? -4 : -2
        applyColors()
        needsDisplay = true
    }

    /// Ends the session of `terminal` (the connection stays).
    func close(_ terminal: ShellTerminalView) {
        terminal.processDelegate = nil
        terminal.stopWatchingExit()
        if terminal.process.running, !terminal.hasEnded {
            let pid = terminal.process.shellPid
            terminal.terminate()
            // SwiftTerm stops watching the process here: it is collected in the background.
            DispatchQueue.global().async {
                var status: Int32 = 0
                waitpid(pid, &status, 0)
            }
        }
        if terminal === self.terminal {
            attach(nil)
        }
    }

    /// Types `text` into the shown terminal.
    func send(_ text: String) {
        terminal?.send(txt: text)
    }

    func focus() {
        guard let terminal else { return }
        window?.makeFirstResponder(terminal)
    }

    /// The lines on the screen, for tests (the terminal's drawing is not in window snapshots).
    var screenText: String? {
        guard let screen = terminal?.getTerminal() else { return nil }
        return (0..<screen.rows).map { screen.getLine(row: $0)?.translateToString(trimRight: true) ?? "" }
            .joined(separator: "\n")
    }

    /// "ru_RU.UTF-8", as Terminal.app sets it; the server gets it through ssh's SendEnv.
    private static var language: String {
        let locale = Locale.current
        guard let language = locale.language.languageCode?.identifier, let region = locale.region?.identifier else {
            return "en_US.UTF-8"
        }
        return "\(language)_\(region).UTF-8"
    }

    private func updateTerminalHeight() {
        guard let terminal, let terminalBottom, let keptHeight else { return }
        if isCollapsed {
            keptHeight.constant = max(terminal.frame.height, 40)
            terminalBottom.isActive = false
            keptHeight.isActive = true
        } else {
            keptHeight.isActive = false
            terminalBottom.isActive = true
        }
    }

    private func resize(by delta: CGFloat) {
        guard let heightConstraint, let panel = superview else { return }
        let maximum = max(Self.minimumHeight, panel.bounds.height - Self.minimumListHeight)
        heightConstraint.constant = min(max(heightConstraint.constant + delta, Self.minimumHeight), maximum)
    }

    @objc private func scrollerStyleDidChange() {
        terminal?.fitScroller()
    }

    // MARK: - Colors

    /// The margins around the terminal are the panel's. Views do not clip their drawing
    /// to their bounds (macOS 14), and `dirtyRect` can reach past them.
    override func draw(_ dirtyRect: NSRect) {
        Theme.panelBackground.setFill()
        bounds.intersection(dirtyRect).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    /// The panel's text colors, resolved for the current light or dark look, and ANSI
    /// colors that read on its background.
    private func applyColors() {
        guard let terminal else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            terminal.nativeForegroundColor = Theme.panelText
            terminal.nativeBackgroundColor = Theme.panelBackground
            terminal.caretColor = .controlAccentColor
            palette = TerminalPalette.colors(onDark: TerminalPalette.isDark(Theme.panelBackground))
            terminal.installColors(palette)
        }
    }

    #if DEBUG
    /// For tests: the font, where the text starts, the background's tone, the ANSI blue
    /// installed and how the scroller shows.
    var lookDescription: String? {
        guard let terminal else { return nil }
        var dark = false
        effectiveAppearance.performAsCurrentDrawingAppearance { dark = TerminalPalette.isDark(Theme.panelBackground) }
        let blue = palette.count == 16 ? "\(palette[4].red >> 8),\(palette[4].green >> 8),\(palette[4].blue >> 8)" : "none"
        let scroller = terminal.subviews.lazy.compactMap { $0 as? NSScroller }.first.map {
            "\($0.scrollerStyle == .overlay ? "overlay" : "legacy") \($0.isHidden ? "hidden" : "shown")"
        } ?? "none"
        return """
            font: \(terminal.font.fontName) \(Int(terminal.font.pointSize))
            inset: \(Int(terminal.frame.minX))
            background: \(dark ? "dark" : "light")
            blue: \(blue)
            scroller: \(scroller)
            """
    }
    #endif
}

extension TerminalPane: @preconcurrency LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard let terminal = source as? ShellTerminalView, !terminal.hasEnded else { return }
        terminal.hasEnded = true
        terminal.stopWatchingExit()
        terminal.feed(text: "\r\n\u{1B}[2m" + String(localized: "Session ended. Press Return to connect again.") + "\u{1B}[0m\r\n")
        if Date.now.timeIntervalSince(terminal.startedAt) < 3 {
            onEndedAtOnce?(terminal)
        }
    }
}

/// SwiftTerm's view, with the file manager's keys taken into account.
final class ShellTerminalView: LocalProcessTerminalView {
    /// Return was pressed after the session ended.
    var onReconnect: (() -> Void)?
    fileprivate(set) var hasEnded = false
    fileprivate(set) var startedAt = Date.distantPast
    /// The connection the shell runs over, asked what runs in the terminal.
    fileprivate(set) var fileSystem: SFTPFileSystem?
    /// The shell's process on the server, reported by the shell command as it starts.
    private(set) var remoteShellPID: Int?
    /// Opened by connecting rather than by ⌃`: hidden again if the server has no shell.
    var opensQuietly = false

    /// What `runningProgram` says when only the screen tells a program runs.
    static let fullScreenProgram = String(localized: "a full-screen program")

    var isRunning: Bool { !hasEnded }

    private var exitWatch: Timer?

    /// SwiftTerm 1.11 may miss the shell's exit: when the end of its output comes
    /// first, it stops watching the process, and never reports the end nor collects
    /// the process. So the process is checked here, twice a second.
    fileprivate func watchExit() {
        let pid = process.shellPid
        guard pid > 0 else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            var status: Int32 = 0
            let result = waitpid(pid, &status, WNOHANG)
            // The pid, or "no such child": SwiftTerm collected it itself.
            guard result == pid || (result == -1 && errno == ECHILD) else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stopWatchingExit()
                self.processDelegate?.processTerminated(source: self, exitCode: result == pid ? status : nil)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        exitWatch = timer
    }

    fileprivate func stopWatchingExit() {
        exitWatch?.invalidate()
        exitWatch = nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let terminal = getTerminal()
        // Only the first report counts: the shell command sends it before anything else,
        // later ones could come from any output (a file shown with cat).
        terminal.registerOscHandler(code: ShellCommand.shellPIDCode) { [weak self] data in
            guard let self, remoteShellPID == nil else { return }
            remoteShellPID = Int(String(decoding: data, as: UTF8.self))
        }
        // Links from the server (OSC 8) would open any address with ⌘-click: they stay plain text.
        terminal.registerOscHandler(code: 8) { _ in }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The program running in the terminal instead of its shell ("apt", "vim"); nil
    /// while the shell waits for a command.
    func runningProgram() async -> String? {
        guard !hasEnded else { return nil }
        if let pid = remoteShellPID, let fileSystem {
            do {
                return try await fileSystem.foregroundProgram(ofShell: pid)
            } catch {
                // The server could not tell: see what is on the screen.
            }
        }
        return getTerminal().isCurrentBufferAlternate ? Self.fullScreenProgram : nil
    }

    /// While the terminal has the focus, keys without ⌘ are the shell's: F-keys and ⌃ or ⌥
    /// combinations would otherwise run the file manager's commands from the menu. ⌘ keys
    /// (copy, paste, …) and the keys of the terminal commands still reach the menu.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.firstResponder === self,
              !event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        if Command.terminalCommands.contains(where: { $0.matches(event) }) {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    /// SwiftTerm keeps a legacy scroller at all times. Where the system shows scroll bars
    /// only while scrolling, it becomes an overlay knob, shown while the terminal is
    /// scrolled back into its history.
    func fitScroller() {
        guard let scroller = subviews.lazy.compactMap({ $0 as? NSScroller }).first else { return }
        let style = NSScroller.preferredScrollerStyle
        let hidden = style == .overlay && !(canScroll && scrollPosition < 1)
        if scroller.scrollerStyle != style { scroller.scrollerStyle = style }
        if scroller.isHidden != hidden { scroller.isHidden = hidden }
    }

    /// Output moved the view.
    override func scrolled(source terminal: Terminal, yDisp: Int) {
        super.scrolled(source: terminal, yDisp: yDisp)
        fitScroller()
    }

    /// The user scrolled (wheel, scroller, Page Up).
    override func scrolled(source: TerminalView, position: Double) {
        super.scrolled(source: source, position: position)
        fitScroller()
    }

    override func bufferActivated(source: Terminal) {
        super.bufferActivated(source: source)
        fitScroller()
    }

    /// After the session ended the keys go nowhere; Return starts a new one.
    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        guard hasEnded else {
            super.send(source: source, data: data)
            return
        }
        if data.contains(13) { onReconnect?() }
    }
}

/// The line above the terminal, dragged to resize it.
private final class TerminalDivider: NSView {
    static let height: CGFloat = 6

    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?
    private var lastY: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        Theme.separator.setFill()
        NSRect(x: 0, y: bounds.midY - 0.5, width: bounds.width, height: 1).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        lastY = event.locationInWindow.y
    }

    /// Dragging up makes the terminal taller.
    override func mouseDragged(with event: NSEvent) {
        let y = event.locationInWindow.y
        onDrag?(y - lastY)
        lastY = y
    }

    override func mouseUp(with event: NSEvent) {
        onDragEnd?()
    }
}
