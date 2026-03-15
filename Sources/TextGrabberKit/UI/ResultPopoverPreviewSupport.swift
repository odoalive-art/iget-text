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
    OPPO 互联

    将电脑本地文件拖动到此处，可快速发送至手机。

    下一页
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
        let size = NSSize(width: 900, height: 560)
        let image = NSImage(size: size)

        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let panelRect = NSRect(x: 80, y: 80, width: 740, height: 400)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 24, yRadius: 24)
        NSColor.controlBackgroundColor.setFill()
        panelPath.fill()

        let heroRect = NSRect(x: 120, y: 170, width: 660, height: 250)
        let heroPath = NSBezierPath(roundedRect: heroRect, xRadius: 20, yRadius: 20)
        NSColor.systemBlue.withAlphaComponent(0.18).setFill()
        heroPath.fill()

        let innerRect = NSRect(x: 250, y: 235, width: 400, height: 120)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 18, yRadius: 18)
        NSColor.white.withAlphaComponent(0.9).setFill()
        innerPath.fill()

        let dashedRect = NSRect(x: 285, y: 250, width: 330, height: 90)
        let dashedPath = NSBezierPath(roundedRect: dashedRect, xRadius: 12, yRadius: 12)
        dashedPath.setLineDash([6, 5], count: 2, phase: 0)
        dashedPath.lineWidth = 2
        NSColor.systemBlue.withAlphaComponent(0.35).setStroke()
        dashedPath.stroke()

        let caption = "将电脑本地文件拖动到此处，可快速发送至手机。"
        caption.draw(
            in: NSRect(x: 155, y: 110, width: 580, height: 36),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let footer = "下一页"
        footer.draw(
            in: NSRect(x: 390, y: 30, width: 120, height: 36),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 30, weight: .regular),
                .foregroundColor: NSColor.systemBlue
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
