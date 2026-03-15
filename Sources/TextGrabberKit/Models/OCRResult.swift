import Foundation

enum OCRTextOutputMode: String, CaseIterable, Sendable {
    case readingOptimized
    case sourceLayout

    var displayName: String {
        switch self {
        case .readingOptimized:
            "阅读优化"
        case .sourceLayout:
            "原始版面"
        }
    }
}

struct OCRLine: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let confidence: Float
}

struct OCRResult: Sendable {
    let rawText: String
    let readingOptimizedText: String
    let lines: [OCRLine]
    let confidenceSummary: Float

    func text(for mode: OCRTextOutputMode) -> String {
        switch mode {
        case .readingOptimized:
            readingOptimizedText
        case .sourceLayout:
            rawText
        }
    }
}
