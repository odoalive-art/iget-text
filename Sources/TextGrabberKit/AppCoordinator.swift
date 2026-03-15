import AppKit
import Combine

@MainActor
public final class AppCoordinator: ObservableObject {
    enum WorkflowState: Equatable {
        case idle
        case selecting
        case recognizing
        case resultVisible
    }

    enum PopoverContentState: Equatable {
        case idle
        case recognizing
        case result
        case permission
        case error
    }

    @Published var workflowState: WorkflowState = .idle
    @Published var popoverState: PopoverContentState = .idle
    @Published var outputMode: OCRTextOutputMode = .readingOptimized
    @Published var recognizedText = ""
    @Published var capturedPreviewImage: NSImage?
    @Published var statusMessage = "按住快捷键开始框选识别"
    @Published var lastErrorMessage: String?

    let settings: AppSettings

    private let captureService = CaptureService()
    private var hotkeyController: HotkeyController?
    private var popoverController: ResultPopoverController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var lastCapturedImage: CGImage?
    private var lastOCRResult: OCRResult?
    private var isShortcutKeyDown = false
    private var activationReleaseMonitorTask: Task<Void, Never>?

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public func start() {
        let hotkeyController = HotkeyController()
        self.hotkeyController = hotkeyController

        hotkeyController.onPress = { [weak self] in
            self?.handleHotkeyPressed()
        }

        hotkeyController.onRelease = { [weak self] in
            self?.handleHotkeyReleased()
        }

        if !hotkeyController.updateActivation(mode: settings.activationMode, shortcut: settings.hotkey) {
            settings.resetHotkey()
            _ = hotkeyController.updateActivation(mode: settings.activationMode, shortcut: settings.hotkey)
        }

        settings.$hotkey
            .combineLatest(settings.$activationMode)
            .dropFirst()
            .sink { [weak self] shortcut, activationMode in
                guard let self else { return }
                if !(self.hotkeyController?.updateActivation(mode: activationMode, shortcut: shortcut) ?? false) {
                    self.settings.resetHotkey()
                    _ = self.hotkeyController?.updateActivation(mode: self.settings.activationMode, shortcut: self.settings.hotkey)
                }
            }
            .store(in: &cancellables)

        popoverController = ResultPopoverController(coordinator: self)
    }

    func handleHotkeyPressed() {
        guard workflowState == .idle || workflowState == .resultVisible else { return }

        isShortcutKeyDown = true
        lastErrorMessage = nil
        capturedPreviewImage = nil
        popoverController?.hide()

        guard captureService.ensureScreenCapturePermission() else {
            workflowState = .idle
            popoverState = .permission
            statusMessage = "需要开启屏幕录制权限后才能识别截图。"
            popoverController?.showPermissionError()
            return
        }

        workflowState = .selecting
        popoverState = .idle
        statusMessage = "请使用系统截图框选要识别的区域。"
        beginActivationReleaseMonitoringIfNeeded()

        Task {
            await captureAndRecognize()
        }
    }

    func handleHotkeyReleased() {
        isShortcutKeyDown = false
    }

    func retryLastSelection() {
        guard let lastCapturedImage else { return }
        Task {
            await recognize(image: lastCapturedImage)
        }
    }

    func copyRecognizedText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedText, forType: .string)
        statusMessage = "识别结果已复制到剪贴板。"
    }

    func setOutputMode(_ mode: OCRTextOutputMode) {
        outputMode = mode
        applyRecognizedTextForCurrentMode()
    }

    func closePopover() {
        popoverController?.hide()
        workflowState = .idle
    }

    func togglePopoverFromStatusItem() {
        popoverController?.toggle()
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }

    func openScreenRecordingPreferences() {
        captureService.openScreenRecordingPreferences()
    }

    private func showResult(_ result: OCRResult) {
        lastOCRResult = result
        applyRecognizedTextForCurrentMode()
        workflowState = .resultVisible
        popoverState = .result
        statusMessage = recognizedText == "未识别到文本" ? "未识别到文本。" : "识别完成，可直接复制或编辑。"
        popoverController?.show(result: result)
    }

    private func captureAndRecognize() async {
        defer {
            stopActivationReleaseMonitoring()
        }

        do {
            let image = try await captureService.captureInteractiveSelection()
            await recognize(image: image)
        } catch {
            workflowState = .idle

            if let captureError = error as? CaptureError, captureError == .cancelled {
                popoverController?.hide()
                statusMessage = captureError.localizedDescription
                return
            }

            popoverState = .error
            lastErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            popoverController?.showError(message: error.localizedDescription)
        }
    }

    private func recognize(image: CGImage) async {
        workflowState = .recognizing
        popoverState = .recognizing
        statusMessage = "正在识别..."
        popoverController?.showRecognizing()

        do {
            lastCapturedImage = image
            capturedPreviewImage = NSImage(cgImage: image, size: .zero)
            let ocrService = OCRService(languages: settings.ocrLanguages)
            let result = try await ocrService.recognizeText(from: image)
            showResult(result)
        } catch {
            workflowState = .idle
            popoverState = .error
            lastErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            popoverController?.showError(message: error.localizedDescription)
        }
    }

    private func beginActivationReleaseMonitoringIfNeeded() {
        stopActivationReleaseMonitoring()

        guard settings.activationMode == .functionKey else {
            return
        }

        activationReleaseMonitorTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))

                await MainActor.run {
                    guard self.workflowState == .selecting else { return }
                    guard self.hotkeyController?.isFunctionKeyPressed() == true else {
                        self.captureService.cancelInteractiveSelection()
                        return
                    }
                }
            }
        }
    }

    private func stopActivationReleaseMonitoring() {
        activationReleaseMonitorTask?.cancel()
        activationReleaseMonitorTask = nil
    }

    private func applyRecognizedTextForCurrentMode() {
        let text = lastOCRResult?.text(for: outputMode).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        recognizedText = text.isEmpty ? "未识别到文本" : text
    }
}
