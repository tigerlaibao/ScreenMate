import Foundation
import XCTest
@testable import Localization

final class LocalizationTests: XCTestCase {
    private func catalog(_ language: String) throws -> [String: String] {
        let url = L10n.resourceURL.appendingPathComponent("\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }

    func testAllLanguagesHaveEveryKeyAndCompatibleFormatSpecifiers() throws {
        let english = try catalog("en")
        let expression = try NSRegularExpression(pattern: "%[@d]")
        func placeholders(_ string: String) -> [String] {
            let range = NSRange(string.startIndex..., in: string)
            return expression.matches(in: string, range: range).map { (string as NSString).substring(with: $0.range) }
        }
        for language in L10n.languages {
            let translated = try catalog(language.code)
            XCTAssertEqual(Set(english.keys), Set(translated.keys), language.code)
            for (key, value) in translated {
                XCTAssertFalse(value.isEmpty, "\(language.code):\(key)")
                XCTAssertEqual(placeholders(value), placeholders(english[key] ?? ""), "\(language.code):\(key)")
                XCTAssertEqual(L10n.text(key, language: language.code), value)
            }
        }
    }

    func testUnknownLanguageFallsBackToEnglish() {
        XCTAssertEqual(L10n.text("save_action", language: "missing"), "Save Current Layout")
    }

    func testUserLanguageOverrideAndFormatting() {
        let previous = L10n.override
        defer { L10n.override = previous }
        L10n.override = "zh-Hans"
        XCTAssertEqual(L10n.language, "zh-Hans")
        XCTAssertEqual(L10n.format("restored_status", 3, 5), "已恢复窗口：3/5")
        L10n.override = "en"
        XCTAssertEqual(L10n.format("restored_status", 3, 5), "Restored windows: 3/5")
    }
}
