// HotkeyManager.swift — Multi-Modifier Keyboard Shortcuts for LuminoBar
import Foundation
import AppKit

public enum ShortcutAction: String {
    case brightnessUp
    case brightnessDown
}

public struct KeyCombo: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: UInt // NSEvent.ModifierFlags rawValue
    public var displayString: String

    public init(keyCode: UInt16, modifiers: UInt, displayString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayString = displayString
    }
}

public final class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()

    @Published public var downShortcut: KeyCombo {
        didSet { saveShortcuts() }
    }
    @Published public var upShortcut: KeyCombo {
        didSet { saveShortcuts() }
    }
    @Published public var isListeningFor: ShortcutAction? = nil

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {
        // Default modifiers: Cmd + Ctrl + Shift (125 = Down Arrow, 126 = Up Arrow)
        let defaultFlags: NSEvent.ModifierFlags = [.command, .control, .shift]

        if let data = UserDefaults.standard.data(forKey: "LuminoBar_DownKey_V3"),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.downShortcut = combo
        } else {
            self.downShortcut = KeyCombo(keyCode: 125, modifiers: defaultFlags.rawValue, displayString: "⌃⇧⌘↓")
        }

        if let data = UserDefaults.standard.data(forKey: "LuminoBar_UpKey_V3"),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            self.upShortcut = combo
        } else {
            self.upShortcut = KeyCombo(keyCode: 126, modifiers: defaultFlags.rawValue, displayString: "⌃⇧⌘↑")
        }
    }

    private func saveShortcuts() {
        if let d = try? JSONEncoder().encode(downShortcut) {
            UserDefaults.standard.set(d, forKey: "LuminoBar_DownKey_V3")
        }
        if let u = try? JSONEncoder().encode(upShortcut) {
            UserDefaults.standard.set(u, forKey: "LuminoBar_UpKey_V3")
        }
    }

    public func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let target = self?.isListeningFor {
                self?.recordKey(event: event, for: target)
                return nil // consume event
            }
            self?.handleKeyEvent(event)
            return event
        }
    }

    public func stopMonitoring() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }

    private func recordKey(event: NSEvent, for action: ShortcutAction) {
        guard event.charactersIgnoringModifiers != nil else { return }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let code = event.keyCode
        let label = formatComboString(keyCode: code, flags: flags, event: event)

        DispatchQueue.main.async {
            let newCombo = KeyCombo(keyCode: code, modifiers: flags.rawValue, displayString: label)
            if action == .brightnessDown {
                self.downShortcut = newCombo
            } else {
                self.upShortcut = newCombo
            }
            self.isListeningFor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let currentFlags = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue

        if event.keyCode == downShortcut.keyCode && currentFlags == downShortcut.modifiers {
            DispatchQueue.main.async {
                DisplayManager.shared.brightness = max(0.0, DisplayManager.shared.brightness - 0.05)
            }
        } else if event.keyCode == upShortcut.keyCode && currentFlags == upShortcut.modifiers {
            DispatchQueue.main.async {
                DisplayManager.shared.brightness = min(1.0, DisplayManager.shared.brightness + 0.05)
            }
        }
    }

    private func formatComboString(keyCode: UInt16, flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var str = ""
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.option)  { str += "⌥" }
        if flags.contains(.shift)   { str += "⇧" }
        if flags.contains(.command) { str += "⌘" }

        str += keyName(for: keyCode, event: event)
        return str
    }

    private func keyName(for keyCode: UInt16, event: NSEvent) -> String {
        switch keyCode {
        case 125: return "↓"
        case 126: return "↑"
        case 123: return "←"
        case 124: return "→"
        case 145: return "F1"
        case 144: return "F2"
        case 160: return "F3"
        case 131: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 49:  return "Space"
        case 36:  return "Return"
        case 53:  return "Esc"
        default:
            if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
                return chars
            }
            return "\(keyCode)"
        }
    }
}
