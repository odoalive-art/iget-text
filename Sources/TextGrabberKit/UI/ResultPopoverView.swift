import AppKit
import SwiftUI

enum ResultPopoverLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 620
    static let compactHeight: CGFloat = 360
    static let cornerRadius: CGFloat = 24
}

private enum ResultPopoverDisplayState {
    case result
    case recognizing
    case permission
    case error
}

private enum ResultPopoverSectionStyle {
    static let cornerRadius: CGFloat = 14
}

struct ResultPopoverView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ResultPopoverContentView(
            displayState: displayState,
            placementMode: coordinator.settings.resultPanelPlacement,
            outputMode: Binding(
                get: { coordinator.outputMode },
                set: { coordinator.setOutputMode($0) }
            ),
            recognizedText: $coordinator.recognizedText,
            capturedPreviewImage: coordinator.capturedPreviewImage,
            lastErrorMessage: coordinator.lastErrorMessage,
            onRetry: coordinator.retryLastSelection,
            onCopy: coordinator.copyRecognizedText,
            onShowSettings: coordinator.showSettings,
            onClose: coordinator.closePopover,
            onOpenScreenRecordingPreferences: coordinator.openScreenRecordingPreferences
        )
    }

    private var displayState: ResultPopoverDisplayState {
        switch coordinator.popoverState {
        case .idle, .result:
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

public struct ResultPopoverPreviewHost: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case result = "结果"
        case recognizing = "识别中"
        case permission = "权限"

        var id: String { rawValue }
    }

    @State private var scenario: Scenario = .result
    @State private var recognizedText = ResultPopoverPreviewFactory.resultText

    public init() {}

    public var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Picker("预览状态", selection: $scenario) {
                    ForEach(Scenario.allCases) { scenario in
                        Text(scenario.rawValue).tag(scenario)
                    }
                }
                .pickerStyle(.segmented)

                ResultPopoverContentView(
                    displayState: displayState,
                    placementMode: .statusItem,
                    outputMode: .constant(.readingOptimized),
                    recognizedText: $recognizedText,
                    capturedPreviewImage: capturedPreviewImage,
                    lastErrorMessage: nil,
                    onRetry: {},
                    onCopy: {},
                    onShowSettings: {},
                    onClose: {},
                    onOpenScreenRecordingPreferences: {}
                )
                .frame(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)
                .clipShape(RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
            }
            .padding(24)
        }
        .frame(minWidth: 420, minHeight: 720, alignment: .top)
    }

    private var displayState: ResultPopoverDisplayState {
        switch scenario {
        case .result:
            .result
        case .recognizing:
            .recognizing
        case .permission:
            .permission
        }
    }

    private var capturedPreviewImage: NSImage? {
        switch scenario {
        case .permission:
            nil
        case .result, .recognizing:
            ResultPopoverPreviewFactory.previewImage()
        }
    }
}

private struct ResultPopoverContentView: View {
    let displayState: ResultPopoverDisplayState
    let placementMode: ResultPanelPlacementMode
    @Binding var outputMode: OCRTextOutputMode
    @Binding var recognizedText: String
    let capturedPreviewImage: NSImage?
    let lastErrorMessage: String?
    let onRetry: () -> Void
    let onCopy: () -> Void
    let onShowSettings: () -> Void
    let onClose: () -> Void
    let onOpenScreenRecordingPreferences: () -> Void

    var body: some View {
        LiquidGlassSurface(cornerRadius: ResultPopoverLayout.cornerRadius) {
            VStack(alignment: .leading, spacing: 16) {
                header

                Group {
                    switch displayState {
                    case .result:
                        resultEditor
                    case .recognizing:
                        recognizingView
                    case .permission:
                        permissionView
                    case .error:
                        errorView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            Text("截图文本识别")
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                onShowSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
            }
            .popoverSecondaryButtonStyle()
        }
    }

    private var resultEditor: some View {
        Group {
            if usesCompactTextLayout {
                textPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 18) {
                    previewPane
                        .frame(maxWidth: .infinity)

                    textPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var recognizingView: some View {
        VStack(spacing: 18) {
            previewPane
                .frame(maxWidth: .infinity)

            sectionCard(title: "识别状态") {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView("正在识别所选区域中的文本...")
                        .controlSize(.small)
                    Text("识别完成后会自动显示文本结果，你可以直接复制或编辑。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var permissionView: some View {
        sectionCard(title: "权限提示") {
            VStack(alignment: .leading, spacing: 12) {
                Text("需要屏幕录制权限")
                    .font(.title3.weight(.semibold))
                Text("请在“系统设置 -> 隐私与安全性 -> 屏幕录制”中允许本应用，然后重新触发快捷键。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("打开系统设置") {
                        onOpenScreenRecordingPreferences()
                    }
                    Button("关闭") {
                        onClose()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var errorView: some View {
        sectionCard(title: "错误信息") {
            VStack(alignment: .leading, spacing: 12) {
                Text("本次识别没有成功")
                    .font(.title3.weight(.semibold))
                Text(lastErrorMessage ?? "请重新尝试。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("重新识别") {
                        onRetry()
                    }
                    Button("关闭") {
                        onClose()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Button("重新识别") {
                onRetry()
            }
            .disabled(displayState == .recognizing)
            .popoverSecondaryButtonStyle()

            Spacer()

            Button("复制文本") {
                onCopy()
            }
            .disabled(recognizedText.isEmpty)
            .popoverPrimaryButtonStyle()

            Button("关闭") {
                onClose()
            }
            .popoverSecondaryButtonStyle()
        }
    }

    private var previewPane: some View {
        sectionCard(title: "截图预览", contentPadding: 0) {
            ZStack {
                if let image = capturedPreviewImage {
                    GeometryReader { proxy in
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: proxy.size.width - 16,
                                height: proxy.size.height - 16,
                                alignment: .center
                            )
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }
                } else {
                    ContentUnavailableView(
                        "暂无截图",
                        systemImage: "photo",
                        description: Text("完成一次截图后，这里会显示实际识别区域。")
                    )
                    .padding(.horizontal, 12)
                    .font(.subheadline)
                }
            }
            .frame(height: 210)
        }
    }

    private var textPane: some View {
        sectionCard(title: "识别文本", contentPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Picker("输出模式", selection: $outputMode) {
                    ForEach(OCRTextOutputMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(12)

                Divider()

                TextEditor(text: $recognizedText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var usesCompactTextLayout: Bool {
        placementMode == .followMouse && displayState == .result
    }

    private func sectionCard<Content: View>(
        title: String,
        contentPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(sectionBackground)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: ResultPopoverSectionStyle.cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: ResultPopoverSectionStyle.cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
    }
}

private struct LiquidGlassSurface<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let view = LiquidGlassContainerView(cornerRadius: cornerRadius)
        view.update(rootView: AnyView(content))
        return view
    }

    func updateNSView(_ nsView: LiquidGlassContainerView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.update(rootView: AnyView(content))
    }
}

private final class LiquidGlassContainerView: NSView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let effectView: NSView
    var cornerRadius: CGFloat {
        didSet {
            updateStyling()
        }
    }

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.tintColor = nil
            effectView = glassView
        } else {
            let visualView = NSVisualEffectView()
            visualView.material = .popover
            visualView.blendingMode = .withinWindow
            visualView.state = .active
            effectView = visualView
        }

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        effectView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.contentView = hostingView
        } else {
            effectView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
            ])
        }

        updateStyling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: AnyView) {
        hostingView.rootView = rootView
    }

    private func updateStyling() {
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.cornerRadius = cornerRadius
        }
    }
}

private extension View {
    @ViewBuilder
    func popoverSecondaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func popoverPrimaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

#if DEBUG
private struct ResultPopoverPreviewSurface: View {
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
}

@MainActor
private enum ResultPopoverPreviewFactory {
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
