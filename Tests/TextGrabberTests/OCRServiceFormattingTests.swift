import CoreGraphics
import XCTest
@testable import TextGrabberKit

final class OCRServiceFormattingTests: XCTestCase {
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
