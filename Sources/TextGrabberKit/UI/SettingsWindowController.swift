import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(settings: AppSettings) {
        let rootView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: rootView)
        let containerController = SettingsWindowContentController(hostingController: hostingController)
        let window = SettingsWindow(contentViewController: containerController)

        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 460, height: 568))
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        window.centerTrafficLightsVertically()
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        (notification.object as? SettingsWindow)?.centerTrafficLightsVertically()
    }

    func windowDidResize(_ notification: Notification) {
        (notification.object as? SettingsWindow)?.centerTrafficLightsVertically()
    }
}

private final class SettingsWindow: NSWindow {
    func centerTrafficLightsVertically() {
        guard let contentView else { return }

        let titlebarCenter = NSPoint(
            x: contentView.bounds.midX,
            y: contentView.bounds.maxY - SettingsTitlebarView.height / 2
        )

        for buttonType in [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ] {
            guard let button = standardWindowButton(buttonType), let buttonSuperview = button.superview else {
                continue
            }

            let centeredPoint = buttonSuperview.convert(titlebarCenter, from: contentView)
            button.setFrameOrigin(
                NSPoint(x: button.frame.minX, y: centeredPoint.y - button.frame.height / 2)
            )
        }
    }
}

private final class SettingsWindowContentController: NSViewController {
    private let hostingController: NSHostingController<SettingsView>

    init(hostingController: NSHostingController<SettingsView>) {
        self.hostingController = hostingController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let containerView = NSView()
        let titlebarView = SettingsTitlebarView(title: "截图识别设置")
        let settingsView = hostingController.view

        titlebarView.translatesAutoresizingMaskIntoConstraints = false
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        // 设置内容铺满整窗(含标题栏下方),标题栏叠在其上层;
        // 标题栏毛玻璃采用 withinWindow 混合,透出的是其下方的设置内容而非桌面。
        containerView.addSubview(settingsView)
        containerView.addSubview(titlebarView)

        NSLayoutConstraint.activate([
            settingsView.topAnchor.constraint(equalTo: containerView.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            titlebarView.topAnchor.constraint(equalTo: containerView.topAnchor),
            titlebarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titlebarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titlebarView.heightAnchor.constraint(equalToConstant: SettingsTitlebarView.height)
        ])

        addChild(hostingController)
        view = containerView
    }
}

private final class SettingsTitlebarView: NSView {
    static let height: CGFloat = 48

    init(title: String) {
        super.init(frame: .zero)

        let effectView = NSVisualEffectView()
        effectView.material = .headerView
        effectView.blendingMode = .withinWindow
        effectView.state = .active

        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
