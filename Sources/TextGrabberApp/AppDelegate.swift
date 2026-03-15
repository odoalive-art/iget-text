import AppKit
import TextGrabberKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings()
        coordinator = AppCoordinator(settings: settings)
        coordinator?.start()
    }
}
