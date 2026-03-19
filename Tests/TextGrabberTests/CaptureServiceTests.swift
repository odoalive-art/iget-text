import XCTest
@testable import TextGrabberKit

final class CaptureServiceTests: XCTestCase {
    func testMissingFileAfterZeroExitIsTreatedAsCancellation() {
        let result = CaptureResultClassifier.classify(
            terminationStatus: 0,
            fileExists: false,
            fileSize: 0,
            hasImage: false
        )

        XCTAssertEqual(result.failure, .cancelled)
    }

    func testEmptyFileAfterZeroExitIsTreatedAsCancellation() {
        let result = CaptureResultClassifier.classify(
            terminationStatus: 0,
            fileExists: true,
            fileSize: 0,
            hasImage: false
        )

        XCTAssertEqual(result.failure, .cancelled)
    }

    func testUnreadableNonEmptyFileRemainsImageUnavailable() {
        let result = CaptureResultClassifier.classify(
            terminationStatus: 0,
            fileExists: true,
            fileSize: 128,
            hasImage: false
        )

        XCTAssertEqual(result.failure, .imageUnavailable)
    }
}

private extension Result where Success == Void, Failure == CaptureError {
    var failure: CaptureError? {
        switch self {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
