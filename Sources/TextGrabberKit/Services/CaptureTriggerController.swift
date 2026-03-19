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

        if !hotkeyController.updateActivation(mode: settings.activationMode, shortcut: settings.hotkey) {
            settings.resetHotkey()
            _ = hotkeyController.updateActivation(mode: settings.activationMode, shortcut: settings.hotkey)
        }

        settings.$hotkey
            .combineLatest(settings.$activationMode)
            .dropFirst()
            .sink { [weak self] shortcut, activationMode in
                guard let self else { return }
                if !self.hotkeyController.updateActivation(mode: activationMode, shortcut: shortcut) {
                    self.settings.resetHotkey()
                    _ = self.hotkeyController.updateActivation(
                        mode: self.settings.activationMode,
                        shortcut: self.settings.hotkey
                    )
                }
            }
            .store(in: &cancellables)
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
