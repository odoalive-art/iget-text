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
    @Published private(set) var textFocusRequestToken = 0

    private var lastOCRResult: OCRResult?
    private var readingOptimizedDraft: String?
    private var sourceLayoutDraft: String?

    func resetForNewCapture() {
        lastErrorMessage = nil
        capturedPreviewImage = nil
        readingOptimizedDraft = nil
        sourceLayoutDraft = nil
        resetTranslation()
    }

    func setCapturedImage(_ image: CGImage) {
        capturedPreviewImage = NSImage(cgImage: image, size: .zero)
    }

    func setOutputMode(_ mode: OCRTextOutputMode) {
        outputMode = mode
        recognizedText = displayText(for: mode)
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
        let readingText = normalizedDisplayText(result.readingOptimizedText)
        let sourceText = normalizedDisplayText(result.rawText)
        let emptyResultMessage = "未识别到文本"
        readingOptimizedDraft = readingText.isEmpty ? emptyResultMessage : readingText
        sourceLayoutDraft = sourceText.isEmpty ? emptyResultMessage : sourceText
        recognizedText = displayText(for: outputMode)
        requestTextFocus()
    }

    func requestTextFocus() {
        textFocusRequestToken += 1
    }

    func updateRecognizedText(_ text: String) {
        recognizedText = text

        switch outputMode {
        case .readingOptimized:
            readingOptimizedDraft = text
        case .sourceLayout:
            sourceLayoutDraft = text
        }
    }

    private func displayText(for mode: OCRTextOutputMode) -> String {
        switch mode {
        case .readingOptimized:
            if let readingOptimizedDraft {
                return readingOptimizedDraft
            }
        case .sourceLayout:
            if let sourceLayoutDraft {
                return sourceLayoutDraft
            }
        }

        let fallbackText = normalizedDisplayText(lastOCRResult?.text(for: mode) ?? "")
        return fallbackText.isEmpty ? "未识别到文本" : fallbackText
    }

    private func normalizedDisplayText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
