#if DEBUG
import AppKit
import SwiftUI

@MainActor
final class ResultPopoverDebugWindowController: NSWindowController {
    init() {
        let rootView = ResultPopoverDebugPanelView()
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "UI 调试面板"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 540, height: 760))
        window.minSize = NSSize(width: 520, height: 720)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private struct ResultPopoverDebugPanelView: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case result = "识别结果"
        case recognizing = "识别中"
        case permission = "权限提示"
        case error = "错误提示"

        var id: String { rawValue }

        var displayState: ResultPopoverDisplayState {
            switch self {
            case .result:
                .result
            case .recognizing:
                .recognizing
            case .permission:
                .permission
            case .error:
                .error
            }
        }
    }

    private enum PlacementMode: String, CaseIterable, Identifiable {
        case followMouse = "跟随鼠标"
        case statusItem = "菜单栏"

        var id: String { rawValue }

        var resultPanelPlacementMode: ResultPanelPlacementMode {
            switch self {
            case .followMouse:
                .followMouse
            case .statusItem:
                .statusItem
            }
        }
    }

    private enum TranslationMode: String, CaseIterable, Identifiable {
        case none = "无翻译"
        case loading = "翻译中"
        case result = "翻译结果"
        case error = "翻译错误"

        var id: String { rawValue }
    }

    @StateObject private var resultState = RecognitionResultState()
    @State private var scenario: Scenario = .result
    @State private var placementMode: PlacementMode = .followMouse
    @State private var translationMode: TranslationMode = .none
    @State private var outputMode: OCRTextOutputMode = .readingOptimized
    @State private var recognizedText = DebugSampleData.resultText
    @State private var isPinned = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("结果面板 UI 调试")
                    .font(.title3.weight(.semibold))
                Text("只在 DEBUG 构建里提供，直接复用真实结果面板组件。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("场景", selection: $scenario) {
                        ForEach(Scenario.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("布局", selection: $placementMode) {
                        ForEach(PlacementMode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("翻译", selection: $translationMode) {
                        ForEach(TranslationMode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(scenario != .result)

                    Picker("文本模式", selection: $outputMode) {
                        ForEach(OCRTextOutputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(scenario != .result)

                    Text("识别文本")
                        .font(.subheadline.weight(.medium))

                    TextEditor(text: $recognizedText)
                        .font(.system(size: 12))
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        Button("填充示例") {
                            recognizedText = DebugSampleData.resultText
                        }

                        Button("空文本") {
                            recognizedText = "未识别到文本"
                        }

                        Spacer()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("实时预览")
                    .font(.headline)

                ResultPopoverContentView(
                    displayState: scenario.displayState,
                    placementMode: placementMode.resultPanelPlacementMode,
                    isPinned: $isPinned,
                    resultState: resultState,
                    translationServiceResolver: TranslationServiceResolver(),
                    translationProvider: .automatic,
                    outputMode: $outputMode,
                    recognizedText: $recognizedText,
                    capturedPreviewImage: previewImage,
                    lastErrorMessage: scenario == .error ? DebugSampleData.errorMessage : nil,
                    onRetry: {},
                    onCopy: {},
                    onTogglePin: { isPinned.toggle() },
                    onShowSettings: {},
                    onClose: {},
                    onOpenScreenRecordingPreferences: {}
                )
                .frame(width: ResultPopoverLayout.width, height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
        .onAppear {
            applyScenario()
        }
        .onChange(of: scenario) { _, _ in
            applyScenario()
        }
        .onChange(of: placementMode) { _, _ in
            applyScenario()
        }
        .onChange(of: translationMode) { _, _ in
            applyScenario()
        }
    }

    private var previewHeight: CGFloat {
        if scenario == .result {
            return ResultPopoverLayout.resultPanelHeight(
                text: recognizedText,
                outputMode: outputMode,
                image: previewImage,
                includePreview: placementMode == .statusItem
            )
        }

        return ResultPopoverLayout.height
    }

    private var previewImage: NSImage? {
        switch scenario {
        case .permission:
            nil
        case .result, .recognizing, .error:
            DebugSampleData.previewImage()
        }
    }

    private func applyScenario() {
        if scenario != .result {
            translationMode = .none
        }

        resultState.resetTranslation()

        switch translationMode {
        case .none:
            break
        case .loading:
            resultState.beginTranslation()
        case .result:
            resultState.completeTranslation(DebugSampleData.translatedText)
        case .error:
            resultState.failTranslation(DebugSampleData.translationErrorMessage)
        }
    }
}

private enum DebugSampleData {
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

    static let translationErrorMessage = "系统翻译暂时不可用，请稍后重试。"
    static let errorMessage = "识别失败，请重新尝试一次。"

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
#endif
