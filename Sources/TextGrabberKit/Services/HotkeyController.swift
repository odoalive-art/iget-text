import AppKit
@preconcurrency import ApplicationServices
import Carbon

@MainActor
final class HotkeyController {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var modifierShortcut: KeyboardShortcut?
    private var activationMonitorMode: ActivationMonitorMode?
    private var isFlagsBasedActivationActive = false
    private let hotKeyID = EventHotKeyID(signature: FourCharCode("TGHB"), id: 1)

    init() {
        installHandlerIfNeeded()
    }

    func isFunctionKeyPressed() -> Bool {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let currentFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
        return currentFlags.contains(NSEvent.ModifierFlags.function)
    }

    func updateActivation(mode: CaptureActivationMode, shortcut: KeyboardShortcut) -> Bool {
        clearShortcutRegistration()

        if mode == .functionKey {
            installFlagsMonitor(for: .functionKey)
            return true
        }

        if shortcut.modifierOnly {
            modifierShortcut = shortcut
            installFlagsMonitor(for: .modifierShortcut)
            return true
        }

        guard let keyCode = shortcut.keyCode else {
            return false
        }

        let status = RegisterEventHotKey(
            keyCode,
            UInt32(shortcut.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        return status == noErr
    }

    private func clearShortcutRegistration() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let globalFlagsMonitor {
            NSEvent.removeMonitor(globalFlagsMonitor)
            self.globalFlagsMonitor = nil
        }

        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
            self.localFlagsMonitor = nil
        }

        modifierShortcut = nil
        activationMonitorMode = nil
        isFlagsBasedActivationActive = false
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard
                    let event,
                    let userData
                else {
                    return noErr
                }

                let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
                let kind = GetEventKind(event)
                MainActor.assumeIsolated {
                    controller.handle(kind: kind)
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            userData,
            &eventHandler
        )
    }

    private func installFlagsMonitor(for mode: ActivationMonitorMode) {
        activationMonitorMode = mode
        requestAccessibilityPermissionIfNeeded()

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleFlagsChanged(event.modifierFlags)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated {
                self.handleFlagsChanged(event.modifierFlags)
            }
            return event
        }
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        let matchesShortcut: Bool

        switch activationMonitorMode {
        case .modifierShortcut:
            guard let modifierShortcut else { return }
            let activeFlags = flags.intersection(.shortcutRelevantModifiers)
            let targetFlags = modifierShortcut.modifierFlags.intersection(.shortcutRelevantModifiers)
            matchesShortcut = activeFlags == targetFlags
        case .functionKey:
            matchesShortcut = flags.contains(.function)
        case .none:
            return
        }

        if matchesShortcut && !isFlagsBasedActivationActive {
            isFlagsBasedActivationActive = true
            onPress?()
        } else if !matchesShortcut && isFlagsBasedActivationActive {
            isFlagsBasedActivationActive = false
            onRelease?()
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = [accessibilityPromptOptionKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func handle(kind: UInt32) {
        switch kind {
        case UInt32(kEventHotKeyPressed):
            onPress?()
        case UInt32(kEventHotKeyReleased):
            onRelease?()
        default:
            break
        }
    }
}

private enum ActivationMonitorMode {
    case modifierShortcut
    case functionKey
}

private let accessibilityPromptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String

private func FourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
