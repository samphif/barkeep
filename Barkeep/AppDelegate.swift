import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        guard !Self.isAnotherInstanceRunning else {
            NSApp.terminate(nil)
            return
        }
        let controller = MenuBarController(settings: Settings(defaults: .standard))
        controller.start()
        self.controller = controller
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Two copies would each add a chevron and divider, fighting over the same icons.
    private static var isAnotherInstanceRunning: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != currentPID && !$0.isTerminated }
    }
}
