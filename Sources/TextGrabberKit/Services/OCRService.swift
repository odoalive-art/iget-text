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
                    var candidates = try variants.enumerated().map { index, variant in
                        try performRecognition(
                            on: variant,
                            usesLanguageCorrection: index == 0,
                            allowsLocalizedRefinement: index == 0
                        )
                    }

                    if OCRTextLayoutRules.shouldRetryWithUpscaledImage(candidates),
                       let upscaledImage = upscaledImage(from: image) {
                        candidates.append(
                            try performRecognition(on: upscaledImage, usesLanguageCorrection: true)
                        )
                    }

                    var best = OCRTextLayoutRules.selectBestCandidate(from: candidates)
                        ?? OCRResult(rawText: "", readingOptimizedText: "", lines: [], confidenceSummary: 0)

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
        recognitionLanguages: [String]? = nil,
        allowsLocalizedRefinement: Bool = false
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages ?? languages
        request.automaticallyDetectsLanguage = false
        request.usesLanguageCorrection = usesLanguageCorrection

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = (request.results ?? [])
            .compactMap { observation -> (String, Float, CGRect)? in
                guard let candidate = preferredCandidate(from: observation.topCandidates(3)),
                      let recognizedText = OCRTextLayoutRules.sanitizeObservationText(candidate.string)
                else {
                    return nil
                }
                let text = allowsLocalizedRefinement
                    ? (try? localizedTrailingCompletion(
                        in: image,
                        boundingBox: observation.boundingBox,
                        originalText: recognizedText
                    )) ?? recognizedText
                    : recognizedText
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

    /// 中英文混排时，Vision 偶尔会把短中文片段猜成带问号的英文音节，或遗漏末尾字。
    /// 仅在后备候选的置信度足够接近时切换，避免用低可信文本覆盖主候选。
    private func preferredCandidate(from candidates: [VNRecognizedText]) -> VNRecognizedText? {
        guard let primaryCandidate = candidates.first else { return nil }

        guard supportsChineseRecognition else { return primaryCandidate }

        if let completedCandidate = candidates.dropFirst().first(where: {
            isPlausibleTrailingCompletion($0, of: primaryCandidate)
        }) {
            return completedCandidate
        }

        if primaryCandidate.string.contains("?") {
            return candidates.dropFirst().first(where: containsHanCharacters) ?? primaryCandidate
        }

        return primaryCandidate
    }

    private var supportsChineseRecognition: Bool {
        languages.contains { $0.lowercased().hasPrefix("zh") }
    }

    private func containsHanCharacters(_ candidate: VNRecognizedText) -> Bool {
        candidate.string.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private func isPlausibleTrailingCompletion(
        _ candidate: VNRecognizedText,
        of primaryCandidate: VNRecognizedText
    ) -> Bool {
        let primaryText = primaryCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraCharacterCount = candidateText.count - primaryText.count

        return primaryText.count >= 2
            && (1...2).contains(extraCharacterCount)
            && candidateText.hasPrefix(primaryText)
            && candidate.confidence + 0.08 >= primaryCandidate.confidence
    }

    /// Vision 将短标签截断在文字框边缘时，向右扩展原框并只重识别该小区域。
    /// 仅接受原文本的 1–2 字末尾补全，避免局部重试改变已经稳定的内容。
    private func localizedTrailingCompletion(
        in image: CGImage,
        boundingBox: CGRect,
        originalText: String
    ) throws -> String? {
        guard isShortChineseLabel(originalText),
              let croppedImage = expandedTextCrop(from: image, boundingBox: boundingBox)
        else {
            return nil
        }

        let refinedImage = scaledImage(from: croppedImage, scale: 3) ?? croppedImage
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.automaticallyDetectsLanguage = false
        request.usesLanguageCorrection = true

        try VNImageRequestHandler(cgImage: refinedImage).perform([request])

        return (request.results ?? [])
            .flatMap { $0.topCandidates(3) }
            .compactMap { OCRTextLayoutRules.sanitizeObservationText($0.string) }
            .first { OCRTextLayoutRules.isLikelyTrailingCompletion($0, of: originalText) }
    }

    private func isShortChineseLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...4).contains(trimmed.count)
            && trimmed.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }

    private func expandedTextCrop(from image: CGImage, boundingBox: CGRect) -> CGImage? {
        let expandedBox = CGRect(
            x: boundingBox.minX - boundingBox.width * 0.15,
            y: boundingBox.minY - boundingBox.height * 0.75,
            width: boundingBox.width * 2.1,
            height: boundingBox.height * 2.5
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !expandedBox.isNull, !expandedBox.isEmpty else { return nil }

        let cropRect = CGRect(
            x: expandedBox.minX * CGFloat(image.width),
            y: (1 - expandedBox.maxY) * CGFloat(image.height),
            width: expandedBox.width * CGFloat(image.width),
            height: expandedBox.height * CGFloat(image.height)
        ).integral
        return image.cropping(to: cropRect)
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

    /// 仅在候选低置信度或疑似末字遗漏时放大重试，避免对所有截图增加不必要的延迟与内存开销。
    private func upscaledImage(from image: CGImage) -> CGImage? {
        let maximumDimension = max(CGFloat(image.width), CGFloat(image.height))
        let scale = min(CGFloat(2), 3_000 / maximumDimension)
        guard scale > 1.05 else { return nil }

        return scaledImage(from: image, scale: scale)
    }

    private func scaledImage(from image: CGImage, scale: CGFloat) -> CGImage? {
        let resize = CIFilter.lanczosScaleTransform()
        resize.inputImage = CIImage(cgImage: image)
        resize.scale = Float(scale)
        resize.aspectRatio = 1

        guard let outputImage = resize.outputImage else { return nil }
        return ciContext.createCGImage(outputImage, from: outputImage.extent)
    }
}
