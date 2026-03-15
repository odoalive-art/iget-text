import AppKit
import Combine
import SwiftUI

@MainActor
final class ResultPopoverController: NSObject, NSWindowDelegate {
    private let coordinator: AppCoordinator
    private let statusItem: NSStatusItem
    private let panel: ResultFloatingPanel
    private let hostingController: NSHostingController<ResultPopoverView>
    private var cancellables = Set<AnyCancellable>()

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
        } else {
            showCurrentState()
        }
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
        observePanelSizingInputs()
    }

    private func showCurrentState() {
        panel.setContentSize(currentPanelSize())
        panel.setFrame(panelFrame(), display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func currentPanelSize() -> NSSize {
        if coordinator.popoverState == .result {
            return NSSize(
                width: ResultPopoverLayout.width,
                height: ResultPopoverLayout.resultPanelHeight(
                    text: coordinator.resultState.recognizedText,
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
    }

    private func refreshVisiblePanelLayout() {
        guard panel.isVisible else { return }
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

        let width = panel.frame.width
        let height = panel.frame.height
        let margin: CGFloat = 8

        var originX = buttonRectOnScreen.midX - (width / 2)
        var originY = buttonRectOnScreen.minY - height - margin

        originX = min(max(originX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        if originY < visibleFrame.minY + margin {
            originY = visibleFrame.minY + margin
        }

        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func mouseFollowPanelFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let width = panel.frame.width
        let height = panel.frame.height
        let margin: CGFloat = 12

        var originX = mouseLocation.x + margin
        var originY = mouseLocation.y - height - margin

        if originX + width > visibleFrame.maxX - margin {
            originX = mouseLocation.x - width - margin
        }
        if originY < visibleFrame.minY + margin {
            originY = min(mouseLocation.y + margin, visibleFrame.maxY - height - margin)
        }

        originX = min(max(originX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        originY = min(max(originY, visibleFrame.minY + margin), visibleFrame.maxY - height - margin)

        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !coordinator.resultState.isTranslating else { return }
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

    @objc
    private func quit() {
        coordinator.quitApplication()
    }
}

private final class ResultFloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
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
        hasShadow = true
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.transient, .moveToActiveSpace]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }
}
