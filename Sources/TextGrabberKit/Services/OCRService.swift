import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

enum OCRServiceError: LocalizedError {
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .recognitionFailed:
            "文本识别失败，请重试。"
        }
    }
}

struct OCRService {
    let languages: [String]
    private let ciContext = CIContext(options: nil)

    func recognizeText(from image: CGImage) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let variants = [image, enhancedImage(from: image) ?? image]
                    let candidates = try variants.enumerated().map { index, variant in
                        try performRecognition(on: variant, usesLanguageCorrection: index == 0)
                    }
                    let best = candidates.max(by: { lhs, rhs in
                        lhs.qualityScore < rhs.qualityScore
                    }) ?? OCRResult(rawText: "", readingOptimizedText: "", lines: [], confidenceSummary: 0)

                    continuation.resume(returning: best)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performRecognition(on image: CGImage, usesLanguageCorrection: Bool) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = usesLanguageCorrection

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = (request.results ?? [])
            .compactMap { observation -> (String, Float, CGRect)? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return (text, candidate.confidence, observation.boundingBox)
            }
            .sorted { lhs, rhs in
                if abs(lhs.2.midY - rhs.2.midY) > 0.02 {
                    return lhs.2.midY > rhs.2.midY
                }

                return lhs.2.minX < rhs.2.minX
            }

        let groupedLines = groupObservationsIntoLines(observations)
        let lines = groupedLines.map { line in
            OCRLayoutLine(
                text: line.map(\.0).joined(separator: lineSeparator(for: line)),
                confidence: line.map(\.1).reduce(0, +) / Float(max(line.count, 1)),
                boundingBox: line.map(\.2).reduce(into: CGRect.null) { partialResult, rect in
                    partialResult = partialResult.union(rect)
                }
            )
        }

        let rawText = lines.map(\.text).joined(separator: "\n")
        let optimizedText = Self.makeReadingOptimizedText(from: lines)
        let averageConfidence = lines.isEmpty
            ? 0
            : lines.map(\.confidence).reduce(0, +) / Float(lines.count)

        return OCRResult(
            rawText: rawText,
            readingOptimizedText: optimizedText,
            lines: lines.map { OCRLine(text: $0.text, confidence: $0.confidence) },
            confidenceSummary: averageConfidence
        )
    }

    static func makeReadingOptimizedText(from lines: [OCRLayoutLine]) -> String {
        guard !lines.isEmpty else { return "" }

        let averageLineHeight = lines.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(lines.count)
        var paragraphs: [String] = []
        var currentParagraph = lines[0].text

        for (current, next) in zip(lines, lines.dropFirst()) {
            if shouldMergeLine(current, withNextLine: next, averageLineHeight: averageLineHeight) {
                currentParagraph = mergeLineText(currentParagraph, with: next.text)
            } else {
                paragraphs.append(currentParagraph)
                currentParagraph = next.text
            }
        }

        paragraphs.append(currentParagraph)

        return paragraphs.enumerated().reduce(into: "") { result, element in
            let (index, paragraph) = element
            if index == 0 {
                result = paragraph
                return
            }

            let previousParagraph = paragraphs[index - 1]
            let separator = paragraphSeparator(between: previousParagraph, and: paragraph)
            result += separator + paragraph
        }
    }

    private func groupObservationsIntoLines(_ observations: [(String, Float, CGRect)]) -> [[(String, Float, CGRect)]] {
        var lines: [[(String, Float, CGRect)]] = []

        for observation in observations {
            if let index = lines.firstIndex(where: { existingLine in
                guard let first = existingLine.first else { return false }
                return abs(first.2.midY - observation.2.midY) < 0.03
            }) {
                lines[index].append(observation)
            } else {
                lines.append([observation])
            }
        }

        return lines.map { line in
            line.sorted(by: { $0.2.minX < $1.2.minX })
        }
    }

    private func lineSeparator(for line: [(String, Float, CGRect)]) -> String {
        let containsLatin = line.contains { token in
            token.0.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains)
        }
        return containsLatin ? " " : ""
    }

    private func enhancedImage(from image: CGImage) -> CGImage? {
        let inputImage = CIImage(cgImage: image)

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = inputImage
        colorControls.contrast = 1.18
        colorControls.brightness = 0.02
        colorControls.saturation = 0

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = colorControls.outputImage
        sharpen.sharpness = 0.45

        guard let outputImage = sharpen.outputImage else {
            return nil
        }

        return ciContext.createCGImage(outputImage, from: outputImage.extent)
    }
}

struct OCRLayoutLine: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

private extension OCRResult {
    var qualityScore: Float {
        let textLengthBonus = min(Float(readingOptimizedText.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).count) / 200, 0.15)
        return confidenceSummary + textLengthBonus
    }
}

private func shouldMergeLine(
    _ current: OCRLayoutLine,
    withNextLine next: OCRLayoutLine,
    averageLineHeight: CGFloat
) -> Bool {
    let currentText = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let nextText = next.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !currentText.isEmpty, !nextText.isEmpty else { return false }

    if isListLine(currentText) || isListLine(nextText) {
        return false
    }

    if currentText.hasSuffix("：") || currentText.hasSuffix(":") {
        return false
    }

    let verticalGap = current.boundingBox.minY - next.boundingBox.maxY
    if verticalGap > max(averageLineHeight * 0.9, 0.028) {
        return false
    }

    let leadingIndentDelta = abs(current.boundingBox.minX - next.boundingBox.minX)
    if leadingIndentDelta > 0.08 {
        return false
    }

    let currentIsLikelyShortLine = current.boundingBox.width < 0.42 || currentText.count <= 10
    if currentIsLikelyShortLine && endsWithSentenceTerminator(currentText) {
        return false
    }

    return true
}

private func mergeLineText(_ current: String, with next: String) -> String {
    let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedNext = next.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedCurrent.isEmpty else { return trimmedNext }
    guard !trimmedNext.isEmpty else { return trimmedCurrent }

    if trimmedCurrent.hasSuffix("-"),
       trimmedNext.first?.isLetter == true {
        return String(trimmedCurrent.dropLast()) + trimmedNext
    }

    if needsSpaceBetween(trimmedCurrent, trimmedNext) {
        return trimmedCurrent + " " + trimmedNext
    }

    return trimmedCurrent + trimmedNext
}

private func needsSpaceBetween(_ current: String, _ next: String) -> Bool {
    guard let last = current.last, let first = next.first else { return false }
    guard last.isASCII, first.isASCII else { return false }

    let lastIsAlphaNumeric = last.isLetter || last.isNumber
    let firstIsAlphaNumeric = first.isLetter || first.isNumber
    return lastIsAlphaNumeric && firstIsAlphaNumeric
}

private func isListLine(_ text: String) -> Bool {
    let patterns = [
        #"^\s*[-•·]\s+"#,
        #"^\s*\d+[.)、]\s*"#
    ]

    return patterns.contains { pattern in
        text.range(of: pattern, options: .regularExpression) != nil
    }
}

private func endsWithSentenceTerminator(_ text: String) -> Bool {
    guard let lastCharacter = text.last else { return false }
    return "。！？.!?".contains(lastCharacter)
}

private func paragraphSeparator(between previous: String, and next: String) -> String {
    if isListLine(previous) || isListLine(next) {
        return "\n"
    }

    return "\n"
}
