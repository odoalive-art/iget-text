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

    func testLineBreaksArePreservedForLayout() {
        // 标题与正文是独立的两行,翻译源文本必须保留换行,避免被并成一句。
        let text = """
        我的错题本
        自动收录刷题、模考全部错题，集中复盘薄弱点
        """

        let normalized = SystemTranslationService.normalizedSourceText(from: text)

        XCTAssertEqual(normalized, "我的错题本\n自动收录刷题、模考全部错题，集中复盘薄弱点")
    }

    func testBlankLinesAndSurroundingWhitespaceAreDropped() {
        let text = "  第一行  \n\n  第二行  \n"

        let normalized = SystemTranslationService.normalizedSourceText(from: text)

        XCTAssertEqual(normalized, "第一行\n第二行")
    }

    func testMostlyEnglishWithFewChineseCharsStillTranslates() {
        let service = SystemTranslationService()
        let text = "Please restart the running instance 实例 and rebuild the latest source right now."

        XCTAssertNil(service.validationMessage(for: text))
        XCTAssertNotNil(service.makePlan(for: text))
    }
}
