import XCTest
@testable import TextGrabberKit

@MainActor
final class SystemTranslationServiceTests: XCTestCase {
    func testChineseTextTargetsEnglish() {
        let service = SystemTranslationService()

        let plan = service.makePlan(for: "我先停掉当前运行的实例，再把这个版最新源码重新拉起来。")

        XCTAssertEqual(plan?.targetLanguageIdentifier, "en")
    }

    func testEnglishTextTargetsSimplifiedChinese() {
        let service = SystemTranslationService()

        let plan = service.makePlan(for: "Restart the running instance and launch the latest build again.")

        XCTAssertEqual(plan?.targetLanguageIdentifier, "zh-Hans")
    }

    func testMixedChineseAndCommandsStillTargetsEnglish() {
        let service = SystemTranslationService()
        let text = """
        我先停掉当前运行的实例，再把这个版最新源码重新拉起来。
        后台终端已完成以及 pkill -f '.build/arm64-apple-macosx/debug/TextGrabber' || true
        启动后台终端以及 swift run TextGrabber
        构建已经完成，我再确认一下最新进程已经挂上。
        """

        let plan = service.makePlan(for: text)

        XCTAssertEqual(plan?.targetLanguageIdentifier, "en")
    }
}
