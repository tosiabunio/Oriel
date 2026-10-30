import AppKit

/// The Finder's tags of files. The Finder keeps them with their colors in an extended
/// attribute ("Czerwony\n6"); a tag written by a name the Finder knows gets its color,
/// any other name none. The names of the color tags depend on the user's language and
/// renaming, so they are found out, not assumed ("Red" on a Polish Mac is a new tag).
enum FinderTags {
    /// The colors as the Finder lists them, red to gray (as label numbers).
    static let colors = [6, 7, 5, 2, 4, 3, 1]

    /// A file's tags with their colors (0: none).
    static func tags(of url: URL) -> [(name: String, color: Int)] {
        let attribute = "com.apple.metadata:_kMDItemUserTags"
        let data = url.withUnsafeFileSystemRepresentation { path -> Data? in
            guard let path else { return nil }
            let size = getxattr(path, attribute, nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { getxattr(path, attribute, $0.baseAddress, size, 0, 0) }
            return read == size ? data : nil
        }
        guard let data, let entries = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
            return []
        }
        return entries.map { entry in
            let parts = entry.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]), parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
        }
    }

    /// The files with the tag `name`, as Spotlight finds them (only in `folder`, if given).
    static func files(taggedWith name: String, in folder: URL? = nil) async -> [URL] {
        let quoted = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var arguments = ["-0"]
        if let folder { arguments += ["-onlyin", folder.path] }
        arguments.append("kMDItemUserTags == \"\(quoted)\"")
        guard let found = try? await ProcessRunner.run("/usr/bin/mdfind", arguments), found.status == 0 else { return [] }
        return found.text.split(separator: "\0").map { URL(filePath: String($0)) }
    }

    /// The Finder's names of the colors: its favorite tags and the standard names, each
    /// tried on a scratch file to see which color it gets.
    static func colorNames() -> [Int: String] {
        #if DEBUG
        // README screenshots show the English names, whatever the Finder's language.
        if ProcessInfo.processInfo.environment["ORICMD_DEMO"] != nil {
            return [6: "Red", 7: "Orange", 5: "Yellow", 2: "Green", 4: "Blue", 3: "Purple", 1: "Gray"]
        }
        #endif
        let candidates = (UserDefaults(suiteName: "com.apple.finder")?.stringArray(forKey: "FavoriteTagNames") ?? [])
            + NSWorkspace.shared.fileLabels
        let scratch = FileManager.default.temporaryDirectory.appending(path: "OriCmd-tags-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: scratch.path, contents: nil) else { return [:] }
        defer { try? FileManager.default.removeItem(at: scratch) }
        var names: [Int: String] = [:]
        for name in candidates where !name.isEmpty && !names.values.contains(name) {
            try? (scratch as NSURL).setResourceValue([name], forKey: .tagNamesKey)
            if let color = tags(of: scratch).first?.color, colors.contains(color), names[color] == nil {
                names[color] = name
            }
            if names.count == colors.count { break }
        }
        return names
    }

    static func setTags(_ names: [String], of url: URL) throws {
        try (url as NSURL).setResourceValue(names, forKey: .tagNamesKey)
    }
}
