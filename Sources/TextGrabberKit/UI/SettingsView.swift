import AppKit
import Carbon
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section("快捷键") {
                Picker("激活方式", selection: $settings.activationMode) {
                    ForEach(CaptureActivationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                HStack {
                    Text("截图识别")
                    Spacer()
                    ShortcutRecorderRepresentable(shortcut: $settings.hotkey)
                        .frame(width: 160, height: 32)
                }
                .opacity(settings.activationMode == .keyboardShortcut ? 1 : 0.45)

                Button("恢复默认快捷键") {
                    settings.resetHotkey()
                }
                .disabled(settings.activationMode != .keyboardShortcut)

                if settings.activationMode == .doubleModifierTap {
                    Picker("双击按键", selection: $settings.doubleTapModifier) {
                        ForEach(DoubleTapModifier.allCases, id: \.self) { modifier in
                            Text(modifier.displayName).tag(modifier)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("快速连按两次所选修饰键即可触发截图识别。连按需要在较短时间内完成，并且不夹带其他修饰键。使用该模式需要额外开启“辅助功能”权限。")
                            .foregroundStyle(.secondary)
                        Button("打开辅助功能设置") {
                            openAccessibilityPreferences()
                        }
                    }
                }

                if settings.activationMode == .functionKey {
                    Text("按住 Fn 键进入框选，松开 Fn 键退出截图。")
                        .foregroundStyle(.secondary)
                }

                if settings.activationMode == .keyboardShortcut, settings.hotkey.modifierOnly {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("纯修饰键会直接影响系统截图选区行为，因此当前仅将其作为触发方式，不再绑定“松开退出”。使用纯修饰键组合需要额外开启“辅助功能”权限。")
                            .foregroundStyle(.secondary)
                        Button("打开辅助功能设置") {
                            openAccessibilityPreferences()
                        }
                    }
                }
            }

            Section("识别语言") {
                Text("固定为简体中文 + 英文")
                    .foregroundStyle(.secondary)
            }

            Section("翻译") {
                Picker("翻译来源", selection: $settings.translationProvider) {
                    ForEach(TranslationProviderMode.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                Text(settings.translationProvider.helperText)
                    .foregroundStyle(.secondary)
            }

            Section("其他") {
                Picker("识别窗口位置", selection: $settings.resultPanelPlacement) {
                    ForEach(ResultPanelPlacementMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Toggle("登录时启动（预留）", isOn: $settings.launchAtLogin)
                    .disabled(true)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 380)
    }

    private func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl(shortcut: shortcut)
        control.onShortcutChange = { newShortcut in
            shortcut = newShortcut
        }
        return control
    }

    func updateNSView(_ nsView: ShortcutRecorderControl, context: Context) {
        nsView.shortcut = shortcut
    }
}

@MainActor
private final class ShortcutRecorderControl: NSView {
    var onShortcutChange: ((KeyboardShortcut) -> Void)?

    var shortcut: KeyboardShortcut {
        didSet {
            updateLabel()
        }
    }

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet {
            updateLabel()
            needsDisplay = true
        }
    }

    init(shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 160, height: 32)))
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let fill = NSColor.controlBackgroundColor
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let strokeColor = isRecording ? NSColor.controlAccentColor : NSColor.separatorColor
        strokeColor.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }

        guard let shortcut = KeyboardShortcut.from(event: event) else {
            NSSound.beep()
            return
        }

        self.shortcut = shortcut
        isRecording = false
        onShortcutChange?(shortcut)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        guard let shortcut = KeyboardShortcut.from(event: event), shortcut.modifierOnly else {
            return
        }

        self.shortcut = shortcut
        isRecording = false
        onShortcutChange?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    private func setupView() {
        wantsLayer = true

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLabel()
    }

    private func updateLabel() {
        label.stringValue = isRecording ? "按下新快捷键" : shortcut.displayString
        label.textColor = isRecording ? .controlAccentColor : .labelColor
    }
}
