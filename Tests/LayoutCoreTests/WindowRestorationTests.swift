import XCTest
@testable import LayoutCore

final class WindowRestorationTests: XCTestCase {
    private let target = Rect(x: -1200, y: 30, width: 1100, height: 800)
    private let displaced = Rect(x: 0, y: 30, width: 900, height: 600)

    private final class Clock {
        var pending: [() -> Void] = []
        func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) {
            XCTAssertEqual(delay, 0.25)
            pending.append(action)
        }
        func advance() { XCTAssertFalse(pending.isEmpty); pending.removeFirst()() }
        func drain() {
            var steps = 0
            while !pending.isEmpty && steps < 20 { advance(); steps += 1 }
            XCTAssertLessThan(steps, 20, "Restoration must terminate")
        }
    }

    func testAcceptedButIgnoredWritesAreNotReportedAsRestored() {
        let clock = Clock()
        var writes = 0, result: Int?
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in self.displaced },
                                          apply: { _, _ in writes += 1 }, shouldContinue: { true },
                                          schedule: clock.schedule, completion: { result = $0 })
        operation.start(); clock.drain()
        XCTAssertEqual(writes, 3)
        XCTAssertEqual(result, 0)
    }

    func testRevertedWindowIsRetriedAndConfirmedBeforeSuccess() {
        let clock = Clock()
        var actual = displaced
        var writes = 0, result: Int?
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in actual },
                                          apply: { _, frame in writes += 1; actual = frame }, shouldContinue: { true },
                                          schedule: clock.schedule, completion: { result = $0 })
        operation.start()
        clock.advance() // First successful observation is not enough.
        XCTAssertNil(result)
        actual = displaced // Simulate an app relayout after accepting the first move.
        clock.advance()
        XCTAssertEqual(writes, 2)
        XCTAssertNil(result)
        clock.drain()
        XCTAssertEqual(result, 1)
        XCTAssertEqual(actual, target)
    }

    func testDelayedMoveIsObservedWithoutBlocking() {
        let clock = Clock()
        var actual = displaced
        var writes = 0, result: Int?
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in actual },
                                          apply: { _, _ in writes += 1 }, shouldContinue: { true },
                                          schedule: clock.schedule, completion: { result = $0 })
        operation.start()
        actual = target // Simulate an asynchronous Accessibility write becoming visible.
        clock.drain()
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(result, 1)
    }

    func testCancelOnNewDisplaySetupStopsRetriesAndCompletion() {
        let clock = Clock()
        var active = true
        var writes = 0, completed = false
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in self.displaced },
                                          apply: { _, _ in writes += 1 }, shouldContinue: { active },
                                          schedule: clock.schedule, completion: { _ in completed = true })
        operation.start(); active = false; clock.drain()
        XCTAssertEqual(writes, 1)
        XCTAssertFalse(completed)
    }

    func testAlreadyPlacedWindowsAreNotMovedAndRoundingIsTolerated() {
        let clock = Clock()
        var actual = target
        actual.x += 1; actual.height -= 1
        var result: Int?
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in actual },
                                          apply: { _, _ in XCTFail("Already placed windows should not be moved") },
                                          shouldContinue: { true }, schedule: clock.schedule, completion: { result = $0 })
        operation.start(); clock.drain()
        XCTAssertEqual(result, 1)
    }

    func testMissingWindowsTerminateWithoutFalseSuccess() {
        let clock = Clock()
        var result: Int?
        let operation = WindowRestoration(targets: [.init(id: 0, frame: target)], read: { _ in nil },
                                          apply: { _, _ in }, shouldContinue: { true }, schedule: clock.schedule,
                                          completion: { result = $0 })
        operation.start(); clock.drain()
        XCTAssertEqual(result, 0)
    }
}
