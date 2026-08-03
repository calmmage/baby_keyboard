import Foundation
import ServiceManagement

class LaunchAtStartup {
    static let shared = LaunchAtStartup()
    private let launcherBundleId = "\(Bundle.main.bundleIdentifier!).LaunchHelper"
    
    private init() {}
    
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let action = enabled ? "register" : "unregister"
            debugPrint("Failed to \(action) app for launch at startup: \(error)")
        }
    }
    
    func isEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
