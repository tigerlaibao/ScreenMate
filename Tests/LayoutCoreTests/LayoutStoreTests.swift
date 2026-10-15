import Foundation
import XCTest
@testable import LayoutCore

final class LayoutStoreTests: XCTestCase {
    private var root: URL!
    private var directory: URL { root.appendingPathComponent(".screenmate") }
    private var legacy: URL { root.appendingPathComponent("legacy/layouts.json") }
    private let emptyLayout = Layout(displays: [], windows: [])

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func write(_ layouts: [String: Layout], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(layouts).write(to: url)
    }

    func testSaveAndReloadInHiddenDirectory() throws {
        let store = LayoutStore(directory: directory, legacyFileURL: legacy)
        try store.save(emptyLayout, key: "laptop")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("layouts.json").path))
        let loaded = LayoutStore(directory: directory, legacyFileURL: legacy)
        XCTAssertNil(loaded.loadError)
        XCTAssertEqual(Set(loaded.layouts.keys), ["laptop"])
        let permissions = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o700)
    }

    func testLegacyMigrationRetainsOriginalAndDoesNotReimportAfterDeletion() throws {
        try write(["legacy": emptyLayout], to: legacy)
        let original = try Data(contentsOf: legacy)
        let store = LayoutStore(directory: directory, legacyFileURL: legacy)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(Set(store.layouts.keys), ["legacy"])
        XCTAssertEqual(try Data(contentsOf: store.fileURL), original)
        XCTAssertEqual(try Data(contentsOf: legacy), original)
        try store.remove(key: "legacy")
        XCTAssertTrue(LayoutStore(directory: directory, legacyFileURL: legacy).layouts.isEmpty)
    }

    func testExistingNewConfigurationTakesPrecedence() throws {
        try write(["legacy": emptyLayout], to: legacy)
        try write(["current": emptyLayout], to: directory.appendingPathComponent("layouts.json"))
        let store = LayoutStore(directory: directory, legacyFileURL: legacy)
        XCTAssertEqual(Set(store.layouts.keys), ["current"])
    }

    func testCorruptCurrentFileIsNotOverwrittenOrReplacedByLegacy() throws {
        try write(["legacy": emptyLayout], to: legacy)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("layouts.json")
        let corrupt = Data("invalid json".utf8)
        try corrupt.write(to: file)
        let store = LayoutStore(directory: directory, legacyFileURL: legacy)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.save(emptyLayout, key: "new"))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    func testCorruptLegacyFileDoesNotCreateOrOverwriteConfiguration() throws {
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("invalid json".utf8).write(to: legacy)
        let store = LayoutStore(directory: directory, legacyFileURL: legacy)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.save(emptyLayout, key: "new"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
