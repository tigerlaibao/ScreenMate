import XCTest
@testable import LayoutCore

final class LayoutTests: XCTestCase {
    func screen(_ id: String, x: Double = 0, y: Double = 0, width: Double = 1440, height: Double = 900) -> Display {
        Display(id: id, name: id, frame: Rect(x: x, y: y, width: width, height: height),
                visible: Rect(x: x, y: y + 25, width: width, height: height - 25))
    }
    func window(_ title: String, id: String = "", bundle: String = "test.app") -> SavedWindow {
        SavedWindow(bundleID: bundle, title: title, identifier: id, displayID: "A",
                    frame: Rect(x: 0, y: 30, width: 500, height: 400))
    }

    func testTopologyIgnoresEnumerationOrderAndArrangement() {
        XCTAssertEqual(LayoutGeometry.key([screen("A"), screen("B", x: 1440)]),
                       LayoutGeometry.key([screen("B", x: -1440), screen("A")]))
        XCTAssertNotEqual(LayoutGeometry.key([screen("A")]), LayoutGeometry.key([screen("B")]))
        XCTAssertNotEqual(LayoutGeometry.key([screen("A")]), LayoutGeometry.key([screen("A", width: 1280)]))
    }

    func testLaptopOnlyOneAndTwoSameModelMonitorsHaveSeparateLayouts() {
        let laptop = screen("laptop")
        var home = screen("home-uuid")
        var work = screen("work-uuid")
        home.name = "Same Monitor Model"
        work.name = "Same Monitor Model"
        let keys = [
            LayoutGeometry.key([laptop]),
            LayoutGeometry.key([laptop, home]),
            LayoutGeometry.key([laptop, work]),
            LayoutGeometry.key([laptop, home, work])
        ]
        XCTAssertEqual(Set(keys).count, 4)
    }

    func testWindowFollowsDisplayToNegativeCoordinates() {
        let frame = Rect(x: 1500, y: 125, width: 800, height: 600)
        let restored = LayoutGeometry.restored(frame, from: screen("B", x: 1440), to: screen("B", x: -1440, y: -200))
        XCTAssertEqual(restored, Rect(x: -1380, y: -75, width: 800, height: 600))
    }

    func testOversizedAndOffscreenWindowIsClampedToUsableArea() {
        let restored = LayoutGeometry.restored(Rect(x: 4000, y: -600, width: 3000, height: 2000),
                                              from: screen("A"), to: screen("A", width: 1280, height: 800))
        XCTAssertEqual(restored, Rect(x: 0, y: 25, width: 1280, height: 775))
    }

    func testAssignSpanningWindowToLargestIntersection() {
        let rect = Rect(x: 1300, y: 50, width: 800, height: 700)
        XCTAssertEqual(LayoutGeometry.display(for: rect, in: [screen("A"), screen("B", x: 1440)])?.id, "B")
        XCTAssertNil(LayoutGeometry.display(for: rect, in: []))
    }

    func testExactTitleMatchIsReservedBeforeChangedTitleFallback() {
        let matches = WindowMatcher.matches(saved: [window("old"), window("keep")], live: [window("keep"), window("new")])
        XCTAssertEqual(matches.map { "\($0.0):\($0.1)" }, ["1:0", "0:1"])
    }

    func testStableIdentifiersSurviveTitleChanges() {
        let matches = WindowMatcher.matches(saved: [window("oldA", id: "A"), window("oldB", id: "B")],
                                            live: [window("newB", id: "B"), window("newA", id: "A")])
        XCTAssertEqual(matches.map { "\($0.0):\($0.1)" }, ["0:1", "1:0"])
    }

    func testAmbiguousTitlesAndOtherAppsAreNotMoved() {
        XCTAssertTrue(WindowMatcher.matches(saved: [window("A"), window("B")], live: [window("C"), window("D")]).isEmpty)
        XCTAssertTrue(WindowMatcher.matches(saved: [window("same")], live: [window("same", bundle: "other.app")]).isEmpty)
    }

    func testOneLiveWindowIsNeverMatchedTwice() {
        let matches = WindowMatcher.matches(saved: [window("same"), window("same")], live: [window("same")])
        XCTAssertTrue(matches.isEmpty)
    }

    func testGenericIdentifiersDoNotOverrideDistinctTitles() {
        let matches = WindowMatcher.matches(saved: [window("A", id: "generic"), window("B", id: "generic")],
                                            live: [window("B", id: "generic"), window("A", id: "generic")])
        XCTAssertEqual(matches.map { "\($0.0):\($0.1)" }, ["0:1", "1:0"])
    }

    func testPersistenceRoundTrip() throws {
        let layout = Layout(displays: [screen("A")], windows: [window("中文窗口标题")])
        let data = try JSONEncoder().encode([LayoutGeometry.key(layout.displays): layout])
        let decoded = try JSONDecoder().decode([String: Layout].self, from: data)
        let result = try XCTUnwrap(decoded[LayoutGeometry.key(layout.displays)])
        XCTAssertEqual(result.windows.first?.title, "中文窗口标题")
        XCTAssertEqual(result.displays, layout.displays)
    }
}
