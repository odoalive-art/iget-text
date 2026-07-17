import AppKit
import SwiftUI

/// 设置分类,对应边栏中的一项。
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case capture
    case result
    case translation
    case textEditing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capture: return "截图识别"
        case .result: return "结果面板"
        case .translation: return "翻译"
        case .textEditing: return "文本编辑"
        }
    }

    var symbol: String {
        switch self {
        case .capture: return "viewfinder"
        case .result: return "macwindow"
        case .translation: return "translate"
        case .textEditing: return "textformat"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var languagePackManager = TranslationLanguagePackManager()
    @State private var selection: SettingsCategory? = .capture

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selection) { category in
                Label(category.title, systemImage: category.symbol)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 195, max: 240)
        } detail: {
            detail(for: selection ?? .capture)
                .navigationTitle((selection ?? .capture).title)
        }
        .frame(minWidth: 700, idealWidth: 720, minHeight: 460, idealHeight: 500)
    }

    @ViewBuilder
    private func detail(for category: SettingsCategory) -> some View {
        Form {
            switch category {
            case .capture:
                captureSection
            case .result:
                resultSection
            case .translation:
                translationSection
                LanguagePackSettingsSection(manager: languagePackManager)
            case .textEditing:
                textEditingSection
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 截图识别

    private var captureSection: some View {
        Section {
            Picker("激活方式", selection: $settings.activationMode) {
                ForEach(CaptureActivationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            switch settings.activationMode {
            case .keyboardShortcut:
                ShortcutRecorderRow(title: "快捷键", shortcut: $settings.hotkey) {
                    settings.resetHotkey()
                }
            case .doubleModifierTap:
                Picker("双击修饰键", selection: $settings.doubleTapModifier) {
                    ForEach(DoubleTapModifier.allCases, id: \.self) { modifier in
                        Text(modifier.displayName).tag(modifier)
                    }
                }
            case .functionKey:
                EmptyView()
            }
        } footer: {
            captureFooter
        }
    }

    @ViewBuilder
    private var captureFooter: some View {
        switch settings.activationMode {
        case .keyboardShortcut:
            if settings.hotkey.modifierOnly {
                PermissionCallout(
                    text: "纯修饰键仅作为触发方式,不绑定“松开退出”。使用此方式需要开启“辅助功能”权限。",
                    actionTitle: "打开辅助功能设置",
                    action: openAccessibilityPreferences
                )
            }
        case .doubleModifierTap:
            PermissionCallout(
                text: "快速连按两次所选修饰键即可触发截图识别。连按需在较短时间内完成,且不夹带其他修饰键。使用此方式需要开启“辅助功能”权限。",
                actionTitle: "打开辅助功能设置",
                action: openAccessibilityPreferences
            )
        case .functionKey:
            SettingsFootnote("按住 Fn 键进入框选,松开 Fn 键退出截图。")
        }
    }

    // MARK: - 结果

    private var resultSection: some View {
        Section {
            SettingsInfoRow("识别语言", value: "简体中文、英文")

            Picker("显示位置", selection: $settings.resultPanelPlacement) {
                ForEach(ResultPanelPlacementMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
    }

    // MARK: - 翻译

    private var translationSection: some View {
        Section {
            Picker("翻译来源", selection: $settings.translationProvider) {
                ForEach(TranslationProviderMode.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            if settings.translationProvider == .appleShortcut || settings.translationProvider == .automatic {
                ShortcutTranslationConfigView(shortcutName: $settings.translationShortcutName)
            }
        } footer: {
            SettingsFootnote(settings.translationProvider.helperText)
        }
    }

    // MARK: - 文本编辑

    private var textEditingSection: some View {
        Section {
            Toggle("段落级全选", isOn: $settings.isBlockEditingEnabled)
        } footer: {
            SettingsFootnote("第一次按 ⌘A 或 ⌃A 选择光标所在段落;连续再按一次选择全文。")
        }
    }

    private func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
