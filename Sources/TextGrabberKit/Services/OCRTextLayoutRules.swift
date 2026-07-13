import CoreGraphics
import Foundation

/// OCR 文本的清洗、列表恢复、段落划分与候选版式评分规则。
enum OCRTextLayoutRules {
    static func sanitizeObservationText(_ text: String) -> String? {
        let decorativeSymbols = CharacterSet(charactersIn: "□■▢▣▤▥▦▧▨▩☐☑☒✓✔✕✖✗✘✚✦✧★☆◇◆◈◉◎◌◍◐◑◒◓◔◕◖◗◘◙◚◛◜◝◞◟☰⚙🔊🔉🔈")
        let scalars = text.precomposedStringWithCompatibilityMapping.unicodeScalars
            .filter { !decorativeSymbols.contains($0) }
        let cleaned = String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        if isStandaloneSequenceMarker(cleaned) {
            return cleaned
        }

        guard cleaned.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else {
            return nil
        }
        return cleaned
    }

    static func makeReadingOptimizedText(from lines: [OCRLayoutLine]) -> String {
        guard !lines.isEmpty else { return "" }

        let restoredLines = restoreSequenceMarkers(in: lines)
        let averageLineHeight = restoredLines.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(restoredLines.count)
        var paragraphs: [String] = []
        var currentParagraph = restoredLines[0].text

        for (current, next) in zip(restoredLines, restoredLines.dropFirst()) {
            if shouldMergeLine(current, withNextLine: next, averageLineHeight: averageLineHeight) {
                currentParagraph = mergeLineText(currentParagraph, with: next.text)
            } else {
                paragraphs.append(currentParagraph)
                currentParagraph = next.text
            }
        }

        paragraphs.append(currentParagraph)
        return paragraphs.joined(separator: "\n")
    }

    static func qualityScore(for result: OCRResult) -> Float {
        let textLengthBonus = min(Float(result.readingOptimizedText.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).count) / 200, 0.15)
        let sourceListItemCount = result.lines.filter { isListLine($0.text) }.count
        let outputListItemCount = result.readingOptimizedText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { isListLine(String($0)) }
            .count
        let structureBonus: Float
        if sourceListItemCount > 0 {
            structureBonus = Float(outputListItemCount) / Float(sourceListItemCount) * 0.04
        } else {
            structureBonus = 0
        }

        return result.confidenceSummary + textLengthBonus + structureBonus
    }
}

extension OCRService {
    static func makeReadingOptimizedText(from lines: [OCRLayoutLine]) -> String {
        OCRTextLayoutRules.makeReadingOptimizedText(from: lines)
    }
}

struct OCRLayoutLine: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

private func isStandaloneSequenceMarker(_ text: String) -> Bool {
    text.range(of: #"^\s*(?:[-•·]|\d+[.)、])\s*$"#, options: .regularExpression) != nil
}

private func restoreSequenceMarkers(in lines: [OCRLayoutLine]) -> [OCRLayoutLine] {
    guard !lines.isEmpty else { return [] }

    var indexesInNumberedSequence = Set<Int>()
    for index in lines.indices.dropLast() {
        guard
            let current = leadingUnpunctuatedNumber(in: lines[index].text.precomposedStringWithCompatibilityMapping),
            let next = leadingUnpunctuatedNumber(in: lines[index + 1].text.precomposedStringWithCompatibilityMapping),
            next.number == current.number + 1,
            abs(lines[index].boundingBox.minX - lines[index + 1].boundingBox.minX) < 0.08
        else {
            continue
        }

        indexesInNumberedSequence.insert(index)
        indexesInNumberedSequence.insert(index + 1)
    }

    return lines.enumerated().map { index, line in
        let sourceText = normalizeBulletMarker(in: line.text)
        let normalizedText = sourceText.precomposedStringWithCompatibilityMapping
        let restoredText: String
        if let sequence = leadingCircledNumber(in: sourceText) {
            restoredText = "\(sequence.number). \(sequence.body)"
        } else if indexesInNumberedSequence.contains(index), let sequence = leadingUnpunctuatedNumber(in: normalizedText) {
            restoredText = "\(sequence.number). \(sequence.body)"
        } else {
            restoredText = normalizedText
        }

        return OCRLayoutLine(text: restoredText, confidence: line.confidence, boundingBox: line.boundingBox)
    }
}

private func leadingUnpunctuatedNumber(in text: String) -> (number: Int, body: String)? {
    let components = text.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
    guard components.count == 2, let number = Int(components[0]) else { return nil }

    let body = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else { return nil }
    return (number, body)
}

private func leadingCircledNumber(in text: String) -> (number: Int, body: String)? {
    let circledNumbers: [Character: Int] = [
        "①": 1, "②": 2, "③": 3, "④": 4, "⑤": 5,
        "⑥": 6, "⑦": 7, "⑧": 8, "⑨": 9, "⑩": 10
    ]
    guard let first = text.first, let number = circledNumbers[first] else { return nil }

    let body = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else { return nil }
    return (number, body)
}

private func normalizeBulletMarker(in text: String) -> String {
    let variants: Set<Character> = ["·", "●", "○", "◦", "▪", "‣"]
    guard let first = text.first, variants.contains(first) else { return text }

    let body = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    return body.isEmpty ? "•" : "• \(body)"
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
    if verticalGap > max(averageLineHeight * 0.35, 0.022) {
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

    if trimmedCurrent.hasSuffix("-"), trimmedNext.first?.isLetter == true {
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

    return (last.isLetter || last.isNumber) && (first.isLetter || first.isNumber)
}

private func isListLine(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return false }

    if first == "•" || first == "·" {
        return !trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    return [#"^-\s+"#, #"^\d+[.)、]\s*"#]
        .contains { trimmed.range(of: $0, options: .regularExpression) != nil }
}

private func endsWithSentenceTerminator(_ text: String) -> Bool {
    guard let lastCharacter = text.last else { return false }
    return "。！？.!?".contains(lastCharacter)
}
