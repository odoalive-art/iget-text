import AppKit
import XCTest
@testable import TextGrabberKit

@MainActor
final class ResultPopoverLayoutTests: XCTestCase {
    func testFollowMouseAnchorStaysStableUntilPopoverIsClosed() {
        var anchorState = ResultPanelAnchorState()
        let initialLocation = NSPoint(x: 160, y: 240)
        let clickedButtonLocation = NSPoint(x: 420, y: 120)

        anchorState.prepareForPresentation(
            placement: .followMouse,
            mouseLocation: initialLocation,
            isNewPresentation: true
        )
        anchorState.prepareForPresentation(
            placement: .followMouse,
            mouseLocation: clickedButtonLocation,
            isNewPresentation: false
        )

        XCTAssertEqual(anchorState.resolvedMouseLocation(currentMouseLocation: clickedButtonLocation), initialLocation)

        anchorState.reset()
        anchorState.prepareForPresentation(
            placement: .followMouse,
            mouseLocation: clickedButtonLocation,
            isNewPresentation: true
        )

        XCTAssertEqual(anchorState.resolvedMouseLocation(currentMouseLocation: .zero), clickedButtonLocation)
    }

    func testFollowMouseAnchorClearsWhenPlacementReturnsToStatusItem() {
        var anchorState = ResultPanelAnchorState()

        anchorState.prepareForPresentation(
            placement: .followMouse,
            mouseLocation: NSPoint(x: 180, y: 260),
            isNewPresentation: true
        )
        anchorState.prepareForPresentation(
            placement: .statusItem,
            mouseLocation: NSPoint(x: 20, y: 20),
            isNewPresentation: false
        )

        XCTAssertNil(anchorState.followMouseAnchor)
    }

    func testPreviewHeightUsesActualImageAspectRatioWithoutMinimumClamp() {
        let image = NSImage(size: NSSize(width: 320, height: 40))
        let expectedHeight = round((ResultPopoverLayout.previewWidth * image.size.height) / image.size.width)

        XCTAssertEqual(ResultPopoverLayout.previewHeight(for: image), expectedHeight)
        XCTAssertEqual(ResultPopoverLayout.previewHeight(for: nil), ResultPopoverLayout.previewPlaceholderHeight)
    }

    func testResultPanelHeightGrowsWhenTranslationPaneIsVisible() {
        let sourceText = "赋能全球化布局锻造精英语言力\n\n深耕英语培训领域32年"
        let translatedText = """
        Empower global expansion and build strong English capability

        32 years of deep focus on English training
        """

        let baseHeight = ResultPopoverLayout.resultPanelHeight(
            text: sourceText,
            image: nil,
            includePreview: false
        )

        let translatedHeight = ResultPopoverLayout.resultPanelHeight(
            text: sourceText,
            translationText: translatedText,
            showsTranslationPane: true,
            image: nil,
            includePreview: false
        )

        XCTAssertGreaterThan(translatedHeight, baseHeight)
    }

    func testTranslationPanelKeepsFooterAtFixedHeightWithoutExtraGap() {
        let sourceText = "原始文本"
        let translatedText = "Translated text"

        let expectedHeight = ResultPopoverLayout.headerHeight +
            ResultPopoverLayout.resultCardHeight(
                for: sourceText,
                translationText: translatedText,
                showsTranslationPane: true
            ) +
            ResultPopoverLayout.footerHeight +
            ResultPopoverLayout.bottomContentPadding

        let actualHeight = ResultPopoverLayout.resultPanelHeight(
            text: sourceText,
            translationText: translatedText,
            showsTranslationPane: true,
            image: nil,
            includePreview: false
        )

        XCTAssertEqual(actualHeight, expectedHeight)
    }

    func testShortTranslationAddsDedicatedTranslationCardHeight() {
        let sourceText = "短文本"
        let translatedText = "Short text"

        let baseCardHeight = ResultPopoverLayout.resultCardHeight(
            for: sourceText,
            outputMode: .readingOptimized
        )

        let translatedCardHeight = ResultPopoverLayout.resultCardHeight(
            for: sourceText,
            translationText: translatedText,
            showsTranslationPane: true,
            outputMode: .readingOptimized
        )

        XCTAssertGreaterThan(translatedCardHeight, baseCardHeight)
    }

    func testMouseFollowPanelFrameUsesAnchorAndRemainsInsideVisibleFrame() {
        let frame = ResultPanelPlacementGeometry.mouseFollowPanelFrame(
            anchorLocation: NSPoint(x: 760, y: 560),
            visibleFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
            panelSize: NSSize(width: 240, height: 180)
        )

        XCTAssertEqual(frame.origin.x, 508)
        XCTAssertEqual(frame.origin.y, 368)
    }

    func testPinnedPanelDoesNotHideOnResignKey() {
        XCTAssertFalse(
            ResultPanelDismissalPolicy.shouldHideOnResignKey(
                isPinned: true,
                isTranslating: false
            )
        )
    }

    func testTranslatingPanelDoesNotHideOnResignKey() {
        XCTAssertFalse(
            ResultPanelDismissalPolicy.shouldHideOnResignKey(
                isPinned: false,
                isTranslating: true
            )
        )
    }

    func testIdleUnpinnedPanelHidesOnResignKey() {
        XCTAssertTrue(
            ResultPanelDismissalPolicy.shouldHideOnResignKey(
                isPinned: false,
                isTranslating: false
            )
        )
    }

    func testPinnedVisiblePanelRestoresAfterAppDeactivation() {
        XCTAssertTrue(
            ResultPanelDismissalPolicy.shouldRestoreAfterAppDeactivation(
                isPinned: true,
                isPanelVisible: true,
                isShowingResult: true
            )
        )
    }

    func testHiddenOrUnpinnedPanelDoesNotRestoreAfterAppDeactivation() {
        XCTAssertFalse(
            ResultPanelDismissalPolicy.shouldRestoreAfterAppDeactivation(
                isPinned: false,
                isPanelVisible: true,
                isShowingResult: true
            )
        )
        XCTAssertFalse(
            ResultPanelDismissalPolicy.shouldRestoreAfterAppDeactivation(
                isPinned: true,
                isPanelVisible: false,
                isShowingResult: true
            )
        )
        XCTAssertFalse(
            ResultPanelDismissalPolicy.shouldRestoreAfterAppDeactivation(
                isPinned: true,
                isPanelVisible: true,
                isShowingResult: false
            )
        )
    }
}
