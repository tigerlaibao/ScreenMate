import AppKit
import ApplicationServices
import LayoutCore

struct LiveWindow {
    let element: AXUIElement
    let snapshot: SavedWindow
}

enum WindowService {
    static var trusted: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func displays() -> [Display] {
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        return NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
            let identifier = CFUUIDCreateString(nil, uuid)! as String
            let visible = screen.visibleFrame
            return Display(id: identifier, name: screen.localizedName,
                           frame: Rect(CGDisplayBounds(id)),
                           visible: Rect(x: visible.minX, y: primaryHeight - visible.maxY,
                                         width: visible.width, height: visible.height))
        }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func frame(of window: AXUIElement) -> Rect? {
        guard let position = attribute(window, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let positionValue = position as! AXValue
        let sizeValue = size as! AXValue
        guard AXValueGetType(positionValue) == .cgPoint, AXValueGetType(sizeValue) == .cgSize else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &dimensions),
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        return Rect(CGRect(origin: point, size: dimensions))
    }

    static func windows(displays: [Display], bundleIDs: Set<String>? = nil) -> [LiveWindow] {
        guard trusted else { return [] }
        var result: [LiveWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            guard let bundleID = app.bundleIdentifier else { continue }
            if let bundleIDs, !bundleIDs.contains(bundleID) { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.2)
            guard let windows = attribute(element, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for window in windows {
                let subrole = attribute(window, kAXSubroleAttribute) as? String
                guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole,
                      attribute(window, kAXMinimizedAttribute) as? Bool != true,
                      attribute(window, "AXFullScreen") as? Bool != true,
                      let rect = frame(of: window) else { continue }
                guard let display = LayoutGeometry.display(for: rect, in: displays) else { continue }
                let snapshot = SavedWindow(bundleID: bundleID,
                                           title: attribute(window, kAXTitleAttribute) as? String ?? "",
                                           identifier: attribute(window, kAXIdentifierAttribute) as? String ?? "",
                                           displayID: display.id, frame: rect)
                result.append(LiveWindow(element: window, snapshot: snapshot))
            }
        }
        return result
    }

    static func restore(_ layout: Layout, displays: [Display], shouldContinue: @escaping () -> Bool,
                        completion: @escaping (Int, Int) -> Void) {
        let live = windows(displays: displays)
        let matches = WindowMatcher.matches(saved: layout.windows, live: live.map(\.snapshot))
        var handles: [Int: AXUIElement] = [:]
        var targets: [WindowRestoreTarget] = []
        for (savedIndex, liveIndex) in matches {
            let saved = layout.windows[savedIndex]
            guard let old = layout.displays.first(where: { $0.id == saved.displayID }),
                  let new = displays.first(where: { $0.id == saved.displayID }) else { continue }
            handles[savedIndex] = live[liveIndex].element
            targets.append(WindowRestoreTarget(id: savedIndex, frame: LayoutGeometry.restored(saved.frame, from: old, to: new)))
        }
        let operation = WindowRestoration(targets: targets, read: { index in
            if let handle = handles[index], let actual = frame(of: handle) { return actual }
            // Some apps recreate the window during display changes. Resolve a stale handle again.
            let refreshed = windows(displays: displays, bundleIDs: [layout.windows[index].bundleID])
            for (savedIndex, liveIndex) in WindowMatcher.matches(saved: layout.windows, live: refreshed.map(\.snapshot)) {
                handles[savedIndex] = refreshed[liveIndex].element
            }
            guard let handle = handles[index] else { return nil }
            return frame(of: handle)
        }, apply: { index, target in
            guard let element = handles[index],
                  attribute(element, kAXMinimizedAttribute) as? Bool != true,
                  attribute(element, "AXFullScreen") as? Bool != true else { return }
            var point = CGPoint(x: target.x, y: target.y)
            var size = CGSize(width: target.width, height: target.height)
            guard let position = AXValueCreate(.cgPoint, &point), let dimensions = AXValueCreate(.cgSize, &size) else { return }
            _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
            _ = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, dimensions)
            _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
        }, shouldContinue: shouldContinue, schedule: { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        }, completion: { restored in completion(restored, layout.windows.count) })
        operation.start()
    }
}
