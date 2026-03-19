import AppKit
import Foundation

struct RecognitionWorkflowOutput: Sendable {
    let image: CGImage
    let result: OCRResult
}

@MainActor
final class RecognitionWorkflow {
    private let captureService: CaptureService

    init(captureService: CaptureService? = nil) {
        self.captureService = captureService ?? CaptureService()
    }

    func ensureScreenCapturePermission() -> Bool {
        captureService.ensureScreenCapturePermission()
    }

    func openScreenRecordingPreferences() {
        captureService.openScreenRecordingPreferences()
    }

    func cancelInteractiveSelection() {
        captureService.cancelInteractiveSelection()
    }

    func captureAndRecognize(languages: [String]) async throws -> RecognitionWorkflowOutput {
        let image = try await captureService.captureInteractiveSelection()
        let result = try await recognize(image: image, languages: languages)
        return RecognitionWorkflowOutput(image: image, result: result)
    }

    func recognize(image: CGImage, languages: [String]) async throws -> OCRResult {
        let ocrService = OCRService(languages: languages)
        return try await ocrService.recognizeText(from: image)
    }
}
