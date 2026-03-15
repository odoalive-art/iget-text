import SwiftUI
import TextGrabberKit

@main
struct TextGrabberPreviewApp: App {
    var body: some Scene {
        WindowGroup("TextGrabber Preview") {
            ResultPopoverPreviewHost()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
