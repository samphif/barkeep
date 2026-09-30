import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }

    /// Turns the login item on once, from the installed copy only, so a build run from
    /// Xcode never registers itself. Turning it off in the menu afterwards sticks.
    static func enableOnFirstInstalledLaunch(settings: Settings) {
        guard !settings.hasConfiguredLaunchAtLogin, Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        settings.hasConfiguredLaunchAtLogin = true
        do {
            try SMAppService.mainApp.register()
        } catch {
            Log.menuBar.error("Couldn't enable Launch at Login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
