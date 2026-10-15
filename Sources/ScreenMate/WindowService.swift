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

    static func windows(displays: [Display]) -> [LiveWindow] {
        guard trusted else { return [] }
        var result: [LiveWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            guard let bundleID = app.bundleIdentifier else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.2)
            guard let windows = attribute(element, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for window in windows {
                let subrole = attribute(window, kAXSubroleAttribute) as? String
                guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole,
                      attribute(window, kAXMinimizedAttribute) as? Bool != true,
                      attribute(window, "AXFullScreen") as? Bool != true,
                      let position = attribute(window, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
                      let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { continue }
                var point = CGPoint.zero, dimensions = CGSize.zero
                guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
                      AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
                      dimensions.width > 0, dimensions.height > 0 else { continue }
                let rect = Rect(CGRect(origin: point, size: dimensions))
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

    static func restore(_ layout: Layout, displays: [Display]) -> (restored: Int, total: Int) {
        let live = windows(displays: displays)
        let matches = WindowMatcher.matches(saved: layout.windows, live: live.map(\.snapshot))
        var restored = 0
        for (savedIndex, liveIndex) in matches {
            let saved = layout.windows[savedIndex]
            guard let old = layout.displays.first(where: { $0.id == saved.displayID }),
                  let new = displays.first(where: { $0.id == saved.displayID }) else { continue }
            let frame = LayoutGeometry.restored(saved.frame, from: old, to: new)
            let element = live[liveIndex].element
            var point = CGPoint(x: frame.x, y: frame.y)
            var size = CGSize(width: frame.width, height: frame.height)
            guard let positionValue = AXValueCreate(.cgPoint, &point), let sizeValue = AXValueCreate(.cgSize, &size) else { continue }
            // Moving before and after resizing handles cross-display size constraints.
            _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
            let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
            let positionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
            if positionResult == .success && (sizeResult == .success || sizeResult == .attributeUnsupported) {
                restored += 1
            }
        }
        return (restored, layout.windows.count)
    }
}
