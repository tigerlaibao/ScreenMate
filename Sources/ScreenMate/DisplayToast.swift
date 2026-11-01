import AppKit
import Localization

private final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ToastView: NSView {
    var title = "" { didSet { titleLabel.stringValue = title } }
    var detail = "" { didSet { detailLabel.stringValue = detail } }
    var progress: Double = 0 { didSet { needsDisplay = true } }
    var counter = "" { didSet { counterLabel.stringValue = counter } }
    private let mint = NSColor(calibratedRed: 0.36, green: 1, blue: 0.65, alpha: 1)
    private let headerLabel = NSTextField(labelWithString: "SCREENMATE  //  DISPLAY WATCH")
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let counterLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLabels()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabels()
    }

    private func configureLabels() {
        configureLabel(headerLabel, size: 11, color: mint.withAlphaComponent(0.7), weight: .medium)
        configureLabel(titleLabel, size: 24, color: mint, weight: .semibold)
        configureLabel(detailLabel, size: 12, color: .white.withAlphaComponent(0.8))
        configureLabel(counterLabel, size: 11, color: mint)
        titleLabel.maximumNumberOfLines = 3
        detailLabel.maximumNumberOfLines = 2
        for label in [headerLabel, titleLabel, detailLabel, counterLabel] {
            addSubview(label)
        }
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, color: NSColor,
                                weight: NSFont.Weight = .regular) {
        // Let AppKit's standard text field manage its font attributes. Direct NSString
        // drawing with a monospaced system font can produce an invalid CoreText font
        // attribute dictionary on some macOS versions and abort the process.
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = L10n.isRightToLeft ? .right : .left
        label.lineBreakMode = .byWordWrapping
        label.isSelectable = false
        label.setAccessibilityElement(false)
    }

    override func layout() {
        super.layout()
        headerLabel.frame = NSRect(x: 30, y: bounds.height - 48, width: bounds.width - 60, height: 20)
        titleLabel.frame = NSRect(x: 30, y: 95, width: bounds.width - 60, height: 74)
        detailLabel.frame = NSRect(x: 30, y: 52, width: bounds.width - 60, height: 42)
        counterLabel.frame = NSRect(x: bounds.width - 80, y: 20, width: 50, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = bounds.insetBy(dx: 2, dy: 2)
        NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.045, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: box, xRadius: 18, yRadius: 18).fill()
        mint.withAlphaComponent(0.32).setStroke()
        let outline = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 18, yRadius: 18)
        outline.lineWidth = 1; outline.stroke()
        // Fine scan lines keep the terminal look subtle at both Retina and standard density.
        mint.withAlphaComponent(0.035).setStroke()
        for y in stride(from: 14.0, to: Double(bounds.height - 12), by: 5) {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 16, y: y)); line.line(to: NSPoint(x: bounds.width - 16, y: y))
            line.lineWidth = 0.5; line.stroke()
        }
        let track = NSRect(x: 30, y: 27, width: bounds.width - 120, height: 4)
        mint.withAlphaComponent(0.13).setFill(); NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()
        mint.setFill()
        NSBezierPath(roundedRect: NSRect(x: track.minX, y: track.minY, width: track.width * min(max(progress, 0), 1), height: 4), xRadius: 2, yRadius: 2).fill()
    }
}

final class DisplayToast {
    private var panel: ToastPanel?
    private var content: ToastView?
    private var timer: Timer?
    private var dismissal: DispatchWorkItem?
    private var generation = 0

    func show(displayNames: [String]) {
        hide()
        guard let screen = NSScreen.screens.first else { return }
        let width = min(700, max(260, screen.visibleFrame.width - 48))
        let frame = NSRect(x: screen.visibleFrame.midX - width / 2,
                           y: screen.visibleFrame.midY - 120, width: width, height: 240)
        let panel = ToastPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true; panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let content = ToastView(frame: NSRect(origin: .zero, size: frame.size))
        content.title = L10n.text("toast_detected")
        content.detail = displayNames.joined(separator: " + ")
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        content.setAccessibilityLabel(content.title + ". " + content.detail)
        panel.contentView = content
        self.panel = panel; self.content = content
        panel.alphaValue = 0; panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18; panel.animator().alphaValue = 1
        }
        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let content = self.content else { return }
            let elapsed = Date().timeIntervalSince(start)
            content.progress = min(elapsed / 3, 1)
            content.counter = String(format: "%.1fs", max(3 - elapsed, 0))
            content.needsDisplay = true
        }
        // Always expire, even if a pending restoration is canceled or an app stalls.
        dismiss(after: 8)
    }

    func finish(title: String, detail: String) {
        guard let content else { return }
        timer?.invalidate(); timer = nil
        content.title = title; content.detail = detail
        content.progress = 1; content.counter = "100%"
        content.setAccessibilityLabel(title + ". " + detail)
        content.needsDisplay = true
        dismiss(after: 1)
    }

    private func dismiss(after delay: TimeInterval) {
        dismissal?.cancel()
        let expected = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == expected, let panel = self.panel else { return }
            self.timer?.invalidate(); self.timer = nil
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3; panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, self.generation == expected else { return }
                self.hide()
            })
        }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func hide() {
        generation += 1
        timer?.invalidate(); timer = nil
        dismissal?.cancel(); dismissal = nil
        panel?.orderOut(nil); panel = nil; content = nil
    }
}
