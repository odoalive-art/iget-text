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

/// 负责 Vision 请求、图像增强与候选结果收集；文本规则见 `OCRTextLayoutRules`。
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
                    var best = candidates.max(by: {
                        OCRTextLayoutRules.qualityScore(for: $0) < OCRTextLayoutRules.qualityScore(for: $1)
                    }) ?? OCRResult(rawText: "", readingOptimizedText: "", lines: [], confidenceSummary: 0)

                    if best.rawText.isEmpty, !languages.isEmpty {
                        best = try performRecognition(
                            on: image,
                            usesLanguageCorrection: true,
                            recognitionLanguages: []
                        )
                    }

                    continuation.resume(returning: best)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performRecognition(
        on image: CGImage,
        usesLanguageCorrection: Bool,
        recognitionLanguages: [String]? = nil
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages ?? languages
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = usesLanguageCorrection

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = (request.results ?? [])
            .compactMap { observation -> (String, Float, CGRect)? in
                guard let candidate = observation.topCandidates(1).first,
                      let text = OCRTextLayoutRules.sanitizeObservationText(candidate.string)
                else {
                    return nil
                }
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
        let optimizedText = OCRTextLayoutRules.makeReadingOptimizedText(from: lines)
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

        return lines.map { $0.sorted { $0.2.minX < $1.2.minX } }
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

        guard let outputImage = sharpen.outputImage else { return nil }
        return ciContext.createCGImage(outputImage, from: outputImage.extent)
    }
}
