import AppKit
import LayoutCore
import ServiceManagement
import Localization

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let store = LayoutStore()
    private var pendingRestore: DispatchWorkItem?
    private var generation = 0
    private var configuration = ""
    private var stableAfter = Date.distantPast
    private var lastMessage = L10n.text("initial_hint")
    private var timer: Timer?
    private var welcome: NSWindow?
    private var autoRestore: Bool {
        get { UserDefaults.standard.object(forKey: "autoRestore") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoRestore") }
    }
    private var autoSave: Bool {
        get { UserDefaults.standard.bool(forKey: "autoSave") }
        set { UserDefaults.standard.set(newValue, forKey: "autoSave") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: L10n.text("quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem); appItem.submenu = appMenu
        mainMenu.addItem(appItem); NSApp.mainMenu = mainMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "ScreenMate")
        statusItem.button?.toolTip = L10n.text("tooltip")
        statusItem.menu = menu
        menu.autoenablesItems = false
        menu.delegate = self
        configuration = fingerprint(WindowService.displays())
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeUp), name: NSWorkspace.didWakeNotification, object: nil)
        timer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(periodicSave), userInfo: nil, repeats: true)
        if let error = store.loadError { lastMessage = L10n.format("read_error", error.localizedDescription) }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            showWelcome()
            UserDefaults.standard.set(true, forKey: "hasLaunched")
        } else if autoRestore { scheduleRestore() }
    }

    private func fingerprint(_ displays: [Display]) -> String {
        LayoutGeometry.key(displays) + displays.sorted { $0.id < $1.id }.map { "\($0.id)@\($0.frame.x),\($0.frame.y)" }.joined()
    }

    @objc private func screensChanged() {
        let current = fingerprint(WindowService.displays())
        guard current != configuration else { return }
        configuration = current
        scheduleRestore()
    }

    @objc private func wokeUp() { scheduleRestore() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWelcome() }
        return true
    }

    private func scheduleRestore() {
        generation += 1
        let expected = generation
        pendingRestore?.cancel()
        stableAfter = Date().addingTimeInterval(12)
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == expected, self.autoRestore else { return }
            self.restoreLayout()
        }
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    @objc private func periodicSave() {
        guard autoSave, Date() > stableAfter, WindowService.trusted else { return }
        let displays = WindowService.displays()
        guard fingerprint(displays) == configuration,
              store.layouts[LayoutGeometry.key(displays)] != nil else { return }
        saveLayout(showErrors: false)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let displays = WindowService.displays()
        let layout = store.layouts[LayoutGeometry.key(displays)]
        add("ScreenMate", enabled: false)
        for display in displays { add("\(display.name) · \(Int(display.frame.width)) × \(Int(display.frame.height))", enabled: false) }
        add(lastMessage, enabled: false)
        menu.addItem(.separator())
        if !WindowService.trusted {
            add(L10n.text("permission_action"), action: #selector(permission))
            add(L10n.text("permission_hint"), enabled: false)
            menu.addItem(.separator())
        }
        add(L10n.text("save_action"), action: #selector(saveAction), enabled: WindowService.trusted)
        add(L10n.text("restore_action"), action: #selector(restoreAction), enabled: WindowService.trusted && layout != nil)
        if let layout {
            let formatter = DateFormatter()
            formatter.locale = L10n.locale
            formatter.dateStyle = .short; formatter.timeStyle = .short
            let time = formatter.string(from: layout.savedAt)
            add(L10n.format("saved_summary", layout.windows.count, time), enabled: false)
        } else { add(L10n.text("no_layout"), enabled: false) }
        menu.addItem(.separator())
        add(L10n.text("auto_restore"), action: #selector(toggleRestore), checked: autoRestore)
        add(L10n.text("auto_save"), action: #selector(toggleSave), checked: autoSave)
        let languageItem = add(L10n.text("language"))
        let languageMenu = NSMenu()
        languageMenu.autoenablesItems = false
        for choice in [(code: "system", name: L10n.text("system_language"))] + L10n.languages {
            let item = NSMenuItem(title: choice.name, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = choice.code
            item.state = (L10n.override ?? "en") == choice.code ? .on : .off
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        add(L10n.text("login"), action: #selector(toggleLogin), checked: SMAppService.mainApp.status == .enabled)
        let profilesItem = add(L10n.format("profiles", store.layouts.count))
        let profiles = NSMenu()
        for (key, saved) in store.layouts.sorted(by: { $0.value.savedAt > $1.value.savedAt }) {
            let names = saved.displays.map(\.name).joined(separator: " + ")
            let item = NSMenuItem(title: L10n.format("profile_summary", names, saved.windows.count), action: #selector(deleteProfile(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = key
            let sub = NSMenu()
            let delete = NSMenuItem(title: L10n.text("delete_action"), action: #selector(deleteProfile(_:)), keyEquivalent: "")
            delete.target = self; delete.representedObject = key
            sub.addItem(delete); item.submenu = sub; profiles.addItem(item)
        }
        profilesItem.submenu = profiles
        profilesItem.isEnabled = !store.layouts.isEmpty
        menu.addItem(.separator())
        add(L10n.text("help"), action: #selector(showWelcome))
        add(L10n.text("open_data"), action: #selector(openData))
        add(L10n.text("quit"), action: #selector(quit))
    }

    @discardableResult
    private func add(_ title: String, action: Selector? = nil, enabled: Bool = true, checked: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; item.isEnabled = enabled
        if let checked { item.state = checked ? .on : .off }
        menu.addItem(item)
        return item
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? String else { return }
        L10n.override = language
        lastMessage = L10n.text("initial_hint")
        statusItem.button?.toolTip = L10n.text("tooltip")
        NSApp.mainMenu?.items.first?.submenu?.items.first?.title = L10n.text("quit")
        let wasVisible = welcome?.isVisible == true
        welcome?.close(); welcome = nil
        if wasVisible { showWelcome() }
    }

    @objc private func permission() { WindowService.requestPermission() }
    @objc private func saveAction() {
        generation += 1; pendingRestore?.cancel()
        saveLayout(showErrors: true)
    }

    private func saveLayout(showErrors: Bool) {
        guard WindowService.trusted else { if showErrors { permission() }; return }
        let displays = WindowService.displays()
        let fingerprintBefore = fingerprint(displays)
        let windows = WindowService.windows(displays: displays).map(\.snapshot)
        guard fingerprint(WindowService.displays()) == fingerprintBefore else {
            lastMessage = L10n.text("display_changing"); return
        }
        guard !windows.isEmpty else {
            lastMessage = L10n.text("no_windows_status")
            if showErrors { inform(L10n.text("no_windows_title"), L10n.text("no_windows_body")) }
            return
        }
        do {
            try store.save(Layout(displays: displays, windows: windows), key: LayoutGeometry.key(displays))
            lastMessage = L10n.format("saved_status", windows.count)
        } catch { report(error, visible: showErrors) }
    }

    @objc private func restoreAction() {
        generation += 1; pendingRestore?.cancel()
        stableAfter = Date().addingTimeInterval(12)
        restoreLayout()
    }

    private func restoreLayout() {
        guard WindowService.trusted else { lastMessage = L10n.text("permission_status"); return }
        let displays = WindowService.displays()
        guard let layout = store.layouts[LayoutGeometry.key(displays)] else {
            lastMessage = L10n.text("new_setup"); return
        }
        let result = WindowService.restore(layout, displays: displays)
        lastMessage = L10n.format("restored_status", result.restored, result.total)
    }

    @objc private func toggleRestore() {
        autoRestore.toggle()
        if !autoRestore { generation += 1; pendingRestore?.cancel() }
    }
    @objc private func toggleSave() {
        if !autoSave {
            let alert = NSAlert()
            alert.messageText = L10n.text("auto_save_title")
            alert.informativeText = L10n.text("auto_save_body")
            alert.addButton(withTitle: L10n.text("enable")); alert.addButton(withTitle: L10n.text("cancel"))
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        autoSave.toggle()
    }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch { report(error) }
    }
    @objc private func deleteProfile(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = L10n.text("delete_title")
        alert.informativeText = L10n.text("delete_body")
        alert.addButton(withTitle: L10n.text("cancel")); alert.addButton(withTitle: L10n.text("delete"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try store.remove(key: key); lastMessage = L10n.text("deleted_status") } catch { report(error) }
    }
    @objc private func openData() {
        do {
            try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            NSWorkspace.shared.open(store.fileURL.deletingLastPathComponent())
        } catch { report(error) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func report(_ error: Error, visible: Bool = true) {
        lastMessage = error.localizedDescription
        if visible { inform(L10n.text("error_title"), error.localizedDescription) }
    }
    private func inform(_ title: String, _ text: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }

    @objc private func showWelcome() {
        if let welcome { NSApp.activate(ignoringOtherApps: true); welcome.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 500), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.text("welcome_title")
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = L10n.isRightToLeft ? .trailing : .leading; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 64), icon.heightAnchor.constraint(equalToConstant: 64)])
        stack.addArrangedSubview(icon)
        let heading = NSTextField(wrappingLabelWithString: L10n.text("welcome_heading"))
        heading.preferredMaxLayoutWidth = 504
        heading.alignment = L10n.isRightToLeft ? .right : .natural
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        stack.addArrangedSubview(heading)
        let text = NSTextField(wrappingLabelWithString: L10n.text("welcome_body"))
        text.preferredMaxLayoutWidth = 504
        text.alignment = L10n.isRightToLeft ? .right : .natural
        text.font = .systemFont(ofSize: 14); stack.addArrangedSubview(text)
        let button = NSButton(title: L10n.text("open_settings"), target: self, action: #selector(permission))
        button.bezelStyle = .rounded; stack.addArrangedSubview(button)
        let note = NSTextField(wrappingLabelWithString: L10n.text("welcome_note"))
        note.preferredMaxLayoutWidth = 504
        note.alignment = L10n.isRightToLeft ? .right : .natural
        note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabelColor
        stack.addArrangedSubview(note)
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24)
        ])
        window.contentView!.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 560, height: max(440, stack.fittingSize.height + 56)))
        welcome = window; window.center()
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
}

// Used by the packaging smoke check without requesting Accessibility or opening a UI.
if CommandLine.arguments.contains("--check-resources") {
    for language in L10n.languages {
        guard L10n.text("save_action", language: language.code) != "save_action" else {
            fputs("Missing localization: \(language.code)\n", stderr)
            exit(1)
        }
    }
    guard Bundle.main.path(forResource: "AppIcon", ofType: "icns") != nil else {
        fputs("Missing app icon\n", stderr)
        exit(1)
    }
    print("Bundled localizations and app icon verified.")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
