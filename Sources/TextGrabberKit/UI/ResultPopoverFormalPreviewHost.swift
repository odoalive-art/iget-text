import AppKit
import SwiftUI

#if DEBUG
@MainActor
private struct ResultPopoverFormalPreviewHost: View {
    @StateObject private var resultState = RecognitionResultState()
    @State private var outputMode: OCRTextOutputMode = .readingOptimized
    @State private var recognizedText = ResultPopoverFormalPreviewData.resultText
    @State private var isPinned = false

    var body: some View {
        ResultPopoverContentView(
            displayState: .result,
            placementMode: .statusItem,
            isPinned: $isPinned,
            resultState: resultState,
            translationServiceResolver: TranslationServiceResolver(),
            translationProvider: .automatic,
            outputMode: $outputMode,
            recognizedText: $recognizedText,
            capturedPreviewImage: ResultPopoverFormalPreviewData.previewImage(),
            lastErrorMessage: nil,
            onRetry: {},
            onCopy: {},
            onTogglePin: { isPinned.toggle() },
            onShowSettings: {},
            onClose: {},
            onOpenScreenRecordingPreferences: {}
        )
        .frame(
            width: ResultPopoverLayout.width,
            height: ResultPopoverLayout.resultPanelHeight(
                text: recognizedText,
                translationText: resultState.translatedText.isEmpty ? nil : resultState.translatedText,
                showsTranslationPane: !resultState.translatedText.isEmpty,
                outputMode: outputMode,
                image: ResultPopoverFormalPreviewData.previewImage(),
                includePreview: true
            )
        )
        .padding(24)
        .background(Color(nsColor: .underPageBackgroundColor))
        .onAppear {
            let result = OCRResult(
                rawText: ResultPopoverFormalPreviewData.resultText,
                readingOptimizedText: ResultPopoverFormalPreviewData.resultText,
                lines: [],
                confidenceSummary: 0.98
            )
            resultState.showResult(result)
            resultState.completeTranslation(ResultPopoverFormalPreviewData.translatedText)
        }
    }
}

private enum ResultPopoverFormalPreviewData {
    static let resultText = """
    创建新分支准备优化 UI 交互...

    新增：翻译功能

    初版开发与架构整理优化
    """

    static let translatedText = """
    Create a new branch to refine the UI interaction...

    Added: translation support

    Initial development and architecture cleanup
    """

    static func previewImage() -> NSImage {
        let size = NSSize(width: 480, height: 280)
        let image = NSImage(size: size)

        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let panelRect = NSRect(x: 88, y: 70, width: 304, height: 142)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 18, yRadius: 18)
        NSColor.white.withAlphaComponent(0.94).setFill()
        panelPath.fill()

        let title = "创建新分支准备优化 UI 交互..."
        title.draw(
            in: NSRect(x: 118, y: 152, width: 240, height: 22),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let subtitle = "新增：翻译功能"
        subtitle.draw(
            in: NSRect(x: 118, y: 117, width: 180, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let footer = "初版开发与架构整理"
        footer.draw(
            in: NSRect(x: 118, y: 85, width: 180, height: 20),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )

        image.unlockFocus()
        return image
    }
}

#Preview("正式结果页（专用）") {
    ResultPopoverFormalPreviewHost()
}
#endif
