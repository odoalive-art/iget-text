import AppKit
import Carbon
import Combine
import Foundation

enum CaptureActivationMode: String, Codable, CaseIterable {
    case keyboardShortcut
    case doubleModifierTap
    case functionKey

    var displayName: String {
        switch self {
        case .keyboardShortcut:
            "组合键"
        case .doubleModifierTap:
            "双击修饰键"
        case .functionKey:
            "Fn 键"
        }
    }
}

enum DoubleTapModifier: String, Codable, CaseIterable {
    case command
    case option
    case control
    case shift

    var displayName: String {
        switch self {
        case .command:
            "⌘ Command"
        case .option:
            "⌥ Option"
        case .control:
            "⌃ Control"
        case .shift:
            "⇧ Shift"
        }
    }

    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            .command
        case .option:
            .option
        case .control:
            .control
        case .shift:
            .shift
        }
    }
}

enum ResultPanelPlacementMode: String, Codable, CaseIterable {
    case statusItem
    case followMouse

    var displayName: String {
        switch self {
        case .statusItem:
            "菜单栏图标"
        case .followMouse:
            "跟随鼠标"
        }
    }
}

enum TranslationProviderMode: String, Codable, CaseIterable {
    case automatic
    case systemOnly
    case appleShortcut

    var displayName: String {
        switch self {
        case .automatic:
            "自动"
        case .systemOnly:
            "仅系统翻译"
        case .appleShortcut:
            "Apple 在线翻译（快捷指令）"
        }
    }

    var helperText: String {
        switch self {
        case .automatic:
            "优先通过「快捷指令」调用 Apple 在线翻译（需已安装指定快捷指令并关闭系统「设备端模式」）；未安装或失败/超时时自动回退到系统翻译。"
        case .systemOnly:
            "仅使用系统翻译能力，适合更看重本地能力和系统一致性的场景。"
        case .appleShortcut:
            "通过「快捷指令」调用系统翻译，可借助 Apple 在线翻译获得更准的结果。需先安装指定快捷指令，并在系统设置中关闭「设备端模式」；文本会经系统在线翻译处理。"
        }
    }
}

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32?
    var carbonModifiers: UInt32

    static let defaultValue = KeyboardShortcut(
        keyCode: nil,
        carbonModifiers: UInt32(controlKey | optionKey)
    )

    static let legacyDefaultValue = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_T),
        carbonModifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    init(keyCode: UInt32?, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.init(
            keyCode: keyCode,
            carbonModifiers: KeyboardShortcut.carbonModifiers(from: modifiers)
        )
    }

    var modifierOnly: Bool {
        keyCode == nil
    }

    var modifierFlags: NSEvent.ModifierFlags {
        KeyboardShortcut.modifierFlags(from: carbonModifiers)
    }

    var displayString: String {
        let modifierText = modifierFlags.readableDisplayString
        let keyText = keyCode.map(KeyCodeFormatter.displayString(for:)) ?? ""
        return modifierText + keyText
    }

    static func from(event: NSEvent) -> KeyboardShortcut? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifierMask = carbonModifiers(from: modifiers)
        guard modifierMask != 0 else { return nil }

        switch Int(event.keyCode) {
        case kVK_Command, kVK_Shift, kVK_RightShift, kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl:
            let relevantModifiers = modifiers.intersection(.shortcutRelevantModifiers)
            guard relevantModifiers.modifierCount >= 2 else { return nil }
            return KeyboardShortcut(keyCode: nil, carbonModifiers: carbonModifiers(from: relevantModifiers))
        default:
            return KeyboardShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: modifierMask)
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0

        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        return result
    }

    private static func modifierFlags(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }

        return flags
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    @Published var hotkey: KeyboardShortcut
    @Published var activationMode: CaptureActivationMode
    @Published var doubleTapModifier: DoubleTapModifier
    @Published var resultPanelPlacement: ResultPanelPlacementMode
    @Published var translationProvider: TranslationProviderMode
    @Published var translationShortcutName: String
    @Published var isBlockEditingEnabled: Bool
    @Published var launchAtLogin = false

    static let defaultTranslationShortcutName = "TextGrabber Translate"
    /// 官方分发的翻译快捷指令 iCloud 链接,供新用户一键获取导入。
    static let translationShortcutICloudURL = URL(string: "https://www.icloud.com/shortcuts/bb63cda2cb9c42beaa5c2af365110db1")!

    let ocrLanguages = ["zh-Hans", "en-US"]

    private let defaults: UserDefaults
    private let hotkeyKey = "app.hotkey"
    private let activationModeKey = "app.activationMode"
    private let doubleTapModifierKey = "app.doubleTapModifier"
    private let resultPanelPlacementKey = "app.resultPanelPlacement"
    private let translationProviderKey = "app.translationProvider"
    private let translationShortcutNameKey = "app.translationShortcutName"
    private let blockEditingEnabledKey = "app.blockEditingEnabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        activationMode = CaptureActivationMode(rawValue: defaults.string(forKey: activationModeKey) ?? "") ?? .keyboardShortcut
        doubleTapModifier = DoubleTapModifier(rawValue: defaults.string(forKey: doubleTapModifierKey) ?? "") ?? .command
        resultPanelPlacement = ResultPanelPlacementMode(rawValue: defaults.string(forKey: resultPanelPlacementKey) ?? "") ?? .statusItem
        translationProvider = TranslationProviderMode(rawValue: defaults.string(forKey: translationProviderKey) ?? "") ?? .automatic
        let storedShortcutName = (defaults.string(forKey: translationShortcutNameKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        translationShortcutName = storedShortcutName.isEmpty ? Self.defaultTranslationShortcutName : storedShortcutName
        isBlockEditingEnabled = defaults.object(forKey: blockEditingEnabledKey) as? Bool ?? true

        if let data = defaults.data(forKey: hotkeyKey),
           let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            if shortcut == .legacyDefaultValue {
                hotkey = .defaultValue
                save(shortcut: .defaultValue)
            } else {
                hotkey = shortcut
            }
        } else {
            hotkey = .defaultValue
        }

        $hotkey
            .dropFirst()
            .sink { [weak self] shortcut in
                self?.save(shortcut: shortcut)
            }
            .store(in: &cancellables)

        $activationMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.defaults.set(mode.rawValue, forKey: self?.activationModeKey ?? "")
            }
            .store(in: &cancellables)

        $doubleTapModifier
            .dropFirst()
            .sink { [weak self] modifier in
                self?.defaults.set(modifier.rawValue, forKey: self?.doubleTapModifierKey ?? "")
            }
            .store(in: &cancellables)

        $resultPanelPlacement
            .dropFirst()
            .sink { [weak self] mode in
                self?.defaults.set(mode.rawValue, forKey: self?.resultPanelPlacementKey ?? "")
            }
            .store(in: &cancellables)

        $translationProvider
            .dropFirst()
            .sink { [weak self] provider in
                self?.defaults.set(provider.rawValue, forKey: self?.translationProviderKey ?? "")
            }
            .store(in: &cancellables)

        $translationShortcutName
            .dropFirst()
            .sink { [weak self] name in
                guard let self else { return }
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                self.defaults.set(trimmed, forKey: self.translationShortcutNameKey)
            }
            .store(in: &cancellables)

        $isBlockEditingEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.defaults.set(isEnabled, forKey: self?.blockEditingEnabledKey ?? "")
            }
            .store(in: &cancellables)
    }

    func resetHotkey() {
        hotkey = .defaultValue
    }

    private var cancellables = Set<AnyCancellable>()

    private func save(shortcut: KeyboardShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: hotkeyKey)
    }
}

private enum KeyCodeFormatter {
    private static let map: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_Escape): "Esc",
        UInt32(kVK_LeftArrow): "Left",
        UInt32(kVK_RightArrow): "Right",
        UInt32(kVK_UpArrow): "Up",
        UInt32(kVK_DownArrow): "Down",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12"
    ]

    static func displayString(for keyCode: UInt32) -> String {
        map[keyCode, default: "Key \(keyCode)"]
    }
}

extension NSEvent.ModifierFlags {
    static let shortcutRelevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var modifierCount: Int {
        let supportedModifiers: [NSEvent.ModifierFlags] = [.control, .option, .shift, .command]
        return supportedModifiers.filter { contains($0) }.count
    }

    var readableDisplayString: String {
        var parts = ""

        if contains(.control) {
            parts += "^"
        }
        if contains(.option) {
            parts += "⌥"
        }
        if contains(.shift) {
            parts += "⇧"
        }
        if contains(.command) {
            parts += "⌘"
        }

        return parts
    }
}
