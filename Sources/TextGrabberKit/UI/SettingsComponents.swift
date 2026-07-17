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
            .frame(width: 210)
        }

        LabeledContent("状态") {
            statusLabel
        }

        HStack(spacing: 12) {
            Button("获取翻译快捷指令") {
                NSWorkspace.shared.open(AppSettings.translationShortcutICloudURL)
            }
            Button("打开「快捷指令」App") {
                if let url = URL(string: "shortcuts://") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .controlSize(.small)
        .task(id: shortcutName) {
            await refreshInstallState()
        }

        if installState == .missing {
            SettingsFootnote("点击「获取翻译快捷指令」会在「快捷指令」中打开导入确认页；导入后请保持名称为「\(AppSettings.defaultTranslationShortcutName)」，并在系统设置中关闭「设备端模式」以使用在线翻译。")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch installState {
        case .checking:
            Label("检测中…", systemImage: "clock").foregroundStyle(.secondary)
        case .installed:
            Label("已安装", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .missing:
            Label("未找到，请在快捷指令中创建", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
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
