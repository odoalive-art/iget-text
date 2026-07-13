import AppKit
import SwiftUI
#if canImport(Translation)
import Translation
#endif

enum ResultPopoverDisplayState {
    case result
    case recognizing
    case permission
    case error
}

struct ResultPopoverContentView: View {
    let displayState: ResultPopoverDisplayState
    let placementMode: ResultPanelPlacementMode
    @Binding var isPinned: Bool
    @ObservedObject var resultState: RecognitionResultState
    let translationServiceResolver: TranslationServiceResolver
    let translationProvider: TranslationProviderMode
    let isBlockEditingEnabled: Bool
    @Binding var outputMode: OCRTextOutputMode
    @Binding var recognizedText: String
    let capturedPreviewImage: NSImage?
    let lastErrorMessage: String?
    let onRetry: () -> Void
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onShowSettings: () -> Void
    let onClose: () -> Void
    let onOpenScreenRecordingPreferences: () -> Void
    @State private var isTranslationAvailabilityAlertPresented = false
    @State private var prewarmRequestToken = 0
    @State private var translationRequestToken = 0
    @State private var prewarmPlan: TranslationPlan?
    @State private var translationPlan: TranslationPlan?
    @State private var activeTooltip: TooltipPresentation?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        contentSurface
            .alert("当前系统不支持系统翻译", isPresented: $isTranslationAvailabilityAlertPresented) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("内嵌系统翻译需要 macOS 15 或更高版本。")
            }
            .onAppear {
                refreshSystemTranslationPrewarm()
            }
            .onChange(of: translationSourceText) { _, _ in
                translationPlan = nil
                resultState.resetTranslation()
                refreshSystemTranslationPrewarm()
            }
            .onChange(of: displayState) { _, newValue in
                guard newValue == .result else { return }
                resultState.requestTextFocus()
            }
    }

    private var contentSurface: some View {
        LiquidGlassSurface(cornerRadius: ResultPopoverLayout.cornerRadius) {
            VStack(spacing: 0) {
                header
                    .zIndex(1)

                VStack(spacing: 0) {
                    if !usesCompactTextLayout {
                        previewPane
                            .padding(.bottom, ResultPopoverLayout.sectionSpacing)
                    }

                    contentCard

                    footer
                        .frame(height: ResultPopoverLayout.footerHeight)
                        .padding(.horizontal, -(ResultPopoverLayout.horizontalInset - ResultPopoverLayout.cornerActionInset))
                }
                .padding(.horizontal, ResultPopoverLayout.horizontalInset)
                .padding(.top, ResultPopoverLayout.topContentPadding)
                .padding(.bottom, ResultPopoverLayout.bottomContentPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .topLeading) {
            tooltipOverlay
        }
        .background(prewarmTranslationTaskBridge)
        .background(translationTaskBridge)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("截图识别")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
                LightIconButton(
                    symbol: isPinned ? "pin.fill" : "pin",
                    accessibilityLabel: isPinned ? "取消固定窗口" : "固定窗口",
                    isSelected: isPinned,
                    usesCapsule: true,
                    iconRotation: .degrees(45),
                    tooltipTarget: .pin,
                    onTooltipVisibilityChange: updateActiveTooltip,
                    action: onTogglePin
                )
                LightIconButton(
                    symbol: "gearshape",
                    accessibilityLabel: "设置",
                    usesCapsule: true,
                    tooltipTarget: .settings,
                    onTooltipVisibilityChange: updateActiveTooltip,
                    action: onShowSettings
                )
            }
        }
        .padding(.leading, ResultPopoverLayout.horizontalInset)
        .padding(.trailing, ResultPopoverLayout.headerTrailingInset)
        .padding(.top, 0)
        .frame(height: ResultPopoverLayout.headerHeight)
    }

    private var previewPane: some View {
        ZStack {
            if let image = capturedPreviewImage {
                capturedPreview(image)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: displayState == .recognizing ? "viewfinder.circle" : "photo")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(displayState == .recognizing ? "截图处理中…" : "暂无截图")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(
                    width: ResultPopoverLayout.previewWidth,
                    height: ResultPopoverLayout.previewViewportHeight(for: capturedPreviewImage)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                        .strokeBorder(
                            previewBorderColor,
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2])
                        )
                    }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: ResultPopoverLayout.previewSectionHeight(for: capturedPreviewImage),
            maxHeight: ResultPopoverLayout.previewSectionHeight(for: capturedPreviewImage),
            alignment: .center
        )
    }

    @ViewBuilder
    private func capturedPreview(_ image: NSImage) -> some View {
        let viewportHeight = ResultPopoverLayout.previewViewportHeight(for: image)
        let naturalHeight = ResultPopoverLayout.previewHeight(for: image)

        Group {
            if ResultPopoverLayout.previewIsScrollable(for: image) {
                NonElasticPreviewScrollView(
                    image: image,
                    contentSize: NSSize(
                        width: ResultPopoverLayout.previewWidth,
                        height: naturalHeight
                    )
                )
                .frame(width: ResultPopoverLayout.previewWidth, height: viewportHeight)
            } else {
                previewImageContent(image, height: naturalHeight)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                .strokeBorder(previewBorderColor, lineWidth: 0.5)
        )
    }

    private var previewBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
    }

    private func previewImageContent(_ image: NSImage, height: CGFloat) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: ResultPopoverLayout.previewWidth, height: height)
    }

    private var contentCard: some View {
        Group {
            switch displayState {
            case .result:
                VStack(alignment: .leading, spacing: 10) {
                    primaryResultCard

                    if shouldShowTranslationPane {
                        translationCard
                    }
                }
            case .recognizing:
                stateCard {
                    progressBlock(
                        title: "正在识别",
                        message: "截图中的文字提取完成后，会自动填充到这里。"
                    )
                }
            case .permission:
                stateCard {
                    messageBlock(
                        title: "需要屏幕录制权限",
                        message: "请在“系统设置 -> 隐私与安全性 -> 屏幕录制”中允许本应用，然后重新触发截图识别。"
                    )
                }
            case .error:
                stateCard {
                    messageBlock(
                        title: "识别没有成功",
                        message: lastErrorMessage ?? "请重新尝试一次。"
                    )
                }
            }
        }
    }

    private func stateCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.top, 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: ResultPopoverLayout.contentCardHeight,
                idealHeight: ResultPopoverLayout.contentCardHeight,
                maxHeight: ResultPopoverLayout.contentCardHeight,
                alignment: .topLeading
            )
            .background(resultCardBackground)
    }

    private var primaryResultCard: some View {
        resultTextBlock
            .padding(.top, 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: primaryCardHeight,
                idealHeight: primaryCardHeight,
                maxHeight: primaryCardHeight,
                alignment: .topLeading
            )
            .background(resultCardBackground)
    }

    private var resultCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.quaternary.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(resultCardBorderColor, lineWidth: 0.5)
            )
    }

    private var resultCardBorderColor: Color {
        Color.black.opacity(0.14)
    }

    private var resultTextBlock: some View {
        ResultTextEditor(
            text: $recognizedText,
            focusRequestToken: resultState.textFocusRequestToken,
            outputMode: outputMode,
            isBlockEditingEnabled: isBlockEditingEnabled
        )
        .frame(
            maxWidth: .infinity,
            minHeight: visibleResultTextHeight,
            maxHeight: visibleResultTextHeight,
            alignment: .topLeading
        )
    }

    private func progressBlock(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
            }

            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func messageBlock(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: .labelColor))

            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        Group {
            switch displayState {
            case .result:
                resultFooter
            case .recognizing:
                stateFooter(
                    primaryTitle: "处理中",
                    primarySymbol: "hourglass",
                    primaryEnabled: false,
                    secondaryTitle: "关闭",
                    secondarySymbol: "xmark",
                    secondaryAction: onClose
                )
            case .permission:
                stateFooter(
                    primaryTitle: "打开设置",
                    primarySymbol: "gearshape",
                    primaryAction: onOpenScreenRecordingPreferences,
                    secondaryTitle: "关闭",
                    secondarySymbol: "xmark",
                    secondaryAction: onClose
                )
            case .error:
                stateFooter(
                    primaryTitle: "重新识别",
                    primarySymbol: "arrow.clockwise",
                    primaryAction: onRetry,
                    secondaryTitle: "关闭",
                    secondarySymbol: "xmark",
                    secondaryAction: onClose
                )
            }
        }
    }

    private var resultFooter: some View {
        HStack(spacing: 0) {
            LightIconButton(
                symbol: "arrow.clockwise",
                accessibilityLabel: "重新识别",
                usesCapsule: true,
                tooltipTarget: .retry,
                onTooltipVisibilityChange: updateActiveTooltip,
                action: onRetry
            )
            .disabled(displayState == .recognizing)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                LightIconButton(
                    symbol: "globe",
                    accessibilityLabel: "翻译",
                    usesCapsule: true,
                    tooltipTarget: .translate,
                    onTooltipVisibilityChange: updateActiveTooltip,
                    action: presentSystemTranslation
                )
                .disabled(!canTranslateCurrentText)

                LightIconButton(
                    symbol: "square.on.square",
                    accessibilityLabel: "拷贝文本",
                    usesCapsule: true,
                    tooltipTarget: .copy,
                    onTooltipVisibilityChange: updateActiveTooltip,
                    action: onCopy
                )
                .disabled(recognizedText.isEmpty || displayState != .result)
            }
        }
    }

    private func stateFooter(
        primaryTitle: String,
        primarySymbol: String,
        primaryEnabled: Bool = true,
        primaryAction: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        secondarySymbol: String? = nil,
        secondaryAction: @escaping () -> Void = {}
    ) -> some View {
        HStack(spacing: 0) {
            if let secondaryTitle, let secondarySymbol {
                stateFooterButton(title: secondaryTitle, symbol: secondarySymbol, emphasized: false, action: secondaryAction)
            }

            Spacer(minLength: 0)

            stateFooterButton(title: primaryTitle, symbol: primarySymbol, emphasized: true, action: primaryAction)
                .disabled(!primaryEnabled)
        }
    }

    private func stateFooterButton(
        title: String,
        symbol: String,
        emphasized: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 12, weight: emphasized ? .medium : .regular))
            .foregroundStyle(emphasized ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var usesCompactTextLayout: Bool {
        placementMode == .followMouse && displayState == .result
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        GeometryReader { proxy in
            if let activeTooltip {
                TooltipBubble(title: activeTooltip.title)
                    .fixedSize()
                    .position(
                        x: activeTooltip.target.centerX(in: proxy.size),
                        y: activeTooltip.target.centerY(in: proxy.size)
                    )
            }
        }
        .allowsHitTesting(false)
        .zIndex(2)
    }

    private func updateActiveTooltip(_ tooltip: TooltipPresentation?) {
        activeTooltip = tooltip
    }

    private var translationSourceText: String {
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != "未识别到文本" else {
            return ""
        }
        return text
    }

    private var visibleResultTextHeight: CGFloat {
        ResultPopoverLayout.visibleResultTextHeight(for: recognizedText, outputMode: outputMode)
    }

    private var primaryCardHeight: CGFloat {
        ResultPopoverLayout.resultPrimaryCardHeight(for: recognizedText, outputMode: outputMode)
    }

    private var canTranslateCurrentText: Bool {
        displayState == .result && !translationSourceText.isEmpty
    }

    private var shouldShowTranslationPane: Bool {
        resultState.isTranslating || !resultState.translatedText.isEmpty || resultState.translationErrorMessage != nil
    }

    private var currentTranslationDisplayText: String? {
        guard shouldShowTranslationPane else { return nil }

        if !resultState.translatedText.isEmpty {
            return resultState.translatedText
        }

        if let translationErrorMessage = resultState.translationErrorMessage {
            return translationErrorMessage
        }

        if resultState.isTranslating {
            return "正在翻译当前文本…"
        }

        return "点击“翻译”后，这里会显示结果。"
    }

    private func refreshSystemTranslationPrewarm() {
        guard #available(macOS 15.0, *) else {
            prewarmPlan = nil
            return
        }

        let service = SystemTranslationService()
        guard let plan = service.makePlan(for: translationSourceText) else {
            prewarmPlan = nil
            return
        }

        prewarmPlan = plan
        prewarmRequestToken += 1
    }

    private func presentSystemTranslation() {
        if let validationMessage = translationServiceResolver.validationMessage(for: translationSourceText, provider: translationProvider) {
            resultState.failTranslation(validationMessage)
            translationPlan = nil
            return
        }

        guard let execution = translationServiceResolver.resolve(for: translationSourceText, provider: translationProvider) else {
            return
        }

        switch execution {
        case let .system(plan, service):
            beginSystemTranslation(plan: plan, service: service)
        case let .online(plan, service):
            translationPlan = nil
            resultState.beginTranslation()
            translationRequestToken += 1
            let currentRequestToken = translationRequestToken

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                guard resultState.isTranslating, translationRequestToken == currentRequestToken else { return }
                if !beginAutomaticSystemFallbackIfAvailable() {
                    resultState.failTranslation(service.timeoutMessage(for: plan))
                }
            }

            Task {
                do {
                    let translatedText = try await service.translate(plan)
                    await MainActor.run {
                        guard translationRequestToken == currentRequestToken else { return }
                        resultState.completeTranslation(translatedText)
                    }
                } catch {
                    await MainActor.run {
                        guard translationRequestToken == currentRequestToken else { return }
                        if !beginAutomaticSystemFallbackIfAvailable() {
                            resultState.failTranslation(service.message(for: error, plan: plan))
                        }
                    }
                }
            }
        }
    }

    private func beginSystemTranslation(plan: TranslationPlan, service: SystemTranslationService) {
        guard #available(macOS 15.0, *) else {
            isTranslationAvailabilityAlertPresented = true
            return
        }

        translationPlan = plan
        resultState.beginTranslation()
        translationRequestToken += 1
        let currentRequestToken = translationRequestToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard resultState.isTranslating, translationRequestToken == currentRequestToken else { return }
            resultState.failTranslation(service.timeoutMessage(for: plan))
        }
    }

    @discardableResult
    private func beginAutomaticSystemFallbackIfAvailable() -> Bool {
        guard translationProvider == .automatic,
              let fallbackExecution = translationServiceResolver.resolve(for: translationSourceText, provider: .systemOnly),
              case let .system(fallbackPlan, fallbackService) = fallbackExecution else {
            return false
        }

        beginSystemTranslation(plan: fallbackPlan, service: fallbackService)
        return true
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "translate")
                    .font(.system(size: 11, weight: .semibold))
                Text("Apple Translate")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)

            if let translationDisplayText = currentTranslationDisplayText {
                ScrollView(.vertical) {
                    translationTextBlock(translationDisplayText)
                        .padding(.leading, 10)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic, axes: .vertical)
                .scrollIndicators(.hidden, axes: .horizontal)
                .padding(.horizontal, -10)
                .frame(height: visibleTranslationTextHeight)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .background(resultCardBackground)
    }

    private var translationDisplayColor: Color {
        .primary
    }

    @ViewBuilder
    private func translationTextBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(ResultPopoverLayout.paragraphDisplayLines(from: text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: ResultPopoverLayout.translationTextFontSize, weight: .regular))
                    .foregroundStyle(translationDisplayColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var visibleTranslationTextHeight: CGFloat {
        ResultPopoverLayout.visibleTranslationTextHeight(for: currentTranslationDisplayText)
    }

    @ViewBuilder
    private var translationTaskBridge: some View {
#if canImport(Translation)
        if #available(macOS 15.0, *), let translationPlan {
            TranslationTaskBridge(
                plan: translationPlan,
                translationService: SystemTranslationService(),
                requestToken: translationRequestToken,
                onSuccess: { translatedText in
                    resultState.completeTranslation(translatedText)
                },
                onFailure: { message in
                    resultState.failTranslation(message)
                }
            )
        }
#endif
    }

    @ViewBuilder
    private var prewarmTranslationTaskBridge: some View {
#if canImport(Translation)
        if #available(macOS 15.0, *), let prewarmPlan {
            TranslationTaskBridge(
                plan: prewarmPlan,
                translationService: SystemTranslationService(),
                requestToken: prewarmRequestToken,
                performTranslation: false,
                onSuccess: { _ in },
                onFailure: { _ in }
            )
        }
#endif
    }
}

private enum TooltipTarget {
    case pin
    case settings
    case retry
    case translate
    case copy

    func centerX(in size: CGSize) -> CGFloat {
        let trailingButtonCenter = size.width - ResultPopoverLayout.cornerActionInset - (ResultPopoverLayout.iconButtonDiameter / 2)
        return switch self {
        case .settings, .copy:
            trailingButtonCenter
        case .pin, .translate:
            trailingButtonCenter - ResultPopoverLayout.iconButtonDiameter - 4
        case .retry:
            ResultPopoverLayout.cornerActionInset + (ResultPopoverLayout.iconButtonDiameter / 2)
        }
    }

    func centerY(in size: CGSize) -> CGFloat {
        return switch self {
        case .pin, .settings:
            ResultPopoverLayout.headerHeight + 10
        case .retry, .translate, .copy:
            size.height - ResultPopoverLayout.footerHeight - ResultPopoverLayout.bottomContentPadding - 10
        }
    }
}

private struct TooltipPresentation {
    let title: String
    let target: TooltipTarget
}

private struct LightIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var isSelected: Bool = false
    var bouncesOnTap: Bool = false
    var standalone: Bool = true
    var usesCapsule: Bool = false
    var iconRotation: Angle = .zero
    var tooltipTarget: TooltipTarget?
    var onTooltipVisibilityChange: ((TooltipPresentation?) -> Void)?
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    @State private var bounceValue = 0
    @State private var tooltipRequestToken = 0

    var body: some View {
        Button {
            if bouncesOnTap {
                bounceValue += 1
            }
            action()
        } label: {
            iconImage
                .symbolEffect(.bounce, value: bounceValue)
                .frame(
                    width: ResultPopoverLayout.iconButtonDiameter,
                    height: ResultPopoverLayout.iconButtonDiameter
                )
                .background { buttonBackground }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(Text(accessibilityLabel))
        .onHover { isHovering = $0; updateTooltipVisibility(for: $0) }
        .onDisappear {
            tooltipRequestToken += 1
            onTooltipVisibilityChange?(nil)
        }
    }

    private func updateTooltipVisibility(for isHovering: Bool) {
        tooltipRequestToken += 1
        let requestToken = tooltipRequestToken
        onTooltipVisibilityChange?(nil)

        guard isHovering, let tooltipTarget else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard requestToken == tooltipRequestToken, self.isHovering else { return }
            onTooltipVisibilityChange?(TooltipPresentation(title: accessibilityLabel, target: tooltipTarget))
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if standalone {
            if isSelected || (isHovering && isEnabled) {
                if usesCapsule {
                    Capsule()
                        .fill(backgroundFill)
                        .overlay(Capsule().strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
                        )
                }
            }
        } else if isSelected {
            Circle().fill(.primary.opacity(0.16))
        } else if isHovering, isEnabled {
            Circle().fill(.primary.opacity(0.24))
        }
    }

    private var backgroundFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.primary.opacity(0.15))
        }
        if isHovering, isEnabled {
            return AnyShapeStyle(.primary.opacity(0.24))
        }
        return AnyShapeStyle(.primary.opacity(0.05))
    }

    private var iconImage: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
            .rotationEffect(iconRotation)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
    }
}

private struct TooltipBubble: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
    }
}

/// 长截图使用原生滚动容器，以关闭到达边界时的弹性回弹。
private struct NonElasticPreviewScrollView: NSViewRepresentable {
    let image: NSImage
    let contentSize: NSSize

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: contentSize))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        scrollView.documentView = imageView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let imageView = scrollView.documentView as? NSImageView else { return }
        imageView.image = image
        imageView.frame = NSRect(origin: .zero, size: contentSize)
    }
}

private struct ResultTextEditor: NSViewRepresentable {
    @Binding var text: String
    let focusRequestToken: Int
    let outputMode: OCRTextOutputMode
    let isBlockEditingEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = FocusableResultTextView(frame: scrollView.bounds)
        textView.delegate = context.coordinator
        textView.string = text
        textView.isBlockEditingEnabled = isBlockEditingEnabled
        textView.isEditable = true
        textView.isRichText = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .textColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.textColor
        ]
        textView.font = .systemFont(ofSize: ResultPopoverLayout.resultTextFontSize, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 2, height: 0)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 1
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.insertionPointColor = .textColor
        applyParagraphStyle(to: textView)
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? FocusableResultTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.isBlockEditingEnabled = isBlockEditingEnabled

        applyParagraphStyle(to: textView)

        if context.coordinator.lastFocusRequestToken != focusRequestToken {
            context.coordinator.lastFocusRequestToken = focusRequestToken
            DispatchQueue.main.async {
                guard let window = textView.window else { return }
                let insertionLocation = textView.string.utf16.count
                let insertionRange = NSRange(location: insertionLocation, length: 0)
                window.makeFirstResponder(textView)
                textView.setSelectedRange(insertionRange)
                textView.scrollRangeToVisible(insertionRange)
            }
        }
    }

    private func applyParagraphStyle(to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = outputMode == .readingOptimized ? ResultPopoverLayout.readingOptimizedParagraphSpacing : 0

        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        let selectedRange = textView.selectedRange()
        textView.textStorage?.setAttributes(
            [
                .font: NSFont.systemFont(ofSize: ResultPopoverLayout.resultTextFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ],
            range: NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        )
        textView.setSelectedRange(selectedRange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var lastFocusRequestToken = 0

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class FocusableResultTextView: NSTextView {
    var isBlockEditingEnabled = false {
        didSet {
            guard !isBlockEditingEnabled else { return }
            usesBlockSelectionAppearance = false
            needsDisplay = true
        }
    }
    private var lastBlockSelectionRange: NSRange?
    private var usesBlockSelectionAppearance = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isSelectAllShortcut = event.charactersIgnoringModifiers?.lowercased() == "a"

        guard isBlockEditingEnabled,
              isSelectAllShortcut,
              modifiers == .command || modifiers == .control else {
            clearBlockSelectionAppearance()
            super.keyDown(with: event)
            return
        }

        selectCurrentBlockOrAllText()
    }

    override func doCommand(by selector: Selector) {
        guard isBlockEditingEnabled,
              selector == #selector(moveToBeginningOfLine(_:)),
              isControlACommand else {
            super.doCommand(by: selector)
            return
        }

        selectCurrentBlockOrAllText()
    }

    override func selectAll(_ sender: Any?) {
        guard isBlockEditingEnabled else {
            super.selectAll(sender)
            return
        }

        selectCurrentBlockOrAllText()
    }

    override func moveToBeginningOfLine(_ sender: Any?) {
        guard isBlockEditingEnabled, isControlACommand else {
            super.moveToBeginningOfLine(sender)
            return
        }

        selectCurrentBlockOrAllText()
    }

    private func selectCurrentBlockOrAllText() {
        let selection = BlockEditingSelection.next(
            in: string,
            selectedRange: selectedRange(),
            previousBlockSelectionRange: lastBlockSelectionRange
        )
        layoutManager?.ensureGlyphs(forCharacterRange: selection.range)
        layoutManager?.ensureLayout(forCharacterRange: selection.range)
        usesBlockSelectionAppearance = true
        lastBlockSelectionRange = selection.selectedBlockRange
        setSelectedRange(selection.range)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        clearBlockSelectionAppearance()
        super.mouseDown(with: event)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard usesBlockSelectionAppearance,
              let layoutManager else {
            return
        }

        let selectedRange = selectedRange()
        guard selectedRange.length > 0 else { return }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: selectedRange,
            actualCharacterRange: nil
        )
        let backgroundColor = (selectedTextAttributes[.backgroundColor] as? NSColor)
            ?? .selectedTextBackgroundColor
        let textOrigin = textContainerOrigin

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineFragmentRect, _, _, _, _ in
            let selectionRect = lineFragmentRect.offsetBy(dx: textOrigin.x, dy: textOrigin.y)
            guard selectionRect.intersects(rect) else { return }
            backgroundColor.setFill()
            selectionRect.intersection(rect).fill()
        }
    }

    private func clearBlockSelectionAppearance() {
        guard usesBlockSelectionAppearance else { return }
        usesBlockSelectionAppearance = false
        needsDisplay = true
    }

    private var isControlACommand: Bool {
        guard let event = NSApp.currentEvent else { return false }

        return event.charactersIgnoringModifiers?.lowercased() == "a"
            && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else { return }

        var adjustedRect = rect
        if adjustedRect.minX < 1 {
            adjustedRect.origin.x = 1
        }

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        adjustedRect.size.width = 1 / scale

        adjustedRect.origin.x = round(adjustedRect.origin.x * scale) / scale
        adjustedRect.size.width = round(adjustedRect.size.width * scale) / scale

        color.setFill()
        NSBezierPath(rect: adjustedRect).fill()
    }
}

#if canImport(Translation)
@available(macOS 15.0, *)
@MainActor
private struct TranslationTaskBridge: View {
    let plan: TranslationPlan
    let translationService: any TranslationServicing
    let requestToken: Int
    var performTranslation = true
    let onSuccess: (String) -> Void
    let onFailure: (String) -> Void

    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: requestToken, initial: true) { _, token in
                guard token > 0 else { return }
                configuration = TranslationSession.Configuration(
                    source: plan.sourceLanguage,
                    target: plan.targetLanguage
                )
            }
            .translationTask(configuration) { session in
                // Swift 6.3 会将 `session` 视为主 actor 隔离值；先创建 nonisolated 别名，
                // 再调用 TranslationSession 的 nonisolated async API，避免 SendingRisksDataRace 诊断。
                nonisolated(unsafe) let translationSession = session
                do {
                    try await translationSession.prepareTranslation()
                    guard performTranslation else {
                        configuration = nil
                        return
                    }
                    let translatedText = try await translationSession.translate(plan.sourceText).targetText
                    let trimmedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedText.isEmpty {
                        onFailure("系统翻译未返回内容，请重试一次。")
                    } else {
                        onSuccess(trimmedText)
                    }
                    configuration = nil
                } catch {
                    onFailure(translationService.message(for: error, plan: plan))
                    configuration = nil
                }
            }
    }
}
#endif
