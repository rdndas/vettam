// LaunchAtLoginHelper.swift — SMAppService Modern Launch at Login Support (macOS 13+)
import Foundation
import ServiceManagement

public final class LaunchAtLoginHelper {
    public static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return UserDefaults.standard.bool(forKey: "LaunchAtLoginFallback")
            }
        }
        set {
            if #available(macOS 13.0, *) {
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
            } else {
                UserDefaults.standard.set(newValue, forKey: "LaunchAtLoginFallback")
            }
        }
    }
}
