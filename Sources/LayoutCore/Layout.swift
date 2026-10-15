import Foundation
import CoreGraphics

public struct Rect: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    public init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

public struct Display: Codable, Equatable {
    public var id: String
    public var name: String
    public var frame: Rect
    public var visible: Rect
    public init(id: String, name: String, frame: Rect, visible: Rect) {
        self.id = id; self.name = name; self.frame = frame; self.visible = visible
    }
}

public struct SavedWindow: Codable {
    public var bundleID: String
    public var title: String
    public var identifier: String
    public var displayID: String
    public var frame: Rect
    public init(bundleID: String, title: String, identifier: String, displayID: String, frame: Rect) {
        self.bundleID = bundleID; self.title = title; self.identifier = identifier
        self.displayID = displayID; self.frame = frame
    }
}

public struct Layout: Codable {
    public var displays: [Display]
    public var windows: [SavedWindow]
    public var savedAt: Date
    public init(displays: [Display], windows: [SavedWindow], savedAt: Date = Date()) {
        self.displays = displays; self.windows = windows; self.savedAt = savedAt
    }
}

public enum LayoutGeometry {
    // Arrangement is deliberately excluded: moving a display should move its windows with it.
    public static func key(_ displays: [Display]) -> String {
        displays.map { "\($0.id):\(Int($0.frame.width))x\(Int($0.frame.height))" }.sorted().joined(separator: "|")
    }

    public static func display(for rect: Rect, in displays: [Display]) -> Display? {
        displays.max {
            area(rect.cgRect.intersection($0.frame.cgRect)) < area(rect.cgRect.intersection($1.frame.cgRect))
        }
    }

    private static func area(_ rect: CGRect) -> Double {
        rect.isNull ? 0 : rect.width * rect.height
    }

    public static func restored(_ rect: Rect, from old: Display, to new: Display) -> Rect {
        let width = min(rect.width, new.visible.width)
        let height = min(rect.height, new.visible.height)
        let x = new.visible.x + rect.x - old.visible.x
        let y = new.visible.y + rect.y - old.visible.y
        return Rect(x: min(max(x, new.visible.x), new.visible.x + new.visible.width - width),
                    y: min(max(y, new.visible.y), new.visible.y + new.visible.height - height),
                    width: width, height: height)
    }
}

public enum WindowMatcher {
    // Strong matches first so a changed title cannot consume another window's exact match.
    public static func matches(saved: [SavedWindow], live: [SavedWindow]) -> [(Int, Int)] {
        var candidates: [(Int, Int, Int)] = []
        for (s, window) in saved.enumerated() {
            for (l, current) in live.enumerated() where window.bundleID == current.bundleID {
                let score: Int
                let uniqueID = !window.identifier.isEmpty && window.identifier == current.identifier
                    && saved.filter { $0.bundleID == window.bundleID && $0.identifier == window.identifier }.count == 1
                    && live.filter { $0.bundleID == window.bundleID && $0.identifier == window.identifier }.count == 1
                let uniqueTitle = !window.title.isEmpty && window.title == current.title
                    && saved.filter { $0.bundleID == window.bundleID && $0.title == window.title }.count == 1
                    && live.filter { $0.bundleID == window.bundleID && $0.title == window.title }.count == 1
                if uniqueID {
                    score = 3
                } else if uniqueTitle {
                    score = 2
                } else { score = 1 }
                candidates.append((s, l, score))
            }
        }
        candidates.sort {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            if $0.0 != $1.0 { return $0.0 < $1.0 }
            return $0.1 < $1.1
        }
        var usedSaved = Set<Int>(), usedLive = Set<Int>()
        var result: [(Int, Int)] = []
        for (s, l, score) in candidates where !usedSaved.contains(s) && !usedLive.contains(l) {
            // Ambiguous changed titles are left alone; a unique remaining window is safe to use.
            let exact = score > 1
            let remainingSaved = saved.indices.filter { !usedSaved.contains($0) && saved[$0].bundleID == saved[s].bundleID }
            let remainingLive = live.indices.filter { !usedLive.contains($0) && live[$0].bundleID == saved[s].bundleID }
            guard exact || (remainingSaved.count == 1 && remainingLive.count == 1) else { continue }
            usedSaved.insert(s); usedLive.insert(l); result.append((s, l))
        }
        return result
    }
}
