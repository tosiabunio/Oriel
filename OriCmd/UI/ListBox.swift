import AppKit

/// A list in a tool window drawn as System Settings draws one: a rounded box with a
/// hairline edge instead of a sunken frame, rows with rounded selection, and along
/// its bottom edge the small symbol buttons that add, remove and move its entries.
/// An empty list can say so in its middle.
final class ListBox: NSView {
    /// What a button of the bar does. Its title stays the button's own (hidden behind
    /// the symbol): VoiceOver reads it, the tooltip shows it.
    enum Action {
        case add, remove, moveUp, moveDown

        var title: String {
            switch self {
            case .add: String(localized: "Add")
            case .remove: String(localized: "Remove")
            case .moveUp: String(localized: "Move Up")
            case .moveDown: String(localized: "Move Down")
            }
        }

        var symbol: String {
            switch self {
            case .add: "plus"
            case .remove: "minus"
            case .moveUp: "chevron.up"
            case .moveDown: "chevron.down"
            }
        }
    }

    private let scrollView = NSScrollView()
    private let placeholderLabel = NSTextField(labelWithString: "")

    /// Shown in the middle while the list (a `ListTableView`) has no rows.
    var placeholder: String? {
        didSet { updatePlaceholder() }
    }

    /// A bar button: `action`'s symbol, its title for VoiceOver and the tooltip.
    static func button(_ action: Action, target: AnyObject?, selector: Selector) -> NSButton {
        let button = NSButton(title: action.title, target: target, action: selector)
        button.image = NSImage(systemSymbolName: action.symbol, accessibilityDescription: action.title)
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.toolTip = action.title
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return button
    }

    /// `document`: the table or text view shown, a table in `style` (rows edge to edge
    /// with `.plain`); `buttons` (from `button(_:target:selector:)`) go in a bar below
    /// it, the add and remove ones apart from the others.
    init(_ document: NSView, style: NSTableView.Style = .inset, buttons: [NSButton] = []) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateBorder()

        if let table = document as? NSTableView {
            table.style = style
        }
        if let table = document as? ListTableView {
            table.onRowsChange = { [weak self] in self?.updatePlaceholder() }
        }
        scrollView.documentView = document
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.lineBreakMode = .byWordWrapping
        placeholderLabel.maximumNumberOfLines = 3
        placeholderLabel.isHidden = true

        var views: [NSView] = [scrollView, placeholderLabel]
        let bar = NSStackView()
        let separator = NSBox()
        separator.boxType = .separator
        if !buttons.isEmpty {
            bar.orientation = .horizontal
            bar.spacing = 0
            bar.edgeInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
            for button in buttons {
                bar.addView(button, in: .leading)
            }
            // The add and remove buttons are a pair; moving entries is another.
            if let last = buttons.last(where: { $0.title == Action.remove.title }), last !== buttons.last {
                bar.setCustomSpacing(10, after: last)
            }
            views += [separator, bar]
        }
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholderLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -32),
        ])
        if buttons.isEmpty {
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        } else {
            NSLayoutConstraint.activate([
                separator.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
                separator.leadingAnchor.constraint(equalTo: leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor),
                bar.topAnchor.constraint(equalTo: separator.bottomAnchor),
                bar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: trailingAnchor),
                bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
        setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A box of `size` for text typed in a dialog: the text view fills it, wraps at its
    /// width and stands on the color of a text field.
    static func editor(_ text: NSTextView, size: NSSize) -> ListBox {
        text.minSize = NSSize(width: 0, height: size.height)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = .width
        text.textContainer?.widthTracksTextView = true
        text.textContainerInset = NSSize(width: 4, height: 6)
        text.drawsBackground = false
        let box = ListBox(text)
        box.isFilled = true
        box.frame = NSRect(origin: .zero, size: size)
        return box
    }

    /// Whether the box stands on a text field's color instead of its window's.
    private var isFilled = false

    override func draw(_ dirtyRect: NSRect) {
        guard isFilled else { return }
        NSColor.textBackgroundColor.setFill()
        bounds.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorder()
    }

    /// The edge, drawn by the layer above the table and the bar.
    private func updateBorder() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    /// The placeholder's text only while it shows, so a hidden one is read by no one.
    private func updatePlaceholder() {
        let isEmpty = (scrollView.documentView as? NSTableView)?.numberOfRows == 0
        let text = isEmpty ? placeholder ?? "" : ""
        placeholderLabel.stringValue = text
        placeholderLabel.isHidden = text.isEmpty
    }
}

/// A table that tells its `ListBox` when its rows change, for the box to say in its
/// middle that it is empty.
class ListTableView: NSTableView {
    fileprivate var onRowsChange: (() -> Void)?

    override func reloadData() {
        super.reloadData()
        onRowsChange?()
    }

    override func noteNumberOfRowsChanged() {
        super.noteNumberOfRowsChanged()
        onRowsChange?()
    }

    override func endUpdates() {
        super.endUpdates()
        onRowsChange?()
    }
}
