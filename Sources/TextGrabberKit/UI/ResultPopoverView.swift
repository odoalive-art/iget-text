import AppKit
import SwiftUI

struct ResultPopoverView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var resultState: RecognitionResultState

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _resultState = ObservedObject(wrappedValue: coordinator.resultState)
    }

    var body: some View {
        ResultPopoverContentView(
            displayState: displayState,
            placementMode: coordinator.settings.resultPanelPlacement,
            outputMode: Binding(
                get: { resultState.outputMode },
                set: { coordinator.setOutputMode($0) }
            ),
            recognizedText: $resultState.recognizedText,
            capturedPreviewImage: resultState.capturedPreviewImage,
            lastErrorMessage: resultState.lastErrorMessage,
            onRetry: coordinator.retryLastSelection,
            onCopy: coordinator.copyRecognizedText,
            onShowSettings: coordinator.showSettings,
            onClose: coordinator.closePopover,
            onOpenScreenRecordingPreferences: coordinator.openScreenRecordingPreferences
        )
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

public struct ResultPopoverPreviewHost: View {
    private enum Scenario: String, CaseIterable, Identifiable {
        case result = "结果"
        case recognizing = "识别中"
        case permission = "权限"

        var id: String { rawValue }
    }

    @State private var scenario: Scenario = .result
    @State private var recognizedText = ResultPopoverPreviewFactory.resultText

    public init() {}

    public var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Picker("预览状态", selection: $scenario) {
                    ForEach(Scenario.allCases) { scenario in
                        Text(scenario.rawValue).tag(scenario)
                    }
                }
                .pickerStyle(.segmented)

                ResultPopoverContentView(
                    displayState: displayState,
                    placementMode: .statusItem,
                    outputMode: .constant(.readingOptimized),
                    recognizedText: $recognizedText,
                    capturedPreviewImage: capturedPreviewImage,
                    lastErrorMessage: nil,
                    onRetry: {},
                    onCopy: {},
                    onShowSettings: {},
                    onClose: {},
                    onOpenScreenRecordingPreferences: {}
                )
                .frame(width: ResultPopoverLayout.width, height: ResultPopoverLayout.height)
                .clipShape(RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
            }
            .padding(24)
        }
        .frame(minWidth: 420, minHeight: 720, alignment: .top)
    }

    private var displayState: ResultPopoverDisplayState {
        switch scenario {
        case .result:
            .result
        case .recognizing:
            .recognizing
        case .permission:
            .permission
        }
    }

    private var capturedPreviewImage: NSImage? {
        switch scenario {
        case .permission:
            nil
        case .result, .recognizing:
            ResultPopoverPreviewFactory.previewImage()
        }
    }
}
