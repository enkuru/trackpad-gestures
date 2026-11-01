import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let trackpads = Trackpads()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "Trackpad Gestures")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Trackpads.onGesture = { [weak self] gesture in
            guard let self, !self.isPaused else { return }
            SystemActions.perform(gesture)
        }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        trackpads.restart()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Give the trackpad a moment to come back before asking for its new handle.
                try? await Task.sleep(for: .seconds(2))
                self?.trackpads.restart()
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(note(statusLine))
        if !AXIsProcessTrusted() {
            menu.addItem(action("Open Accessibility Settings…", #selector(openAccessibilitySettings)))
        }

        menu.addItem(.separator())
        menu.addItem(note("Three-finger tap: middle click"))
        menu.addItem(note("Rest one finger, tap left or right: volume down or up"))
        menu.addItem(note("Rest two fingers, tap between them: mute"))

        menu.addItem(.separator())
        menu.addItem(action("Pause", #selector(togglePause), checked: isPaused))
        menu.addItem(action("Open at Login", #selector(toggleOpenAtLogin), checked: SMAppService.mainApp.status == .enabled))
        menu.addItem(action("Rescan Trackpads", #selector(rescanTrackpads)))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Trackpad Gestures", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
    }

    private var statusLine: String {
        if !trackpads.isAvailable { return "Trackpad access is not available on this macOS" }
        if !AXIsProcessTrusted() { return "Needs Accessibility permission" }
        if trackpads.count == 0 { return "No trackpad found" }
        if isPaused { return "Paused" }
        return trackpads.count == 1 ? "Active" : "Active on \(trackpads.count) trackpads"
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func togglePause() {
        isPaused.toggle()
    }

    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    @objc private func rescanTrackpads() {
        trackpads.restart()
    }

    private func note(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector, checked: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.state = checked ? .on : .off
        return item
    }
}
