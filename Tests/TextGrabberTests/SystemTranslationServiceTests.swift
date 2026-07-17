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

    func testWrappedChineseSentenceCollapsesToSingleLine() {
        let text = """
        我先停掉当前运行的实例,再把这个
        版最新源码重新拉起来。
        """

        let normalized = SystemTranslationService.normalizedSourceText(from: text)

        XCTAssertEqual(normalized, "我先停掉当前运行的实例,再把这个版最新源码重新拉起来。")
    }

    func testWrappedEnglishSentenceJoinsWithSpace() {
        let text = """
        Restart the running
        instance again.
        """

        let normalized = SystemTranslationService.normalizedSourceText(from: text)

        XCTAssertEqual(normalized, "Restart the running instance again.")
    }

    func testBlankLineParagraphsArePreserved() {
        let text = """
        第一段第一行
        第一段第二行

        第二段
        """

        let normalized = SystemTranslationService.normalizedSourceText(from: text)

        XCTAssertEqual(normalized, "第一段第一行第一段第二行\n第二段")
    }

    func testMostlyEnglishWithFewChineseCharsStillTranslates() {
        let service = SystemTranslationService()
        let text = "Please restart the running instance 实例 and rebuild the latest source right now."

        XCTAssertNil(service.validationMessage(for: text))
        XCTAssertNotNil(service.makePlan(for: text))
    }
}
