import AppKit
import Carbon
import SwiftUI

// MARK: - 只读信息行

/// 一行只读信息:左标题,右侧次要颜色的取值。用于展示不可编辑的配置。
struct SettingsInfoRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 说明文本

/// 统一的次要说明文本(footnote 灰字),用作 Section footer 或行下说明。
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 权限提示

/// 权限提示:说明文字 + 跳转按钮,作为分组说明(footer)使用。
struct PermissionCallout: View {
    let text: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFootnote(text)
            Button(actionTitle, action: action)
                .controlSize(.small)
        }
    }
}

// MARK: - 快捷指令翻译配置

/// 「Apple 在线翻译(快捷指令)」选中时的附加配置:快捷指令名称、安装状态与打开入口。
struct ShortcutTranslationConfigView: View {
    @Binding var shortcutName: String

    @State private var installState: InstallState = .checking

    private enum InstallState {
        case checking
        case installed
        case missing
    }

    var body: some View {
        LabeledContent("快捷指令名称") {
            TextField(
                "",
                text: $shortcutName,
                prompt: Text(AppSettings.defaultTranslationShortcutName)
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 200)
        }

        VStack(alignment: .leading, spacing: 14) {
            ShortcutSetupStep(
                marker: stepOneMarker,
                title: stepOneTitle,
                detail: "点右侧按钮，在「快捷指令」中点「添加快捷指令」完成导入。若被系统拦截，先到「快捷指令 → 设置」开启「允许不受信任的快捷指令」；导入后名称需保持「\(AppSettings.defaultTranslationShortcutName)」。"
            ) {
                HStack(spacing: 8) {
                    if installState != .installed {
                        Button("获取快捷指令") {
                            NSWorkspace.shared.open(AppSettings.translationShortcutICloudURL)
                        }
                    }
                    Button("重新检测") {
                        Task { await refreshInstallState() }
                    }
                }
            }

            ShortcutSetupStep(
                marker: .optional,
                title: "关闭系统「设备端模式」（可选，在线翻译更准）",
                detail: "离线也能翻译；关闭后快捷指令会走 Apple 在线翻译，结果更准确。此开关由系统管理，App 无法自动检测。"
            ) {
                Button("打开系统设置") {
                    openTranslationSettings()
                }
            }
        }
        .task(id: shortcutName) {
            await refreshInstallState()
        }
    }

    private var stepOneMarker: ShortcutSetupStepMarker {
        switch installState {
        case .checking: return .checking
        case .installed: return .done
        case .missing: return .pending
        }
    }

    private var stepOneTitle: String {
        switch installState {
        case .checking: return "获取并导入翻译快捷指令（检测中…）"
        case .installed: return "翻译快捷指令已安装"
        case .missing: return "获取并导入翻译快捷指令"
        }
    }

    private func openTranslationSettings() {
        for candidate in [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.general"
        ] {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func refreshInstallState() async {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetName = name.isEmpty ? AppSettings.defaultTranslationShortcutName : name
        installState = .checking
        let installed = await Task.detached {
            ShortcutsTranslationService.installedShortcutNames().contains(targetName)
        }.value
        installState = installed ? .installed : .missing
    }
}

private enum ShortcutSetupStepMarker {
    case done
    case checking
    case pending
    case optional
}

/// 引导步骤行:左侧状态标记 + 标题/说明 + 右侧操作。
private struct ShortcutSetupStep<Trailing: View>: View {
    let marker: ShortcutSetupStepMarker
    let title: String
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            markerView
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                    Spacer(minLength: 8)
                    trailing()
                        .controlSize(.small)
                        .fixedSize()
                }
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var markerView: some View {
        switch marker {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .checking:
            ProgressView().controlSize(.small)
        case .pending:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .optional:
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
    }
}

// MARK: - 快捷键录制

/// 快捷键录制行:录制控件 + 恢复默认按钮。
struct ShortcutRecorderRow: View {
    let title: String
    @Binding var shortcut: KeyboardShortcut
    let onReset: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            HStack(spacing: 8) {
                ShortcutRecorderRepresentable(shortcut: $shortcut)
                    .frame(width: 150, height: 24)
                    .fixedSize()

                Button("恢复默认", action: onReset)
            }
        }
    }
}

struct ShortcutRecorderRepresentable: NSViewRepresentable {
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
final class ShortcutRecorderControl: NSView {
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
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 160, height: 24)))
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 150, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill = NSColor.controlBackgroundColor
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        let strokeColor = isRecording ? NSColor.controlAccentColor : NSColor.separatorColor
        strokeColor.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
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
