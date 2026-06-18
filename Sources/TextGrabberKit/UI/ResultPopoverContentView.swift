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
    @State private var hoveredHeaderButtonSymbol: String?
    @State private var isHoveringRetryButton = false
    @State private var isHoveringTranslateButton = false

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

                VStack(spacing: 10) {
                    if !usesCompactTextLayout {
                        previewPane
                    }

                    contentCard

                    footer
                }
                .padding(.horizontal, ResultPopoverLayout.horizontalInset)
                .padding(.top, ResultPopoverLayout.topContentPadding)
                .padding(.bottom, ResultPopoverLayout.bottomContentPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white.opacity(0.82))
        }
        .overlay(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
                .stroke(
                    Color.white.opacity(0.65),
                    lineWidth: 1
                )
        )
        .background(prewarmTranslationTaskBridge)
        .background(translationTaskBridge)
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles.2")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.345, blue: 0.231))

                Text("iGET！")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.345, blue: 0.231))
            }

            Spacer()

            HStack(spacing: 5) {
                compactIconButton(
                    symbol: isPinned ? "pin.fill" : "pin",
                    accessibilityLabel: isPinned ? "取消固定窗口" : "固定窗口",
                    isSelected: isPinned,
                    action: onTogglePin
                )
                compactIconButton(symbol: "gearshape", accessibilityLabel: "设置", action: onShowSettings)
            }
        }
        .padding(.horizontal, ResultPopoverLayout.horizontalInset)
        .padding(.top, 0)
        .frame(height: ResultPopoverLayout.headerHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 0.5)
        }
    }

    private func compactIconButton(
        symbol: String,
        accessibilityLabel: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    isSelected
                        ? Color(red: 1.0, green: 0.345, blue: 0.231)
                        : Color.black.opacity(0.5)
                )
                .frame(
                    width: 32,
                    height: 32
                )
                .background {
                    if hoveredHeaderButtonSymbol == symbol || isSelected {
                        Circle()
                            .fill(
                                isSelected
                                    ? Color(red: 1.0, green: 0.345, blue: 0.231).opacity(0.12)
                                    : Color.black.opacity(0.05)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .onHover { isHovering in
            hoveredHeaderButtonSymbol = isHovering ? symbol : nil
        }
    }

    private var previewPane: some View {
        ZStack {
            if let image = capturedPreviewImage {
                RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 18,
                        y: 12
                    )
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: ResultPopoverLayout.previewWidth,
                                height: ResultPopoverLayout.previewHeight(for: capturedPreviewImage)
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: ResultPopoverLayout.previewCornerRadius,
                                    style: .continuous
                                )
                            )
                    }
                    .frame(
                        width: ResultPopoverLayout.previewWidth,
                        height: ResultPopoverLayout.previewHeight(for: capturedPreviewImage)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.9),
                                lineWidth: 1
                            )
                    )
            } else {
                RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .frame(
                        width: ResultPopoverLayout.previewWidth,
                        height: ResultPopoverLayout.previewHeight(for: capturedPreviewImage)
                    )
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: displayState == .recognizing ? "viewfinder.circle" : "photo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.5))
                            Text(displayState == .recognizing ? "截图处理中…" : "暂无截图")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                    }
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 18,
                        y: 12
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: ResultPopoverLayout.previewSectionHeight(for: capturedPreviewImage),
            maxHeight: ResultPopoverLayout.previewSectionHeight(for: capturedPreviewImage),
            alignment: .center
        )
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
            .background(primaryResultCardBackground)
    }

    private var primaryResultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            outputModeControl
            resultTextBlock
        }
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
        .background(primaryResultCardBackground)
    }

    private var primaryResultCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }

    private var outputModeControl: some View {
        HStack(spacing: 0) {
            outputModeButton(.readingOptimized)
            outputModeButton(.sourceLayout)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(
            Color.black.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func outputModeButton(_ mode: OCRTextOutputMode) -> some View {
        let isSelected = outputMode == mode

        return Button {
            outputMode = mode
        } label: {
            Text(mode == .sourceLayout ? "原始文本" : mode.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? Color(nsColor: .labelColor)
                        : Color.black.opacity(0.5)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: 6,
                            style: .continuous
                        )
                        .fill(Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }



    private var resultTextBlock: some View {
        ResultTextEditor(
            text: $recognizedText,
            focusRequestToken: resultState.textFocusRequestToken,
            outputMode: outputMode
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
                    primarySymbol: "gearshape.fill",
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
        HStack(spacing: 4) {
            iconFooterButton(symbol: "arrow.triangle.2.circlepath", showsBackground: isHoveringRetryButton, action: onRetry)
                .onHover { isHovering in
                    isHoveringRetryButton = isHovering
                }
                .disabled(displayState == .recognizing)

            Spacer(minLength: 0)

            textFooterButton(
                title: "翻译",
                symbol: "globe",
                style: .secondary,
                showsBackground: isHoveringTranslateButton,
                action: presentSystemTranslation
            )
            .onHover { isHovering in
                isHoveringTranslateButton = isHovering
            }
            .disabled(!canTranslateCurrentText)

            textFooterButton(
                title: "拷贝文本",
                symbol: "document.on.document",
                style: .primary,
                action: onCopy
            )
            .disabled(recognizedText.isEmpty || displayState != .result)
        }
    }

    private func iconFooterButton(symbol: String, showsBackground: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.5))
                .frame(
                    width: 32,
                    height: 32
                )
                .background {
                    if showsBackground {
                        Capsule()
                            .fill(Color.black.opacity(0.05))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private enum FooterButtonStyle {
        case primary
        case secondary
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
        HStack(spacing: 4) {
            if let secondaryTitle, let secondarySymbol {
                textFooterButton(
                    title: secondaryTitle,
                    symbol: secondarySymbol,
                    style: .secondary,
                    action: secondaryAction
                )
            }

            Spacer(minLength: 0)

            textFooterButton(
                title: primaryTitle,
                symbol: primarySymbol,
                style: .primary,
                action: primaryAction
            )
            .disabled(!primaryEnabled)
        }
    }

    private func textFooterButton(
        title: String,
        symbol: String,
        style: FooterButtonStyle,
        showsBackground: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                Text(title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            .foregroundStyle(style == .primary ? Color.white : Color.black.opacity(0.5))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background {
                if showsBackground {
                    Capsule()
                        .fill(style == .primary ? Color.black : Color.black.opacity(0.05))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var usesCompactTextLayout: Bool {
        placementMode == .followMouse && displayState == .result
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
            HStack(spacing: 0) {
                Text("翻译结果")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.9647, green: 0.3137, blue: 0.1961))
            }

            if let translationDisplayText = currentTranslationDisplayText {
                ScrollView(.vertical, showsIndicators: translationNeedsScrolling) {
                    translationTextBlock(translationDisplayText)
                        .padding(.trailing, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: visibleTranslationTextHeight)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .background(translationCardBackground)
    }

    private var translationCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.9647, green: 0.3137, blue: 0.1961).opacity(0.04),
                        Color(red: 0.9647, green: 0.3137, blue: 0.1961).opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.9647, green: 0.3137, blue: 0.1961).opacity(0.16), lineWidth: 1)
            )
    }

    private var translationDisplayColor: Color {
        if resultState.translationErrorMessage != nil {
            return Color(nsColor: .labelColor)
        }

        return Color.black.opacity(0.62)
    }

    @ViewBuilder
    private func translationTextBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(ResultPopoverLayout.paragraphDisplayLines(from: text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 12, weight: .regular))
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

    private var translationNeedsScrolling: Bool {
        guard let translationDisplayText = currentTranslationDisplayText else {
            return false
        }

        let measuredHeight = ResultPopoverLayout.measuredTextHeight(
            for: ResultPopoverLayout.normalizedParagraphText(translationDisplayText),
            width: ResultPopoverLayout.translationTextWidth,
            paragraphSpacing: ResultPopoverLayout.translationParagraphSpacing
        )

        return measuredHeight > visibleTranslationTextHeight
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

private struct ResultTextEditor: NSViewRepresentable {
    @Binding var text: String
    let focusRequestToken: Int
    let outputMode: OCRTextOutputMode

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

        let textView = FocusableResultTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isEditable = true
        textView.isRichText = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.font = .systemFont(ofSize: 12, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 2, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 1
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.insertionPointColor = NSColor(
            calibratedRed: 1.0,
            green: 0.345,
            blue: 0.231,
            alpha: 1.0
        )
        applyParagraphStyle(to: textView)
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? FocusableResultTextView else { return }

        if textView.string != text {
            textView.string = text
        }

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
        let attributedText = NSMutableAttributedString(string: textView.string)
        attributedText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ],
            range: NSRange(location: 0, length: attributedText.length)
        )
        textView.textStorage?.setAttributedString(attributedText)
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
    override var acceptsFirstResponder: Bool { true }

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
