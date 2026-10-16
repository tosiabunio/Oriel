import AppKit
import SwiftTerm

/// The 16 ANSI colors of the server terminal, made of the system's colors so that each
/// reads on the panel's background. SwiftTerm's own (Terminal.app's Basic) has a dark
/// blue, red and magenta that are hard to read on a dark background.
enum TerminalPalette {
    /// Black, red, green, yellow, blue, magenta, cyan and white, then their bright
    /// variants. On a light background the plain colors are the system's darkened and
    /// the bright ones the system's own; on a dark one the plain colors are the
    /// system's and the bright ones lightened.
    static func colors(onDark dark: Bool) -> [SwiftTerm.Color] {
        let hues = [NSColor.systemRed, .systemGreen, .systemYellow, .systemBlue, .systemPurple, .systemCyan]
            .map { resolved($0, dark: dark) }
        let plain = dark ? hues : hues.map { $0.blended(withFraction: 0.35, of: .black) ?? $0 }
        let bright = dark ? hues.map { $0.blended(withFraction: 0.3, of: .white) ?? $0 } : hues
        let palette = [NSColor.black] + plain + [NSColor(white: dark ? 0.9 : 0.7, alpha: 1)]
            + [resolved(.systemGray, dark: dark)] + bright + [NSColor.white]
        return palette.map(terminalColor)
    }

    /// Whether text on `background` needs light colors.
    static func isDark(_ background: NSColor) -> Bool {
        guard let rgb = background.usingColorSpace(.sRGB) else { return false }
        return 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent < 0.5
    }

    private static func resolved(_ color: NSColor, dark: Bool) -> NSColor {
        var result = color
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            result = color.usingColorSpace(.sRGB) ?? color
        }
        return result
    }

    private static func terminalColor(_ color: NSColor) -> SwiftTerm.Color {
        let rgb = color.usingColorSpace(.sRGB) ?? .black
        func channel(_ value: CGFloat) -> UInt16 { UInt16((min(max(value, 0), 1) * 65535).rounded()) }
        return SwiftTerm.Color(red: channel(rgb.redComponent), green: channel(rgb.greenComponent),
                               blue: channel(rgb.blueComponent))
    }
}
