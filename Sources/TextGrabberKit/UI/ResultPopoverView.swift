import AppKit
import SwiftUI

struct ResultPopoverView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var resultState: RecognitionResultState
    @ObservedObject private var settings: AppSettings

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _resultState = ObservedObject(wrappedValue: coordinator.resultState)
        _settings = ObservedObject(wrappedValue: coordinator.settings)
    }

    var body: some View {
        ResultPopoverContentView(
            displayState: displayState,
            placementMode: settings.resultPanelPlacement,
            isPinned: $coordinator.isResultPanelPinned,
            resultState: resultState,
            translationServiceResolver: coordinator.translationServiceResolver,
            translationProvider: settings.translationProvider,
            isBlockEditingEnabled: settings.isBlockEditingEnabled,
            outputMode: Binding(
                get: { resultState.outputMode },
                set: { coordinator.setOutputMode($0) }
            ),
            recognizedText: Binding(
                get: { resultState.recognizedText },
                set: { resultState.updateRecognizedText($0) }
            ),
            capturedPreviewImage: resultState.capturedPreviewImage,
            lastErrorMessage: resultState.lastErrorMessage,
            onRetry: coordinator.retryLastSelection,
            onCopy: coordinator.copyRecognizedText,
            onTogglePin: coordinator.toggleResultPanelPin,
            onShowSettings: coordinator.showSettings,
            onClose: coordinator.closePopover,
            onOpenScreenRecordingPreferences: coordinator.openScreenRecordingPreferences
        )
        .padding(.top, ResultPopoverShadowCanvas.topInset)
        .padding(.horizontal, ResultPopoverShadowCanvas.horizontalInset)
        .padding(.bottom, ResultPopoverShadowCanvas.bottomInset)
    }

    private var displayState: ResultPopoverDisplayState {
        switch coordinator.popoverState {
        case .idle, .result:
            .result
        case .recognizing:
            .recognizing
        case .permission:
            .permission
        case .error:
            .error
        }
    }
}
