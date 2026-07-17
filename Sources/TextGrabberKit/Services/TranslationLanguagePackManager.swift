import Foundation
#if canImport(Translation)
import Translation
#endif

/// 管理应用实际使用的中↔英系统翻译语言包状态。
///
/// 受 Apple `Translation` 框架能力限制:只能查询安装状态、通过 `prepareTranslation()`
/// 唤起系统下载弹窗;没有删除或自定义进度的公开 API,删除需引导用户到系统设置手动完成。
@MainActor
final class TranslationLanguagePackManager: ObservableObject {
    enum PackStatus: Equatable {
        case unknown
        case checking
        case installed
        case notInstalled
        /// 系统版本过低或该语言对不受支持,无法内嵌管理。
        case unavailable
    }

    /// 应用只做中↔英识别与翻译,这里固定管理这一对语言包的两个方向。
    static let primaryLanguageIdentifier = "zh-Hans"
    static let secondaryLanguageIdentifier = "en"

    @Published private(set) var status: PackStatus = .unknown
    @Published private(set) var isDownloading = false
    /// 供下载桥接视图观察:每次自增触发一次 `prepareTranslation()` 下载流程。
    @Published private(set) var downloadToken = 0

    func refresh() async {
#if canImport(Translation)
        guard #available(macOS 15.0, *) else {
            status = .unavailable
            return
        }

        if status == .unknown {
            status = .checking
        }

        let availability = LanguageAvailability()
        let primary = Locale.Language(identifier: Self.primaryLanguageIdentifier)
        let secondary = Locale.Language(identifier: Self.secondaryLanguageIdentifier)
        let forward = await availability.status(from: primary, to: secondary)
        let backward = await availability.status(from: secondary, to: primary)
        status = Self.combine(forward, backward)
#else
        status = .unavailable
#endif
    }

    /// 请求下载:仅在确认未安装时触发,交由下载桥接视图唤起系统下载弹窗。
    func requestDownload() {
        guard status == .notInstalled, !isDownloading else { return }
        isDownloading = true
        downloadToken += 1
    }

    /// 下载流程结束(无论成功与否)后回收状态并重新查询真实安装情况。
    func finishDownload() async {
        isDownloading = false
        await refresh()
    }

#if canImport(Translation)
    @available(macOS 15.0, *)
    private static func combine(
        _ forward: LanguageAvailability.Status,
        _ backward: LanguageAvailability.Status
    ) -> PackStatus {
        switch (forward, backward) {
        case (.installed, .installed):
            return .installed
        case (.unsupported, _), (_, .unsupported):
            return .unavailable
        default:
            return .notInstalled
        }
    }
#endif
}
