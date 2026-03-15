import AppKit
import SwiftUI

enum ResultPopoverLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 483
    static let compactHeight: CGFloat = 360
    static let cornerRadius: CGFloat = 24
    static let headerHeight: CGFloat = 49
    static let horizontalInset: CGFloat = 20
    static let previewCornerRadius: CGFloat = 12
    static let contentCardHeight: CGFloat = 200
    static let topContentPadding: CGFloat = 17
    static let bottomContentPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 17
    static let footerHeight: CGFloat = 24
    static let previewVerticalPadding: CGFloat = 36
    static let previewWidthRatio: CGFloat = 0.8
    static let previewPlaceholderHeight: CGFloat = 110
    static let contentCardTopPadding: CGFloat = 15
    static let contentCardBottomPadding: CGFloat = 20
    static let contentCardInnerHorizontalPadding: CGFloat = 20
    static let contentCardInnerSpacing: CGFloat = 15
    static let outputModeHeight: CGFloat = 28
    static let resultLineHeight: CGFloat = 16
    static let minimumTextLines: CGFloat = 8
    static let maximumTextLines: CGFloat = 24

    static var contentWidth: CGFloat {
        width - (horizontalInset * 2)
    }

    static var previewWidth: CGFloat {
        floor(contentWidth * previewWidthRatio)
    }

    static var textContentWidth: CGFloat {
        contentWidth - (contentCardInnerHorizontalPadding * 2)
    }

    static func previewHeight(for image: NSImage?) -> CGFloat {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return previewPlaceholderHeight
        }

        return max(
            previewPlaceholderHeight,
            round((previewWidth * image.size.height) / image.size.width)
        )
    }

    static func previewSectionHeight(for image: NSImage?) -> CGFloat {
        previewHeight(for: image) + previewVerticalPadding
    }

    static func measuredLineCount(for text: String) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return minimumTextLines
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]

        let rect = NSString(string: trimmed).boundingRect(
            with: CGSize(width: textContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        return max(minimumTextLines, ceil(rect.height / resultLineHeight))
    }

    static func resultCardHeight(for text: String) -> CGFloat {
        let lineCount = min(maximumTextLines, measuredLineCount(for: text))
        return contentCardTopPadding +
            outputModeHeight +
            contentCardInnerSpacing +
            (lineCount * resultLineHeight) +
            contentCardBottomPadding
    }

    static func resultPanelHeight(text: String, image: NSImage?, includePreview: Bool) -> CGFloat {
        let previewSection = includePreview ? previewSectionHeight(for: image) + sectionSpacing : 0
        return headerHeight +
            topContentPadding +
            previewSection +
            resultCardHeight(for: text) +
            sectionSpacing +
            footerHeight +
            bottomContentPadding
    }
}

enum ResultPopoverPalette {
    static let accent = Color(red: 1.0, green: 0.345, blue: 0.231)
    static let baseText = Color(nsColor: .labelColor)
    static let secondaryText = Color.black.opacity(0.5)
    static let panelBackground = Color.white.opacity(0.82)
    static let softFill = Color.black.opacity(0.05)
    static let controlFill = Color.black.opacity(0.02)
    static let controlStroke = Color.black.opacity(0.04)
    static let shadowColor = Color.black.opacity(0.08)
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

extension Font {
    static let resultPopoverTitle = Font.system(size: 24, weight: .heavy, design: .rounded)
    static let resultPopoverIcon = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let resultPopoverSymbol = Font.system(size: 12, weight: .heavy, design: .rounded)
    static let resultPopoverBody = Font.system(size: 12, weight: .regular)
    static let resultPopoverMedium = Font.system(size: 12, weight: .medium)
    static let resultPopoverButton = Font.system(size: 12, weight: .regular, design: .rounded)
}
