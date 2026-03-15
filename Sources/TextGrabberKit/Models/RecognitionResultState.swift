import AppKit
import Foundation

@MainActor
final class RecognitionResultState: ObservableObject {
    @Published var outputMode: OCRTextOutputMode = .readingOptimized
    @Published var recognizedText = ""
    @Published var capturedPreviewImage: NSImage?
    @Published var lastErrorMessage: String?

    private var lastOCRResult: OCRResult?

    func resetForNewCapture() {
        lastErrorMessage = nil
        capturedPreviewImage = nil
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

    func showResult(_ result: OCRResult) {
        lastOCRResult = result
        applyRecognizedTextForCurrentMode()
    }

    private func applyRecognizedTextForCurrentMode() {
        let text = lastOCRResult?.text(for: outputMode).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        recognizedText = text.isEmpty ? "未识别到文本" : text
    }
}
