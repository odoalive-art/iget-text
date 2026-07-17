import AppKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var languagePackManager = TranslationLanguagePackManager()

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            captureSection
            resultSection
            translationSection
            LanguagePackSettingsSection(manager: languagePackManager)
            textEditingSection
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
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
        } header: {
            Text("截图识别")
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
        Section("结果") {
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
        } header: {
            Text("翻译")
        } footer: {
            SettingsFootnote(settings.translationProvider.helperText)
        }
    }

    // MARK: - 文本编辑

    private var textEditingSection: some View {
        Section {
            Toggle("段落级全选", isOn: $settings.isBlockEditingEnabled)
        } header: {
            Text("文本编辑")
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
