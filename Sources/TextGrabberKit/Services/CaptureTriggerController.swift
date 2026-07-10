import Combine
import Foundation

@MainActor
final class CaptureTriggerController {
    var onTrigger: (() -> Void)?

    private let settings: AppSettings
    private let hotkeyController: HotkeyController
    private var cancellables = Set<AnyCancellable>()
    private var activationReleaseMonitorTask: Task<Void, Never>?

    init(settings: AppSettings, hotkeyController: HotkeyController? = nil) {
        self.settings = settings
        self.hotkeyController = hotkeyController ?? HotkeyController()
    }

    func start() {
        hotkeyController.onPress = { [weak self] in
            self?.onTrigger?()
        }

        if !applyActivation(
            mode: settings.activationMode,
            shortcut: settings.hotkey,
            doubleTapModifier: settings.doubleTapModifier
        ) {
            settings.resetHotkey()
            _ = applyActivation(
                mode: settings.activationMode,
                shortcut: settings.hotkey,
                doubleTapModifier: settings.doubleTapModifier
            )
        }

        settings.$hotkey
            .combineLatest(settings.$activationMode, settings.$doubleTapModifier)
            .dropFirst()
            .sink { [weak self] shortcut, activationMode, doubleTapModifier in
                guard let self else { return }
                if !self.applyActivation(
                    mode: activationMode,
                    shortcut: shortcut,
                    doubleTapModifier: doubleTapModifier
                ) {
                    self.settings.resetHotkey()
                    _ = self.applyActivation(
                        mode: self.settings.activationMode,
                        shortcut: self.settings.hotkey,
                        doubleTapModifier: self.settings.doubleTapModifier
                    )
                }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    private func applyActivation(
        mode: CaptureActivationMode,
        shortcut: KeyboardShortcut,
        doubleTapModifier: DoubleTapModifier
    ) -> Bool {
        hotkeyController.updateActivation(
            mode: mode,
            shortcut: shortcut,
            doubleTapModifier: doubleTapModifier
        )
    }

    func beginSelectionMonitoring(
        isSelectionActive: @escaping @MainActor () -> Bool,
        cancelSelection: @escaping @MainActor () -> Void
    ) {
        stopSelectionMonitoring()

        guard settings.activationMode == .functionKey else {
            return
        }

        activationReleaseMonitorTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))

                await MainActor.run {
                    guard isSelectionActive() else { return }
                    guard self.hotkeyController.isFunctionKeyPressed() else {
                        cancelSelection()
                        return
                    }
                }
            }
        }
    }

    func stopSelectionMonitoring() {
        activationReleaseMonitorTask?.cancel()
        activationReleaseMonitorTask = nil
    }
}
