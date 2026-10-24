// LaunchAtLoginHelper.swift — Modern SMAppService Launch at Login Support (macOS 26+)
import Foundation
import ServiceManagement

public final class LaunchAtLoginHelper {
    public static var isEnabled: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("SMAppService register/unregister failed: \(error)")
            }
        }
    }
}
