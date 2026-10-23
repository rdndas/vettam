// main.swift — Vettam Menu Bar App Entry Point
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Standard HIG menu bar item scaled for authentic vettam_ref.png icon
        statusItem = NSStatusBar.system.statusItem(withLength: 32.0)
        
        if let button = statusItem.button {
            button.image = StatusItemIconHelper.makeVettamTemplateIcon()
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Configure Liquid Glass Popover with rigid fixed sizing
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = false // Prevent transition jitter
        popover.contentViewController = NSHostingController(rootView: VettamView())

        // Start keyboard shortcut monitoring
        HotkeyManager.shared.startMonitoring()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GammaEngine.shared.restoreOriginal()
        HotkeyManager.shared.stopMonitoring()
    }
}

// Bootstrap Application
ProcessInfo.processInfo.processName = "Vettam"
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
