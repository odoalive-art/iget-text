import CoreGraphics
import XCTest
@testable import TextGrabberKit

final class OCRServiceFormattingTests: XCTestCase {
    func testTrailingCompletionOnlyAcceptsShortSuffixExtension() {
        XCTAssertTrue(OCRTextLayoutRules.isLikelyTrailingCompletion("考试目的", of: "考试目"))
        XCTAssertFalse(OCRTextLayoutRules.isLikelyTrailingCompletion("考试项目", of: "考试目"))
        XCTAssertFalse(OCRTextLayoutRules.isLikelyTrailingCompletion("考试目", of: "考试目的"))
    }

    func testCandidateSelectionPrefersCompleteTrailingCharacterWhenConfidenceIsClose() {
        let complete = OCRResult(
            rawText: "考试目的",
            readingOptimizedText: "考试目的",
            lines: [OCRLine(text: "考试目的", confidence: 0.88)],
            confidenceSummary: 0.88
        )
        let truncated = OCRResult(
            rawText: "考试目",
            readingOptimizedText: "考试目",
            lines: [OCRLine(text: "考试目", confidence: 0.92)],
            confidenceSummary: 0.92
        )

        let selected = OCRTextLayoutRules.selectBestCandidate(from: [complete, truncated])

        XCTAssertEqual(selected?.rawText, "考试目的")
        XCTAssertTrue(OCRTextLayoutRules.shouldRetryWithUpscaledImage([complete, truncated]))
    }

    func testCandidateSelectionDoesNotOverrideMateriallyMoreConfidentText() {
        let complete = OCRResult(
            rawText: "考试目的",
            readingOptimizedText: "考试目的",
            lines: [OCRLine(text: "考试目的", confidence: 0.78)],
            confidenceSummary: 0.78
        )
        let truncated = OCRResult(
            rawText: "考试目",
            readingOptimizedText: "考试目",
            lines: [OCRLine(text: "考试目", confidence: 0.92)],
            confidenceSummary: 0.92
        )

        let selected = OCRTextLayoutRules.selectBestCandidate(from: [complete, truncated])

        XCTAssertEqual(selected?.rawText, "考试目")
    }

    func testShortChineseLabelTriggersUpscaledRetry() {
        let result = OCRResult(
            rawText: "考试目",
            readingOptimizedText: "考试目",
            lines: [OCRLine(text: "考试目", confidence: 0.96)],
            confidenceSummary: 0.96
        )

        XCTAssertTrue(OCRTextLayoutRules.shouldRetryWithUpscaledImage([result]))
    }

    func testCandidateSelectionMergesCompleteLineWithoutReplacingHigherConfidenceLines() {
        let original = OCRResult(
            rawText: "目标分数\n考试目",
            readingOptimizedText: "目标分数\n考试目",
            lines: [
                OCRLine(text: "目标分数", confidence: 1.0),
                OCRLine(text: "考试目", confidence: 1.0)
            ],
            confidenceSummary: 1.0
        )
        let upscaled = OCRResult(
            rawText: "目标分数\n考试目的",
            readingOptimizedText: "目标分数\n考试目的",
            lines: [
                OCRLine(text: "目标分数", confidence: 0.5),
                OCRLine(text: "考试目的", confidence: 1.0)
            ],
            confidenceSummary: 0.75
        )

        let selected = OCRTextLayoutRules.selectBestCandidate(from: [original, upscaled])

        XCTAssertEqual(selected?.rawText, "目标分数\n考试目的")
        XCTAssertEqual(selected?.readingOptimizedText, "目标分数\n考试目的")
        XCTAssertEqual(selected?.lines.first?.confidence, 1.0)
    }

    func testCandidateSelectionMergesCompletedFieldWithinTwoColumnRow() {
        let original = OCRResult(
            rawText: "考试目 兴趣爱好",
            readingOptimizedText: "考试目 兴趣爱好",
            lines: [OCRLine(text: "考试目 兴趣爱好", confidence: 0.75)],
            confidenceSummary: 0.75
        )
        let upscaled = OCRResult(
            rawText: "考试目的 兴趣爱好",
            readingOptimizedText: "考试目的 兴趣爱好",
            lines: [OCRLine(text: "考试目的 兴趣爱好", confidence: 0.75)],
            confidenceSummary: 0.75
        )

        let selected = OCRTextLayoutRules.selectBestCandidate(from: [original, upscaled])

        XCTAssertTrue(OCRTextLayoutRules.shouldRetryWithUpscaledImage([original]))
        XCTAssertEqual(selected?.rawText, "考试目的 兴趣爱好")
    }


    func testReadingOptimizedTextMergesChineseParagraphLines() {
        let lines = [
            OCRLayoutLine(text: "这是第一段的第一行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.70, width: 0.72, height: 0.06)),
            OCRLayoutLine(text: "这是第一段的第二行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.62, width: 0.74, height: 0.06))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "这是第一段的第一行这是第一段的第二行")
    }

    func testReadingOptimizedTextAddsSpaceForEnglishWrappedLines() {
        let lines = [
            OCRLayoutLine(text: "OpenAI builds", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.66, width: 0.60, height: 0.05)),
            OCRLayoutLine(text: "helpful tools", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.59, width: 0.58, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "OpenAI builds helpful tools")
    }

    func testReadingOptimizedTextKeepsListItemsOnSeparateLines() {
        let lines = [
            OCRLayoutLine(text: "1. 第一项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.62, width: 0.24, height: 0.05)),
            OCRLayoutLine(text: "2. 第二项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.54, width: 0.24, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "1. 第一项\n2. 第二项")
    }

    func testReadingOptimizedTextKeepsBulletsWithoutFollowingWhitespaceSeparate() {
        let lines = [
            OCRLayoutLine(text: "•第一项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.62, width: 0.24, height: 0.05)),
            OCRLayoutLine(text: "•第二项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.54, width: 0.24, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "•第一项\n•第二项")
    }

    func testReadingOptimizedTextSeparatesParagraphsAfterOnlyTightLineWraps() {
        let lines = [
            OCRLayoutLine(text: "第一段第一行", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.60, width: 0.72, height: 0.10)),
            OCRLayoutLine(text: "第一段第二行", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.476, width: 0.72, height: 0.10)),
            OCRLayoutLine(text: "第二段第一行", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.338, width: 0.72, height: 0.10))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "第一段第一行第一段第二行\n第二段第一行")
    }

    func testReadingOptimizedTextRestoresConsecutiveNumberedMarkers() {
        let lines = [
            OCRLayoutLine(text: "1 第一项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.62, width: 0.24, height: 0.05)),
            OCRLayoutLine(text: "2 第二项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.54, width: 0.24, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "1. 第一项\n2. 第二项")
    }

    func testReadingOptimizedTextRestoresCircledAndVariantBulletMarkers() {
        let lines = [
            OCRLayoutLine(text: "① 第一项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.62, width: 0.24, height: 0.05)),
            OCRLayoutLine(text: "○ 第二项", confidence: 0.9, boundingBox: CGRect(x: 0.10, y: 0.54, width: 0.24, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "1. 第一项\n• 第二项")
    }

    func testReadingOptimizedTextSeparatesParagraphsWithSingleLineBreak() {
        let lines = [
            OCRLayoutLine(text: "这是第一段第一行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.78, width: 0.70, height: 0.05)),
            OCRLayoutLine(text: "这是第一段第二行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.71, width: 0.72, height: 0.05)),
            OCRLayoutLine(text: "这是第二段第一行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.52, width: 0.70, height: 0.05)),
            OCRLayoutLine(text: "这是第二段第二行", confidence: 0.9, boundingBox: CGRect(x: 0.12, y: 0.45, width: 0.72, height: 0.05))
        ]

        let optimizedText = OCRService.makeReadingOptimizedText(from: lines)

        XCTAssertEqual(optimizedText, "这是第一段第一行这是第一段第二行\n这是第二段第一行这是第二段第二行")
    }
}
