import Foundation

public final class LayoutStore {
    public let fileURL: URL
    public private(set) var layouts: [String: Layout] = [:]
    public private(set) var loadError: Error?

    public init(directory: URL? = nil, legacyFileURL: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        fileURL = (directory ?? home.appendingPathComponent(".screenmate", isDirectory: true))
            .appendingPathComponent("layouts.json")
        let legacy = legacyFileURL ?? home.appendingPathComponent("Library/Application Support/ScreenMate/layouts.json")
        let manager = FileManager.default
        let currentExists = manager.fileExists(atPath: fileURL.path)
        let source = currentExists ? fileURL : legacy
        guard manager.fileExists(atPath: source.path) else { return }
        do {
            let data = try Data(contentsOf: source)
            let decoded = try JSONDecoder().decode([String: Layout].self, from: data)
            if !currentExists {
                // Migrate only a validated legacy file, retaining the original as a backup.
                try createDirectory()
                try data.write(to: fileURL, options: .atomic)
            }
            layouts = decoded
        } catch { loadError = error }
    }

    public func save(_ layout: Layout, key: String) throws {
        var updated = layouts
        updated[key] = layout
        try persist(updated)
    }

    public func remove(key: String) throws {
        var updated = layouts
        updated.removeValue(forKey: key)
        try persist(updated)
    }

    private func createDirectory() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }

    private func persist(_ updated: [String: Layout]) throws {
        // Never overwrite data that failed to load, including a corrupt legacy file.
        if let loadError { throw loadError }
        try createDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: fileURL, options: .atomic)
        layouts = updated
    }
}
