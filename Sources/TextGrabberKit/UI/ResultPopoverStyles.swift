import AppKit
import SwiftUI

enum ResultPopoverLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 483
    static let compactHeight: CGFloat = 360
    static let cornerRadius: CGFloat = 24
    static let contentCardCornerRadius: CGFloat = 12
    static let headerHeight: CGFloat = 49
    static let horizontalInset: CGFloat = 10
    static let previewCornerRadius: CGFloat = 12
    static let contentCardHeight: CGFloat = 200
    static let topContentPadding: CGFloat = 10
    static let bottomContentPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
    static let footerHeight: CGFloat = 32
    static let previewVerticalPadding: CGFloat = 36
    static let previewWidthRatio: CGFloat = 0.8
    static let previewPlaceholderHeight: CGFloat = 110
    static let contentCardTopPadding: CGFloat = 10
    static let contentCardBottomPadding: CGFloat = 10
    static let contentCardInnerHorizontalPadding: CGFloat = 10
    static let contentCardInnerSpacing: CGFloat = 10
    static let outputModeHeight: CGFloat = 28
    static let resultLineHeight: CGFloat = 16
    static let minimumTextLines: CGFloat = 8
    static let maximumTextLines: CGFloat = 24
    static let minimumTranslationLines: CGFloat = 3
    static let maximumTranslationLines: CGFloat = 12
    static let translationCardSpacing: CGFloat = 10
    static let translationCardTopPadding: CGFloat = 10
    static let translationCardBottomPadding: CGFloat = 10
    static let translationCardHorizontalPadding: CGFloat = 10
    static let translationHeaderHeight: CGFloat = 16
    static let bodyParagraphSpacing: CGFloat = 6
    static let readingOptimizedParagraphSpacing: CGFloat = 6
    static let translationParagraphSpacing: CGFloat = 6

    static var contentWidth: CGFloat {
        width - (horizontalInset * 2)
    }

    static var previewWidth: CGFloat {
        floor(contentWidth * previewWidthRatio)
    }

    static var textContentWidth: CGFloat {
        contentWidth - (contentCardInnerHorizontalPadding * 2)
    }

    static var translationTextWidth: CGFloat {
        textContentWidth -
            (translationCardHorizontalPadding * 2)
    }

    static func previewHeight(for image: NSImage?) -> CGFloat {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return previewPlaceholderHeight
        }

        return round((previewWidth * image.size.height) / image.size.width)
    }

    static func previewSectionHeight(for image: NSImage?) -> CGFloat {
        previewHeight(for: image) + previewVerticalPadding
    }

    static func measuredLineCount(for text: String, width: CGFloat = textContentWidth) -> CGFloat {
        let measuredHeight = measuredTextHeight(for: text, width: width)
        return max(minimumTextLines, ceil(measuredHeight / resultLineHeight))
    }

    static func measuredTextHeight(
        for text: String,
        width: CGFloat,
        paragraphSpacing: CGFloat = 0
    ) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return minimumTextLines * resultLineHeight
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = paragraphSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]

        let rect = NSString(string: trimmed).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        return ceil(rect.height)
    }

    static func normalizedParagraphText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
    }

    static func paragraphDisplayLines(from text: String) -> [String] {
        normalizedParagraphText(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func resultTextHeight(for text: String, outputMode: OCRTextOutputMode) -> CGFloat {
        let measuredHeight: CGFloat
        switch outputMode {
        case .readingOptimized:
            measuredHeight = measuredTextHeight(
                for: normalizedParagraphText(text),
                width: textContentWidth,
                paragraphSpacing: readingOptimizedParagraphSpacing
            )
        case .sourceLayout:
            measuredHeight = measuredTextHeight(for: text, width: textContentWidth)
        }

        let minimumHeight = minimumTextLines * resultLineHeight
        let maximumHeight = maximumTextLines * resultLineHeight
        return min(maximumHeight, max(minimumHeight, measuredHeight))
    }

    static func visibleResultTextHeight(for text: String, outputMode: OCRTextOutputMode) -> CGFloat {
        let measuredHeight: CGFloat
        switch outputMode {
        case .readingOptimized:
            measuredHeight = measuredTextHeight(
                for: normalizedParagraphText(text),
                width: textContentWidth,
                paragraphSpacing: readingOptimizedParagraphSpacing
            )
        case .sourceLayout:
            measuredHeight = measuredTextHeight(for: text, width: textContentWidth)
        }

        let minimumHeight = minimumTextLines * resultLineHeight
        let maximumHeight = maximumTextLines * resultLineHeight
        return min(maximumHeight, max(minimumHeight, measuredHeight))
    }

    static func resultPrimaryCardHeight(for text: String, outputMode: OCRTextOutputMode = .readingOptimized) -> CGFloat {
        let textHeight = visibleResultTextHeight(for: text, outputMode: outputMode)
        return contentCardTopPadding +
            outputModeHeight +
            contentCardInnerSpacing +
            textHeight +
            contentCardBottomPadding
    }

    static func visibleTranslationTextHeight(for text: String?) -> CGFloat {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let measuredHeight = measuredTextHeight(
            for: normalizedParagraphText(text),
            width: translationTextWidth,
            paragraphSpacing: translationParagraphSpacing
        )
        let minimumHeight = minimumTranslationLines * resultLineHeight
        let maximumHeight = maximumTranslationLines * resultLineHeight
        let textHeight = min(maximumHeight, max(minimumHeight, measuredHeight))

        return textHeight
    }

    static func translationSectionHeight(for text: String?) -> CGFloat {
        let textHeight = visibleTranslationTextHeight(for: text)
        guard textHeight > 0 else {
            return 0
        }

        return translationCardTopPadding +
            translationHeaderHeight +
            translationCardSpacing +
            textHeight +
            translationCardBottomPadding
    }

    static func resultCardHeight(
        for text: String,
        translationText: String? = nil,
        showsTranslationPane: Bool = false,
        outputMode: OCRTextOutputMode = .readingOptimized
    ) -> CGFloat {
        let primaryCardHeight = resultPrimaryCardHeight(for: text, outputMode: outputMode)

        guard showsTranslationPane else {
            return primaryCardHeight
        }

        return primaryCardHeight +
            sectionSpacing +
            translationSectionHeight(for: translationText)
    }

    static func resultPanelHeight(
        text: String,
        translationText: String? = nil,
        showsTranslationPane: Bool = false,
        outputMode: OCRTextOutputMode = .readingOptimized,
        image: NSImage?,
        includePreview: Bool
    ) -> CGFloat {
        let previewSection = includePreview ? previewSectionHeight(for: image) + sectionSpacing : 0
        return headerHeight +
            topContentPadding +
            previewSection +
            resultCardHeight(
                for: text,
                translationText: translationText,
                showsTranslationPane: showsTranslationPane,
                outputMode: outputMode
            ) +
            sectionSpacing +
            footerHeight +
            bottomContentPadding
    }
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
