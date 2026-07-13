import AppKit
import Combine
import SwiftUI

struct ResultPanelAnchorState {
    private(set) var followMouseAnchor: NSPoint?

    mutating func prepareForPresentation(
        placement: ResultPanelPlacementMode,
        mouseLocation: NSPoint,
        isNewPresentation: Bool
    ) {
        switch placement {
        case .statusItem:
            followMouseAnchor = nil
        case .followMouse:
            if isNewPresentation || followMouseAnchor == nil {
                followMouseAnchor = mouseLocation
            }
        }
    }

    func resolvedMouseLocation(currentMouseLocation: NSPoint) -> NSPoint {
        followMouseAnchor ?? currentMouseLocation
    }

    mutating func reset() {
        followMouseAnchor = nil
    }
}

enum ResultPanelPlacementGeometry {
    static func mouseFollowPanelFrame(
        anchorLocation: NSPoint,
        visibleFrame: NSRect,
        panelSize: NSSize,
        margin: CGFloat = 12
    ) -> NSRect {
        let width = panelSize.width
        let height = panelSize.height

        var originX = anchorLocation.x + margin
        var originY = anchorLocation.y - height - margin

        if originX + width > visibleFrame.maxX - margin {
            originX = anchorLocation.x - width - margin
        }
        if originY < visibleFrame.minY + margin {
            originY = min(anchorLocation.y + margin, visibleFrame.maxY - height - margin)
        }

        originX = min(max(originX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        originY = min(max(originY, visibleFrame.minY + margin), visibleFrame.maxY - height - margin)

        return NSRect(x: originX, y: originY, width: width, height: height)
    }
}

enum ResultPanelDismissalPolicy {
    static func shouldHideOnResignKey(isPinned: Bool, isTranslating: Bool) -> Bool {
        !isPinned && !isTranslating
    }

    static func shouldRestoreAfterAppDeactivation(
        isPinned: Bool,
        isPanelVisible: Bool,
        isShowingResult: Bool
    ) -> Bool {
        isPinned && isPanelVisible && isShowingResult
    }
}

@MainActor
final class ResultPopoverController: NSObject, NSWindowDelegate {
    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private let panel: ResultFloatingPanel
    private let hostingController: NSHostingController<ResultPopoverView>
    private var cancellables = Set<AnyCancellable>()
    private var anchorState = ResultPanelAnchorState()
    private var lastResignHideUptime: TimeInterval?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingController = NSHostingController(rootView: ResultPopoverView(coordinator: coordinator))
        panel = ResultFloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ResultPopoverLayout.width,
                height: ResultPopoverLayout.height
            )
        )
        super.init()

        panel.onEscape = { [weak coordinator] in
            coordinator?.closePopover()
        }
        configureStatusItem()
        configurePanel()
    }

    func toggle() {
        if panel.isVisible {
            hide()
            return
        }

        // 再次点击状态栏图标时，mouseDown 会先让面板 resignKey 并自动隐藏；
        // 若隐藏发生在极短时间内，说明就是这次点击导致的收起，不应再重新弹出。
        if let lastResignHideUptime,
           ProcessInfo.processInfo.systemUptime - lastResignHideUptime < 0.25 {
            self.lastResignHideUptime = nil
            return
        }

        showCurrentState()
    }

    func show(result _: OCRResult) {
        showCurrentState()
    }

    func showPermissionError() {
        showCurrentState()
    }

    func showRecognizing() {
        guard coordinator.settings.resultPanelPlacement != .followMouse else {
            hide()
            return
        }
        showCurrentState()
    }

    func showError(message: String) {
        coordinator.resultState.setErrorMessage(message)
        showCurrentState()
    }

    func hide() {
        anchorState.reset()
        panel.orderOut(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "截图文本识别")
        button.imagePosition = .imageOnly
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePanel() {
        panel.delegate = self
        panel.contentViewController = hostingController
        panel.setContentSize(currentPanelSize())
        applyPinningState()
        observeApplicationState()
        observePanelSizingInputs()
    }

    private func showCurrentState() {
        anchorState.prepareForPresentation(
            placement: coordinator.settings.resultPanelPlacement,
            mouseLocation: NSEvent.mouseLocation,
            isNewPresentation: !panel.isVisible
        )
        panel.setContentSize(currentPanelSize())
        panel.setFrame(panelFrame(), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func currentPanelSize() -> NSSize {
        ResultPopoverShadowCanvas.size(for: currentSurfaceSize())
    }

    private func currentSurfaceSize() -> NSSize {
        if coordinator.popoverState == .result || coordinator.popoverState == .idle {
            return NSSize(
                width: ResultPopoverLayout.width,
                height: ResultPopoverLayout.resultPanelHeight(
                    text: coordinator.resultState.recognizedText,
                    translationText: currentTranslationDisplayText(),
                    showsTranslationPane: coordinator.resultState.isTranslating ||
                        !coordinator.resultState.translatedText.isEmpty ||
                        coordinator.resultState.translationErrorMessage != nil,
                    outputMode: coordinator.resultState.outputMode,
                    image: coordinator.resultState.capturedPreviewImage,
                    includePreview: coordinator.settings.resultPanelPlacement != .followMouse
                )
            )
        }

        return NSSize(
            width: ResultPopoverLayout.width,
            height: ResultPopoverLayout.height
        )
    }

    private func observePanelSizingInputs() {
        coordinator.resultState.$recognizedText
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.resultState.$capturedPreviewImage
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.resultState.$translatedText
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.resultState.$translationErrorMessage
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.resultState.$isTranslating
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.$popoverState
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.settings.$resultPanelPlacement
            .sink { [weak self] _ in
                self?.refreshVisiblePanelLayout()
            }
            .store(in: &cancellables)

        coordinator.$isResultPanelPinned
            .sink { [weak self] _ in
                self?.applyPinningState()
            }
            .store(in: &cancellables)
    }

    private func applyPinningState() {
        panel.shouldRemainVisibleWhenInactive = coordinator.isResultPanelPinned
        panel.collectionBehavior = coordinator.isResultPanelPinned
            ? [.moveToActiveSpace]
            : [.transient, .moveToActiveSpace]
    }

    private func observeApplicationState() {
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.restorePinnedPanelIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func restorePinnedPanelIfNeeded() {
        guard ResultPanelDismissalPolicy.shouldRestoreAfterAppDeactivation(
            isPinned: coordinator.isResultPanelPinned,
            isPanelVisible: panel.isVisible,
            isShowingResult: coordinator.popoverState == .result
        ) else {
            return
        }

        panel.orderFrontRegardless()
    }

    private func refreshVisiblePanelLayout() {
        guard panel.isVisible else { return }
        anchorState.prepareForPresentation(
            placement: coordinator.settings.resultPanelPlacement,
            mouseLocation: NSEvent.mouseLocation,
            isNewPresentation: false
        )
        panel.setContentSize(currentPanelSize())
        panel.setFrame(panelFrame(), display: true)
    }

    private func panelFrame() -> NSRect {
        switch coordinator.settings.resultPanelPlacement {
        case .statusItem:
            if let button = statusItem.button {
                return statusItemPanelFrame(relativeTo: button)
            }
            return mouseFollowPanelFrame()
        case .followMouse:
            return mouseFollowPanelFrame()
        }
    }

    private func statusItemPanelFrame(relativeTo button: NSStatusBarButton) -> NSRect {
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = button.window?.convertToScreen(buttonRectInWindow) ?? .zero
        let visibleFrame = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let surfaceSize = currentSurfaceSize()
        let width = surfaceSize.width
        let height = surfaceSize.height
        let margin: CGFloat = 8

        var originX = buttonRectOnScreen.midX - (width / 2)
        var originY = buttonRectOnScreen.minY - height - margin

        originX = min(max(originX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        if originY < visibleFrame.minY + margin {
            originY = visibleFrame.minY + margin
        }

        return ResultPopoverShadowCanvas.frame(
            for: NSRect(x: originX, y: originY, width: width, height: height)
        )
    }

    private func mouseFollowPanelFrame() -> NSRect {
        let anchorLocation = anchorState.resolvedMouseLocation(currentMouseLocation: NSEvent.mouseLocation)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(anchorLocation, $0.frame, false) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let surfaceFrame = ResultPanelPlacementGeometry.mouseFollowPanelFrame(
            anchorLocation: anchorLocation,
            visibleFrame: visibleFrame,
            panelSize: currentSurfaceSize()
        )
        return ResultPopoverShadowCanvas.frame(for: surfaceFrame)
    }

    private func currentTranslationDisplayText() -> String? {
        if !coordinator.resultState.translatedText.isEmpty {
            return coordinator.resultState.translatedText
        }

        if let translationErrorMessage = coordinator.resultState.translationErrorMessage {
            return translationErrorMessage
        }

        if coordinator.resultState.isTranslating {
            return "正在翻译当前文本…"
        }

        return nil
    }

    func windowDidResignKey(_ notification: Notification) {
        guard ResultPanelDismissalPolicy.shouldHideOnResignKey(
            isPinned: coordinator.isResultPanelPinned,
            isTranslating: coordinator.resultState.isTranslating
        ) else {
            return
        }

        lastResignHideUptime = ProcessInfo.processInfo.systemUptime
        hide()
    }

    @objc
    private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggle()
            return
        }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "开始识别", action: #selector(beginRecognition), keyEquivalent: "")
        #if DEBUG
        menu.addItem(withTitle: "UI 调试面板", action: #selector(openUIDebugPanel), keyEquivalent: "")
        #endif
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func beginRecognition() {
        coordinator.handleHotkeyPressed()
    }

    @objc
    private func openSettings() {
        coordinator.showSettings()
    }

    #if DEBUG
    @objc
    private func openUIDebugPanel() {
        coordinator.showUIDebugPanel()
    }
    #endif

    @objc
    private func quit() {
        coordinator.quitApplication()
    }
}

private final class ResultFloatingPanel: NSWindow {
    var onEscape: (() -> Void)?
    var shouldRemainVisibleWhenInactive = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func resignKey() {
        super.resignKey()
        keepVisibleIfNeeded()
    }

    override func resignMain() {
        super.resignMain()
        keepVisibleIfNeeded()
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.transient, .moveToActiveSpace]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    private func keepVisibleIfNeeded() {
        guard shouldRemainVisibleWhenInactive, isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldRemainVisibleWhenInactive, self.isVisible else { return }
            self.orderFrontRegardless()
        }
    }
}
