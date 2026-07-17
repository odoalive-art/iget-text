import AppKit
import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// 设置页里的「翻译语言包」区块:展示中↔英语言包安装状态,支持下载与跳转系统设置删除。
struct LanguagePackSettingsSection: View {
    @ObservedObject var manager: TranslationLanguagePackManager

    var body: some View {
        Section {
            LabeledContent("中文 ⇄ 英文") {
                HStack(spacing: 10) {
                    statusLabel
                    trailingControl
                }
            }
            .task { await manager.refresh() }
            .background(downloadBridge)

            Button("在系统设置中管理") {
                openSystemTranslationSettings()
            }
            .controlSize(.small)
        } header: {
            Text("翻译语言包")
        } footer: {
            SettingsFootnote(footerText)
        }
    }

    // MARK: - 状态与操作

    @ViewBuilder
    private var statusLabel: some View {
        switch manager.status {
        case .unknown, .checking:
            Label("检测中…", systemImage: "clock")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.secondary)
        case .installed:
            Label("已安装", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        case .notInstalled:
            Label("未安装", systemImage: "arrow.down.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.secondary)
        case .unavailable:
            Label("不可用", systemImage: "exclamationmark.triangle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch manager.status {
        case .notInstalled:
            if manager.isDownloading {
                ProgressView().controlSize(.small)
            } else {
                Button("下载") { manager.requestDownload() }
            }
        default:
            EmptyView()
        }
    }

    private var footerText: String {
        switch manager.status {
        case .unavailable:
            return "当前系统或语言暂不支持内嵌语言包管理;可在系统设置的“翻译语言”中查看。"
        default:
            return "语言包由系统按需下载,首次下载会弹出系统下载窗口。语言包由系统统一管理,删除请前往系统设置的“翻译语言”。"
        }
    }

    private func openSystemTranslationSettings() {
        // 系统没有直达“翻译语言”子面板的公开链接,退回到“语言与地区”设置,翻译语言在此页管理。
        let candidates = [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.general"
        ]

        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    // MARK: - 下载桥接

    @ViewBuilder
    private var downloadBridge: some View {
#if canImport(Translation)
        if #available(macOS 15.0, *) {
            LanguagePackDownloadBridge(manager: manager)
        }
#endif
    }
}

#if canImport(Translation)
/// 通过 `.translationTask` 依次为中→英、英→中两个方向调用 `prepareTranslation()`,
/// 未安装时会唤起系统下载弹窗。下载能力仅此一条系统路径,无法自绘进度。
@available(macOS 15.0, *)
private struct LanguagePackDownloadBridge: View {
    @ObservedObject var manager: TranslationLanguagePackManager

    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingDirections: [(source: Locale.Language, target: Locale.Language)] = []

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: manager.downloadToken) { _, token in
                guard token > 0 else { return }
                let primary = Locale.Language(identifier: TranslationLanguagePackManager.primaryLanguageIdentifier)
                let secondary = Locale.Language(identifier: TranslationLanguagePackManager.secondaryLanguageIdentifier)
                pendingDirections = [
                    (primary, secondary),
                    (secondary, primary)
                ]
                advanceToNextDirection()
            }
            .translationTask(configuration) { session in
                // Swift 6.3 会把 session 视为主 actor 隔离值,先建 nonisolated 别名再调用其 async API。
                nonisolated(unsafe) let translationSession = session
                do {
                    try await translationSession.prepareTranslation()
                } catch {
                    // 下载失败或被取消不额外提示,刷新后按真实安装状态呈现。
                }
                advanceToNextDirection()
            }
    }

    private func advanceToNextDirection() {
        guard !pendingDirections.isEmpty else {
            configuration = nil
            Task { await manager.finishDownload() }
            return
        }

        let next = pendingDirections.removeFirst()
        configuration = TranslationSession.Configuration(source: next.source, target: next.target)
    }
}
#endif
