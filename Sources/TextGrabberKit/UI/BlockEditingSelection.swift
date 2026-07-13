import Foundation

struct BlockEditingSelection {
    let range: NSRange
    let selectedBlockRange: NSRange?

    static func next(
        in text: String,
        selectedRange: NSRange,
        previousBlockSelectionRange: NSRange?
    ) -> BlockEditingSelection {
        let content = text as NSString
        let fullRange = NSRange(location: 0, length: content.length)

        guard content.length > 0 else {
            return BlockEditingSelection(range: fullRange, selectedBlockRange: nil)
        }

        if let previousBlockSelectionRange,
           NSEqualRanges(selectedRange, previousBlockSelectionRange) {
            return BlockEditingSelection(range: fullRange, selectedBlockRange: nil)
        }

        let insertionLocation = min(selectedRange.location, content.length - 1)
        var paragraphRange = content.paragraphRange(for: NSRange(location: insertionLocation, length: 0))

        while paragraphRange.length > 0 {
            let finalCharacter = content.character(at: NSMaxRange(paragraphRange) - 1)
            guard finalCharacter == 10 || finalCharacter == 13 else { break }
            paragraphRange.length -= 1
        }

        return BlockEditingSelection(
            range: paragraphRange,
            selectedBlockRange: paragraphRange
        )
    }
}
