import AppKit
import SwiftUI

enum ResultPopoverLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 620
    static let compactHeight: CGFloat = 360
    static let cornerRadius: CGFloat = 24
}

struct LiquidGlassSurface<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let view = LiquidGlassContainerView(cornerRadius: cornerRadius)
        view.update(rootView: AnyView(content))
        return view
    }

    func updateNSView(_ nsView: LiquidGlassContainerView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.update(rootView: AnyView(content))
    }
}

final class LiquidGlassContainerView: NSView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let effectView: NSView
    var cornerRadius: CGFloat {
        didSet {
            updateStyling()
        }
    }

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.tintColor = nil
            effectView = glassView
        } else {
            let visualView = NSVisualEffectView()
            visualView.material = .popover
            visualView.blendingMode = .withinWindow
            visualView.state = .active
            effectView = visualView
        }

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        effectView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.contentView = hostingView
        } else {
            effectView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
            ])
        }

        updateStyling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: AnyView) {
        hostingView.rootView = rootView
    }

    private func updateStyling() {
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.cornerRadius = cornerRadius
        }
    }
}

extension View {
    @ViewBuilder
    func popoverSecondaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func popoverPrimaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
