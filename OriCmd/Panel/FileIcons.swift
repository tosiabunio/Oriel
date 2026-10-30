import AppKit
import UniformTypeIdentifiers

/// Small file icons, cached by extension (packages by path).
enum FileIcons {
    private static let size = NSSize(width: 16, height: 16)
    private static var byExtension: [String: NSImage] = [:]
    private static var byPackagePath: [String: NSImage] = [:]
    private static var unreadableFolders: [String: NSImage] = [:]

    private static let folder = sized(NSWorkspace.shared.icon(for: .folder))
    /// In the label color, so it shows in dark mode too.
    private static let parent = NSImage(systemSymbolName: "arrow.turn.left.up", accessibilityDescription: "Parent folder")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])) ?? folder

    static func icon(for item: FileItem) -> NSImage {
        if item.isParent { return parent }
        if item.isFolder, item.isUnreadable {
            return cached(&unreadableFolders, item.url.path) { unreadableFolder(item.url) }
        }
        if item.isFolder { return item.tagColor == 0 ? folder : folder(tagColor: item.tagColor) }
        if item.isPackage {
            return cached(&byPackagePath, item.url.path) { NSWorkspace.shared.icon(forFile: item.url.path) }
        }
        let ext = item.fileExtension.lowercased()
        return cached(&byExtension, ext) {
            NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
        }
    }

    /// The large icon of what an operation acts on: the item's own, a folder for several
    /// folders, the Finder's stack of documents for several files.
    static func icon(for urls: [URL]) -> NSImage {
        if urls.count > 1, urls.allSatisfy({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }) {
            return NSWorkspace.shared.icon(for: .folder)
        }
        return NSWorkspace.shared.icon(forFiles: urls.map(\.path)) ?? NSWorkspace.shared.icon(for: .data)
    }

    /// A folder that cannot be opened as the Finder shows it, with its no-entry badge:
    /// its own icon, as the system makes it for that folder.
    static func unreadableFolder(_ url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    private static var tintedFolders: [String: NSImage] = [:]

    /// The folder icon in the color of a tag (a label number) at `size`, its shading kept,
    /// as the Finder colors tagged folders; the plain icon for no color.
    static func folder(tagColor: Int, size: NSSize = size) -> NSImage {
        let base = size == Self.size ? folder : NSWorkspace.shared.icon(for: .folder)
        let colors = NSWorkspace.shared.fileLabelColors
        guard tagColor > 0, colors.indices.contains(tagColor) else { return base }
        let color = colors[tagColor]
        let key = "\(tagColor) \(Int(size.width))"
        if let image = tintedFolders[key] { return image }
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            // The icon takes the color's hue and keeps its own light and shade; drawn
            // again over it, the icon's outline cuts away what fell outside it.
            color.setFill()
            rect.fill(using: .color)
            base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        tintedFolders[key] = image
        return image
    }

    private static func cached(_ cache: inout [String: NSImage], _ key: String, _ make: () -> NSImage) -> NSImage {
        if let image = cache[key] { return image }
        let image = sized(make())
        cache[key] = image
        return image
    }

    private static func sized(_ image: NSImage) -> NSImage {
        image.size = size
        return image
    }
}
