import AppKit

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
    @Published var statusMessage = "按住快捷键开始框选识别"

    let settings: AppSettings
    let resultState = RecognitionResultState()

    private let triggerController: CaptureTriggerController
    private let workflow: RecognitionWorkflow
    private var popoverController: ResultPopoverController?
    private var settingsWindowController: SettingsWindowController?
    private var lastCapturedImage: CGImage?

    public init(settings: AppSettings) {
        self.settings = settings
        self.triggerController = CaptureTriggerController(settings: settings)
        self.workflow = RecognitionWorkflow()
    }

    init(
        settings: AppSettings,
        workflow: RecognitionWorkflow,
        triggerController: CaptureTriggerController
    ) {
        self.settings = settings
        self.workflow = workflow
        self.triggerController = triggerController
    }

    public func start() {
        triggerController.onTrigger = { [weak self] in
            self?.handleHotkeyPressed()
        }
        triggerController.start()

        popoverController = ResultPopoverController(coordinator: self)
    }

    func handleHotkeyPressed() {
        guard workflowState == .idle || workflowState == .resultVisible else { return }

        resultState.resetForNewCapture()
        popoverController?.hide()

        guard workflow.ensureScreenCapturePermission() else {
            workflowState = .idle
            popoverState = .permission
            statusMessage = "需要开启屏幕录制权限后才能识别截图。"
            popoverController?.showPermissionError()
            return
        }

        workflowState = .selecting
        popoverState = .idle
        statusMessage = "请使用系统截图框选要识别的区域。"
        triggerController.beginSelectionMonitoring(
            isSelectionActive: { [weak self] in
                self?.workflowState == .selecting
            },
            cancelSelection: { [weak self] in
                self?.workflow.cancelInteractiveSelection()
            }
        )

        Task {
            await captureAndRecognize()
        }
    }

    func retryLastSelection() {
        guard let lastCapturedImage else { return }
        Task {
            await recognize(image: lastCapturedImage)
        }
    }

    func copyRecognizedText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultState.recognizedText, forType: .string)
        statusMessage = "识别结果已复制到剪贴板。"
    }

    func setOutputMode(_ mode: OCRTextOutputMode) {
        resultState.setOutputMode(mode)
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
        workflow.openScreenRecordingPreferences()
    }

    private func showResult(_ result: OCRResult) {
        resultState.showResult(result)
        workflowState = .resultVisible
        popoverState = .result
        statusMessage = resultState.recognizedText == "未识别到文本" ? "未识别到文本。" : "识别完成，可直接复制或编辑。"
        popoverController?.show(result: result)
    }

    private func captureAndRecognize() async {
        defer {
            triggerController.stopSelectionMonitoring()
        }

        do {
            let output = try await workflow.captureAndRecognize(languages: settings.ocrLanguages)
            lastCapturedImage = output.image
            resultState.setCapturedImage(output.image)
            showResult(output.result)
        } catch {
            workflowState = .idle

            if let captureError = error as? CaptureError, captureError == .cancelled {
                popoverController?.hide()
                statusMessage = captureError.localizedDescription
                return
            }

            popoverState = .error
            resultState.setErrorMessage(error.localizedDescription)
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
            resultState.setCapturedImage(image)
            let result = try await workflow.recognize(image: image, languages: settings.ocrLanguages)
            showResult(result)
        } catch {
            workflowState = .idle
            popoverState = .error
            resultState.setErrorMessage(error.localizedDescription)
            statusMessage = error.localizedDescription
            popoverController?.showError(message: error.localizedDescription)
        }
    }

}
