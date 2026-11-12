import AppKit

/// Horizontal geometry of the Full view columns: Name | Ext | Size | Date |
/// optional metadata columns | Attr. Fixed columns keep their width (measured, or
/// the column set's own, dragged in the header); Name takes the rest, and in a narrow
/// panel the other columns give way to it.
struct ColumnLayout {
    static let minimumNameWidth: CGFloat = 60
    /// Below this Name width, Attr, optional columns, Date and Size are left out in
    /// turn.
    static let preferredNameWidth: CGFloat = 140
    /// The narrowest a column can be dragged to.
    static let minimumColumnWidth: CGFloat = 24

    private static var cachedWidths: (key: String, widths: [(SortColumn, CGFloat)])?

    /// Widths of the columns after Name, measured with the current panel font.
    static func fixedWidths(of shown: [SortColumn]) -> [(SortColumn, CGFloat)] {
        let font = Theme.panelNumberFont
        let columns = [.name] + shown
        let key = "\(font.fontName) \(font.pointSize) \(columns.map(\.rawValue))"
        if let cachedWidths, cachedWidths.key == key { return cachedWidths.widths }
        let sampleDate = Theme.dateText(Date(timeIntervalSince1970: 1_798_761_540))
        func width(_ sample: String) -> CGFloat {
            ceil((sample as NSString).size(withAttributes: [.font: font]).width) + 12
        }
        let widths: [(SortColumn, CGFloat)] = columns.dropFirst().map { column in
            return switch column {
            // Four wide letters, or five where all letters are as wide as a digit.
            case .ext: (column, max(width("WWWW"), width("00000"), 44))
            case .size: (column, width("999 999 999"))
            case .date, .created: (column, width(sampleDate))
            case .attr: (column, width("rwxrwxrwx"))
            case .kind: (column, max(width("Markdown document"), 110))
            case .dimensions: (column, width("99999 × 99999"))
            case .duration: (column, width("99:59:59"))
            case .tags: (column, 110)
            case .comment: (column, 160)
            case .name: (column, 0)
            }
        }
        cachedWidths = (key, widths)
        return widths
    }

    private(set) var frames: [SortColumn: (x: CGFloat, width: CGFloat)] = [:]
    /// The columns that fit, in order (Name first).
    private(set) var columns: [SortColumn] = []
    /// The optional metadata columns in this layout.
    private(set) var extraColumns: [SortColumn] = []

    /// `shown`: the columns after Name (a column set's); `widths`: the set's own
    /// widths; `inset`: the room left free at each side.
    init(width: CGFloat, columns shown: [SortColumn], widths: [SortColumn: CGFloat], inset: CGFloat = 0) {
        let width = width - 2 * inset
        var fixedWidths = Self.fixedWidths(of: shown).map { ($0.0, widths[$0.0] ?? $0.1) }
        // Keep names readable: drop Attr first, then optional columns from the right,
        // then the date and the size.
        while width - fixedWidths.reduce(0, { $0 + $1.1 }) < Self.preferredNameWidth,
              let index = fixedWidths.firstIndex(where: { $0.0 == .attr })
                ?? fixedWidths.lastIndex(where: { SortColumn.extras.contains($0.0) })
                ?? fixedWidths.firstIndex(where: { $0.0 == .date })
                ?? fixedWidths.firstIndex(where: { $0.0 == .size }) {
            fixedWidths.remove(at: index)
        }
        let fixed = fixedWidths.reduce(0) { $0 + $1.1 }
        let nameWidth = max(width - fixed, Self.minimumNameWidth)
        frames[.name] = (inset, nameWidth)
        var x = inset + nameWidth
        for (column, columnWidth) in fixedWidths {
            frames[column] = (x, columnWidth)
            x += columnWidth
        }
        columns = [.name] + fixedWidths.map(\.0)
        extraColumns = columns.filter(SortColumn.extras.contains)
    }

    func contains(_ column: SortColumn) -> Bool {
        frames[column] != nil
    }

    func rect(for column: SortColumn, y: CGFloat, height: CGFloat) -> NSRect {
        let frame = frames[column]!
        return NSRect(x: frame.x, y: y, width: frame.width, height: height)
    }

    func column(at x: CGFloat) -> SortColumn? {
        frames.first { x >= $0.value.x && x < $0.value.x + $0.value.width }?.key
    }

    func width(of column: SortColumn) -> CGFloat {
        frames[column]?.width ?? 0
    }

    /// The edge between two columns near `x` (within `slop`), named by the column it
    /// resizes: the one left of it, or for Name's edge the one right of it (Name
    /// takes what is left), and how its width changes as the edge moves right.
    func resizableEdge(near x: CGFloat, slop: CGFloat = 3) -> (column: SortColumn, sign: CGFloat, x: CGFloat)? {
        for (index, column) in columns.dropLast().enumerated() {
            guard let frame = frames[column] else { continue }
            let edge = frame.x + frame.width
            guard abs(x - edge) <= slop else { continue }
            return column == .name ? (columns[index + 1], -1, edge) : (column, 1, edge)
        }
        return nil
    }
}
