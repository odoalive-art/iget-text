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
    @ObservedObject var resultState: RecognitionResultState
    let translationServiceResolver: TranslationServiceResolver
    let translationProvider: TranslationProviderMode
    @Binding var outputMode: OCRTextOutputMode
    @Binding var recognizedText: String
    let capturedPreviewImage: NSImage?
    let lastErrorMessage: String?
    let onRetry: () -> Void
    let onCopy: () -> Void
    let onShowSettings: () -> Void
    let onClose: () -> Void
    let onOpenScreenRecordingPreferences: () -> Void
    @State private var isTranslationAvailabilityAlertPresented = false
    @State private var prewarmRequestToken = 0
    @State private var translationRequestToken = 0
    @State private var prewarmPlan: TranslationPlan?
    @State private var translationPlan: TranslationPlan?

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
    }

    private var contentSurface: some View {
        LiquidGlassSurface(cornerRadius: ResultPopoverLayout.cornerRadius) {
            VStack(spacing: 0) {
                header

                VStack(spacing: 17) {
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
            .background(ResultPopoverPalette.panelBackground)
        }
        .overlay(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .background(prewarmTranslationTaskBridge)
        .background(translationTaskBridge)
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.resultPopoverIcon)
                    .foregroundStyle(ResultPopoverPalette.accent)

                Text("iGET！")
                    .font(.resultPopoverTitle)
                    .foregroundStyle(ResultPopoverPalette.accent)
            }

            Spacer()

            HStack(spacing: 5) {
                compactIconButton(symbol: "gearshape", action: onShowSettings)
                compactIconButton(symbol: "xmark.circle", action: onClose)
            }
        }
        .padding(.horizontal, ResultPopoverLayout.horizontalInset)
        .padding(.top, 10)
        .frame(height: ResultPopoverLayout.headerHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 0.5)
        }
    }

    private func compactIconButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.resultPopoverSymbol)
                .foregroundStyle(ResultPopoverPalette.secondaryText)
                .frame(width: 24, height: 24)
                .background(ResultPopoverPalette.softFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(symbol == "gearshape" ? "设置" : "关闭"))
    }

    private var previewPane: some View {
        ZStack {
            if let image = capturedPreviewImage {
                RoundedRectangle(cornerRadius: ResultPopoverLayout.previewCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: ResultPopoverPalette.shadowColor, radius: 18, y: 12)
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
                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
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
                                .foregroundStyle(ResultPopoverPalette.secondaryText)
                            Text(displayState == .recognizing ? "截图处理中…" : "暂无截图")
                                .font(.resultPopoverMedium)
                                .foregroundStyle(ResultPopoverPalette.secondaryText)
                        }
                    }
                    .shadow(color: ResultPopoverPalette.shadowColor, radius: 18, y: 12)
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
        VStack(alignment: .leading, spacing: 15) {
            if displayState == .result {
                outputModeControl
            }

            Group {
                switch displayState {
                case .result:
                    resultTextBlock
                case .recognizing:
                    progressBlock(
                        title: "正在识别",
                        message: "截图中的文字提取完成后，会自动填充到这里。"
                    )
                case .permission:
                    messageBlock(
                        title: "需要屏幕录制权限",
                        message: "请在“系统设置 -> 隐私与安全性 -> 屏幕录制”中允许本应用，然后重新触发截图识别。"
                    )
                case .error:
                    messageBlock(
                        title: "识别没有成功",
                        message: lastErrorMessage ?? "请重新尝试一次。"
                    )
                }
            }
        }
        .padding(.top, ResultPopoverLayout.contentCardTopPadding)
        .padding(.leading, ResultPopoverLayout.contentCardInnerHorizontalPadding)
        .padding(.trailing, ResultPopoverLayout.contentCardInnerHorizontalPadding)
        .padding(.bottom, ResultPopoverLayout.contentCardBottomPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: cardHeight,
            idealHeight: cardHeight,
            maxHeight: cardHeight,
            alignment: .topLeading
        )
        .background(contentCardBackground)
    }

    private var contentCardBackground: some View {
        RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
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
                RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
                    .stroke(ResultPopoverPalette.controlStroke, lineWidth: 1)
            )
    }

    private var outputModeControl: some View {
        HStack(spacing: 0) {
            outputModeButton(.readingOptimized)
            outputModeButton(.sourceLayout)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .background(ResultPopoverPalette.controlFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func outputModeButton(_ mode: OCRTextOutputMode) -> some View {
        let isSelected = outputMode == mode

        return Button {
            outputMode = mode
        } label: {
            Text(mode == .sourceLayout ? "原始文本" : mode.displayName)
                .font(.resultPopoverMedium)
                .foregroundStyle(ResultPopoverPalette.baseText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var resultTextBlock: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(recognizedText)
                    .font(.resultPopoverBody)
                    .foregroundStyle(ResultPopoverPalette.baseText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)

                if shouldShowTranslationPane {
                    translationPane
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func progressBlock(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(title)
                    .font(.resultPopoverMedium)
                    .foregroundStyle(ResultPopoverPalette.baseText)
            }

            Text(message)
                .font(.resultPopoverBody)
                .foregroundStyle(ResultPopoverPalette.baseText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func messageBlock(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.resultPopoverMedium)
                .foregroundStyle(ResultPopoverPalette.baseText)

            Text(message)
                .font(.resultPopoverBody)
                .foregroundStyle(ResultPopoverPalette.baseText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            iconFooterButton(symbol: "pencil", action: {})
                .disabled(true)

            iconFooterButton(symbol: "arrow.clockwise", action: onRetry)
                .disabled(displayState == .recognizing)

            Spacer(minLength: 0)

            textFooterButton(
                title: "翻译",
                symbol: "globe",
                style: .secondary,
                action: presentSystemTranslation
            )
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

    private func iconFooterButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.resultPopoverButton)
                .foregroundStyle(ResultPopoverPalette.secondaryText)
                .frame(width: 24, height: 24)
                .background(ResultPopoverPalette.softFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private enum FooterButtonStyle {
        case primary
        case secondary
    }

    private func textFooterButton(
        title: String,
        symbol: String,
        style: FooterButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.resultPopoverButton)
                Text(title)
                    .font(.resultPopoverButton)
            }
            .foregroundStyle(style == .primary ? Color.white : ResultPopoverPalette.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                (style == .primary ? Color.black : ResultPopoverPalette.softFill),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var usesCompactTextLayout: Bool {
        placementMode == .followMouse && displayState == .result
    }

    private var cardHeight: CGFloat {
        guard displayState == .result else {
            return ResultPopoverLayout.contentCardHeight
        }

        return ResultPopoverLayout.resultCardHeight(for: recognizedText)
    }

    private var translationSourceText: String {
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != "未识别到文本" else {
            return ""
        }
        return text
    }

    private var canTranslateCurrentText: Bool {
        displayState == .result && !translationSourceText.isEmpty
    }

    private var shouldShowTranslationPane: Bool {
        resultState.isTranslating || !resultState.translatedText.isEmpty || resultState.translationErrorMessage != nil
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
        case let .online(plan, service):
            translationPlan = nil
            resultState.beginTranslation()
            translationRequestToken += 1
            let currentRequestToken = translationRequestToken

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                guard resultState.isTranslating, translationRequestToken == currentRequestToken else { return }
                resultState.failTranslation(service.timeoutMessage(for: plan))
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
                        if translationProvider == .automatic,
                           let fallbackExecution = translationServiceResolver.resolve(for: translationSourceText, provider: .systemOnly),
                           case let .system(fallbackPlan, fallbackService) = fallbackExecution,
                           #available(macOS 15.0, *) {
                            translationPlan = fallbackPlan
                            resultState.beginTranslation()
                            translationRequestToken += 1
                            let fallbackToken = translationRequestToken
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(20))
                                guard resultState.isTranslating, translationRequestToken == fallbackToken else { return }
                                resultState.failTranslation(fallbackService.timeoutMessage(for: fallbackPlan))
                            }
                        } else {
                            resultState.failTranslation(service.message(for: error, plan: plan))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var translationPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.black.opacity(0.08))

            HStack {
                Text("翻译结果")
                    .font(.resultPopoverMedium)
                    .foregroundStyle(ResultPopoverPalette.baseText)
                Spacer()
                if resultState.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Group {
                if !resultState.translatedText.isEmpty {
                    Text(resultState.translatedText)
                } else if let translationErrorMessage = resultState.translationErrorMessage {
                    Text(translationErrorMessage)
                } else if resultState.isTranslating {
                    Text("正在使用系统翻译处理当前文本…")
                } else {
                    Text("点击“翻译”后，这里会显示结果。")
                }
            }
            .font(.resultPopoverBody)
            .foregroundStyle(ResultPopoverPalette.baseText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
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
                Task { @MainActor in
                    do {
                        try await session.prepareTranslation()
                        guard performTranslation else {
                            configuration = nil
                            return
                        }
                        let translatedText = try await session.translate(plan.sourceText).targetText
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
}
#endif
