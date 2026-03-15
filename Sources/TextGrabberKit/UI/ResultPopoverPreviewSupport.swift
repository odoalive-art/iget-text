import AppKit
import SwiftUI

#if DEBUG
struct ResultPopoverPreviewSurface: View {
    let displayState: ResultPopoverDisplayState
    let capturedPreviewImage: NSImage?
    let lastErrorMessage: String?
    @State private var recognizedText: String

    init(
        displayState: ResultPopoverDisplayState,
        recognizedText: String,
        capturedPreviewImage: NSImage?,
        lastErrorMessage: String? = nil
    ) {
        self.displayState = displayState
        self.capturedPreviewImage = capturedPreviewImage
        self.lastErrorMessage = lastErrorMessage
        _recognizedText = State(initialValue: recognizedText)
    }

    var body: some View {
        ResultPopoverContentView(
            displayState: displayState,
            placementMode: .statusItem,
            resultState: previewState,
            translationServiceResolver: TranslationServiceResolver(),
            translationProvider: .automatic,
            outputMode: .constant(.readingOptimized),
            recognizedText: $recognizedText,
            capturedPreviewImage: capturedPreviewImage,
            lastErrorMessage: lastErrorMessage,
            onRetry: {},
            onCopy: {},
            onShowSettings: {},
            onClose: {},
            onOpenScreenRecordingPreferences: {}
        )
        .frame(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var previewState: RecognitionResultState {
        let state = RecognitionResultState()
        state.translatedText = "Apple Translation\n\nThis preview uses the system translation service abstraction."
        return state
    }
}

@MainActor
enum ResultPopoverPreviewFactory {
    static let resultText = """
    阅创建新分支准备优化 UI 交互...

    新增：翻译功能

    初版开发与架构整理读优化
    """

    static func resultSurface() -> ResultPopoverPreviewSurface {
        ResultPopoverPreviewSurface(
            displayState: .result,
            recognizedText: resultText,
            capturedPreviewImage: previewImage()
        )
    }

    static func recognizingSurface() -> ResultPopoverPreviewSurface {
        ResultPopoverPreviewSurface(
            displayState: .recognizing,
            recognizedText: resultText,
            capturedPreviewImage: previewImage()
        )
    }

    static func permissionSurface() -> ResultPopoverPreviewSurface {
        ResultPopoverPreviewSurface(
            displayState: .permission,
            recognizedText: "",
            capturedPreviewImage: nil
        )
    }

    static func previewImage() -> NSImage {
        let size = NSSize(width: 480, height: 280)
        let image = NSImage(size: size)

        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let panelRect = NSRect(x: 90, y: 70, width: 300, height: 140)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 18, yRadius: 18)
        NSColor.white.withAlphaComponent(0.94).setFill()
        panelPath.fill()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.08)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()

        let caption = "创建新分支准备优化 UI 交互..."
        caption.draw(
            in: NSRect(x: 120, y: 150, width: 240, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let translation = "新增：翻译功能"
        translation.draw(
            in: NSRect(x: 120, y: 115, width: 180, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let footer = "初版开发与架构整理"
        footer.draw(
            in: NSRect(x: 120, y: 82, width: 180, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )

        image.unlockFocus()
        return image
    }
}

#Preview("Result", traits: .fixedLayout(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)) {
    ResultPopoverPreviewFactory.resultSurface()
}

#Preview("Recognizing", traits: .fixedLayout(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)) {
    ResultPopoverPreviewFactory.recognizingSurface()
}

#Preview("Permission", traits: .fixedLayout(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)) {
    ResultPopoverPreviewFactory.permissionSurface()
}
#endif
