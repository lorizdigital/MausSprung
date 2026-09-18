import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "de.lorizdigital.maussprung")
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "MausSprung")
        let menu = NSMenu()
        menu.addItem(withTitle: "MausSprung – Einstellungen …", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        for index in 0..<3 {
            let item = menu.addItem(withTitle: "Zu Ziel \(index + 1) springen", action: #selector(jumpFromMenu(_:)), keyEquivalent: "")
            item.tag = index; item.target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "MausSprung beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appMenu = NSMenuItem(); mainMenu.addItem(appMenu)
        appMenu.submenu = NSMenu()
        appMenu.submenu?.addItem(withTitle: "MausSprung beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 640),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "MausSprung"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        showSettings()
    }
    @objc func showSettings() { NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
    @objc func jumpFromMenu(_ sender: NSMenuItem) { model.jump(sender.tag) }
    func windowWillClose(_ notification: Notification) { model.cancelRecording() }
    func applicationDidBecomeActive(_ notification: Notification) { model?.launchAtLogin.refresh() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showSettings(); return true }
}

do {
    if CommandLine.arguments.contains("--self-test") {
        try runSelfTests()
    } else if CommandLine.arguments.contains("--diagnostics") {
        _ = NSApplication.shared
        for display in Display.connected() {
            print("\(display.name) | \(display.id) | bounds=\(display.bounds) | center=\(display.center)")
        }
    } else if CommandLine.arguments.contains("--smoke-test") {
        try runSmokeTest()
    } else {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1) // All throwing test scopes, including cursor restoration, have unwound.
}
