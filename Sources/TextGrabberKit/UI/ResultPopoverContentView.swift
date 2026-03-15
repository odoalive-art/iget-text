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

private enum ResultPopoverSectionStyle {
    static let cornerRadius: CGFloat = 14
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
        .background(prewarmTranslationTaskBridge)
        .background(translationTaskBridge)
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

            Button("系统翻译") {
                presentSystemTranslation()
            }
            .disabled(!canTranslateCurrentText)
            .popoverSecondaryButtonStyle()

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
                    .frame(minHeight: 140, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)

                if shouldShowTranslationPane {
                    Divider()
                    translationPane
                }
            }
        }
        .frame(maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("翻译结果")
                    .font(.headline)
                Spacer()
                if resultState.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Group {
                if !resultState.translatedText.isEmpty {
                    TextEditor(text: .constant(resultState.translatedText))
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                } else if let translationErrorMessage = resultState.translationErrorMessage {
                    Text(translationErrorMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                } else if resultState.isTranslating {
                    Text("正在使用系统翻译处理当前文本...")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                } else {
                    Text("点击“系统翻译”后，这里会显示翻译结果。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(12)
                }
            }
            .frame(minHeight: 120, maxHeight: 160, alignment: .topLeading)
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
