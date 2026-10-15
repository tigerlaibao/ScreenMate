import Foundation

public struct WindowRestoreTarget {
    public let id: Int
    public let frame: Rect
    public init(id: Int, frame: Rect) { self.id = id; self.frame = frame }
}

/// Confirms geometry across two observations, retrying rejected or reverted moves a bounded number of times.
public final class WindowRestoration {
    public typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void
    private let targets: [WindowRestoreTarget]
    private let read: (Int) -> Rect?
    private let apply: (Int, Rect) -> Void
    private let shouldContinue: () -> Bool
    private let schedule: Scheduler
    private let completion: (Int) -> Void
    private var attempts: [Int: Int] = [:]
    private var confirmations: [Int: Int] = [:]
    private var finished = Set<Int>()
    private var restored = 0
    private var started = false
    private let maximumAttempts = 3

    public init(targets: [WindowRestoreTarget], read: @escaping (Int) -> Rect?,
                apply: @escaping (Int, Rect) -> Void, shouldContinue: @escaping () -> Bool,
                schedule: @escaping Scheduler, completion: @escaping (Int) -> Void) {
        self.targets = targets; self.read = read; self.apply = apply
        self.shouldContinue = shouldContinue; self.schedule = schedule; self.completion = completion
    }

    public func start() {
        guard !started else { return }
        started = true
        observe()
    }

    public static func matches(_ actual: Rect, _ target: Rect, tolerance: Double = 2) -> Bool {
        abs(actual.x - target.x) <= tolerance && abs(actual.y - target.y) <= tolerance
            && abs(actual.width - target.width) <= tolerance && abs(actual.height - target.height) <= tolerance
    }

    private func observe() {
        guard shouldContinue() else { return }
        for target in targets where !finished.contains(target.id) {
            // Cancellation can happen while a window provider processes an event.
            guard shouldContinue() else { return }
            if let actual = read(target.id), Self.matches(actual, target.frame) {
                confirmations[target.id, default: 0] += 1
                if confirmations[target.id, default: 0] >= 2 {
                    finished.insert(target.id); restored += 1
                }
            } else {
                confirmations[target.id] = 0
                guard attempts[target.id, default: 0] < maximumAttempts else {
                    finished.insert(target.id); continue
                }
                attempts[target.id, default: 0] += 1
                apply(target.id, target.frame)
            }
        }
        if finished.count == targets.count { completion(restored); return }
        schedule(0.25) { self.observe() }
    }
}
