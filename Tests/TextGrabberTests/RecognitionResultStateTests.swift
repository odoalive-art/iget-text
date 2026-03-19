import XCTest
@testable import TextGrabberKit

@MainActor
final class RecognitionResultStateTests: XCTestCase {
    func testShowResultRequestsTextFocus() {
        let state = RecognitionResultState()
        let result = OCRResult(
            rawText: "raw text",
            readingOptimizedText: "reading text",
            lines: [],
            confidenceSummary: 0.98
        )

        XCTAssertEqual(state.textFocusRequestToken, 0)

        state.showResult(result)

        XCTAssertEqual(state.recognizedText, "reading text")
        XCTAssertEqual(state.textFocusRequestToken, 1)
    }

    func testManualFocusRequestIncrementsToken() {
        let state = RecognitionResultState()

        state.requestTextFocus()
        state.requestTextFocus()

        XCTAssertEqual(state.textFocusRequestToken, 2)
    }

    func testManualEditsArePreservedAcrossOutputModes() {
        let state = RecognitionResultState()
        let result = OCRResult(
            rawText: "raw text",
            readingOptimizedText: "reading text",
            lines: [],
            confidenceSummary: 0.98
        )

        state.showResult(result)
        state.updateRecognizedText("reading edited")
        state.setOutputMode(.sourceLayout)
        state.updateRecognizedText("raw edited")

        XCTAssertEqual(state.recognizedText, "raw edited")

        state.setOutputMode(.readingOptimized)
        XCTAssertEqual(state.recognizedText, "reading edited")

        state.setOutputMode(.sourceLayout)
        XCTAssertEqual(state.recognizedText, "raw edited")
    }

    func testClearingEditedTextDoesNotRestoreOriginalOnModeSwitch() {
        let state = RecognitionResultState()
        let result = OCRResult(
            rawText: "raw text",
            readingOptimizedText: "reading text",
            lines: [],
            confidenceSummary: 0.98
        )

        state.showResult(result)
        state.updateRecognizedText("")

        state.setOutputMode(.sourceLayout)
        state.setOutputMode(.readingOptimized)

        XCTAssertEqual(state.recognizedText, "")
    }
}
