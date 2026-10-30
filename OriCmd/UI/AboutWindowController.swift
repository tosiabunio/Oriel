import AppKit

/// App information, the fork's release identity and bundled dependency notices.
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        let info = Bundle.main.infoDictionary ?? [:]
        let name = Bundle.main.appName
        window.title = String(localized: "About \(name)")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel(name)
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .boldSystemFont(ofSize: 22)

        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let localBuild = info["OriCmdForkBuild"] as? String ?? ""
        let build = localBuild.isEmpty ? info["CFBundleVersion"] as? String ?? "" : localBuild
        let versionLabel = NSTextField(labelWithString: build.isEmpty ? version : "\(version) (\(build))")
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .medium)

        // What Oriel is a fork of, the same in every interface language.
        let forkLabel = NSTextField(labelWithString: "OriCmd fork")
        forkLabel.font = .systemFont(ofSize: 13)
        forkLabel.textColor = .secondaryLabelColor
        let copyrightLabel = NSTextField(wrappingLabelWithString: info["NSHumanReadableCopyright"] as? String ?? "")
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.textColor = .secondaryLabelColor
        for label in [nameLabel, versionLabel, forkLabel, copyrightLabel] {
            label.alignment = .center
            label.isSelectable = true
        }

        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 512, height: 260))
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 512, height: CGFloat.greatestFiniteMagnitude)
        text.textContainerInset = NSSize(width: 8, height: 10)
        text.textContainer?.lineFragmentPadding = 0
        text.linkTextAttributes = [.foregroundColor: NSColor.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
        text.setAccessibilityLabel(String(localized: "Credits and licenses"))
        text.textStorage?.setAttributedString(Self.credits())

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = text
        let stack = NSStackView(views: [icon, nameLabel, versionLabel, forkLabel, copyrightLabel, scroll])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(16, after: copyrightLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        window.contentView = content
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
            copyrightLabel.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -48),
            scroll.heightAnchor.constraint(equalToConstant: 300),
        ])
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSMutableAttributedString()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        for (label, repository) in [(String(localized: "Fork repository"), "tosiabunio/Oriel"),
                                    (String(localized: "Original repository"), "mmag/OriCmd")] {
            credits.append(NSAttributedString(string: label + ": ", attributes: attributes))
            var linkAttributes = attributes
            linkAttributes[.link] = URL(string: "https://github.com/" + repository)
            credits.append(NSAttributedString(string: repository + "\n", attributes: linkAttributes))
        }
        var headingAttributes = attributes
        headingAttributes[.font] = NSFont.boldSystemFont(ofSize: 12)
        credits.append(NSAttributedString(string: "\n" + String(localized: "Credits and licenses") + "\n\n",
                                         attributes: headingAttributes))
        if let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let notices = try? NSMutableAttributedString(url: url, options: [:], documentAttributes: nil) {
            let range = NSRange(location: 0, length: notices.length)
            notices.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            // The system's font, as the rest of the window, at the notices' sizes and weights.
            notices.enumerateAttribute(.font, in: range) { value, range, _ in
                if let font = value as? NSFont {
                    let bold = font.fontDescriptor.symbolicTraits.contains(.bold)
                    notices.addAttribute(.font, value: NSFont.systemFont(ofSize: font.pointSize + 2, weight: bold ? .bold : .regular),
                                         range: range)
                }
            }
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                for match in detector.matches(in: notices.string, range: range) {
                    if let link = match.url { notices.addAttribute(.link, value: link, range: match.range) }
                }
            }
            credits.append(notices)
        }
        return credits
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
    }
}
