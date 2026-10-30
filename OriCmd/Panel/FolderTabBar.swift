import AppKit

/// Folder tabs above a panel's path bar: Mac-style tabs with an icon and a close
/// button under the mouse, or flat TC-style ones (as chosen in Settings).
/// Click selects a tab, double click or a click of the middle button (the mouse wheel)
/// closes it; a tab dragged to another place of the bar, or to the other panel's, goes there.
/// Tabs that do not fit become narrower, down to a minimum; past that the bar scrolls
/// (wheel, trackpad or the arrows at the ends), always showing the selected tab.
final class FolderTabBar: NSView, NSDraggingSource {
    /// A tab being dragged: its identifier (tabs are only dragged inside OriCmd).
    static let pasteboardType = NSPasteboard.PasteboardType("ru.themmag.OriCmd.tab")

    private static let maximumTabWidth: CGFloat = 180
    /// Mac-style tabs follow the header's fonts in the modern look: 24 pt for a 13 pt list.
    static var height: CGFloat { Settings.macStyleTabs ? max(24, Theme.lineHeight(font) + 10) : 20 }

    private static var font: NSFont { Settings.isModern ? Theme.headerDetailFont : Theme.chromeFont }

    var titles: [String] = [] {
        didSet {
            needsDisplay = true
            revealSelected()
        }
    }

    /// The tabs' icons, in the order of `titles` (Mac-style tabs only).
    var icons: [NSImage] = [] {
        didSet { needsDisplay = true }
    }

    /// The tabs' identifiers, in the order of `titles`.
    var identifiers: [UUID] = []

    var selectedIndex = 0 {
        didSet {
            needsDisplay = true
            revealSelected()
        }
    }

    /// How far the tabs are scrolled, when they do not fit.
    private var offset: CGFloat = 0 {
        didSet { if offset != oldValue { needsDisplay = true } }
    }
    private static let arrowWidth: CGFloat = 16

    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    /// Right click on a tab.
    var onContextMenu: ((Int) -> NSMenu?)?
    /// A double click on the empty part of the bar: a new tab, as ⌘T.
    var onNewTab: (() -> Void)?
    /// A tab (from this bar or the other panel's) dropped before the tab at the index
    /// (the count: at the end); whether it went there.
    var onDropTab: ((UUID, Int) -> Bool)?

    /// Where a press on a tab started, until it becomes a drag.
    private var pressed: (point: NSPoint, index: Int)?
    /// The tab the middle button was pressed on: it closes when the button is let go
    /// over it (as in browsers), not when the press leaves it.
    private var middlePressed: Int?
    /// Where a dragged tab would go (a line is drawn there).
    private var dropIndex: Int? {
        didSet { if dropIndex != oldValue { needsDisplay = true } }
    }
    /// The tab under the mouse, which shows its close button.
    private var hoveredIndex: Int? {
        didSet { if hoveredIndex != oldValue { needsDisplay = true } }
    }
    /// The mouse is over the hovered tab's close button.
    private var closeHovered = false {
        didSet { if closeHovered != oldValue { needsDisplay = true } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([Self.pasteboardType])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    nonisolated override var isFlipped: Bool { true }

    private var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .center
        return [.font: Self.font, .foregroundColor: Theme.chromeText, .paragraphStyle: paragraph]
    }

    private static var iconSize: CGFloat { Settings.isModern ? font.pointSize + 3 : 14 }
    private static let closeSize: CGFloat = 14
    /// The room on either side of a Mac-style tab's title: the icon on one, the close
    /// button on the other.
    private static var sideRoom: CGFloat { max(closeSize, iconSize) + 10 }

    /// The room before the first tab and after the last.
    private var margin: CGFloat { Settings.macStyleTabs ? 4 : 2 }

    /// Each tab as wide as its title, or, when they do not all fit, as wide as an
    /// equal share of the bar, but not narrower than room for a few letters.
    private var tabWidths: [CGFloat] {
        // An icon and a close button on either side of the title.
        let extra: CGFloat = Settings.macStyleTabs ? 2 * Self.sideRoom : 20
        let widths = titles.map { min(($0 as NSString).size(withAttributes: attributes).width + extra, Self.maximumTabWidth) }
        let room = bounds.width - 2 * margin - CGFloat(max(widths.count - 1, 0))
        guard !widths.isEmpty, widths.reduce(0, +) > room else { return widths }
        let share = max(floor(room / CGFloat(widths.count)), extra + 3 * Self.font.pointSize)
        return widths.map { min($0, share) }
    }

    private var contentWidth: CGFloat {
        tabWidths.reduce(2 * margin) { $0 + $1 } + CGFloat(max(titles.count - 1, 0))
    }

    private var overflows: Bool { contentWidth > bounds.width }

    /// Where the tabs show: between the arrows when they do not fit.
    private var tabArea: NSRect {
        overflows ? bounds.insetBy(dx: Self.arrowWidth, dy: 0) : bounds
    }

    private var maxOffset: CGFloat { max(contentWidth - tabArea.width, 0) }

    private var leftArrow: NSRect { NSRect(x: 0, y: 0, width: Self.arrowWidth, height: bounds.height) }
    private var rightArrow: NSRect {
        NSRect(x: bounds.maxX - Self.arrowWidth, y: 0, width: Self.arrowWidth, height: bounds.height)
    }

    private func tabRects() -> [NSRect] {
        let macStyle = Settings.macStyleTabs
        var x = tabArea.minX + margin - offset
        return tabWidths.map { width in
            defer { x += width + 1 }
            return NSRect(x: x, y: macStyle ? 3 : 2, width: width, height: bounds.height - (macStyle ? 3 : 2))
        }
    }

    private func scroll(to value: CGFloat) {
        offset = min(max(value, 0), maxOffset)
    }

    /// Scrolls so that the selected tab shows whole.
    private func revealSelected() {
        scroll(to: offset)
        let rects = tabRects()
        guard bounds.width > 0, rects.indices.contains(selectedIndex) else { return }
        let rect = rects[selectedIndex], area = tabArea
        if rect.minX < area.minX {
            scroll(to: offset - (area.minX - rect.minX) - margin)
        } else if rect.maxX > area.maxX {
            scroll(to: offset + rect.maxX - area.maxX + margin)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        revealSelected()
    }

    /// The arrows at the ends of a bar whose tabs do not fit, grey where it cannot
    /// scroll further.
    private func drawArrows() {
        guard overflows else { return }
        for (rect, symbol, enabled) in [(leftArrow, "chevron.left", offset > 0),
                                        (rightArrow, "chevron.right", offset < maxOffset)] {
            let color = enabled ? Theme.chromeText : Theme.chromeText.withAlphaComponent(0.3)
            let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) {
                image.draw(in: NSRect(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2,
                                      width: image.size.width, height: image.size.height))
            }
        }
    }

    /// Where the close button of the tab in `rect` is: at its right end.
    private func closeRect(in rect: NSRect) -> NSRect {
        NSRect(x: rect.maxX - Self.closeSize - 5, y: rect.midY - Self.closeSize / 2, width: Self.closeSize, height: Self.closeSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        if Settings.macStyleTabs {
            drawMacStyle()
            return
        }
        Theme.chromeBackground.setFill()
        bounds.fill()
        drawArrows()
        NSGraphicsContext.saveGraphicsState()
        tabArea.clip()
        for (index, rect) in tabRects().enumerated() {
            let selected = index == selectedIndex
            (selected ? Theme.panelBackground : Theme.inactiveHeaderBackground).setFill()
            rect.fill()
            Theme.separator.setStroke()
            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: rect.minX + 0.5, y: rect.maxY))
            outline.line(to: NSPoint(x: rect.minX + 0.5, y: rect.minY + 0.5))
            outline.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.minY + 0.5))
            outline.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.maxY))
            outline.stroke()
            let textHeight = Theme.lineHeight(Self.font)
            (titles[index] as NSString).draw(
                with: NSRect(x: rect.minX + 6, y: rect.midY - textHeight / 2, width: rect.width - 12, height: textHeight),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        Theme.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        if let dropIndex {
            let rects = tabRects()
            let x = dropIndex < rects.count ? rects[dropIndex].minX - 1 : (rects.last?.maxX ?? 2) + 1
            NSColor.controlAccentColor.setFill()
            NSRect(x: x - 1, y: 1, width: 2, height: bounds.height - 2).fill()
        }
    }

    /// The selected tab is a card joined to the file list below it; the others are
    /// plain titles split by thin lines, with a soft background under the mouse.
    private func drawMacStyle() {
        Theme.chromeBackground.setFill()
        bounds.fill()
        let rects = tabRects()
        Theme.separator.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        drawArrows()
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        tabArea.clip()

        for (index, rect) in rects.enumerated() {
            let selected = index == selectedIndex, hovered = index == hoveredIndex
            if selected {
                let card = Self.topRoundedPath(NSRect(x: rect.minX + 0.5, y: rect.minY + 0.5, width: rect.width - 1, height: rect.height),
                                               radius: 5)
                Theme.panelBackground.setFill()
                card.fill()
                Theme.separator.setStroke()
                card.lineWidth = 1
                card.stroke()
                // The card is open towards the list.
                Theme.panelBackground.setFill()
                NSRect(x: rect.minX + 1, y: bounds.height - 1, width: rect.width - 2, height: 1).fill()
            } else if hovered {
                NSColor.quaternaryLabelColor.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1).offsetBy(dx: 0, dy: -1), xRadius: 5, yRadius: 5).fill()
            }
            // Thin lines between tabs that are neither selected nor under the mouse.
            if index > 0, !selected, !hovered, index - 1 != selectedIndex, index - 1 != hoveredIndex {
                Theme.separator.setFill()
                NSRect(x: rect.minX - 1, y: rect.midY - 6, width: 1, height: 12).fill()
            }

            let textColor = selected ? NSColor.labelColor : NSColor.secondaryLabelColor
            var attributes = attributes
            attributes[.foregroundColor] = textColor
            let title = titles[index] as NSString
            let textHeight = Theme.lineHeight(Self.font)
            let space = rect.insetBy(dx: Self.sideRoom, dy: 0)
            let titleWidth = min(title.size(withAttributes: attributes).width, space.width)
            // The icon goes just before the centred title.
            if icons.indices.contains(index) {
                let iconX = max(space.midX - titleWidth / 2 - Self.iconSize - 4, rect.minX + 6)
                icons[index].draw(in: NSRect(x: iconX, y: rect.midY - Self.iconSize / 2, width: Self.iconSize, height: Self.iconSize),
                                  from: .zero, operation: .sourceOver, fraction: selected ? 1 : 0.85,
                                  respectFlipped: true, hints: nil)
            }
            title.draw(with: NSRect(x: space.minX, y: rect.midY - textHeight / 2, width: space.width, height: textHeight),
                       options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)

            if hovered {
                let close = closeRect(in: rect)
                if closeHovered {
                    NSColor.tertiaryLabelColor.setFill()
                    NSBezierPath(roundedRect: close, xRadius: 3, yRadius: 3).fill()
                }
                let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.secondaryLabelColor]))
                if let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: String(localized: "Close Tab"))?
                    .withSymbolConfiguration(configuration) {
                    image.draw(in: NSRect(x: close.midX - image.size.width / 2, y: close.midY - image.size.height / 2,
                                          width: image.size.width, height: image.size.height))
                }
            }
        }
        if let dropIndex {
            let x = dropIndex < rects.count ? rects[dropIndex].minX - 1 : (rects.last?.maxX ?? 4) + 1
            NSColor.controlAccentColor.setFill()
            NSRect(x: x - 1, y: 3, width: 2, height: bounds.height - 4).fill()
        }
    }

    /// A rectangle with rounded top corners (the view is flipped: the top is minY).
    private static func topRoundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
        path.appendArc(withCenter: NSPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                       startAngle: 180, endAngle: 270)
        path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
        path.appendArc(withCenter: NSPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                       startAngle: 270, endAngle: 360)
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        return path
    }

    // MARK: - Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        closeHovered = false
    }

    private func updateHover(at point: NSPoint) {
        guard Settings.macStyleTabs else { return }
        let rects = tabRects()
        hoveredIndex = tabArea.contains(point) ? rects.firstIndex { $0.contains(point) } : nil
        closeHovered = hoveredIndex.map { closeRect(in: rects[$0]).contains(point) } ?? false
    }

    /// The tab whose close button is at `point`.
    private func closeButtonIndex(at point: NSPoint) -> Int? {
        guard Settings.macStyleTabs, tabArea.contains(point) else { return nil }
        return tabRects().firstIndex { closeRect(in: $0).contains(point) }
    }

    /// Where the tab's close button is (for the tests).
    func closeButtonRect(_ index: Int) -> NSRect? {
        let rects = tabRects()
        return rects.indices.contains(index) ? closeRect(in: rects[index]) : nil
    }

    /// Shows the tab as under the mouse (for the tests' snapshots).
    func hover(_ index: Int) {
        hoveredIndex = index
    }

    /// The tab under the event's location.
    private func tabIndex(at event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        guard tabArea.contains(point) else { return nil }
        return tabRects().firstIndex { $0.contains(point) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let index = tabIndex(at: event) else { return nil }
        return onContextMenu?(index)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pressed = nil
        if overflows, leftArrow.contains(point) {
            scroll(to: offset - tabArea.width * 0.7)
            return
        } else if overflows, rightArrow.contains(point) {
            scroll(to: offset + tabArea.width * 0.7)
            return
        }
        if let index = closeButtonIndex(at: point) {
            hoveredIndex = nil
            onClose?(index)
            return
        }
        guard let index = tabIndex(at: event) else {
            if event.clickCount == 2 { onNewTab?() }
            return
        }
        if event.clickCount == 2 {
            onClose?(index)
        } else {
            pressed = (point, index)
            onSelect?(index)
        }
    }

    /// A tab pressed and moved a few points is dragged.
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let start = pressed, hypot(point.x - start.point.x, point.y - start.point.y) > 4,
              identifiers.indices.contains(start.index), tabRects().indices.contains(start.index) else { return }
        pressed = nil
        let item = NSPasteboardItem()
        item.setString(identifiers[start.index].uuidString, forType: Self.pasteboardType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let rect = tabRects()[start.index]
        dragging.setDraggingFrame(rect, contents: picture(of: rect))
        beginDraggingSession(with: [dragging], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        pressed = nil
    }

    override func scrollWheel(with event: NSEvent) {
        guard overflows else { return super.scrollWheel(with: event) }
        var delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        if !event.hasPreciseScrollingDeltas { delta *= 12 }
        scroll(to: offset - delta)
    }

    /// The middle button (the mouse wheel pressed) closes a tab; other extra buttons
    /// (back, forward) go on up the responder chain.
    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return super.otherMouseDown(with: event) }
        middlePressed = tabIndex(at: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return super.otherMouseUp(with: event) }
        defer { middlePressed = nil }
        guard let index = middlePressed, tabIndex(at: event) == index else { return }
        onClose?(index)
    }

    private func picture(of rect: NSRect) -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.addRepresentation(rep)
        return image
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext)
        -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    // MARK: - Dropping

    /// The gap nearest to `point`: before the tab whose middle is past it.
    private func insertionIndex(at point: NSPoint) -> Int {
        tabRects().firstIndex { point.x < $0.midX } ?? titles.count
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.string(forType: Self.pasteboardType) != nil else { return [] }
        dropIndex = insertionIndex(at: convert(sender.draggingLocation, from: nil))
        return .move
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        dropIndex = nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let index = dropIndex ?? insertionIndex(at: convert(sender.draggingLocation, from: nil))
        dropIndex = nil
        guard let text = sender.draggingPasteboard.string(forType: Self.pasteboardType),
              let id = UUID(uuidString: text) else { return false }
        return onDropTab?(id, index) ?? false
    }

    /// Drops a tab as if it were dragged there (for the tests).
    func drop(_ id: UUID, at index: Int) -> Bool {
        onDropTab?(id, index) ?? false
    }

    #if DEBUG
    /// Where the tabs show: "shown from to", then "index from to" for each tab, with a
    /// * after the selected one (for the tests).
    var layoutDescription: String {
        let area = tabArea
        return (["shown \(Int(area.minX)) \(Int(area.maxX))"] + tabRects().enumerated().map { index, rect in
            "\(index) \(Int(rect.minX)) \(Int(rect.maxX))" + (index == selectedIndex ? " *" : "")
        }).joined(separator: "\n")
    }
    #endif

    /// The middle of the tab at the index (for the tests).
    func center(ofTab index: Int) -> NSPoint? {
        let rects = tabRects()
        return rects.indices.contains(index) ? NSPoint(x: rects[index].midX, y: rects[index].midY) : nil
    }
}
