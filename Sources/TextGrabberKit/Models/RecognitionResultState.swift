import AppKit
import Foundation

@MainActor
final class RecognitionResultState: ObservableObject {
    @Published var outputMode: OCRTextOutputMode = .readingOptimized
    @Published var recognizedText = ""
    @Published var capturedPreviewImage: NSImage?
    @Published var lastErrorMessage: String?
    @Published var translatedText = ""
    @Published var translationErrorMessage: String?
    @Published var isTranslating = false

    private var lastOCRResult: OCRResult?

    func resetForNewCapture() {
        lastErrorMessage = nil
        capturedPreviewImage = nil
        resetTranslation()
    }

    func setCapturedImage(_ image: CGImage) {
        capturedPreviewImage = NSImage(cgImage: image, size: .zero)
    }

    func setOutputMode(_ mode: OCRTextOutputMode) {
        outputMode = mode
        applyRecognizedTextForCurrentMode()
    }

    func setErrorMessage(_ message: String?) {
        lastErrorMessage = message
    }

    func setIsTranslating(_ isTranslating: Bool) {
        self.isTranslating = isTranslating
    }

    func resetTranslation() {
        translatedText = ""
        translationErrorMessage = nil
        isTranslating = false
    }

    func beginTranslation() {
        translatedText = ""
        translationErrorMessage = nil
        isTranslating = true
    }

    func completeTranslation(_ text: String) {
        translatedText = text
        translationErrorMessage = nil
        isTranslating = false
    }

    func failTranslation(_ message: String) {
        translatedText = ""
        translationErrorMessage = message
        isTranslating = false
    }

    func showResult(_ result: OCRResult) {
        lastOCRResult = result
        applyRecognizedTextForCurrentMode()
    }

    private func applyRecognizedTextForCurrentMode() {
        let text = lastOCRResult?.text(for: outputMode).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        recognizedText = text.isEmpty ? "未识别到文本" : text
    }
}
