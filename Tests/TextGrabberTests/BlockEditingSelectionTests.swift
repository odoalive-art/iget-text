import Foundation
import XCTest
@testable import TextGrabberKit

final class BlockEditingSelectionTests: XCTestCase {
    func testSelectsCurrentParagraphBeforeSelectingEntireText() {
        let text = "第一段\n第二段"
        let firstParagraph = NSRange(location: 0, length: ("第一段" as NSString).length)

        let firstSelection = BlockEditingSelection.next(
            in: text,
            selectedRange: NSRange(location: 1, length: 0),
            previousBlockSelectionRange: nil
        )
        let secondSelection = BlockEditingSelection.next(
            in: text,
            selectedRange: firstSelection.range,
            previousBlockSelectionRange: firstSelection.selectedBlockRange
        )

        XCTAssertEqual(firstSelection.range, firstParagraph)
        XCTAssertEqual(secondSelection.range, NSRange(location: 0, length: (text as NSString).length))
        XCTAssertNil(secondSelection.selectedBlockRange)
    }

    func testSelectsParagraphContainingCursor() {
        let text = "第一段\n第二段\n第三段"
        let secondParagraph = NSRange(
            location: ("第一段\n" as NSString).length,
            length: ("第二段" as NSString).length
        )

        let selection = BlockEditingSelection.next(
            in: text,
            selectedRange: NSRange(location: secondParagraph.location + 1, length: 0),
            previousBlockSelectionRange: nil
        )

        XCTAssertEqual(selection.range, secondParagraph)
    }
}
