// DisplayManager.swift — Hybrid Display Discovery & State Controller
import Foundation
import CoreGraphics
import IOKit

public struct DisplayModel: Identifiable, Equatable {
    public let id: CGDirectDisplayID
    public let name: String
    public let isBuiltin: Bool
    public var transport: String
    public var isHardwareDDCActive: Bool
}

@MainActor
public final class DisplayManager: ObservableObject {
    public static let shared = DisplayManager()

    @Published public var displays: [DisplayModel] = []
    @Published public var activeDisplay: DisplayModel?
    @Published public var activeProfile: String = "standard"
    @Published public var showingSettings: Bool = false
    @Published public var launchAtLoginEnabled: Bool = LaunchAtLoginHelper.isEnabled

    // Display Parameters
    @Published public var brightness: Float = 0.80 {
        didSet { applySettings() }
    }
    @Published public var contrast: Float = 0.50 {
        didSet { applySettings() }
    }
    @Published public var warmth: Float = 6500.0 {
        didSet { applySettings() }
    }
    @Published public var isMonochrome: Bool = false {
        didSet { applySettings() }
    }
    @Published public var isSleeping: Bool = false {
        didSet { applySettings() }
    }
    @Published public var headphoneVolume: Float = 0.40 {
        didSet { applyDDCVolume() }
    }

    private init() {
        refreshDisplays()
        setupHotplugNotifications()
    }

    public func refreshDisplays() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &ids, &count)

        var found: [DisplayModel] = []
        for d in ids.prefix(Int(count)) {
            let isBuiltin = (CGDisplayIsBuiltin(d) != 0)
            let name = getDisplayName(d)
            let transport = detectTransport(d)

            found.append(DisplayModel(
                id: d,
                name: name,
                isBuiltin: isBuiltin,
                transport: transport,
                isHardwareDDCActive: false
            ))
        }

        self.displays = found
        self.activeDisplay = found.first(where: { !$0.isBuiltin }) ?? found.first

        // Verify live DDC hardware support
        DDCService.shared.isHardwareAvailable { [weak self] isWorking in
            guard let self = self else { return }
            if let active = self.activeDisplay, let idx = self.displays.firstIndex(where: { $0.id == active.id }) {
                self.displays[idx].isHardwareDDCActive = isWorking
                self.activeDisplay = self.displays[idx]
            }
        }

        applySettings()
    }

    public func applySettings() {
        guard let d = activeDisplay else { return }

        if isSleeping {
            GammaEngine.shared.apply(display: d.id, brightness: 0.0, contrast: 0.5, kelvin: 6500, isMonochrome: false)
            return
        }

        GammaEngine.shared.apply(
            display: d.id,
            brightness: brightness,
            contrast: contrast,
            kelvin: warmth,
            isMonochrome: isMonochrome
        )

        if d.isHardwareDDCActive {
            DDCService.shared.setCoalesced(vcp: .brightness, value: UInt16(brightness * 100))
        }
    }

    private func applyDDCVolume() {
        guard let d = activeDisplay, d.isHardwareDDCActive else { return }
        DDCService.shared.setCoalesced(vcp: .audioVolume, value: UInt16(headphoneVolume * 100))
    }

    private func getDisplayName(_ id: CGDirectDisplayID) -> String {
        var it: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleCLCD2"), &it) == KERN_SUCCESS {
            defer { IOObjectRelease(it) }
            while case let s = IOIteratorNext(it), s != 0 {
                if let attrs = IORegistryEntryCreateCFProperty(s, "DisplayAttributes" as CFString, nil, 0)?.takeRetainedValue() as? [String: Any],
                   let pa = attrs["ProductAttributes"] as? [String: Any],
                   let prodName = pa["ProductName"] as? String {
                    if CGDisplayIsBuiltin(id) == 0 {
                        return prodName
                    }
                }
            }
        }
        return CGDisplayIsBuiltin(id) != 0 ? "Built-in Retina Display" : "External Display"
    }

    private func detectTransport(_ id: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(id) != 0 { return "Internal" }
        var it: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleCLCD2"), &it) == KERN_SUCCESS {
            defer { IOObjectRelease(it) }
            while case let s = IOIteratorNext(it), s != 0 {
                if let t = IORegistryEntryCreateCFProperty(s, "Transport" as CFString, nil, 0)?.takeRetainedValue() as? [String: String] {
                    let down = t["Downstream"] ?? ""
                    return down == "HDMI" ? "HDMI" : "USB-C / DP"
                }
            }
        }
        return "Unknown"
    }

    private func setupHotplugNotifications() {
        CGDisplayRegisterReconfigurationCallback({ _, _, _ in
            DispatchQueue.main.async {
                DisplayManager.shared.refreshDisplays()
            }
        }, nil)
    }
}
